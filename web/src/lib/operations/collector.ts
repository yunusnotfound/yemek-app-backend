import "server-only";
import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { callBackend } from "@/lib/api/client";
import type { OperationsSnapshot, RuntimeMetrics } from "./types";

const CACHE_MS = 15_000;
let lastSnapshot: OperationsSnapshot | null = null;
let lastHostSnapshot: OperationsSnapshot | null = null;
let expiresAt = 0;
let pending: Promise<OperationsSnapshot> | null = null;

export class OperationsUnavailable extends Error {}

function connection() {
  const host = process.env.OPS_SSH_HOST;
  const user = process.env.OPS_SSH_USER;
  const key = process.env.OPS_SSH_KEY;
  const port = Number(process.env.OPS_SSH_PORT || 22);
  if (!host || !user || !key) throw new OperationsUnavailable("Sunucu ölçüm bağlantısı yapılandırılmamış.");
  if (!/^[a-zA-Z0-9][a-zA-Z0-9.-]*$/.test(host)
    || !/^[a-z_][a-z0-9_-]*$/i.test(user) || !path.isAbsolute(key)
    || !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new OperationsUnavailable("Sunucu ölçüm bağlantısı ayarları geçersiz.");
  }
  return { host, user, key, port };
}

async function collectHost(): Promise<OperationsSnapshot> {
  const config = connection();
  const script = await readFile(path.join(process.cwd(), "src/lib/operations/collect-operations.py"), "utf8");
  const raw = await new Promise<string>((resolve, reject) => {
    const child = execFile("/usr/bin/ssh", [
      "-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
      "-o", "IdentitiesOnly=yes", "-o", "ConnectTimeout=5",
      "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=2",
      "-i", config.key, "-p", String(config.port), `${config.user}@${config.host}`, "python3 -",
    ], { timeout: 18_000, maxBuffer: 512 * 1024, encoding: "utf8" }, (error, stdout) => {
      if (error) reject(new OperationsUnavailable("Canlı sunucudan ölçüm alınamadı."));
      else resolve(stdout);
    });
    child.stdin?.on("error", () => { /* execFile callback reports connection failures. */ });
    child.stdin?.end(script);
  });
  const value = JSON.parse(raw) as OperationsSnapshot;
  if (!value.collectedAt || !Number.isFinite(Date.parse(value.collectedAt))
    || !Array.isArray(value.containers) || !Array.isArray(value.partialErrors)) {
    throw new OperationsUnavailable("Sunucu ölçüm yanıtı geçersiz.");
  }
  return value;
}

async function collectRuntime(token: string): Promise<{ runtime: RuntimeMetrics | null; runtimeError: string | null }> {
  const response = await callBackend("/admin/operations/runtime", { token, signal: AbortSignal.timeout(8_000) });
  if (!response.ok) return {
    runtime: null,
    runtimeError: response.status === 404 ? "API trafik ölçümü henüz yayında değil." : "API çalışma zamanı ölçümü alınamadı.",
  };
  const value = (await response.json().catch(() => null))?.runtime;
  if (!value || typeof value.requests !== "number" || !value.sampledAt) {
    return { runtime: null, runtimeError: "API çalışma zamanı ölçüm yanıtı geçersiz." };
  }
  return { runtime: value as RuntimeMetrics, runtimeError: null };
}

function runtimeOnlySnapshot(collectionMs: number): OperationsSnapshot {
  return {
    collectedAt: new Date(Date.now()).toISOString(), collectionMs, source: "API çalışma zamanı",
    partialErrors: ["Canlı sunucu ölçümü alınamadı; yalnızca API ölçümleri gösteriliyor."],
    host: null, containers: [], database: null, redis: null,
    http: { api: null, web: null, tls: null }, logs: null, backups: null,
    release: null, integrations: null, queues: null, runtime: null, runtimeError: null,
  };
}

/** Every caller must pass the route's live admin authorization before using this shared cache. */
export async function getOperationsSnapshot(token: string): Promise<OperationsSnapshot> {
  if (lastSnapshot && Date.now() < expiresAt) return lastSnapshot;
  if (pending) return pending;
  pending = (async () => {
    try {
      const started = Date.now();
      const [hostResult, runtimeResult] = await Promise.allSettled([collectHost(), collectRuntime(token)]);
      const runtime = runtimeResult.status === "fulfilled" ? runtimeResult.value : {
        runtime: null, runtimeError: "API çalışma zamanı ölçümü alınamadı.",
      };
      let host: OperationsSnapshot;
      if (hostResult.status === "fulfilled") {
        lastHostSnapshot = hostResult.value;
        host = lastHostSnapshot;
      } else if (lastHostSnapshot) {
        // Preserve the host sample's original timestamp while independently
        // merging the newest API sample (which carries its own sampledAt).
        host = {
          ...lastHostSnapshot,
          partialErrors: [...new Set([...lastHostSnapshot.partialErrors, "Sunucu bağlantısı: eski ölçümler gösteriliyor."])],
        };
      } else if (runtime.runtime) {
        host = runtimeOnlySnapshot(Date.now() - started);
      } else {
        if (hostResult.reason instanceof OperationsUnavailable) throw hostResult.reason;
        throw new OperationsUnavailable("Teknik ölçümler şu anda alınamıyor.");
      }
      lastSnapshot = { ...host, ...runtime };
      expiresAt = Date.now() + CACHE_MS;
      return lastSnapshot;
    } catch (error) {
      if (error instanceof OperationsUnavailable) throw error;
      throw new OperationsUnavailable("Teknik ölçümler şu anda alınamıyor.");
    } finally {
      pending = null;
    }
  })();
  return pending;
}

import "server-only";
import { callBackendJson } from "@/lib/api/client";
import { getRefreshToken, setSession, clearSession } from "@/lib/auth/session";
import { createHash } from "node:crypto";

type RefreshResult = { accessToken: string; refreshToken: string };
// One backend rotation per cookie, including concurrent BFF requests. Retain
// the result briefly for requests already in flight with the old cookie.
const rotations = new Map<string, Promise<{ data?: RefreshResult; revoked?: boolean }>>();

/**
 * Refresh token ile yeni access/refresh token alır ve çerezleri günceller.
 * Başarılıysa yeni access token'ı döndürür, başarısızsa oturumu temizleyip null döner.
 * Yalnızca route handler içinde çağrılmalı (çerez yazımı gerektirir).
 */
export async function refreshSession(): Promise<string | null> {
  const refreshToken = await getRefreshToken();
  if (!refreshToken) return null;

  const key = createHash("sha256").update(refreshToken).digest("hex");
  let rotation = rotations.get(key);
  if (!rotation) {
    rotation = (async () => {
      const res = await callBackendJson("/auth/refresh", "POST", { refreshToken });
      if (!res.ok) return { revoked: res.status === 401 };
      const data = await res.json().catch(() => null);
      if (typeof data?.accessToken !== "string" || typeof data?.refreshToken !== "string") return {};
      return { data: data as RefreshResult };
    })();
    rotations.set(key, rotation);
    void rotation.finally(() => { setTimeout(() => rotations.delete(key), 5000).unref(); });
  }
  const { data, revoked } = await rotation;
  if (!data) {
    if (revoked) await clearSession();
    return null;
  }
  await setSession(data.accessToken, data.refreshToken);
  return data.accessToken;
}

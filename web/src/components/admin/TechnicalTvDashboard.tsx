"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
import { Activity, ChevronLeft, ChevronRight, Maximize, Minimize, Pause, Play, RefreshCw } from "lucide-react";
import type { OperationsSnapshot } from "@/lib/operations/types";
import { TvDashboard } from "./TvDashboard";
import styles from "./TechnicalTvDashboard.module.css";

const REFRESH_MS = 20_000;
const ROTATION_MS = 25_000;
const STALE_MS = 90_000;
const VIEWS = ["Teknik özet", "Veri & kuyruklar", "Yazılım & tanılama", "Satış & iş özeti"];
const timeFormat = new Intl.DateTimeFormat("tr-TR", { timeZone: "Europe/Istanbul", hour: "2-digit", minute: "2-digit", second: "2-digit" });
const dateFormat = new Intl.DateTimeFormat("tr-TR", { timeZone: "Europe/Istanbul", day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });
const numberFormat = new Intl.NumberFormat("tr-TR", { maximumFractionDigits: 1 });
type SectionKey = "host" | "containers" | "database" | "redis" | "logs" | "backups" | "release" | "integrations" | "queues" | "runtime" | "api" | "web" | "tls";
const SECTION_LABELS: Record<SectionKey, string> = { host: "Sunucu", containers: "Container", database: "PostgreSQL", redis: "Redis", logs: "Loglar", backups: "Yedek", release: "Sürüm", integrations: "Entegrasyon", queues: "Kuyruklar", runtime: "API telemetrisi", api: "API sağlık", web: "Web", tls: "TLS" };
type Sample = { at: string; cpu: number | null; ram: number | null; p95: number | null };
type Telemetry = { data: OperationsSnapshot | null; retained: SectionKey[]; history: Sample[] };

function number(value: number | null | undefined) { return value == null || !Number.isFinite(value) ? "—" : numberFormat.format(value); }
function percent(value: number | null | undefined) { return value == null || !Number.isFinite(value) ? "—" : `${number(value)}%`; }
function ms(value: number | null | undefined) { return value == null || !Number.isFinite(value) ? "—" : `${number(value)} ms`; }
function bytes(value: number | null | undefined) {
  if (value == null || !Number.isFinite(value)) return "—";
  const units = ["B", "KiB", "MiB", "GiB", "TiB"];
  const unit = value <= 0 ? 0 : Math.min(4, Math.floor(Math.log(value) / Math.log(1024)));
  return `${number(value / 1024 ** unit)} ${units[unit]}`;
}
function duration(seconds: number | null | undefined) {
  if (seconds == null || !Number.isFinite(seconds)) return "—";
  if (seconds < 60) return `${number(Math.floor(seconds))} sn`;
  if (seconds < 3600) return `${number(Math.floor(seconds / 60))} dk`;
  if (seconds < 86400) return `${number(Math.floor(seconds / 3600))} sa`;
  return `${number(Math.floor(seconds / 86400))} gün`;
}
function date(value: string | null | undefined) {
  if (!value || !Number.isFinite(Date.parse(value))) return "—";
  return dateFormat.format(new Date(value));
}
function stateLabel(value: string | null | undefined) {
  if (!value) return "—";
  const labels: Record<string, string> = { connected: "Bağlı", disconnected: "Bağlı değil", running: "Çalışıyor", healthy: "Sağlıklı", unhealthy: "Sorunlu", starting: "Başlıyor", exited: "Durdu", restarting: "Yeniden başlıyor", paused: "Duraklatıldı", dead: "Durdu", created: "Oluşturuldu", none: "Probe yok", ok: "Hazır", error: "Hata", live: "Canlı", sandbox: "Sandbox", unconfigured: "Yapılandırılmadı" };
  return labels[value.toLowerCase()] ?? value;
}

// A missing source never becomes a healthy zero. Keep its last measurement and label it.
function acceptSnapshot(previous: Telemetry, next: OperationsSnapshot): Telemetry {
  const data = { ...next, http: { ...next.http } };
  const retained: SectionKey[] = [];
  const keys = ["host", "database", "redis", "logs", "backups", "release", "integrations", "queues", "runtime"] as const;
  for (const key of keys) {
    if (next[key] === null && previous.data?.[key] != null) {
      Object.assign(data, { [key]: previous.data[key] });
      retained.push(key);
    }
  }
  for (const key of ["api", "web", "tls"] as const) {
    if (next.http[key] === null && previous.data?.http[key] != null) {
      Object.assign(data.http, { [key]: previous.data.http[key] });
      retained.push(key);
    }
  }
  if (!next.containers.length && next.partialErrors.length && previous.data?.containers.length) {
    data.containers = previous.data.containers;
    retained.push("containers");
  }
  const sampled = previous.history.at(-1)?.at !== next.collectedAt;
  const history = sampled ? [...previous.history, { at: next.collectedAt, cpu: next.host?.cpuPercent ?? null, ram: next.host?.memory.percent ?? null, p95: next.runtime?.p95Ms ?? null }].slice(-30) : previous.history;
  return { data, retained, history };
}

function Sparkline({ values, label }: { values: (number | null)[]; label: string }) {
  const valid = values.filter((value): value is number => value !== null && Number.isFinite(value));
  if (valid.length < 2) return <span className={styles.sparkPlaceholder}>Grafik için ölçüm birikiyor</span>;
  const max = Math.max(...valid, 1);
  const points = values.map((value, index) => value === null ? null : `${index / Math.max(values.length - 1, 1) * 180},${32 - value / max * 28}`);
  const segments: string[][] = [[]];
  for (const point of points) { if (point === null) segments.push([]); else segments[segments.length - 1].push(point); }
  return <svg className={styles.sparkline} viewBox="0 0 180 36" role="img" aria-label={label} preserveAspectRatio="none">{segments.map((segment, index) => segment.length > 1 ? <polyline key={index} points={segment.join(" ")} fill="none" stroke="currentColor" strokeWidth="2" vectorEffect="non-scaling-stroke" /> : null)}</svg>;
}

function Metric({ label, value, detail, valuePercent, warning, chart }: { label: string; value: string; detail: ReactNode; valuePercent?: number; warning?: boolean; chart?: ReactNode }) {
  return <article className={`${styles.metric} ${warning ? styles.metricWarning : ""}`}>
    <p>{label}</p><strong>{value}</strong><span>{detail}</span>
    {valuePercent !== undefined && <div className={styles.meter} aria-hidden="true"><i style={{ width: `${Math.max(0, Math.min(100, valuePercent))}%` }} /></div>}
    {chart}
  </article>;
}
function Panel({ title, subtitle, stale, children, className = "" }: { title: string; subtitle?: string; stale?: boolean; children: ReactNode; className?: string }) {
  return <section className={`${styles.panel} ${className}`}><div className={styles.panelTitle}><h2>{title}</h2>{stale && <span className={styles.staleBadge}>Eski veri</span>}</div>{subtitle && <p className={styles.subtitle}>{subtitle}</p>}{children}</section>;
}
function Row({ label, value, warn = false }: { label: string; value: ReactNode; warn?: boolean }) { return <div className={styles.row}><span>{label}</span><strong className={warn ? styles.warning : ""}>{value}</strong></div>; }
function Empty({ children = "Bu kaynaktan ölçüm alınamadı." }: { children?: ReactNode }) { return <p className={styles.empty}>{children}</p>; }
function imageId(value: string) { return value.replace(/^sha256:/, "").slice(0, 12) || "—"; }

export function TechnicalTvDashboard() {
  const router = useRouter();
  const [telemetry, setTelemetry] = useState<Telemetry>({ data: null, retained: [], history: [] });
  const [now, setNow] = useState<number | null>(null);
  const [view, setView] = useState(0);
  const [businessRefreshKey, setBusinessRefreshKey] = useState(0);
  const [paused, setPaused] = useState(false);
  const [online, setOnline] = useState(true);
  const [failure, setFailure] = useState(false);
  const [accessError, setAccessError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [fullscreen, setFullscreen] = useState(false);
  const [fullscreenError, setFullscreenError] = useState<string | null>(null);
  const mounted = useRef(false);
  const inFlight = useRef(false);
  const denied = useRef(false);
  const controller = useRef<AbortController | null>(null);

  const refresh = useCallback(async () => {
    if (inFlight.current || !mounted.current || denied.current) return;
    inFlight.current = true;
    setRefreshing(true);
    const request = new AbortController();
    controller.current = request;
    const timeout = setTimeout(() => request.abort(), 60_000);
    try {
      const response = await fetch("/api/admin/operations", { credentials: "same-origin", cache: "no-store", signal: request.signal });
      if (!mounted.current) return;
      if (response.status === 401 || response.status === 403) {
        denied.current = true;
        setTelemetry({ data: null, retained: [], history: [] });
        setAccessError(response.status === 403 ? "Bu ekranı görüntülemek için yönetici yetkisi gerekiyor." : "Oturum sona erdi. Giriş ekranına yönlendiriliyorsunuz.");
        if (response.status === 401) router.replace("/giris?next=%2Fadmin%2Ftv");
        return;
      }
      if (!response.ok) throw new Error("Telemetry unavailable");
      const next = await response.json() as OperationsSnapshot;
      if (!next.collectedAt || !Number.isFinite(Date.parse(next.collectedAt)) || !Array.isArray(next.partialErrors) || !next.http || !Array.isArray(next.containers)) throw new Error("Invalid telemetry");
      if (mounted.current) {
        setTelemetry(previous => acceptSnapshot(previous, next));
        setFailure(false);
      }
    } catch {
      if (mounted.current) setFailure(true);
    } finally {
      clearTimeout(timeout);
      inFlight.current = false;
      controller.current = null;
      if (mounted.current) setRefreshing(false);
    }
  }, [router]);

  useEffect(() => {
    mounted.current = true;
    let cancelled = false;
    let pollTimer: ReturnType<typeof setTimeout>;
    const poll = async () => { await refresh(); if (!cancelled) pollTimer = setTimeout(poll, REFRESH_MS); };
    pollTimer = setTimeout(poll, 0);
    const tick = () => setNow(Date.now());
    const networkChanged = () => setOnline(navigator.onLine);
    const fullscreenChanged = () => setFullscreen(Boolean(document.fullscreenElement));
    tick(); networkChanged(); fullscreenChanged();
    const clock = setInterval(tick, 1000);
    window.addEventListener("online", networkChanged);
    window.addEventListener("offline", networkChanged);
    document.addEventListener("fullscreenchange", fullscreenChanged);
    const remoteKey = (event: KeyboardEvent) => {
      if (!(event.key === "ArrowLeft" || event.key === "ArrowRight")) return;
      if ((event.target as HTMLElement | null)?.closest?.("button,a,input,textarea,select,[contenteditable=true]")) return;
      event.preventDefault();
      setView(previous => (previous + (event.key === "ArrowLeft" ? VIEWS.length - 1 : 1)) % VIEWS.length);
    };
    window.addEventListener("keydown", remoteKey);
    return () => {
      cancelled = true; mounted.current = false; controller.current?.abort();
      clearTimeout(pollTimer); clearInterval(clock);
      window.removeEventListener("online", networkChanged);
      window.removeEventListener("offline", networkChanged);
      window.removeEventListener("keydown", remoteKey);
      document.removeEventListener("fullscreenchange", fullscreenChanged);
    };
  }, [refresh]);

  useEffect(() => {
    if (paused) return;
    const rotation = setTimeout(() => setView(previous => (previous + 1) % VIEWS.length), ROTATION_MS);
    return () => clearTimeout(rotation);
  }, [paused, view]);

  async function toggleFullscreen() {
    setFullscreenError(null);
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else if (document.documentElement.requestFullscreen) await document.documentElement.requestFullscreen();
      else setFullscreenError("Bu TV tarayıcısında tam ekran desteklenmiyor. Tarayıcının ekran seçeneğini kullanın.");
    } catch { setFullscreenError("Tam ekran açılamadı. Tarayıcının tam ekran seçeneğini kullanın."); }
  }

  const s = telemetry.data;
  const host = s?.host;
  const runtime = s?.runtime;
  const db = s?.database;
  const redis = s?.redis;
  const api = s?.http.api;
  const queues = s?.queues;
  const stale = failure || !online || Boolean(s?.partialErrors.includes("Sunucu bağlantısı: eski ölçümler gösteriliyor.")) || Boolean(s && now && now - Date.parse(s.collectedAt) > STALE_MS);
  const runtimeStale = failure || !online || Boolean(runtime && now && (!Number.isFinite(Date.parse(runtime.sampledAt)) || now - Date.parse(runtime.sampledAt) > STALE_MS));
  const retained = (key: SectionKey) => (key === "runtime" ? runtimeStale : stale) || telemetry.retained.includes(key);
  const partial = Boolean(s?.partialErrors.length || s?.runtimeError || telemetry.retained.length);
  const unhealthyContainers = s?.containers.filter(container => container.state !== "running" || container.health === "unhealthy") ?? [];
  const serviceProblem = Boolean(unhealthyContainers.length || (api && (api.httpStatus !== 200 || api.status !== "ok" || api.database !== "connected" || api.redis !== "connected")) || (s?.http.web && s.http.web.httpStatus >= 400));
  const status = accessError ? "YETKİ GEREKİYOR" : !s ? failure ? "VERİ ALINAMADI" : "BAĞLANIYOR" : stale ? "VERİ ESKİ" : serviceProblem ? "SERVİS SORUNU" : partial || !api || !host ? "TELEMETRİ EKSİK" : "SERVİSLER HAZIR";
  const paymentMode = api?.paymentMode ?? s?.integrations?.paymentMode;
  const alerts = [
    !online && "TV bağlantısı çevrimdışı",
    stale && s && "Son ölçümler korunuyor · güncel değil",
    partial && `Eksik kaynaklar${telemetry.retained.length ? `: ${telemetry.retained.map(key => SECTION_LABELS[key]).join(", ")}` : ` · ${s?.partialErrors.length || 1} ölçüm sorunu`}`,
    serviceProblem && `Servis kontrolü gerekli${unhealthyContainers.length ? ` · ${unhealthyContainers.map(item => item.service).join(", ")}` : ""}`,
    paymentMode === "sandbox" && "Ödemeler SANDBOX modunda",
    paymentMode === "unconfigured" && "Ödeme entegrasyonu yapılandırılmamış",
    host && host.disk.percent >= 85 && `Disk doluluğu ${percent(host.disk.percent)}`,
    host && host.memory.percent >= 90 && `RAM kullanımı ${percent(host.memory.percent)}`,
    host && host.cpuPercent >= 90 && `CPU kullanımı ${percent(host.cpuPercent)}`,
    s?.backups && (s.backups.ageSeconds === null || s.backups.ageSeconds > 36 * 3600) && "Güncel yedek bulunamadı (>36 sa)",
    s?.http.tls && s.http.tls.daysRemaining < 14 && `TLS süresi: ${number(s.http.tls.daysRemaining)} gün`,
    runtime && runtime.statusCounts.serverError > 0 && `API 5xx: ${number(runtime.statusCounts.serverError)}`,
    queues && queues.staleRefunds > 0 && `Gecikmiş iade: ${number(queues.staleRefunds)}`,
  ].filter((alert): alert is string => typeof alert === "string");

  return <main className={styles.dashboard}>
    <header className={styles.header}>
      <div className={styles.brand}><span className={styles.logo}><Activity aria-hidden="true" /></span><div><p>BİTİR GİTSİN / TEKNİK OPERASYON</p><h1>{VIEWS[view]}</h1></div></div>
      <div className={`${styles.status} ${stale || serviceProblem || partial || !s || accessError ? styles.statusWarning : ""}`}><i />{status}</div>
      <div className={styles.clock}><strong>{now ? timeFormat.format(now) : "—"}</strong><span>Türkiye saati · {view + 1} / {VIEWS.length}</span></div>
    </header>

    <nav className={styles.navigation} aria-label="Teknik ekran kontrolleri" onKeyDown={event => {
      if (!["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)) return;
      const controls = Array.from(event.currentTarget.querySelectorAll<HTMLElement>("a,button:not(:disabled)"));
      const index = controls.indexOf(document.activeElement as HTMLElement);
      if (index < 0) return;
      event.preventDefault();
      controls[(index + (event.key === "ArrowLeft" || event.key === "ArrowUp" ? controls.length - 1 : 1)) % controls.length].focus();
    }}>
      <div className={styles.tabs}>{VIEWS.map((label, index) => <button key={label} onClick={() => setView(index)} aria-pressed={view === index} className={view === index ? styles.activeTab : ""}>{String(index + 1).padStart(2, "0")} <span>{label}</span></button>)}</div>
      <div className={styles.controls}>
        <button onClick={() => setView(previous => (previous + VIEWS.length - 1) % VIEWS.length)} aria-label="Önceki ekran" title="Önceki ekran"><ChevronLeft /></button>
        <button onClick={() => setPaused(previous => !previous)} aria-label={paused ? "Otomatik geçişi başlat" : "Otomatik geçişi duraklat"} title={paused ? "Otomatik geçişi başlat" : "Otomatik geçişi duraklat"}>{paused ? <Play /> : <Pause />}<span>{paused ? "Duraklatıldı" : "25 sn"}</span></button>
        <button onClick={() => setView(previous => (previous + 1) % VIEWS.length)} aria-label="Sonraki ekran" title="Sonraki ekran"><ChevronRight /></button>
        <button onClick={() => { setBusinessRefreshKey(previous => previous + 1); void refresh(); }} disabled={refreshing || Boolean(accessError)} aria-label="Verileri yenile" title="Verileri yenile"><RefreshCw className={refreshing ? styles.spinning : ""} /></button>
        <button onClick={() => void toggleFullscreen()} aria-label={fullscreen ? "Tam ekrandan çık" : "Tam ekran"} title={fullscreen ? "Tam ekrandan çık" : "Tam ekran"}>{fullscreen ? <Minimize /> : <Maximize />}</button>
        <Link href="/admin/tv?view=business" className={styles.businessLink}>İş metrikleri ↗</Link>
      </div>
    </nav>

    <div className={`${styles.alertBar} ${alerts.length || accessError || failure ? styles.alertWarning : ""}`} role="status">
      <span>{accessError || (!s ? failure ? "Sunucu ölçümleri alınamadı. 20 saniye sonra yeniden denenecek." : "Sunucu, servis ve uygulama ölçümleri alınıyor…" : alerts.length ? alerts.slice(0, 4).join("  ·  ") : "İzlenen servislerde etkin uyarı yok.")}</span>
      {alerts.length > 4 && <strong>+{alerts.length - 4} uyarı</strong>}
    </div>

    {accessError ? <div className={styles.accessError}><h2>Erişim sınırlandı</h2><p>{accessError}</p><Link href="/giris?next=%2Fadmin%2Ftv">Yönetici hesabıyla giriş yap</Link></div> : <div className={`${styles.content} ${view === 3 ? styles.salesContent : ""}`}>
      {view === 0 && <>
        <div className={styles.metrics}>
          <Metric label={`Paylaşımlı VPS CPU${retained("host") ? " · eski veri" : ""}`} value={percent(host?.cpuPercent)} detail={`${number(host?.cpuCores)} çekirdek · yük ${host?.loadAverage.map(value => number(value)).join(" / ") ?? "—"}`} warning={Boolean(host && host.cpuPercent >= 90)} chart={<Sparkline values={telemetry.history.map(item => item.cpu)} label="Bu tarayıcı oturumunda CPU ölçümleri" />} />
          <Metric label={`Paylaşımlı VPS RAM${retained("host") ? " · eski veri" : ""}`} value={percent(host?.memory.percent)} detail={`${bytes(host?.memory.usedBytes)} / ${bytes(host?.memory.totalBytes)}`} warning={Boolean(host && host.memory.percent >= 90)} chart={<Sparkline values={telemetry.history.map(item => item.ram)} label="Bu tarayıcı oturumunda RAM ölçümleri" />} />
          <Metric label={`Disk doluluğu${retained("host") ? " · eski veri" : ""}`} value={percent(host?.disk.percent)} detail={`${bytes(host?.disk.usedBytes)} / ${bytes(host?.disk.totalBytes)}`} valuePercent={host?.disk.percent} warning={Boolean(host && host.disk.percent >= 85)} />
          <Metric label={`API yanıt · p95${retained("runtime") ? " · eski veri" : ""}`} value={ms(runtime?.p95Ms)} detail={`${number(runtime?.requests)} istek · ${duration(runtime?.windowSeconds)} pencere`} chart={<Sparkline values={telemetry.history.map(item => item.p95)} label="Bu tarayıcı oturumunda API p95 ölçümleri" />} />
        </div>
        <div className={styles.overviewPanels}>
          <Panel title="Çalışan servisler" subtitle="CPU: çekirdek başına %100 · ağ: container ömrü boyunca" stale={retained("containers")}>
            {!s?.containers.length ? <Empty /> : <div className={styles.tableWrap}><table className={styles.serviceTable}><thead><tr><th>Servis</th><th>Durum / sağlık</th><th>CPU</th><th>Bellek</th><th>Restart</th><th>Ağ ↓ / ↑</th></tr></thead><tbody>{s.containers.map(item => <tr key={item.service}><td><strong>{item.service}</strong><small>{item.startedAt ? `Başlangıç ${date(item.startedAt)}` : "Başlangıç —"}</small></td><td className={item.state !== "running" || item.health === "unhealthy" ? styles.warning : ""}>{stateLabel(item.state)}<small>{stateLabel(item.health)}</small></td><td>{percent(item.cpuPercent)}</td><td>{bytes(item.memoryUsedBytes)}<small>{percent(item.memoryPercent)} · limit {item.memoryLimitBytes === null && item.memoryUsedBytes !== null ? "yok" : bytes(item.memoryLimitBytes)}</small></td><td>{number(item.restarts)}</td><td>{bytes(item.networkRxBytes)}<small>{bytes(item.networkTxBytes)}</small></td></tr>)}</tbody></table></div>}
          </Panel>
          <Panel title="Erişilebilirlik & trafik" stale={retained("api") || retained("web") || retained("runtime")}>
            <Row label="API sağlık / HTTP" value={api ? `${stateLabel(api.status)} / ${number(api.httpStatus)}` : "—"} warn={Boolean(api && api.httpStatus !== 200)} />
            <Row label="API probe gecikmesi" value={ms(api?.latencyMs)} />
            <Row label="Web HTTP / gecikme" value={s?.http.web ? `${s.http.web.httpStatus} / ${ms(s.http.web.latencyMs)}` : "—"} />
            <Row label="DB / Redis bağlantısı" value={api ? `${stateLabel(api.database)} / ${stateLabel(api.redis)}` : "—"} />
            <div className={styles.miniMetrics}><div><span>İstek / dk</span><strong>{number(runtime?.requestsPerMinute)}</strong></div><div><span>5xx / hata oranı</span><strong className={runtime?.statusCounts.serverError ? styles.warning : ""}>{number(runtime?.statusCounts.serverError)} <small>{percent(runtime?.errorRatePercent)}</small></strong></div><div><span>Devam eden</span><strong>{number(runtime?.inFlight)}</strong></div></div>
            <Row label="Sunucu / API uptime" value={`${duration(host?.uptimeSeconds)} / ${duration(runtime?.uptimeSeconds ?? api?.uptimeSeconds)}`} />
            <Row label="TLS kalan süre" value={s?.http.tls ? `${number(s.http.tls.daysRemaining)} gün · ${date(s.http.tls.expiresAt)}` : "—"} warn={Boolean(s?.http.tls && s.http.tls.daysRemaining < 14)} />
          </Panel>
        </div>
      </>}

      {view === 1 && <>
        <div className={styles.metrics}>
          <Metric label={`PostgreSQL bağlantı${retained("database") ? " · eski veri" : ""}`} value={`${number(db?.connections)} / ${number(db?.maxConnections)}`} detail={`${number(db?.activeQueries)} aktif · ${number(db?.waitingQueries)} bekleyen sorgu`} valuePercent={db && db.maxConnections > 0 ? db.connections / db.maxConnections * 100 : undefined} />
          <Metric label={`DB buffer cache${retained("database") ? " · eski veri" : ""}`} value={percent(db?.cacheHitPercent)} detail={`Boyut ${bytes(db?.sizeBytes)} · exec + psql ${ms(db?.latencyMs)}`} valuePercent={db?.cacheHitPercent ?? undefined} />
          <Metric label={`Redis işlem / sn${retained("redis") ? " · eski veri" : ""}`} value={number(redis?.opsPerSecond)} detail={`Cache isabeti ${percent(redis?.hitRatePercent)} · ${number(redis?.keyCount)} anahtar`} />
          <Metric label={`Son yedeğin yaşı${retained("backups") ? " · eski veri" : ""}`} value={duration(s?.backups?.ageSeconds)} detail={`${date(s?.backups?.latestAt)} · ${bytes(s?.backups?.sizeBytes)}`} warning={Boolean(s?.backups && (s.backups.ageSeconds === null || s.backups.ageSeconds > 36 * 3600))} />
        </div>
        <div className={styles.threePanels}>
          <Panel title="PostgreSQL" subtitle={db ? `v${db.version} · sayaçlar istatistik sıfırlamasından beri` : undefined} stale={retained("database")}>
            <Row label="Commit / rollback" value={`${number(db?.commits)} / ${number(db?.rollbacks)}`} />
            <Row label="Deadlock / uzun sorgu" value={`${number(db?.deadlocks)} / ${duration(db?.longestQuerySeconds)}`} warn={Boolean(db?.deadlocks)} />
            <Row label="İstatistik başlangıcı" value={date(db?.statsReset)} />
            <p className={styles.subheading}>En büyük tablolar · tahmini satır</p>
            {db?.tables.length ? <div className={styles.tableWrap}><table><thead><tr><th>Tablo</th><th>Satır</th><th>Boyut</th></tr></thead><tbody>{db.tables.slice(0, 5).map(table => <tr key={table.name}><td className={styles.code}>{table.name}</td><td>{number(table.rows)}</td><td>{bytes(table.bytes)}</td></tr>)}</tbody></table></div> : <Empty />}
          </Panel>
          <Panel title="Redis" subtitle={redis ? `v${redis.version} · sayaçlar Redis başlangıcından beri` : undefined} stale={retained("redis")}>
            <Row label="Bellek / limit" value={redis ? `${bytes(redis.usedMemoryBytes)} / ${redis.maxMemoryBytes === 0 ? "Sınırsız" : bytes(redis.maxMemoryBytes)}` : "—"} />
            <Row label="Fragmentation" value={redis ? `${number(redis.fragmentationRatio)}×` : "—"} />
            <Row label="İstemci / bloke" value={`${number(redis?.clients)} / ${number(redis?.blockedClients)}`} warn={Boolean(redis?.blockedClients)} />
            <Row label="Eviction / reddedilen" value={`${number(redis?.evictedKeys)} / ${number(redis?.rejectedConnections)}`} warn={Boolean(redis?.evictedKeys || redis?.rejectedConnections)} />
            <Row label="Bağlanma + INFO" value={ms(redis?.latencyMs)} />
            <Row label="AOF / RDB" value={redis ? `${stateLabel(redis.aofStatus)} / ${stateLabel(redis.rdbStatus)}` : "—"} />
            <Row label="Son Redis kaydı" value={date(redis?.lastSaveAt)} />
            <Row label="Redis uptime" value={duration(redis?.uptimeSeconds)} />
          </Panel>
          <Panel title="İş kuyrukları & yedek" subtitle="Anlık kayıt sayıları · geciken işlemler" stale={retained("queues") || retained("backups")}>
            <Row label="Ödeme bekleyen" value={number(queues?.awaitingPayment)} />
            <Row label="Süresi dolan rezervasyon" value={number(queues?.expiredPaymentHolds)} warn={Boolean(queues?.expiredPaymentHolds)} />
            <Row label="Bekleyen iade" value={number(queues?.pendingRefunds)} />
            <Row label="Gecikmiş iade" value={number(queues?.staleRefunds)} warn={Boolean(queues?.staleRefunds)} />
            <Row label="Onay bekleyen" value={number(queues?.heldApprovals)} />
            <Row label="Mevcut yedek sayısı" value={number(s?.backups?.count)} />
            <p className={styles.note}>Yedek dosyasının varlığı ve yaşı izlenir. Geri yüklenebilirlik bu ekranda test edilmez.</p>
          </Panel>
        </div>
      </>}

      {view === 2 && <>
        <div className={styles.metrics}>
          <Metric label={`Node.js heap${retained("runtime") ? " · eski veri" : ""}`} value={bytes(runtime?.heapUsedBytes)} detail={`Ayrılan ${bytes(runtime?.heapTotalBytes)} · RSS ${bytes(runtime?.rssBytes)}`} valuePercent={runtime && runtime.heapTotalBytes > 0 ? runtime.heapUsedBytes / runtime.heapTotalBytes * 100 : undefined} />
          <Metric label={`Event loop · p95${retained("runtime") ? " · eski veri" : ""}`} value={ms(runtime?.eventLoopP95Ms)} detail={`${duration(runtime?.eventLoopWindowSeconds)} ölçüm penceresi · Node ${runtime?.nodeVersion ?? "—"}`} />
          <Metric label={`API 5xx${retained("runtime") ? " · eski veri" : ""}`} value={number(runtime?.statusCounts.serverError)} detail={`${percent(runtime?.errorRatePercent)} hata · ${duration(runtime?.windowSeconds)} pencere`} warning={Boolean(runtime?.statusCounts.serverError)} />
          <Metric label={`Log hata / uyarı${retained("logs") ? " · eski veri" : ""}`} value={`${number(s?.logs?.errors)} / ${number(s?.logs?.warnings)}`} detail={`${number(s?.logs?.windowMinutes)} dk · ${number(s?.logs?.sampledLines)} satır${s?.logs?.limited ? " · sınırlandırıldı" : ""}`} warning={Boolean(s?.logs?.errors)} />
        </div>
        <div className={styles.softwarePanels}>
          <Panel title="Entegrasyon yapılandırması" subtitle="Ayarın varlığını gösterir; bağlantı testi değildir." stale={retained("integrations")}>
            {([['Sentry', 'sentry'], ['E-posta', 'email'], ['Google OAuth', 'google'], ['Apple OAuth', 'apple'], ['Ödeme', 'payments']] as const).map(([label, key]) => <Row key={key} label={label} value={s?.integrations ? s.integrations[key] ? "Yapılandırıldı" : "Kapalı" : "—"} />)}
            <Row label="Ödeme modu" value={stateLabel(paymentMode)} warn={paymentMode === "sandbox" || paymentMode === "unconfigured"} />
            <Row label="Alloy durumu" value={stateLabel(s?.integrations?.alloy)} />
            <Row label="Sunucu swap" value={`${bytes(host?.swap.usedBytes)} / ${bytes(host?.swap.totalBytes)}`} />
          </Panel>
          <Panel title="Sürüm & çalışan image" subtitle="Checkout, çalışan image sürümünü kanıtlamaz." stale={retained("release") || retained("containers")}>
            <Row label="Sunucu checkout" value={<code>{s?.release?.checkoutSha.slice(0, 12) || "—"}</code>} />
            <Row label="Commit zamanı" value={date(s?.release?.checkoutAt)} />
            <Row label="Çalışma ağacı" value={s?.release ? s.release.checkoutDirty ? "Değişiklik var" : "Temiz" : "—"} warn={s?.release?.checkoutDirty} />
            <Row label="Son migration" value={<span className={styles.migration}>{db?.lastMigration ?? "—"}</span>} />
            <p className={styles.subheading}>Çalışan container image ID</p>
            <div className={styles.tableWrap}><table><thead><tr><th>Servis</th><th>Image</th><th>Oluşturma</th></tr></thead><tbody>{s?.containers.map(item => <tr key={item.service}><td>{item.service}</td><td><code>{imageId(item.imageId)}</code></td><td>{date(item.imageCreatedAt)}</td></tr>)}</tbody></table></div>
          </Panel>
          <Panel title="Tanılama" subtitle="Toplu log grupları ve API route şablonları" stale={retained("logs") || retained("runtime")}>
            <div className={styles.logGroups}>{s?.logs ? s.logs.categories.length ? s.logs.categories.slice(0, 3).map(item => <Row key={item.label} label={item.label} value={number(item.count)} warn={item.count > 0} />) : <p className={styles.note}>Örneklenen loglarda hata grubu yok.</p> : <Empty />}</div>
            <p className={styles.subheading}>En yavaş route · p95 / istek / 5xx</p>
            {runtime?.slowRoutes.length ? <div className={styles.tableWrap}><table className={styles.routeTable}><thead><tr><th>Route</th><th>p95</th><th>İstek</th><th>5xx</th></tr></thead><tbody>{runtime.slowRoutes.slice(0, 5).map(route => <tr key={`${route.method}:${route.route}`}><td><span>{route.method}</span><code>{route.route}</code></td><td>{ms(route.p95Ms)}</td><td>{number(route.requests)}</td><td className={route.errors ? styles.warning : ""}>{number(route.errors)}</td></tr>)}</tbody></table></div> : <Empty>{runtime ? "Bu pencerede route ölçümü yok." : "API telemetrisi alınamadı."}</Empty>}
            <p className={styles.note}>p50 {ms(runtime?.p50Ms)} · en yüksek {ms(runtime?.maxMs)} · atılan örnek {number(runtime?.droppedSamples)}</p>
          </Panel>
        </div>
      </>}
      {view === 3 && <TvDashboard embedded refreshKey={businessRefreshKey} />}
    </div>}

    <footer className={styles.footer}><span>Erişim: oturum çerezi · Yenileme 20 sn · {paused ? "Geçiş duraklatıldı" : "Otomatik geçiş 25 sn"}</span><span className={stale ? styles.warning : ""}>Ölçüm {date(s?.collectedAt)} · API pencere {duration(runtime?.windowSeconds)} · Grafik {telemetry.history.length}/30 örnek{stale ? " · ESKİ VERİ" : ""}</span></footer>
    {fullscreenError && <div className={styles.fullscreenError} role="alert"><span>{fullscreenError}</span><button onClick={() => setFullscreenError(null)}>Kapat</button></div>}
  </main>;
}

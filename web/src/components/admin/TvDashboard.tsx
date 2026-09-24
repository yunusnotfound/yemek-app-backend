"use client";

import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { ArrowLeft, Maximize, Minimize, RefreshCw, Sprout } from "lucide-react";
import { getAdminDashboard, getOrders, getSettlementSummary } from "@/lib/api/admin";
import { paymentBadge } from "@/lib/adminFormat";
import { orderStatusLabel } from "@/lib/format";
import type { AdminStats, Order, SettlementSummary } from "@/lib/types";
import styles from "./TvDashboard.module.css";

const REFRESH_MS = 30_000;
const STALE_MS = 90_000;
const numberFormat = new Intl.NumberFormat("tr-TR");
const moneyFormat = new Intl.NumberFormat("tr-TR", {
  style: "currency", currency: "TRY", maximumFractionDigits: 2,
});
const timeFormat = new Intl.DateTimeFormat("tr-TR", {
  timeZone: "Europe/Istanbul", hour: "2-digit", minute: "2-digit", second: "2-digit",
});
const dateFormat = new Intl.DateTimeFormat("tr-TR", {
  timeZone: "Europe/Istanbul", day: "numeric", month: "long", weekday: "long",
});
const orderTimeFormat = new Intl.DateTimeFormat("tr-TR", {
  timeZone: "Europe/Istanbul", day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit",
});

type TvOrder = Omit<Order, "user" | "userId" | "pickupCode" | "package"> & {
  package?: Order["package"] & { business?: { id: string; name: string } };
};
type Snapshot<T> = { data: T | null; updatedAt: number | null; failed: boolean };
const emptySnapshot = <T,>(): Snapshot<T> => ({ data: null, updatedAt: null, failed: false });

function amount(value?: number | null) {
  return value == null || !Number.isFinite(Number(value)) ? "—" : moneyFormat.format(Number(value));
}

function count(value?: number | null) {
  return value == null || !Number.isFinite(Number(value)) ? "—" : numberFormat.format(Number(value));
}

function orderTime(value: string) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "—" : orderTimeFormat.format(date);
}

function isStale(snapshot: Snapshot<unknown>, now: number | null) {
  return snapshot.failed || (snapshot.updatedAt !== null && now !== null && now - snapshot.updatedAt > STALE_MS);
}

function Freshness({ snapshot, now }: { snapshot: Snapshot<unknown>; now: number | null }) {
  const stale = isStale(snapshot, now);
  return (
    <span className={`${styles.freshness} ${stale ? styles.warningText : ""}`}>
      {snapshot.updatedAt === null
        ? snapshot.failed ? "Veri alınamadı" : "Yükleniyor…"
        : `${stale ? "Eski veri · " : "Güncellendi · "}${timeFormat.format(snapshot.updatedAt)}`}
    </span>
  );
}

export function TvDashboard({ embedded = false, refreshKey = 0 }: { embedded?: boolean; refreshKey?: number }) {
  const [stats, setStats] = useState<Snapshot<AdminStats>>(emptySnapshot);
  const [settlement, setSettlement] = useState<Snapshot<SettlementSummary>>(emptySnapshot);
  const [orders, setOrders] = useState<Snapshot<TvOrder[]>>(emptySnapshot);
  const [now, setNow] = useState<number | null>(null);
  const [online, setOnline] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [fullscreen, setFullscreen] = useState(false);
  const [fullscreenSupported, setFullscreenSupported] = useState(false);
  const [fullscreenError, setFullscreenError] = useState<string | null>(null);
  const mounted = useRef(false);
  const inFlight = useRef(false);

  const refresh = useCallback(async () => {
    if (inFlight.current || !mounted.current) return;
    inFlight.current = true;
    setRefreshing(true);

    try {
      const results = await Promise.allSettled([
        getAdminDashboard(), getSettlementSummary(), getOrders({ limit: 6 }),
      ]);
      if (!mounted.current) return;
      const updatedAt = Date.now();
      const [statsResult, settlementResult, ordersResult] = results;

      setStats(previous => statsResult.status === "fulfilled"
        ? { data: statsResult.value.stats, updatedAt, failed: false }
        : { ...previous, failed: true });
      setSettlement(previous => settlementResult.status === "fulfilled"
        ? { data: settlementResult.value.summary, updatedAt, failed: false }
        : { ...previous, failed: true });
      setOrders(previous => ordersResult.status === "fulfilled"
        ? {
            // Keep only fields used on the shared screen; customer details and pickup codes are excluded.
            data: ordersResult.value.data.map(order => ({
              id: order.id, packageId: order.packageId, package: order.package,
              quantity: order.quantity, totalPrice: order.totalPrice, finalPrice: order.finalPrice,
              discountAmount: order.discountAmount, paidPrice: order.paidPrice,
              status: order.status, paymentStatus: order.paymentStatus, createdAt: order.createdAt,
            })),
            updatedAt, failed: false,
          }
        : { ...previous, failed: true });
    } finally {
      inFlight.current = false;
      if (mounted.current) setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    mounted.current = true;
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout>;
    const poll = async () => {
      await refresh();
      if (!cancelled) timer = setTimeout(poll, REFRESH_MS);
    };
    timer = setTimeout(poll, 0);
    const tick = () => setNow(Date.now());
    const networkChanged = () => setOnline(navigator.onLine);
    const fullscreenChanged = () => setFullscreen(Boolean(document.fullscreenElement));
    tick();
    networkChanged();
    setFullscreenSupported(Boolean(document.documentElement.requestFullscreen) && document.fullscreenEnabled !== false);
    fullscreenChanged();
    const clock = setInterval(tick, 1000);
    window.addEventListener("online", networkChanged);
    window.addEventListener("offline", networkChanged);
    document.addEventListener("fullscreenchange", fullscreenChanged);

    return () => {
      cancelled = true;
      mounted.current = false;
      clearTimeout(timer);
      clearInterval(clock);
      window.removeEventListener("online", networkChanged);
      window.removeEventListener("offline", networkChanged);
      document.removeEventListener("fullscreenchange", fullscreenChanged);
    };
  }, [refresh]);

  useEffect(() => {
    if (!refreshKey) return;
    const timer = setTimeout(() => void refresh(), 0);
    return () => clearTimeout(timer);
  }, [refreshKey, refresh]);

  async function toggleFullscreen() {
    setFullscreenError(null);
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else if (document.documentElement.requestFullscreen) await document.documentElement.requestFullscreen();
      else setFullscreenError("Bu tarayıcı tam ekran özelliğini desteklemiyor.");
    } catch {
      setFullscreenError("Tam ekran açılamadı. Tarayıcının tam ekran seçeneğini kullanabilirsiniz.");
    }
  }

  const s = stats.data;
  const settlementData = settlement.data;
  const staleSections = [
    isStale(stats, now) && "genel bakış",
    isStale(settlement, now) && "işletme payları",
    isStale(orders, now) && "siparişler",
  ].filter(Boolean);
  const hasData = Boolean(s || settlementData || orders.data);
  const degraded = !online || staleSections.length > 0;
  const Root = embedded ? "section" : "main";

  return (
    <Root className={`${styles.dashboard} ${embedded ? styles.embedded : ""}`} aria-label={embedded ? "Satış ve iş metrikleri" : undefined}>
      {!embedded && <header className={styles.header}>
        <div className={styles.brand}>
          <span className={styles.logo}><Sprout aria-hidden="true" /></span>
          <div>
            <p className={styles.eyebrow}>BİTİR GİTSİN / PLATFORM GENELİ</p>
            <h1>Operasyon ekranı</h1>
          </div>
        </div>
        <div className={styles.headerRight}>
          <div className={styles.clock}>
            <strong>{now ? timeFormat.format(now) : "—"}</strong>
            <span>{now ? dateFormat.format(now) : "Türkiye saati"}</span>
          </div>
          <nav aria-label="Ekran kontrolleri" className={styles.controls} onKeyDown={event => {
            if (!["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)) return;
            const controls = Array.from(event.currentTarget.querySelectorAll<HTMLElement>("a, button:not(:disabled)"));
            const current = controls.indexOf(document.activeElement as HTMLElement);
            if (current < 0 || controls.length < 2) return;
            const direction = event.key === "ArrowLeft" || event.key === "ArrowUp" ? -1 : 1;
            controls[(current + direction + controls.length) % controls.length].focus();
            event.preventDefault();
          }}>
            <Link href="/admin/tv" className={styles.iconButton} aria-label="Teknik dashboarda dön" title="Teknik dashboarda dön"><ArrowLeft aria-hidden="true" /></Link>
            <button type="button" onClick={() => void refresh()} disabled={refreshing} className={styles.iconButton} aria-label="Verileri yenile" title="Verileri yenile"><RefreshCw aria-hidden="true" className={refreshing ? styles.spinning : ""} /></button>
            {fullscreenSupported && <button type="button" onClick={() => void toggleFullscreen()} className={styles.iconButton} aria-label={fullscreen ? "Tam ekrandan çık" : "Tam ekran"} title={fullscreen ? "Tam ekrandan çık" : "Tam ekran"}>{fullscreen ? <Minimize aria-hidden="true" /> : <Maximize aria-hidden="true" />}</button>}
          </nav>
        </div>
      </header>}

      <section aria-label="Platform metrikleri" className={styles.overview}>
        <div className={styles.sectionHeading}>
          <h2>Genel bakış</h2>
          <Freshness snapshot={stats} now={now} />
        </div>
        <div className={styles.metrics}>
          <article className={`${styles.metric} ${styles.featured}`}>
            <p>Bugünkü tahsilat</p><strong>{amount(s?.todayRevenue)}</strong>
            <span>Bugün oluşturulan, ödenmiş siparişler</span>
          </article>
          <article className={styles.metric}>
            <p>Bugünkü ödenmiş sipariş</p><strong>{count(s?.todayOrders)}</strong>
            <span>Toplam sipariş: {count(s?.totalOrders)}</span>
          </article>
          <article className={styles.metric}>
            <p>Toplam işlem hacmi · GMV</p><strong>{amount(s?.gmv)}</strong>
            <span>Ödendi durumundaki tüm siparişler</span>
          </article>
          <article className={styles.metric}>
            <p>Toplam komisyon</p><strong>{amount(s?.commissionTotal)}</strong>
            <span>Ödendi durumundaki siparişlerden</span>
          </article>
        </div>
        <div className={styles.platformGrid}>
          <article><div><p>Kullanıcı</p><strong>{count(s?.totalUsers)}</strong></div><span>{count(s?.customers)} müşteri · {count(s?.businessOwners)} işletmeci · {count(s?.admins)} yönetici</span></article>
          <article><div><p>İşletme</p><strong>{count(s?.totalBusinesses)}</strong></div><span>{count(s?.activeBusinesses)} aktif işletme</span></article>
          <article><div><p>Onay bekleyen işletme</p><strong className={s && s.pendingBusinesses > 0 ? styles.warningText : ""}>{count(s?.pendingBusinesses)}</strong></div><span>İşletme başvuruları</span></article>
          <article><div><p>Paket ilanı</p><strong>{count(s?.totalPackages)}</strong></div><span>Toplam oluşturulan ilan sayısı</span></article>
        </div>
      </section>

      <div className={styles.detailGrid}>
        <section className={styles.panel} aria-labelledby="tv-orders-heading">
          <div className={styles.sectionHeading}>
            <div><h2 id="tv-orders-heading">Son siparişler</h2><p>Platform genelinde en son oluşturulan 6 sipariş</p></div>
            <Freshness snapshot={orders} now={now} />
          </div>
          {orders.data === null ? (
            <p className={styles.empty}>{orders.failed ? "Siparişler alınamadı. Otomatik olarak yeniden denenecek." : "Siparişler yükleniyor…"}</p>
          ) : orders.data.length === 0 ? (
            <p className={styles.empty}>Henüz sipariş bulunmuyor.</p>
          ) : (
            <div className={styles.tableWrap}>
              <table className={styles.ordersTable}>
                <thead><tr><th scope="col">İşletme / paket</th><th scope="col">Durum</th><th scope="col">Tutar</th></tr></thead>
                <tbody>{orders.data.map(order => {
                  const payment = paymentBadge(order.paymentStatus);
                  const hasPaidPrice = ["paid", "refunded", "partially_refunded"].includes(order.paymentStatus || "")
                    && order.paidPrice !== null && order.paidPrice !== undefined;
                  return (
                    <tr key={order.id}>
                      <td><strong>{order.package?.business?.name || "İşletme bilgisi yok"}</strong><span title={`${order.package?.title || "Paket bilgisi yok"} · ${count(order.quantity)} adet · ${orderTime(order.createdAt)}`}>{order.package?.title || "Paket bilgisi yok"} · {count(order.quantity)} adet · {orderTime(order.createdAt)}</span></td>
                      <td><span className={`${styles.badge} ${styles[payment.tone]}`}>{payment.label}</span><small>{orderStatusLabel(order.status)}</small></td>
                      <td><strong>{amount(hasPaidPrice ? order.paidPrice : order.finalPrice ?? order.totalPrice)}</strong><small>{hasPaidPrice ? "Tahsil edilen" : "Sipariş tutarı"}</small></td>
                    </tr>
                  );
                })}</tbody>
              </table>
            </div>
          )}
        </section>

        <section className={`${styles.panel} ${styles.settlement}`} aria-labelledby="tv-settlement-heading">
          <div className={styles.sectionHeading}>
            <h2 id="tv-settlement-heading">İşletme payları ve iadeler</h2>
            <Freshness snapshot={settlement} now={now} />
          </div>
          <div className={styles.settlementCard}>
            <p><span className={`${styles.dot} ${styles.amberDot}`} />Onay bekleyen işletme payı</p>
            <strong>{amount(settlementData?.held)}</strong>
            <span>{count(settlementData?.heldCount)} ödenmiş sipariş</span>
          </div>
          <div className={styles.settlementCard}>
            <p><span className={styles.dot} />Onaylanan işletme payı</p>
            <strong>{amount(settlementData?.approved)}</strong>
            <span>{count(settlementData?.approvedCount)} ödenmiş sipariş</span>
          </div>
          <div className={`${styles.settlementCard} ${styles.refundCard}`}>
            <p>Toplam iade tutarı</p><strong>{amount(settlementData?.refunded)}</strong>
            <span>Tam ve kısmi iadeler</span>
          </div>
          <p className={styles.settlementNote}>İşletme payı onayı, banka hesabına aktarımın tamamlandığı anlamına gelmez.</p>
        </section>
      </div>

      <footer className={styles.footer}>
        <p role="status" className={degraded ? styles.warningText : ""}>
          <span className={`${styles.dot} ${degraded ? styles.amberDot : ""}`} />
          {!online
            ? "Bağlantı yok · Son alınan veriler gösteriliyor"
            : staleSections.length > 0
              ? `Güncellenemedi: ${staleSections.join(", ")} · Yeniden denenecek`
              : refreshing ? "Veriler güncelleniyor…" : hasData ? "Bağlantı açık · 30 saniyede bir yenilenir" : "Veriler bekleniyor…"}
        </p>
        {!embedded && <span>Saat: Türkiye · <Link href="/cerez-politikasi">Yalnızca oturum çerezleri kullanılır.</Link></span>}
      </footer>
      {fullscreenError && <p className={styles.fullscreenError} role="alert">{fullscreenError}<button type="button" onClick={() => setFullscreenError(null)}>Kapat</button></p>}
    </Root>
  );
}

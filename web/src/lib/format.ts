/** Türkçe biçimlendirme yardımcıları. */

const tl = new Intl.NumberFormat("tr-TR", {
  style: "currency",
  currency: "TRY",
  maximumFractionDigits: 2,
});

export function formatPrice(value: number | string | null | undefined): string {
  const n = typeof value === "string" ? parseFloat(value) : value ?? 0;
  return tl.format(Number.isFinite(n as number) ? (n as number) : 0);
}

export function formatDate(value: string | null | undefined): string {
  if (!value) return "-";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleDateString("tr-TR", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  });
}

export function formatDateTime(value: string | null | undefined): string {
  if (!value) return "-";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleDateString("tr-TR", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

/** "18:00:00" → "18:00" */
export function formatTime(value: string | null | undefined): string {
  if (!value) return "-";
  return value.slice(0, 5);
}

const ORDER_STATUS_LABELS: Record<string, string> = {
  pending: "Bekliyor",
  confirmed: "Onaylandı",
  picked_up: "Teslim edildi",
  cancelled: "İptal edildi",
};

export function orderStatusLabel(status: string): string {
  return ORDER_STATUS_LABELS[status] ?? status;
}

export function discountPercent(original: number, discounted: number): number {
  if (!original || original <= 0) return 0;
  return Math.round(((original - discounted) / original) * 100);
}

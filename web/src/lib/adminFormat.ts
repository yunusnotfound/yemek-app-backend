import type { ApprovalStatus, PaymentStatus, SubMerchantStatus, Role } from "@/lib/types";

type Tone = "green" | "amber" | "slate" | "blue" | "red";

export function approvalBadge(s?: ApprovalStatus): { label: string; tone: Tone } {
  if (s === "approved") return { label: "Onaylı", tone: "green" };
  if (s === "rejected") return { label: "Reddedildi", tone: "red" };
  return { label: "Onay bekliyor", tone: "amber" };
}

export function activeBadge(a?: boolean): { label: string; tone: Tone } {
  return a ? { label: "Aktif", tone: "green" } : { label: "Askıda", tone: "slate" };
}

export function subMerchantBadge(s?: SubMerchantStatus): { label: string; tone: Tone } {
  if (s === "active") return { label: "Aktif", tone: "green" };
  if (s === "error") return { label: "Hata", tone: "red" };
  return { label: "Tanımsız", tone: "slate" };
}

export function paymentBadge(s?: PaymentStatus): { label: string; tone: Tone } {
  switch (s) {
    case "paid":
      return { label: "Ödendi", tone: "green" };
    case "pending":
      return { label: "Bekliyor", tone: "amber" };
    case "refunded":
      return { label: "İade", tone: "red" };
    case "partially_refunded":
      return { label: "Kısmi iade", tone: "red" };
    case "failed":
      return { label: "Başarısız", tone: "red" };
    default:
      return { label: "Ödenmedi", tone: "slate" };
  }
}

export function roleLabel(r?: Role | string): string {
  return r === "admin" ? "Admin" : r === "business_owner" ? "İşletme" : "Müşteri";
}

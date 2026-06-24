import { proxyFetch } from "@/lib/api/browser";
import type {
  BusinessWithStats,
  Business,
  Category,
  DashboardResponse,
  EarningsResponse,
  Order,
  OrderStatus,
  Paginated,
  PackageWithStats,
  SubMerchantSummary,
  SurprisePackage,
  Review,
  User,
} from "@/lib/types";

/** İşletme paneli için backend uçlarını saran istemci yardımcıları (proxy üzerinden). */

function qs(params: Record<string, string | number | undefined>): string {
  const sp = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== "") sp.set(k, String(v));
  }
  const s = sp.toString();
  return s ? `?${s}` : "";
}

// ── Profil ────────────────────────────────────────────────────────────────────
export function getProfile() {
  return proxyFetch<{ user: User }>("/users/profile");
}

// ── İşletme sahibi paneli ────────────────────────────────────────────────────
export function getMyBusinesses() {
  return proxyFetch<Paginated<BusinessWithStats>>(
    "/business-dashboard/my-businesses?limit=50",
  );
}

export function getDashboard(businessId: string) {
  return proxyFetch<DashboardResponse>(
    `/business-dashboard/${businessId}/dashboard`,
  );
}

export function getBusinessOrders(
  businessId: string,
  opts: { status?: OrderStatus; page?: number; limit?: number } = {},
) {
  return proxyFetch<Paginated<Order>>(
    `/business-dashboard/${businessId}/orders${qs(opts)}`,
  );
}

export function getBusinessPackages(
  businessId: string,
  opts: { page?: number; limit?: number } = {},
) {
  return proxyFetch<Paginated<PackageWithStats>>(
    `/business-dashboard/${businessId}/packages${qs(opts)}`,
  );
}

export function getBusinessReviews(
  businessId: string,
  opts: { page?: number; limit?: number } = {},
) {
  return proxyFetch<Paginated<Review>>(
    `/business-dashboard/${businessId}/reviews${qs(opts)}`,
  );
}

export function verifyOrder(businessId: string, pickupCode: string) {
  return proxyFetch<{ message: string; order: Order }>(
    `/business-dashboard/${businessId}/verify-order`,
    { method: "POST", body: JSON.stringify({ pickupCode }) },
  );
}

// ── Ödemeler (iyzico Pazaryeri) ────────────────────────────────────────────────
export function getEarnings(businessId: string) {
  return proxyFetch<EarningsResponse>(`/business-dashboard/${businessId}/earnings`);
}

export function upsertSubMerchant(businessId: string, input: Record<string, unknown>) {
  return proxyFetch<{ message: string; submerchant: SubMerchantSummary }>(
    `/business-dashboard/${businessId}/submerchant`,
    { method: "POST", body: JSON.stringify(input) },
  );
}

// ── İşletme CRUD ──────────────────────────────────────────────────────────────
export function getCategories() {
  return proxyFetch<{ categories: Category[] }>("/categories");
}

export function createBusiness(input: Record<string, unknown>) {
  return proxyFetch<{ message: string; business: Business }>("/businesses", {
    method: "POST",
    body: JSON.stringify(input),
  });
}

export function updateBusiness(id: string, input: Record<string, unknown>) {
  return proxyFetch<{ message: string; business: Business }>(
    `/businesses/${id}`,
    { method: "PUT", body: JSON.stringify(input) },
  );
}

// ── Paket CRUD ────────────────────────────────────────────────────────────────
export function getPackage(id: string) {
  return proxyFetch<{ package: SurprisePackage }>(`/packages/${id}`);
}

export function createPackage(input: Record<string, unknown>) {
  return proxyFetch<{ message: string; package: SurprisePackage }>("/packages", {
    method: "POST",
    body: JSON.stringify(input),
  });
}

export function updatePackage(id: string, input: Record<string, unknown>) {
  return proxyFetch<{ package: SurprisePackage }>(`/packages/${id}`, {
    method: "PUT",
    body: JSON.stringify(input),
  });
}

export function deletePackage(id: string) {
  return proxyFetch<{ message: string }>(`/packages/${id}`, {
    method: "DELETE",
  });
}

// ── Sipariş ───────────────────────────────────────────────────────────────────
export function updateOrderStatus(id: string, status: OrderStatus) {
  return proxyFetch<{ message: string; order: Order }>(
    `/orders/${id}/status`,
    { method: "PATCH", body: JSON.stringify({ status }) },
  );
}

// ── Görsel yükleme ────────────────────────────────────────────────────────────
export function uploadImage(file: File) {
  const fd = new FormData();
  fd.append("file", file);
  return proxyFetch<{ url: string }>("/upload", { method: "POST", body: fd });
}

import { proxyFetch } from "@/lib/api/browser";
import type {
  AdminStats,
  ApprovalStatus,
  AuditLogEntry,
  Business,
  BusinessAdminDetail,
  Category,
  Coupon,
  Order,
  OrderStatus,
  Paginated,
  PaymentStatus,
  Role,
  SettlementSummary,
  SubMerchantRow,
  SubMerchantStatus,
  SurprisePackage,
  User,
} from "@/lib/types";

/** Admin uçlarını saran istemci yardımcıları (BFF proxy üzerinden). */

function qs(params: Record<string, string | number | undefined>): string {
  const sp = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== "") sp.set(k, String(v));
  }
  const s = sp.toString();
  return s ? `?${s}` : "";
}

// ── Dashboard ───────────────────────────────────────────────────────────────
export function getAdminDashboard() {
  return proxyFetch<{ stats: AdminStats }>("/admin/dashboard");
}

// ── Kullanıcılar ──────────────────────────────────────────────────────────────
export function getUsers(opts: { page?: number; limit?: number; search?: string; role?: Role } = {}) {
  return proxyFetch<Paginated<User>>(`/admin/users${qs(opts)}`);
}
export function getUser(id: string) {
  return proxyFetch<{ user: User & { businesses?: Business[]; orders?: Order[] } }>(`/admin/users/${id}`);
}
export function updateUser(id: string, input: Record<string, unknown>) {
  return proxyFetch<{ message: string; user: User }>(`/admin/users/${id}`, {
    method: "PUT",
    body: JSON.stringify(input),
  });
}
export function deleteUser(id: string) {
  return proxyFetch<{ message: string }>(`/admin/users/${id}`, { method: "DELETE" });
}

// ── İşletmeler ────────────────────────────────────────────────────────────────
export function getBusinesses(
  opts: {
    page?: number;
    limit?: number;
    search?: string;
    city?: string;
    approvalStatus?: ApprovalStatus;
    isActive?: "true" | "false";
    subMerchantStatus?: SubMerchantStatus;
  } = {},
) {
  return proxyFetch<Paginated<Business>>(`/admin/businesses${qs(opts)}`);
}
export function getBusiness(id: string) {
  return proxyFetch<BusinessAdminDetail>(`/admin/businesses/${id}`);
}
export function getPendingBusinesses(opts: { page?: number; limit?: number } = {}) {
  return proxyFetch<Paginated<Business>>(`/admin/businesses/pending${qs(opts)}`);
}
export function approveBusiness(id: string) {
  return proxyFetch<{ message: string; business: Business }>(`/admin/businesses/${id}/approve`, {
    method: "PATCH",
  });
}
export function rejectBusiness(id: string) {
  return proxyFetch<{ message: string; business: Business }>(`/admin/businesses/${id}/reject`, {
    method: "PATCH",
  });
}
export function setBusinessActive(id: string, isActive: boolean) {
  return proxyFetch<{ message: string; business: Business }>(`/admin/businesses/${id}/active`, {
    method: "PATCH",
    body: JSON.stringify({ isActive }),
  });
}

// ── Siparişler ────────────────────────────────────────────────────────────────
export function getOrders(
  opts: {
    page?: number;
    limit?: number;
    status?: OrderStatus;
    paymentStatus?: PaymentStatus;
    businessId?: string;
    search?: string;
  } = {},
) {
  return proxyFetch<Paginated<Order>>(`/admin/orders${qs(opts)}`);
}
export function getOrder(id: string) {
  return proxyFetch<{ order: Order }>(`/admin/orders/${id}`);
}
export function refundOrder(id: string, reason?: string) {
  return proxyFetch<{ message: string; order: Order }>(`/admin/orders/${id}/refund`, {
    method: "POST",
    body: JSON.stringify({ reason }),
  });
}

// ── Kategoriler ───────────────────────────────────────────────────────────────
export function getCategories() {
  return proxyFetch<{ categories: Category[] }>("/categories");
}
export function createCategory(input: { name: string; slug?: string }) {
  return proxyFetch<{ message: string; category: Category }>("/admin/categories", {
    method: "POST",
    body: JSON.stringify(input),
  });
}
export function updateCategory(id: number, input: { name?: string; slug?: string }) {
  return proxyFetch<{ message: string; category: Category }>(`/admin/categories/${id}`, {
    method: "PUT",
    body: JSON.stringify(input),
  });
}
export function deleteCategory(id: number) {
  return proxyFetch<{ message: string }>(`/admin/categories/${id}`, { method: "DELETE" });
}

// ── Kuponlar (mevcut /coupons uçları, admin-only) ──────────────────────────────
export function getCoupons(opts: { page?: number; limit?: number } = {}) {
  return proxyFetch<Paginated<Coupon>>(`/coupons${qs(opts)}`);
}
export function createCoupon(input: Record<string, unknown>) {
  return proxyFetch<{ message: string; coupon: Coupon }>("/coupons", {
    method: "POST",
    body: JSON.stringify(input),
  });
}
export function updateCoupon(id: string, input: Record<string, unknown>) {
  return proxyFetch<{ message: string; coupon: Coupon }>(`/coupons/${id}`, {
    method: "PUT",
    body: JSON.stringify(input),
  });
}
export function deleteCoupon(id: string) {
  return proxyFetch<{ message: string }>(`/coupons/${id}`, { method: "DELETE" });
}

// ── Paketler ──────────────────────────────────────────────────────────────────
export type AdminPackage = SurprisePackage & { business?: Pick<Business, "id" | "name"> };
export function getPackages(
  opts: { page?: number; limit?: number; businessId?: string; isActive?: "true" | "false"; search?: string } = {},
) {
  return proxyFetch<Paginated<AdminPackage>>(`/admin/packages${qs(opts)}`);
}
export function setPackageActive(id: string, isActive: boolean) {
  return proxyFetch<{ message: string; package: SurprisePackage }>(`/admin/packages/${id}/active`, {
    method: "PATCH",
    body: JSON.stringify({ isActive }),
  });
}

// ── Değerlendirmeler ──────────────────────────────────────────────────────────
export type AdminReview = {
  id: string;
  rating: number;
  comment?: string | null;
  createdAt: string;
  user?: Pick<User, "id" | "name">;
  business?: Pick<Business, "id" | "name">;
  order?: { id: string; createdAt: string };
};
export function getReviews(opts: { page?: number; limit?: number; businessId?: string; minRating?: number } = {}) {
  return proxyFetch<Paginated<AdminReview>>(`/admin/reviews${qs(opts)}`);
}
export function deleteReview(id: string) {
  return proxyFetch<{ message: string }>(`/admin/reviews/${id}`, { method: "DELETE" });
}

// ── Ödeme / Mutabakat ─────────────────────────────────────────────────────────
export function getSettlementSummary() {
  return proxyFetch<{ summary: SettlementSummary }>("/admin/settlement/summary");
}
export function getSubMerchants(opts: { page?: number; limit?: number; subMerchantStatus?: SubMerchantStatus } = {}) {
  return proxyFetch<Paginated<SubMerchantRow>>(`/admin/sub-merchants${qs(opts)}`);
}

// ── Denetim kaydı ─────────────────────────────────────────────────────────────
export function getAuditLog(
  opts: { page?: number; limit?: number; action?: string; targetType?: string; adminId?: string } = {},
) {
  return proxyFetch<Paginated<AuditLogEntry>>(`/admin/audit-log${qs(opts)}`);
}

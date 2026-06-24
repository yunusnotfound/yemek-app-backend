/** Backend yanıtlarının TypeScript karşılıkları (src/models + controller yanıtları). */

export type Role = "customer" | "business_owner" | "admin";

export type OrderStatus =
  | "awaiting_payment"
  | "pending"
  | "confirmed"
  | "picked_up"
  | "cancelled";

export type PaymentStatus =
  | "unpaid"
  | "pending"
  | "paid"
  | "failed"
  | "refunded"
  | "partially_refunded";

export type SettlementStatus = "none" | "held" | "approved" | "disapproved" | "refunded";

export type ApprovalStatus = "pending" | "approved" | "rejected";

export type SubMerchantType =
  | "PERSONAL"
  | "PRIVATE_COMPANY"
  | "LIMITED_OR_JOINT_STOCK_COMPANY";

export type SubMerchantStatus = "none" | "active" | "error";

export interface User {
  id: string;
  name: string;
  email: string;
  phone?: string | null;
  role: Role;
  latitude?: number | null;
  longitude?: number | null;
  isEmailVerified: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface Category {
  id: number;
  name: string;
  slug: string;
}

export interface Business {
  id: string;
  ownerId: string;
  categoryId: number;
  name: string;
  description?: string | null;
  address: string;
  city: string;
  district: string;
  latitude: number;
  longitude: number;
  phone?: string | null;
  imageUrl?: string | null;
  rating: number;
  isActive: boolean;
  isApproved: boolean;
  approvalStatus?: ApprovalStatus;
  category?: Category;
  // iyzico alt üye işyeri (sub-merchant)
  subMerchantStatus?: SubMerchantStatus;
  subMerchantType?: SubMerchantType | null;
  subMerchantError?: string | null;
  createdAt: string;
  updatedAt: string;
}

/** getMyBusinesses ek hesaplanan alanlarla döner. */
export interface BusinessWithStats extends Business {
  activePackages: number;
  pendingOrders: number;
}

export interface SurprisePackage {
  id: string;
  businessId: string;
  title: string;
  description?: string | null;
  originalPrice: number;
  discountedPrice: number;
  quantity: number;
  remainingQuantity: number;
  pickupDate: string; // YYYY-MM-DD
  pickupStart: string; // HH:MM
  pickupEnd: string; // HH:MM
  imageUrl?: string | null;
  isActive: boolean;
  isRecurring: boolean;
  recurringDays?: number[] | null;
  createdAt: string;
  updatedAt: string;
}

/** getBusinessPackages ek satış istatistikleriyle döner. */
export interface PackageWithStats extends SurprisePackage {
  soldQuantity: number;
  totalRevenue: number;
}

export interface Order {
  id: string;
  userId: string;
  packageId: string;
  quantity: number;
  totalPrice: number;
  finalPrice: number;
  discountAmount: number;
  status: OrderStatus;
  paymentStatus?: PaymentStatus;
  settlementStatus?: SettlementStatus;
  paidPrice?: number | null;
  commissionAmount?: number | null;
  subMerchantPrice?: number | null;
  refundAmount?: number | null;
  paymentTransactionId?: string | null;
  paymentId?: string | null;
  conversationId?: string | null;
  paidAt?: string | null;
  couponId?: string | null;
  pickupCode: string;
  createdAt: string;
  package?: Pick<
    SurprisePackage,
    "id" | "title" | "pickupDate" | "pickupStart" | "pickupEnd"
  >;
  user?: Pick<User, "id" | "name" | "phone">;
}

export interface Review {
  id: string;
  businessId: string;
  rating: number;
  comment?: string | null;
  createdAt: string;
  user?: Pick<User, "id" | "name">;
  order?: { id: string; createdAt: string };
}

export interface DashboardStats {
  totalPackages: number;
  activePackages: number;
  todayOrders: number;
  todayRevenue: number;
  pendingOrders: number;
  totalOrders: number;
  totalRevenue: number;
  averageRating: number;
  weeklyRevenue: number;
  monthlyRevenue: number;
}

export interface DailyStat {
  date: string;
  orders: number;
  revenue: number;
}

export interface DashboardResponse {
  stats: DashboardStats;
  dailyStats: DailyStat[];
}

export interface Pagination {
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface Paginated<T> {
  data: T[];
  pagination: Pagination;
}

/** İşletmenin iyzico alt üye işyeri (ödeme hesabı) özeti. */
export interface SubMerchantSummary {
  status: SubMerchantStatus;
  hasKey: boolean;
  type?: SubMerchantType | null;
  iban?: string | null; // maskeli
  error?: string | null;
}

/** Kazanç özeti (orders'tan türetilir). */
export interface Earnings {
  totalSales: number;
  commission: number;
  netHeld: number; // teslim bekleyen (henüz onaylanmamış)
  netApproved: number; // onaylandı -> iyzico öder
  refunded: number;
  currency: string;
  commissionRate?: number;
}

export interface EarningsResponse {
  submerchant: SubMerchantSummary;
  earnings: Earnings;
}

// ── Admin paneli ───────────────────────────────────────────────────────────
export interface AdminStats {
  totalUsers: number;
  totalBusinesses: number;
  totalOrders: number;
  totalPackages: number;
  pendingBusinesses: number;
  activeBusinesses: number;
  todayOrders: number;
  todayRevenue: number;
  gmv: number;
  commissionTotal: number;
  refundedTotal: number;
  customers: number;
  businessOwners: number;
  admins: number;
}

export interface SettlementSummary {
  gmv: number;
  commission: number;
  refunded: number;
  held: number;
  approved: number;
  heldCount: number;
  approvedCount: number;
}

export type CouponType = "percentage" | "fixed";
export interface Coupon {
  id: string;
  code: string;
  discountType: CouponType;
  discountValue: number;
  minOrderAmount: number;
  maxUsage: number;
  currentUsage: number;
  expiresAt: string;
  isActive: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface SubMerchantRow {
  id: string;
  name: string;
  city: string;
  subMerchantStatus: SubMerchantStatus;
  subMerchantType?: SubMerchantType | null;
  iban?: string | null; // maskeli
  subMerchantError?: string | null;
  hasKey: boolean;
  updatedAt: string;
}

export interface BusinessAdminDetail {
  business: Business & { owner?: Pick<User, "id" | "name" | "email" | "phone">; iban?: string | null };
  stats: { packageCount: number; orderCount: number; gmv: number; commission: number };
}

export interface AuditLogEntry {
  id: string;
  action: string;
  targetType?: string | null;
  targetId?: string | null;
  metadata?: Record<string, unknown> | null;
  ip?: string | null;
  createdAt: string;
  admin?: Pick<User, "id" | "name" | "email">;
}

/** Backend kimlik doğrulama yanıtı (login/register). */
export interface AuthResponse {
  message: string;
  user: User;
  accessToken: string;
  refreshToken: string;
}

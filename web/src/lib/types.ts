/** Backend yanıtlarının TypeScript karşılıkları (src/models + controller yanıtları). */

export type Role = "customer" | "business_owner" | "admin";

export type OrderStatus = "pending" | "confirmed" | "picked_up" | "cancelled";

export type ApprovalStatus = "pending" | "approved" | "rejected";

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

/** Backend kimlik doğrulama yanıtı (login/register). */
export interface AuthResponse {
  message: string;
  user: User;
  accessToken: string;
  refreshToken: string;
}

const { z } = require("zod");

// Auth
const registerSchema = z.object({
  name: z.string().min(1, "Ad soyad gerekli"),
  email: z.string().email("Geçerli bir e-posta adresi girin"),
  password: z.string().min(8, "Şifre en az 8 karakter olmalı"),
  phone: z.string().optional(),
  role: z.enum(["customer", "business_owner"]).optional(),
});

const loginSchema = z.object({
  email: z.string().email("Geçerli bir e-posta adresi girin"),
  password: z.string().min(1, "Şifre gerekli"),
});

// Business
const businessSchema = z.object({
  name: z.string().min(1, "İşletme adı gerekli"),
  description: z.string().optional(),
  address: z.string().min(1, "Adres gerekli"),
  city: z.string().min(1, "Şehir gerekli"),
  district: z.string().min(1, "İlçe gerekli"),
  latitude: z.number({ invalid_type_error: "Geçerli bir enlem girin" }).min(-90, "Enlem -90 ile 90 arasında olmalı").max(90, "Enlem -90 ile 90 arasında olmalı"),
  longitude: z.number({ invalid_type_error: "Geçerli bir boylam girin" }).min(-180, "Boylam -180 ile 180 arasında olmalı").max(180, "Boylam -180 ile 180 arasında olmalı"),
  phone: z.string().optional(),
  imageUrl: z.string().url("Geçerli bir URL girin").optional(),
  categoryId: z.number().int("Kategori gerekli"),
});

// Package
const packageSchema = z.object({
  businessId: z.string().uuid("Geçerli bir işletme ID girin"),
  title: z.string().min(1, "Paket adı gerekli"),
  description: z.string().optional(),
  originalPrice: z.number().min(0, "Geçerli bir fiyat girin"),
  discountedPrice: z.number().min(0, "Geçerli bir indirimli fiyat girin"),
  quantity: z.number().int().min(1, "Adet en az 1 olmalı"),
  pickupStart: z.string().min(1, "Teslim alma başlangıç saati gerekli"),
  pickupEnd: z.string().min(1, "Teslim alma bitiş saati gerekli"),
  pickupDate: z.string().date("Geçerli bir tarih girin (YYYY-MM-DD)"),
  imageUrl: z.string().url("Geçerli bir URL girin").optional(),
}).refine(data => data.discountedPrice < data.originalPrice, {
  message: "İndirimli fiyat orijinal fiyattan düşük olmalı",
  path: ["discountedPrice"],
});

// Package update (partial)
const packageUpdateSchema = z.object({
  title: z.string().min(1).optional(),
  description: z.string().optional(),
  originalPrice: z.number().min(0).optional(),
  discountedPrice: z.number().min(0).optional(),
  quantity: z.number().int().min(1).optional(),
  remainingQuantity: z.number().int().min(0).optional(),
  isActive: z.boolean().optional(),
  pickupStart: z.string().optional(),
  pickupEnd: z.string().optional(),
  pickupDate: z.string().date("Geçerli bir tarih girin").optional(),
  imageUrl: z.string().url().optional(),
});

// Map query schemas
const directionsQuerySchema = z.object({
  originLat: z.string().regex(/^-?\d+\.?\d*$/).transform(Number).refine(v => v >= -90 && v <= 90, "Geçerli enlem girin"),
  originLng: z.string().regex(/^-?\d+\.?\d*$/).transform(Number).refine(v => v >= -180 && v <= 180, "Geçerli boylam girin"),
  destLat: z.string().regex(/^-?\d+\.?\d*$/).transform(Number).refine(v => v >= -90 && v <= 90, "Geçerli enlem girin"),
  destLng: z.string().regex(/^-?\d+\.?\d*$/).transform(Number).refine(v => v >= -180 && v <= 180, "Geçerli boylam girin"),
});

const nearbyQuerySchema = z.object({
  lat: z.string().regex(/^-?\d+\.?\d*$/).transform(Number).refine(v => v >= -90 && v <= 90, "Geçerli enlem girin"),
  lng: z.string().regex(/^-?\d+\.?\d*$/).transform(Number).refine(v => v >= -180 && v <= 180, "Geçerli boylam girin"),
  radius: z.string().regex(/^\d+\.?\d*$/).transform(Number).optional(),
});

const reverseGeocodeQuerySchema = z.object({
  lat: z.string().regex(/^-?\d+\.?\d*$/).transform(Number).refine(v => v >= -90 && v <= 90, "Geçerli enlem girin"),
  lng: z.string().regex(/^-?\d+\.?\d*$/).transform(Number).refine(v => v >= -180 && v <= 180, "Geçerli boylam girin"),
});

const geocodeQuerySchema = z.object({
  address: z.string().min(1, "Adres gerekli"),
});

// --- Kart (iyzico kart saklama) ---
const luhnOk = (num) => {
  let sum = 0;
  let dbl = false;
  for (let i = num.length - 1; i >= 0; i--) {
    let d = num.charCodeAt(i) - 48;
    if (dbl) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    dbl = !dbl;
  }
  return sum % 10 === 0;
};

const newCardSchema = z.object({
  cardHolderName: z.string().trim().min(2, "Kart üzerindeki isim gerekli").max(80),
  cardNumber: z
    .string()
    .transform((s) => s.replace(/\s+/g, ""))
    .refine((v) => /^\d{12,19}$/.test(v) && luhnOk(v), "Geçerli bir kart numarası girin"),
  expireMonth: z.string().regex(/^(0[1-9]|1[0-2])$/, "Geçerli bir ay girin (01-12)"),
  expireYear: z.string().regex(/^\d{4}$/, "Geçerli bir yıl girin (4 hane)"),
  cardAlias: z.string().trim().max(50).optional(),
});

// POST /cards — CVV alınmaz (iyzico card.create CVV istemez)
const cardCreateSchema = newCardSchema;

const cardTokenParamSchema = z.object({
  cardToken: z.string().min(1, "Kart token gerekli").max(200),
});

// Sipariş ödemesi: kayıtlı kart (token) VEYA yeni kart (+ CVV, isteğe bağlı kaydet)
const orderPaymentCardSchema = z.union([
  z.object({ savedCardToken: z.string().min(1).max(200) }),
  newCardSchema.extend({
    cvc: z.string().regex(/^\d{3,4}$/, "Geçerli bir CVV girin"),
    saveCard: z.boolean().optional(),
  }),
], { error: "Geçerli bir ödeme kartı bilgisi girin" });

// Order
const orderSchema = z.object({
  packageId: z.string().uuid("Geçerli bir paket ID girin"),
  quantity: z.number().int().min(1).optional(),
  couponCode: z.string().optional(),
  // Varsa native 3DS akışı; yoksa checkout form (eski app sürümleri) — geriye uyumlu.
  paymentCard: orderPaymentCardSchema.optional(),
});

// iyzico alt üye işyeri (sub-merchant) onboarding
const ibanRegex = /^TR\d{24}$/;
const subMerchantSchema = z
  .object({
    subMerchantType: z.enum(['PERSONAL', 'PRIVATE_COMPANY', 'LIMITED_OR_JOINT_STOCK_COMPANY']),
    iban: z
      .string()
      .trim()
      .transform((s) => s.replace(/\s+/g, '').toUpperCase())
      .refine((v) => ibanRegex.test(v), 'Geçerli bir IBAN girin (TR ile başlamalı)'),
    gsmNumber: z.string().trim().min(1, 'Telefon numarası gerekli'),
    contactName: z.string().trim().optional(),
    contactSurname: z.string().trim().optional(),
    identityNumber: z.string().trim().optional(),
    legalCompanyTitle: z.string().trim().optional(),
    taxOffice: z.string().trim().optional(),
    taxNumber: z.string().trim().optional(),
  })
  .superRefine((d, ctx) => {
    if (d.subMerchantType === 'PERSONAL') {
      if (!d.contactName) ctx.addIssue({ code: 'custom', path: ['contactName'], message: 'Ad gerekli' });
      if (!d.contactSurname) ctx.addIssue({ code: 'custom', path: ['contactSurname'], message: 'Soyad gerekli' });
      if (!d.identityNumber || !/^\d{11}$/.test(d.identityNumber)) {
        ctx.addIssue({ code: 'custom', path: ['identityNumber'], message: '11 haneli TC kimlik no gerekli' });
      }
    } else {
      if (!d.legalCompanyTitle) ctx.addIssue({ code: 'custom', path: ['legalCompanyTitle'], message: 'Şirket ünvanı gerekli' });
      if (!d.taxOffice) ctx.addIssue({ code: 'custom', path: ['taxOffice'], message: 'Vergi dairesi gerekli' });
      if (d.subMerchantType === 'LIMITED_OR_JOINT_STOCK_COMPANY' && (!d.taxNumber || !/^\d{10}$/.test(d.taxNumber))) {
        ctx.addIssue({ code: 'custom', path: ['taxNumber'], message: '10 haneli vergi no gerekli' });
      }
    }
  });

// Review
const reviewSchema = z.object({
  orderId: z.string().uuid("Geçerli bir sipariş ID girin"),
  rating: z
    .number()
    .int()
    .min(1, "Puan en az 1 olmalı")
    .max(5, "Puan en fazla 5 olmalı"),
  comment: z.string().max(2000, "Yorum en fazla 2000 karakter olabilir").optional(),
});

// Order status update
const orderStatusSchema = z.object({
  status: z.enum(["pending", "confirmed", "picked_up", "cancelled"], {
    errorMap: () => ({
      message:
        "Geçerli bir durum girin (pending, confirmed, picked_up, cancelled)",
    }),
  }),
});

// User profile update
const profileUpdateSchema = z.object({
  name: z.string().min(1).optional(),
  phone: z.string().optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
});

// Query parameter schemas
const paginationSchema = z.object({
  page: z.string().regex(/^\d+$/).transform(Number).optional(),
  limit: z.string().regex(/^\d+$/).transform(Number).optional(),
});

const packageQuerySchema = z.object({
  page: z.string().regex(/^\d+$/).transform(Number).optional(),
  limit: z.string().regex(/^\d+$/).transform(Number).optional(),
  city: z.string().optional(),
  district: z.string().optional(),
  categoryId: z.string().regex(/^\d+$/).transform(Number).optional(),
  maxPrice: z
    .string()
    .regex(/^\d+\.?\d*$/)
    .transform(Number)
    .optional(),
  lat: z
    .string()
    .regex(/^-?\d+\.?\d*$/)
    .transform(Number)
    .optional(),
  lng: z
    .string()
    .regex(/^-?\d+\.?\d*$/)
    .transform(Number)
    .optional(),
  radius: z
    .string()
    .regex(/^\d+\.?\d*$/)
    .transform(Number)
    .optional(),
  excludeExpired: z.enum(["true", "false"]).optional(),
});

const businessQuerySchema = z.object({
  page: z.string().regex(/^\d+$/).transform(Number).optional(),
  limit: z.string().regex(/^\d+$/).transform(Number).optional(),
  city: z.string().optional(),
  district: z.string().optional(),
  categoryId: z.string().regex(/^\d+$/).transform(Number).optional(),
  search: z.string().optional(),
  lat: z
    .string()
    .regex(/^-?\d+\.?\d*$/)
    .transform(Number)
    .optional(),
  lng: z
    .string()
    .regex(/^-?\d+\.?\d*$/)
    .transform(Number)
    .optional(),
  radius: z
    .string()
    .regex(/^\d+\.?\d*$/)
    .transform(Number)
    .optional(),
});

const idParamSchema = z.object({
  id: z.string().uuid("Geçerli bir ID girin"),
});

// Ödeme durumu sorgusu — conversationId = order.id (UUID)
const conversationIdParamSchema = z.object({
  conversationId: z.string().uuid("Geçerli bir ID girin"),
});

const businessIdParamSchema = z.object({
  businessId: z.string().uuid("Geçerli bir işletme ID girin"),
});

// Password reset schemas
const forgotPasswordSchema = z.object({
  email: z.string().email("Geçerli bir e-posta adresi girin"),
});

const resetPasswordSchema = z.object({
  token: z.string().min(1, "Token gerekli"),
  password: z.string().min(8, "Şifre en az 8 karakter olmalı"),
});

// Passwordless OTP login/registration
const otpRequestSchema = z.object({
  email: z.string().email("Geçerli bir e-posta adresi girin"),
});

const otpVerifySchema = z.object({
  email: z.string().email("Geçerli bir e-posta adresi girin"),
  code: z.string().length(6, "Kod 6 haneli olmalı"),
  name: z.string().min(2, "Ad soyad en az 2 karakter olmalı").optional(),
  phone: z.string().optional(),
});

// --- Admin paneli ---
const pageLimit = {
  page: z.string().regex(/^\d+$/).transform(Number).optional(),
  limit: z.string().regex(/^\d+$/).transform(Number).optional(),
};

// Category.id INTEGER (UUID değil)
const intIdParamSchema = z.object({
  id: z.string().regex(/^\d+$/, "Geçerli bir ID girin").transform(Number),
});

const categoryCreateSchema = z.object({
  name: z.string().min(1, "Kategori adı gerekli"),
  slug: z.string().min(1).optional(),
});
const categoryUpdateSchema = z.object({
  name: z.string().min(1).optional(),
  slug: z.string().min(1).optional(),
});

const adminUserUpdateSchema = z.object({
  name: z.string().min(1).optional(),
  phone: z.string().optional(),
  role: z.enum(["customer", "business_owner", "admin"]).optional(),
  isEmailVerified: z.boolean().optional(),
});

const businessActiveSchema = z.object({ isActive: z.boolean() });
const packageActiveSchema = z.object({ isActive: z.boolean() });
const adminOrderRefundSchema = z.object({ reason: z.string().max(500).optional() });

const adminUserQuerySchema = z.object({
  ...pageLimit,
  search: z.string().optional(),
  role: z.enum(["customer", "business_owner", "admin"]).optional(),
});
const adminBusinessQuerySchema = z.object({
  ...pageLimit,
  search: z.string().optional(),
  city: z.string().optional(),
  approvalStatus: z.enum(["pending", "approved", "rejected"]).optional(),
  isActive: z.enum(["true", "false"]).optional(),
  subMerchantStatus: z.enum(["none", "active", "error"]).optional(),
});
const adminOrderQuerySchema = z.object({
  ...pageLimit,
  status: z.enum(["awaiting_payment", "pending", "confirmed", "picked_up", "cancelled"]).optional(),
  paymentStatus: z.enum(["unpaid", "pending", "paid", "failed", "refunded", "partially_refunded"]).optional(),
  businessId: z.string().uuid().optional(),
  search: z.string().optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
});
const adminPackageQuerySchema = z.object({
  ...pageLimit,
  businessId: z.string().uuid().optional(),
  isActive: z.enum(["true", "false"]).optional(),
  search: z.string().optional(),
});
const adminReviewQuerySchema = z.object({
  ...pageLimit,
  businessId: z.string().uuid().optional(),
  minRating: z.string().regex(/^[1-5]$/).transform(Number).optional(),
});
const subMerchantQuerySchema = z.object({
  ...pageLimit,
  subMerchantStatus: z.enum(["none", "active", "error"]).optional(),
});
const auditQuerySchema = z.object({
  ...pageLimit,
  action: z.string().optional(),
  targetType: z.string().optional(),
  adminId: z.string().uuid().optional(),
});

module.exports = {
  registerSchema,
  intIdParamSchema,
  categoryCreateSchema,
  categoryUpdateSchema,
  adminUserUpdateSchema,
  businessActiveSchema,
  packageActiveSchema,
  adminOrderRefundSchema,
  adminUserQuerySchema,
  adminBusinessQuerySchema,
  adminOrderQuerySchema,
  adminPackageQuerySchema,
  adminReviewQuerySchema,
  subMerchantQuerySchema,
  auditQuerySchema,
  loginSchema,
  businessSchema,
  packageSchema,
  packageUpdateSchema,
  orderSchema,
  cardCreateSchema,
  cardTokenParamSchema,
  subMerchantSchema,
  reviewSchema,
  orderStatusSchema,
  profileUpdateSchema,
  paginationSchema,
  packageQuerySchema,
  businessQuerySchema,
  idParamSchema,
  conversationIdParamSchema,
  businessIdParamSchema,
  forgotPasswordSchema,
  resetPasswordSchema,
  otpRequestSchema,
  otpVerifySchema,
  directionsQuerySchema,
  nearbyQuerySchema,
  reverseGeocodeQuerySchema,
  geocodeQuerySchema,
};

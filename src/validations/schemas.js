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

// Order
const orderSchema = z.object({
  packageId: z.string().uuid("Geçerli bir paket ID girin"),
  quantity: z.number().int().min(1).optional(),
  couponCode: z.string().optional(),
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

module.exports = {
  registerSchema,
  loginSchema,
  businessSchema,
  packageSchema,
  packageUpdateSchema,
  orderSchema,
  reviewSchema,
  orderStatusSchema,
  profileUpdateSchema,
  paginationSchema,
  packageQuerySchema,
  businessQuerySchema,
  idParamSchema,
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

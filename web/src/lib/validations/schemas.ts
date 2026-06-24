import { z } from "zod";

/**
 * Web formları için Zod şemaları — backend src/validations/schemas.js'in aynası.
 * Sayısal alanlar formda react-hook-form `valueAsNumber` ile number olarak gelir.
 */

export const registerSchema = z.object({
  name: z.string().min(1, "Ad soyad gerekli"),
  email: z.email("Geçerli bir e-posta adresi girin"),
  password: z.string().min(8, "Şifre en az 8 karakter olmalı"),
  phone: z.string().optional(),
});
export type RegisterInput = z.infer<typeof registerSchema>;

export const loginSchema = z.object({
  email: z.email("Geçerli bir e-posta adresi girin"),
  password: z.string().min(1, "Şifre gerekli"),
});
export type LoginInput = z.infer<typeof loginSchema>;

export const forgotPasswordSchema = z.object({
  email: z.email("Geçerli bir e-posta adresi girin"),
});
export type ForgotPasswordInput = z.infer<typeof forgotPasswordSchema>;

export const resetPasswordSchema = z.object({
  token: z.string().min(1, "Doğrulama kodu gerekli"),
  password: z.string().min(8, "Şifre en az 8 karakter olmalı"),
});
export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>;

const optionalUrl = z
  .url("Geçerli bir URL girin")
  .optional()
  .or(z.literal(""));

export const businessSchema = z.object({
  name: z.string().min(1, "İşletme adı gerekli"),
  description: z.string().optional(),
  address: z.string().min(1, "Adres gerekli"),
  city: z.string().min(1, "Şehir gerekli"),
  district: z.string().min(1, "İlçe gerekli"),
  latitude: z
    .number({ error: "Konum seçin" })
    .min(-90, "Geçerli bir konum seçin")
    .max(90, "Geçerli bir konum seçin"),
  longitude: z
    .number({ error: "Konum seçin" })
    .min(-180, "Geçerli bir konum seçin")
    .max(180, "Geçerli bir konum seçin"),
  phone: z.string().optional(),
  imageUrl: optionalUrl,
  categoryId: z
    .number({ error: "Kategori seçin" })
    .int("Kategori seçin")
    .min(1, "Kategori seçin"),
});
export type BusinessInput = z.infer<typeof businessSchema>;

export const packageSchema = z
  .object({
    title: z.string().min(1, "Paket adı gerekli"),
    description: z.string().optional(),
    originalPrice: z
      .number({ error: "Geçerli bir fiyat girin" })
      .min(0, "Geçerli bir fiyat girin"),
    discountedPrice: z
      .number({ error: "Geçerli bir indirimli fiyat girin" })
      .min(0, "Geçerli bir indirimli fiyat girin"),
    quantity: z
      .number({ error: "Adet girin" })
      .int("Adet tam sayı olmalı")
      .min(1, "Adet en az 1 olmalı"),
    pickupDate: z.string().min(1, "Teslim alma tarihi gerekli"),
    pickupStart: z.string().min(1, "Başlangıç saati gerekli"),
    pickupEnd: z.string().min(1, "Bitiş saati gerekli"),
    imageUrl: optionalUrl,
  })
  .refine((d) => d.discountedPrice < d.originalPrice, {
    message: "İndirimli fiyat orijinal fiyattan düşük olmalı",
    path: ["discountedPrice"],
  });
export type PackageInput = z.infer<typeof packageSchema>;

// iyzico alt üye işyeri (ödeme hesabı) onboarding — backend subMerchantSchema'nın aynası.
const ibanRegex = /^TR\d{24}$/;
export const subMerchantSchema = z
  .object({
    subMerchantType: z.enum([
      "PERSONAL",
      "PRIVATE_COMPANY",
      "LIMITED_OR_JOINT_STOCK_COMPANY",
    ]),
    iban: z
      .string()
      .transform((s) => s.replace(/\s+/g, "").toUpperCase())
      .refine((v) => ibanRegex.test(v), "Geçerli bir IBAN girin (TR ile başlamalı)"),
    gsmNumber: z.string().min(1, "Telefon numarası gerekli"),
    contactName: z.string().optional(),
    contactSurname: z.string().optional(),
    identityNumber: z.string().optional(),
    legalCompanyTitle: z.string().optional(),
    taxOffice: z.string().optional(),
    taxNumber: z.string().optional(),
  })
  .superRefine((d, ctx) => {
    if (d.subMerchantType === "PERSONAL") {
      if (!d.contactName)
        ctx.addIssue({ code: "custom", path: ["contactName"], message: "Ad gerekli" });
      if (!d.contactSurname)
        ctx.addIssue({ code: "custom", path: ["contactSurname"], message: "Soyad gerekli" });
      if (!d.identityNumber || !/^\d{11}$/.test(d.identityNumber))
        ctx.addIssue({
          code: "custom",
          path: ["identityNumber"],
          message: "11 haneli TC kimlik no gerekli",
        });
    } else {
      if (!d.legalCompanyTitle)
        ctx.addIssue({
          code: "custom",
          path: ["legalCompanyTitle"],
          message: "Şirket ünvanı gerekli",
        });
      if (!d.taxOffice)
        ctx.addIssue({ code: "custom", path: ["taxOffice"], message: "Vergi dairesi gerekli" });
      if (
        d.subMerchantType === "LIMITED_OR_JOINT_STOCK_COMPANY" &&
        (!d.taxNumber || !/^\d{10}$/.test(d.taxNumber))
      )
        ctx.addIssue({ code: "custom", path: ["taxNumber"], message: "10 haneli vergi no gerekli" });
    }
  });
export type SubMerchantInput = z.infer<typeof subMerchantSchema>;

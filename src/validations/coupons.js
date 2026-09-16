const { z } = require('zod');
const money = z.coerce.number().finite().min(0).max(10000000).refine((v) => Math.abs(v * 100 - Math.round(v * 100)) < 0.00001, 'Tutar en fazla iki ondalık basamak içermeli');
const couponSettingsSchema = z.object({
  code: z.string().trim().min(1).max(40).regex(/^[A-Za-z0-9_-]+$/, 'Kod yalnız harf, rakam, tire ve alt çizgi içerebilir').transform((s) => s.toUpperCase()),
  title: z.string().trim().max(100).nullable().optional(),
  discountType: z.enum(['percentage', 'fixed']),
  discountValue: money.refine((n) => n > 0, 'İndirim sıfırdan büyük olmalı'),
  minOrderAmount: money.default(0),
  maxDiscountAmount: money.nullable().default(null),
  maxUsage: z.coerce.number().int().min(1).max(1000000).default(100),
  perUserLimit: z.coerce.number().int().min(1).max(1000).nullable().default(null),
  budgetLimit: money.refine((n) => n > 0, 'Bütçe sıfırdan büyük olmalı').nullable().default(null),
  firstOrderOnly: z.boolean().default(false),
  isDiscoverable: z.boolean().default(false),
  businessIds: z.array(z.string().uuid()).max(500).default([]).transform((a) => [...new Set(a)]),
  merchantConsentConfirmed: z.boolean().default(false),
  expiresAt: z.coerce.date(),
  isActive: z.boolean().default(true),
}).superRefine((v, ctx) => {
  const issue = (message) => ctx.addIssue({ code: 'custom', message });
  if (v.discountType === 'percentage' && v.discountValue > 100) issue('Yüzde indirim 100’ü aşamaz');
  if (v.isActive && v.isDiscoverable && (!v.businessIds.length || !v.merchantConsentConfirmed)) {
    issue('Kampanyayı yayımlamak için katılan işletmeleri seçin ve indirim paylaşımı onayını doğrulayın');
  }
});
module.exports = { couponSettingsSchema };

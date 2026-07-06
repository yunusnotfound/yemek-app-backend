const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const {
  sequelize,
  User,
  Category,
  Business,
  SurprisePackage,
  Coupon,
} = require('../src/models');
const cacheService = require('../src/services/cacheService');

// Testler arası izolasyon: tüm tabloları temizle (FK CASCADE + kimlik sıfırla)
// VE liste cache'lerini boşalt — aksi halde Redis'te kalan stale liste sonucu
// (truncate Redis'i temizlemez) cache-backed uçları belirsiz yapar.
async function resetDb() {
  await sequelize.truncate({ cascade: true, restartIdentity: true });
  await Promise.all([
    cacheService.delPattern('packages:list:*'),
    cacheService.delPattern('businesses:list:*'),
    cacheService.delPattern('maps:nearby:*'),
  ]);
}

// Dosya sonunda bağlantıları kapat (Jest her test dosyasına ayrı modül kaydı
// verdiğinden bu güvenli). forceExit yine de artçı güvence olarak açık.
async function closeDb() {
  await sequelize.close();
  await cacheService.quit();
}

// Fixture değerleri crypto ile KÜRESEL benzersiz üretilir — böylece suite/dosya
// çalışma sırası veya truncate zamanlamasından bağımsız olarak asla çakışmaz.
const uid = () => crypto.randomUUID();

async function createUser(overrides = {}) {
  return User.create({
    name: 'Test User',
    email: `u-${uid()}@test.local`,
    password: 'password123',
    phone: '5551112233',
    role: 'customer',
    isEmailVerified: true,
    ...overrides,
  });
}

async function createCategory(overrides = {}) {
  const slug = `cat-${uid()}`;
  return Category.create({ name: slug, slug, ...overrides });
}

async function createBusiness(overrides = {}) {
  const ownerId = overrides.ownerId || (await createUser({ role: 'business_owner' })).id;
  const categoryId = overrides.categoryId || (await createCategory()).id;
  return Business.create({
    name: 'Test Business',
    address: 'Test Address',
    city: 'Istanbul',
    district: 'Kadikoy',
    latitude: 41.0,
    longitude: 29.0,
    isActive: true,
    isApproved: true, // test işletmeleri varsayılan onaylı — sipariş alınabilsin
    // Aktif sub-merchant — ücretli siparişler marketplace ödeme yolunu kullansın
    // (aksi halde create "İşletme henüz ödeme almaya hazır değil" 400 döner).
    subMerchantKey: 'test-submerchant-key',
    subMerchantStatus: 'active',
    ...overrides,
    ownerId,
    categoryId,
  });
}

// Lokal tarih (YYYY-MM-DD) — controller "today"'ı da lokal saatle hesapladığından
// UTC toISOString kullanmak gece yarısı sınırında bir gün kayıp/fazla verebilir.
function localDatePlus(days = 0) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

async function createPackage(overrides = {}) {
  const businessId = overrides.businessId || (await createBusiness()).id;
  return SurprisePackage.create({
    title: 'Test Package',
    originalPrice: 100,
    discountedPrice: 50,
    quantity: 5,
    remainingQuantity: 5,
    pickupStart: '10:00:00',
    pickupEnd: '20:00:00',
    // Birkaç gün ileri — TZ sınırından bağımsız olarak "pickupDate >= today" geçer.
    pickupDate: localDatePlus(3),
    isActive: true,
    ...overrides,
    businessId,
  });
}

async function createCoupon(overrides = {}) {
  return Coupon.create({
    code: `T${uid().replace(/-/g, '').slice(0, 12).toUpperCase()}`,
    discountType: 'percentage',
    discountValue: 10,
    minOrderAmount: 0,
    maxUsage: 100,
    currentUsage: 0,
    isActive: true,
    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
    ...overrides,
  });
}

function authToken(user) {
  return jwt.sign(
    { id: user.id, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: '15m' },
  );
}

function authHeader(user) {
  return { Authorization: `Bearer ${authToken(user)}` };
}

module.exports = {
  resetDb,
  closeDb,
  createUser,
  createCategory,
  createBusiness,
  createPackage,
  createCoupon,
  authToken,
  authHeader,
};

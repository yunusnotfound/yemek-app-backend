'use strict';

// Explicit, reversible catalog fixtures. Never runs during deployment/migrations.
require('dotenv').config({ quiet: true });
const { createHash } = require('node:crypto');
const assert = require('node:assert/strict');

const namespace = 'bitirgitsin:demo-catalog:v1';
const email = 'catalog-demo@bitirgitsin.invalid';
const notice = 'TEST VERİSİ — Bu işletme ve paketler uygulama denemesi içindir. Gerçek satış veya teslimat yapılmaz.';
const imageBase = 'https://api.bitirgitsin.com/uploads/demo-catalog-v1';
// These are existing public upload filenames, not local Flutter asset paths.
// The mobile sources now use lossless WebP; keep the deployed PNG URLs stable.
// See docs/demo-catalog.md for preparing equivalent PNGs from those sources.
const definitions = [
  { key: 'bakery', name: 'Mahalle Fırını', category: 'firin-pastane', image: 'firin-pastane.png', lat: 41.0468, lng: 28.9101,
    items: [['Fırından Sürpriz', 'Simit, poğaça ve günlük ekmek seçkisi.', 240, 80, 8], ['Kahvaltılık Kutu', 'Açma, zeytinli poğaça ve mini kruvasan seçkisi.', 300, 100, 3]] },
  { key: 'cafe', name: 'Mola Kahve', category: 'kafe', image: 'kafe.png', lat: 41.0479, lng: 28.9132,
    items: [['Kahve Molası', 'Bir kahve ve günün tatlı atıştırmalığı.', 280, 95, 5], ['Kruvasan Keyfi', 'İki kruvasan ve filtre kahve seçkisi.', 360, 120, 2]] },
  { key: 'restaurant', name: 'Sofra Mutfağı', category: 'restoran', image: 'restoran.png', lat: 41.0446, lng: 28.9125,
    items: [['Günün Sofrası', 'Günün ana yemeği, pilav ve mevsim salatası.', 450, 150, 6], ['Doyuran İkili', 'İki kişilik ana yemek ve tamamlayıcı lezzetler.', 630, 210, 4]] },
  { key: 'greengrocer', name: 'Taze Bahçe', category: 'manav', image: 'manav.png', lat: 41.0498, lng: 28.9091,
    items: [['Mevsim Sepeti', 'Mevsim meyve ve sebzelerinden karışık bir seçki.', 300, 100, 12], ['Meyve Molası', 'Günlük meyvelerden küçük bir paylaşım kutusu.', 180, 60, 2]] },
  { key: 'market', name: 'Komşu Market', category: 'market', image: 'market.png', lat: 41.0428, lng: 28.9086,
    items: [['Kahvaltı Sepeti', 'Ambalajlı kahvaltılık ve fırın ürünleri seçkisi.', 390, 130, 7], ['Atıştırmalık Kutu', 'Paketli atıştırmalık ve içeceklerden sürpriz seçki.', 270, 90, 1]] },
  { key: 'patisserie', name: 'Tatlı Atölyesi', category: 'firin-pastane', image: 'pastane.png', lat: 41.0503, lng: 28.9152,
    items: [['Tatlı Bir Sürpriz', 'Günün pasta dilimi ve mini tatlılarından seçki.', 420, 140, 4], ['Kurabiye Kutusu', 'Karışık el yapımı kurabiye seçkisi.', 210, 70, 9]] },
  { key: 'lunch', name: 'Yeşil Tabak', category: 'restoran', image: 'foodbox-meal.png', lat: 41.0435, lng: 28.9162,
    items: [['Dengeli Öğün', 'Sebze, tahıl ve protein içeren bir öğün kutusu.', 360, 120, 3], ['Hafif Akşam', 'Mevsim salatası ve günün sebze yemeği.', 330, 110, 6]] },
];

function id(key) {
  const hex = createHash('sha256').update(`${namespace}:${key}`).digest('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-a${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}

function buildCatalog(now = new Date()) {
  // Istanbul's UTC+03 date, independent of the host/server timezone.
  const local = new Date(now.getTime() + 3 * 3600000);
  const startOffset = local.getUTCHours() >= 22 ? 1 : 0;
  return definitions.map((entry, index) => ({
    ...entry,
    id: id(entry.key),
    packages: entry.items.map(([title, description, originalPrice, discountedPrice, quantity], variant) => {
      const date = new Date(local);
      date.setUTCDate(date.getUTCDate() + startOffset + variant);
      const pickupDate = date.toISOString().slice(0, 10);
      return {
        id: id(`${entry.key}:${variant}:${pickupDate}`),
        businessId: id(entry.key),
        title: `TEST · ${title}`,
        description: `${notice}\n\nÖrnek içerik: ${description}`,
        originalPrice, discountedPrice, quantity, remainingQuantity: quantity,
        pickupDate,
        pickupStart: variant === 0 ? ['20:00', '20:30', '21:00'][index % 3] : ['12:00', '14:00', '17:00'][index % 3],
        pickupEnd: variant === 0 ? '23:45' : ['15:00', '18:00', '21:00'][index % 3],
        imageUrl: `${imageBase}/${entry.image}`,
        isActive: true, isSuspended: false, isRecurring: false,
      };
    }),
  }));
}

async function main() {
  const args = new Set(process.argv.slice(2));
  for (const arg of args) assert(['--apply', '--allow-production', '--archive'].includes(arg), `Unknown argument: ${arg}`);
  const apply = args.has('--apply');
  const archive = args.has('--archive');
  if (apply && process.env.NODE_ENV === 'production') {
    assert(args.has('--allow-production'), 'Production changes require --allow-production.');
  }
  const { sequelize, User, Category, Business, SurprisePackage, BusinessHours, Order } = require('../src/models');
  const catalog = buildCatalog();
  const ownerId = id('owner');
  sequelize.options.logging = false;
  try {
    const categories = await Category.findAll({ attributes: ['id', 'slug'], raw: true });
    const categoryIds = new Map(categories.map((c) => [c.slug, c.id]));
    for (const entry of catalog) assert(categoryIds.has(entry.category), `Missing category: ${entry.category}`);
    const existingOwner = await User.findByPk(ownerId, { paranoid: false });
    if (existingOwner) assert(existingOwner.email === email && !existingOwner.deletedAt, 'Demo owner conflict.');
    const plan = {
      action: archive ? 'archive' : 'create-missing', apply,
      businesses: catalog.map((entry) => ({ id: entry.id, name: `TEST · ${entry.name}`, category: entry.category })),
      packageCount: catalog.reduce((sum, entry) => sum + entry.packages.length, 0),
      dates: [...new Set(catalog.flatMap((entry) => entry.packages.map((pkg) => pkg.pickupDate)))],
    };
    if (!apply) { console.log(JSON.stringify(plan, null, 2)); return; }
    const results = await sequelize.transaction(async (transaction) => {
      // Serialize repeated invocations; no existing stock or prices are reset.
      await sequelize.query("SELECT pg_advisory_xact_lock(hashtext('bitirgitsin-demo-catalog-v1'))", { transaction });
      if (!archive) await User.findOrCreate({
        where: { id: ownerId },
        defaults: { name: 'TEST · Katalog İşletmeleri', email, role: 'business_owner', password: null, isEmailVerified: false },
        transaction,
      });
      const counts = { businessesCreated: 0, packagesCreated: 0, businessesArchived: 0, packagesArchived: 0 };
      for (const entry of catalog) {
        let business = await Business.findByPk(entry.id, { transaction, paranoid: false });
        if (business) assert(business.ownerId === ownerId && business.name.startsWith('TEST · ') && !business.deletedAt, 'Demo business conflict.');
        if (archive) {
          if (!business) continue;
          const packages = await SurprisePackage.findAll({ where: { businessId: entry.id }, attributes: ['id'], transaction });
          const activeOrders = await Order.count({ where: { packageId: packages.map((pkg) => pkg.id), status: ['awaiting_payment', 'pending', 'confirmed'] }, transaction });
          assert(activeOrders === 0, 'Resolve active demo orders before archiving.');
          const [count] = await SurprisePackage.update({ isActive: false, isRecurring: false }, { where: { businessId: entry.id }, transaction });
          await business.update({ isActive: false }, { transaction });
          counts.businessesArchived++;
          counts.packagesArchived += count;
          continue;
        }
        if (!business) {
          business = await Business.create({
            id: entry.id, ownerId, categoryId: categoryIds.get(entry.category),
            name: `TEST · ${entry.name}`, description: notice,
            address: `TEST adresi — Numunebağ çevresi, örnek nokta ${catalog.indexOf(entry) + 1}. Teslimat yapılmaz.`,
            city: 'İstanbul', district: 'Bayrampaşa', latitude: entry.lat, longitude: entry.lng,
            imageUrl: `${imageBase}/${entry.image}`, rating: 0,
            isActive: true, isApproved: true, approvalStatus: 'approved', approvedAt: new Date(),
            subMerchantStatus: 'none',
          }, { transaction });
          counts.businessesCreated++;
          for (let dayOfWeek = 0; dayOfWeek < 7; dayOfWeek++) await BusinessHours.create({
            businessId: entry.id, dayOfWeek, openTime: '09:00', closeTime: '23:59', isClosed: false,
          }, { transaction });
        }
        assert(business.isActive, 'Archived demo business: refusing to reactivate automatically.');
        for (const pkg of entry.packages) {
          const [record, created] = await SurprisePackage.findOrCreate({ where: { id: pkg.id }, defaults: pkg, transaction });
          assert(record.businessId === entry.id && record.title.startsWith('TEST · '), 'Demo package conflict.');
          if (created) counts.packagesCreated++;
        }
      }
      return counts;
    });
    // Await a ready connection so invalidation completes before this CLI exits.
    const Redis = require('ioredis');
    const redis = new Redis(process.env.REDIS_URL || {
      host: process.env.REDIS_HOST || 'localhost',
      port: Number(process.env.REDIS_PORT) || 6379,
      password: process.env.REDIS_PASSWORD || undefined,
    }, {
      lazyConnect: true, maxRetriesPerRequest: 1,
      retryStrategy: () => null,
      ...(process.env.REDIS_URL?.startsWith('rediss://')
        ? { tls: { rejectUnauthorized: true, ...(process.env.REDIS_CA_CERT ? { ca: process.env.REDIS_CA_CERT } : {}) } }
        : {}),
    });
    redis.on('error', () => {});
    try {
      await redis.incr('cachever:businesses:list');
      await redis.incr('cachever:packages:list');
    } catch (error) {
      console.error('Catalog committed; cache invalidation failed. Cached lists expire in 5 minutes.');
      throw error;
    } finally { redis.disconnect(); }
    console.log(JSON.stringify({ ...plan, results }, null, 2));
  } finally { await sequelize.close(); }
}

module.exports = { buildCatalog, id, definitions };
if (require.main === module) main().catch((error) => { console.error(error.message); process.exitCode = 1; });

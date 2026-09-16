const { SurprisePackage, Business, Category, Order, sequelize } = require('../models');
const { Op } = require('sequelize');
const { paginate, paginatedResponse, haversineSql } = require('../utils/helpers');
const cacheService = require('../services/cacheService');
const coalesce = require('../services/requestCoalescer');

exports.getAll = async (req, res, next) => {
  try {
    const { city, district, categoryId, maxPrice, lat, lng, radius, excludeExpired } = req.query;
    const { page, limit, offset } = paginate(req.query);

    const userLat = parseFloat(lat);
    const userLng = parseFloat(lng);
    const maxRadius = parseFloat(radius);

    // Bu üç değer SQL ifadesine SAYI olarak gömüldüğünden (haversineSql), sonlu
    // sayı olmaları zorunlu — aksi halde geo filtresi hiç uygulanmaz.
    const useGeoFilter =
      Number.isFinite(userLat) && Number.isFinite(userLng) && Number.isFinite(maxRadius) && maxRadius > 0;

    // SQL filters and orders by the exact coordinate. Its cache key must use
    // the same coordinate, otherwise nearby users can receive the wrong list.
    const cacheKeyParts = { city, district, categoryId, maxPrice, excludeExpired, page, limit };
    if (useGeoFilter) {
      cacheKeyParts.lat = userLat;
      cacheKeyParts.lng = userLng;
      cacheKeyParts.radius = maxRadius;
    }
    // Sürümlü anahtar: geçersiz kılma tek INCR ile O(1) (bkz. cacheService).
    const cacheKey = await cacheService.versionedKey('packages:list', cacheKeyParts);
    const cached = req.campaign ? null : await cacheService.get(cacheKey);
    if (cached) {
      return res.json(cached);
    }

    const responseData = await coalesce(req.campaign ? null : cacheKey, async () => {
    // Yalnızca onaylı + aktif işletmelerin paketleri herkese listelenir.
    const businessWhere = { isActive: true, isApproved: true, isSuspended: false };
    if (req.campaign?.businessIds.length) businessWhere.id = { [Op.in]: req.campaign.businessIds };
    if (city) businessWhere.city = city;
    if (district) businessWhere.district = district;
    if (categoryId) businessWhere.categoryId = categoryId;

    const packageWhere = { isActive: true, isSuspended: false, remainingQuantity: { [Op.gt]: 0 } };
    if (maxPrice) packageWhere.discountedPrice = { [Op.lte]: maxPrice };
    if (req.campaign) {
      packageWhere[Op.and] = [
        sequelize.where(sequelize.literal('"SurprisePackage"."discountedPrice" * LEAST("SurprisePackage"."remainingQuantity", 100)'), { [Op.gte]: Number(req.campaign.minOrderAmount) }),
        sequelize.literal(`(("SurprisePackage"."pickupDate"::date + "SurprisePackage"."pickupEnd"::time +
          CASE WHEN "SurprisePackage"."pickupEnd"::time <= "SurprisePackage"."pickupStart"::time
          THEN INTERVAL '1 day' ELSE INTERVAL '0 day' END) AT TIME ZONE 'Europe/Istanbul') > NOW()`),
      ];
    }

    if (excludeExpired !== 'false') {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      packageWhere.pickupDate = { [Op.gte]: today };
    }

    // Bounding-box ön filtresi: idx_businesses_lat_lng'i kullanabilsin diye önce
    // SQL'de kutu ile daralt. Kesin dairesel filtre aşağıda yine SQL'de (Haversine)
    // uygulanır; kutu yalnız indeksten faydalanmak için var.
    if (useGeoFilter) {
      const latDelta = maxRadius / 111.32; // ~111.32 km per degree of latitude
      const cosLat = Math.cos((userLat * Math.PI) / 180);
      // Guard against division by ~0 near the poles (not relevant for Turkey, but safe).
      const lngDelta = maxRadius / (111.32 * Math.max(Math.abs(cosLat), 1e-6));

      businessWhere.latitude = { [Op.between]: [userLat - latDelta, userLat + latDelta] };
      businessWhere.longitude = { [Op.between]: [userLng - lngDelta, userLng + lngDelta] };
    }

    const businessAttributes = ['id', 'name', 'address', 'city', 'district', 'latitude', 'longitude', 'imageUrl', 'rating'];

    const queryOptions = {
      where: packageWhere,
      include: [
        {
          model: Business,
          as: 'business',
          where: businessWhere,
          attributes: businessAttributes,
          include: [{ model: Category, as: 'category', attributes: ['id', 'name', 'slug'] }],
        },
      ],
      order: [['pickupDate', 'ASC'], ['pickupStart', 'ASC']],
      limit,
      offset,
    };

    if (useGeoFilter) {
      // Mesafe artık SQL'de hesaplanıyor: yarıçap filtresi, sıralama ve
      // LIMIT/OFFSET veritabanında yapılır. Böylece "en yakın" gerçekten en yakın
      // olur ve `total` gerçek toplamı gösterir (eskiden 500'lük aday penceresi
      // yüzünden ikisi de yanlış olabiliyordu).
      const distanceSql = haversineSql(userLat, userLng, '"business"."latitude"', '"business"."longitude"');

      // subQuery:false şart — LIMIT'li bir sorguda include kolonlarına ORDER BY /
      // WHERE ile ancak böyle erişilebilir. Paket→işletme çoktan-teke olduğu için
      // JOIN satır çoğaltmaz, dolayısıyla LIMIT doğru sayıda paket döndürür.
      queryOptions.subQuery = false;
      queryOptions.where = {
        [Op.and]: [packageWhere, sequelize.where(sequelize.literal(distanceSql), { [Op.lte]: maxRadius })],
      };
      // distance'ı işletme nesnesinin içine koy — istemci onu orada bekliyor.
      // AÇIK liste kullanılıyor: `{ include: [...] }` biçimi "tüm kolonlar + bunlar"
      // anlamına gelir ve iban/identityNumber gibi alanları geri sızdırırdı.
      queryOptions.include[0].attributes = [
        ...businessAttributes,
        [sequelize.literal(distanceSql), 'distance'],
      ];
      queryOptions.order = [[sequelize.literal(distanceSql), 'ASC'], ['pickupDate', 'ASC']];
    }

    const { count, rows: packages } = await SurprisePackage.findAndCountAll(queryOptions);

    const responseData = paginatedResponse(packages, count, page, limit);
    if (!req.campaign) await cacheService.set(cacheKey, responseData, 300);
    return responseData;
    });
    res.json(responseData);
  } catch (error) {
    next(error);
  }
};

exports.getById = async (req, res, next) => {
  try {
    const pkg = await SurprisePackage.findByPk(req.params.id, {
      include: [
        {
          model: Business,
          as: 'business',
          // GET /packages/:id kimlik doğrulaması İSTEMEYEN public bir uç
          // (bkz. routes/packages.js). Whitelist olmadan işletmenin iban,
          // identityNumber, gsmNumber gibi alanları herkese açılırdı.
          attributes: Business.PUBLIC_ATTRIBUTES,
          where: { isActive: true, isApproved: true, isSuspended: false },
          required: true,
          include: [{ model: Category, as: 'category', attributes: ['id', 'name', 'slug'] }],
        },
      ],
    });

    if (!pkg || !pkg.isActive || pkg.isSuspended) {
      return res.status(404).json({ message: 'Paket bulunamadı' });
    }

    // Onaylanmamış/pasif işletmenin paketi public detayda görünmez (liste ile tutarlı).
    if (!pkg.business || !pkg.business.isActive || !pkg.business.isApproved) {
      return res.status(404).json({ message: 'Paket bulunamadı' });
    }

    res.json({ package: pkg });
  } catch (error) {
    next(error);
  }
};

exports.create = async (req, res, next) => {
  try {
    const { businessId, title, description, originalPrice, discountedPrice, quantity, pickupStart, pickupEnd, pickupDate, imageUrl } = req.body;

    const business = await Business.findByPk(businessId);
    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı' });
    }

    if (business.ownerId !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Bu işletme için paket oluşturma yetkiniz yok' });
    }

    const pkg = await SurprisePackage.create({
      businessId,
      title,
      description,
      originalPrice,
      discountedPrice,
      quantity,
      remainingQuantity: quantity,
      pickupStart,
      pickupEnd,
      pickupDate,
      imageUrl,
    });

    await cacheService.invalidateNamespace('packages:list');

    res.status(201).json({
      message: 'Paket oluşturuldu',
      package: pkg,
    });
  } catch (error) {
    next(error);
  }
};

exports.update = async (req, res, next) => {
  try {
    const pkg = await SurprisePackage.findByPk(req.params.id, {
      include: [{ model: Business, as: 'business' }],
    });

    if (!pkg) {
      return res.status(404).json({ message: 'Paket bulunamadı' });
    }

    if (pkg.business.ownerId !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Bu paketi güncelleme yetkiniz yok' });
    }

    const { title, description, originalPrice, discountedPrice, quantity, remainingQuantity, pickupStart, pickupEnd, pickupDate, imageUrl, isActive } = req.body;

    await sequelize.transaction(async (transaction) => {
      await pkg.reload({ transaction, lock: { level: transaction.LOCK.UPDATE, of: SurprisePackage } });
      if (pkg.isSuspended && isActive === true && req.user.role !== 'admin') {
        throw Object.assign(new Error('Paket yönetici tarafından askıya alınmış'), { statusCode: 403 });
      }
      // Read both counters under the row lock: a concurrent reservation may
      // have reduced availability since the edit form was opened. Changing the
      // total adds/removes only that difference, preserving committed stock.
      const nextQuantity = quantity ?? pkg.quantity;
      const nextRemainingQuantity = remainingQuantity ??
        (pkg.remainingQuantity + nextQuantity - pkg.quantity);
      if (nextRemainingQuantity < 0) {
        throw Object.assign(new Error('Toplam adet, satılmış veya rezerve edilmiş adetten az olamaz'), { statusCode: 400 });
      }
      if (nextRemainingQuantity > nextQuantity) {
        throw Object.assign(new Error('Kalan miktar toplam miktardan fazla olamaz'), { statusCode: 400 });
      }
      if (Number(discountedPrice ?? pkg.discountedPrice) >= Number(originalPrice ?? pkg.originalPrice)) {
        throw Object.assign(new Error('İndirimli fiyat orijinal fiyattan düşük olmalı'), { statusCode: 400 });
      }
      await pkg.update({ title, description, originalPrice, discountedPrice,
        quantity: nextQuantity, remainingQuantity: nextRemainingQuantity,
        pickupStart, pickupEnd, pickupDate, imageUrl, isActive }, { transaction });
    });

    await cacheService.invalidateNamespace('packages:list');

    res.json({
      message: 'Paket güncellendi',
      package: pkg,
    });
  } catch (error) {
    next(error);
  }
};

exports.remove = async (req, res, next) => {
  try {
    const pkg = await SurprisePackage.findByPk(req.params.id, {
      include: [{ model: Business, as: 'business' }],
    });

    if (!pkg) {
      return res.status(404).json({ message: 'Paket bulunamadı' });
    }

    if (pkg.business.ownerId !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Bu paketi silme yetkiniz yok' });
    }

    await sequelize.transaction(async (transaction) => {
      await pkg.reload({ transaction, lock: { level: transaction.LOCK.UPDATE, of: SurprisePackage } });
      const activeOrders = await Order.count({ where: { packageId: pkg.id,
        [Op.or]: [{ status: { [Op.in]: ['awaiting_payment', 'pending', 'confirmed'] } },
          { refundStatus: { [Op.in]: ['pending', 'processing', 'review'] } }] }, transaction });
      if (activeOrders > 0) throw Object.assign(new Error('Bu paket için aktif sipariş veya iade var, silinemez'), { statusCode: 409 });
      await pkg.destroy({ transaction });
    });

    await cacheService.invalidateNamespace('packages:list');

    res.json({ message: 'Paket silindi' });
  } catch (error) {
    next(error);
  }
};

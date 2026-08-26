const { SurprisePackage, Business, Category, Order, sequelize } = require('../models');
const { Op } = require('sequelize');
const { paginate, paginatedResponse, haversineSql } = require('../utils/helpers');
const cacheService = require('../services/cacheService');

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

    // Koordinatlar ~1.1 km'lik ızgaraya (2 ondalık) yuvarlanır. 3 ondalık ~110 m
    // demekti; yürüyen bir kullanıcı her 110 m'de yeni anahtar üretiyor, her giriş
    // yaklaşık BİR kez okunup ölüyordu — cache'in maliyeti vardı, faydası yoktu.
    // Yarıçap zaten km mertebesinde olduğu için 1.1 km'lik merkez kayması sonucu
    // pratikte değiştirmez, buna karşılık anahtar sayısını ~100 kat düşürür.
    const cacheKeyParts = { city, district, categoryId, maxPrice, excludeExpired, page, limit };
    if (useGeoFilter) {
      cacheKeyParts.lat = parseFloat(lat).toFixed(2);
      cacheKeyParts.lng = parseFloat(lng).toFixed(2);
      cacheKeyParts.radius = radius;
    }
    // Sürümlü anahtar: geçersiz kılma tek INCR ile O(1) (bkz. cacheService).
    const cacheKey = await cacheService.versionedKey('packages:list', cacheKeyParts);
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return res.json(cached);
    }

    // Yalnızca onaylı + aktif işletmelerin paketleri herkese listelenir.
    const businessWhere = { isActive: true, isApproved: true };
    if (city) businessWhere.city = city;
    if (district) businessWhere.district = district;
    if (categoryId) businessWhere.categoryId = categoryId;

    const packageWhere = { isActive: true, remainingQuantity: { [Op.gt]: 0 } };
    if (maxPrice) packageWhere.discountedPrice = { [Op.lte]: maxPrice };

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
    await cacheService.set(cacheKey, responseData, 300);
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
          include: [{ model: Category, as: 'category', attributes: ['id', 'name', 'slug'] }],
        },
      ],
    });

    if (!pkg) {
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

    // remainingQuantity validasyonu
    if (remainingQuantity !== undefined && quantity !== undefined) {
      if (remainingQuantity > quantity) {
        return res.status(400).json({ message: 'Kalan miktar toplam miktardan fazla olamaz' });
      }
    } else if (remainingQuantity !== undefined) {
      if (remainingQuantity > pkg.quantity) {
        return res.status(400).json({ message: 'Kalan miktar toplam miktardan fazla olamaz' });
      }
    }

    await pkg.update({
      title, description, originalPrice, discountedPrice,
      quantity, remainingQuantity, pickupStart, pickupEnd,
      pickupDate, imageUrl, isActive,
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

    // Aktif sipariş kontrolü
    const activeOrders = await Order.count({
      where: {
        packageId: pkg.id,
        status: { [Op.in]: ['pending', 'confirmed'] },
      },
    });

    if (activeOrders > 0) {
      return res.status(400).json({ message: 'Bu paket için aktif siparişler var, silinemez' });
    }

    await pkg.destroy();

    await cacheService.invalidateNamespace('packages:list');

    res.json({ message: 'Paket silindi' });
  } catch (error) {
    next(error);
  }
};

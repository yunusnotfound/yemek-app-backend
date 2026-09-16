const {
  Business,
  Order,
  Category,
  User,
  Review,
  SurprisePackage,
  sequelize,
} = require("../models");
const { Op } = require("sequelize");
const {
  paginate,
  paginatedResponse,
  haversineSql,
} = require("../utils/helpers");
const cacheService = require('../services/cacheService');
const coalesce = require('../services/requestCoalescer');

exports.getAll = async (req, res, next) => {
  try {
    const { city, district, categoryId, search, lat, lng, radius } = req.query;
    const { page, limit, offset } = paginate(req.query);

    const userLat = parseFloat(lat);
    const userLng = parseFloat(lng);
    const maxRadius = parseFloat(radius);

    // Bu üç değer SQL ifadesine SAYI olarak gömülüyor (haversineSql) — sonlu
    // olmaları zorunlu, aksi halde geo filtresi hiç uygulanmaz.
    const useGeoFilter =
      Number.isFinite(userLat) && Number.isFinite(userLng) && Number.isFinite(maxRadius) && maxRadius > 0;

    // Keep the cache key consistent with the exact SQL distance filter.
    const keyParts = { city, district, categoryId, search, page, limit };
    if (useGeoFilter) {
      keyParts.lat = userLat;
      keyParts.lng = userLng;
      keyParts.radius = maxRadius;
    }
    // Sürümlü anahtar: geçersiz kılma tek INCR ile O(1) (bkz. cacheService).
    const cacheKey = await cacheService.versionedKey('businesses:list', keyParts);
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return res.json(cached);
    }

    const responseData = await coalesce(cacheKey, async () => {
    const where = { isActive: true, isApproved: true, isSuspended: false };
    if (city) where.city = city;
    if (district) where.district = district;
    if (categoryId) where.categoryId = categoryId;
    if (search) where.name = { [Op.iLike]: `%${search}%` };

    // Bounding-box ön filtresi (idx_businesses_lat_lng): sınırsız tarama yerine
    // önce SQL'de daralt; BETWEEN, koordinatı NULL olan satırları da eler.
    if (useGeoFilter) {
      const latDelta = maxRadius / 111.32;
      const cosLat = Math.cos((userLat * Math.PI) / 180);
      const lngDelta = maxRadius / (111.32 * Math.max(Math.abs(cosLat), 1e-6));
      where.latitude = { [Op.between]: [userLat - latDelta, userLat + latDelta] };
      where.longitude = { [Op.between]: [userLng - lngDelta, userLng + lngDelta] };
    }

    const queryOptions = {
      where,
      // GET /businesses kimlik doğrulaması istemeyen PUBLIC bir uç; whitelist
      // olmadan iban/identityNumber/gsmNumber gibi alanlar herkese açılıyordu.
      attributes: Business.PUBLIC_ATTRIBUTES,
      include: [
        { model: Category, as: "category", attributes: ["id", "name", "slug"] },
      ],
      order: [["createdAt", "DESC"]],
      limit,
      offset,
    };

    if (useGeoFilter) {
      // Mesafe SQL'de hesaplanır; yarıçap filtresi, sıralama ve LIMIT/OFFSET
      // veritabanında yapılır. Eskiden 500 aday çekilip JS'te sıralanıyordu —
      // kutu içinde 500'den fazla işletme olduğunda en yakınlar listeye hiç
      // girmeyebiliyor ve `total` yanlış çıkıyordu.
      const distanceSql = haversineSql(userLat, userLng, '"Business"."latitude"', '"Business"."longitude"');

      queryOptions.where = {
        [Op.and]: [where, sequelize.where(sequelize.literal(distanceSql), { [Op.lte]: maxRadius })],
      };
      // AÇIK liste: `{ include: [...] }` biçimi tüm kolonları geri getirir ve
      // PUBLIC_ATTRIBUTES whitelist'ini etkisiz kılardı.
      queryOptions.attributes = [
        ...Business.PUBLIC_ATTRIBUTES,
        [sequelize.literal(distanceSql), 'distance'],
      ];
      queryOptions.order = [[sequelize.literal(distanceSql), 'ASC']];
    }

    const { count, rows: businesses } = await Business.findAndCountAll(queryOptions);

    const responseData = paginatedResponse(businesses, count, page, limit);
    await cacheService.set(cacheKey, responseData, 300);
    return responseData;
    });
    res.json(responseData);
  } catch (error) {
    next(error);
  }
};

exports.getById = async (req, res, next) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const business = await Business.findOne({
      where: { id: req.params.id, isActive: true, isApproved: true, isSuspended: false },
      // GET /businesses/:id de PUBLIC (authenticate yok) — bkz. routes/businesses.js.
      attributes: Business.PUBLIC_ATTRIBUTES,
      include: [
        { model: Category, as: "category", attributes: ["id", "name", "slug"] },
        { model: User, as: "owner", attributes: ["id", "name"] },
        {
          model: Review,
          as: "reviews",
          // Ayrı sorgu (separate) -> hasMany'de limit doğru çalışır. Tüm review
          // geçmişini limitsiz döndürmek yerine son 20; tamamı /reviews/business/:id'de.
          separate: true,
          limit: 20,
          order: [["createdAt", "DESC"]],
          include: [{ model: User, as: "user", attributes: ["id", "name"] }],
        },
        {
          model: SurprisePackage,
          as: "packages",
          where: {
            isActive: true,
            isSuspended: false,
            remainingQuantity: { [Op.gt]: 0 },
            pickupDate: { [Op.gte]: today },
          },
          required: false,
        },
      ],
    });

    if (!business) {
      return res.status(404).json({ message: "İşletme bulunamadı" });
    }

    res.json({ business });
  } catch (error) {
    next(error);
  }
};

exports.create = async (req, res, next) => {
  try {
    const {
      name,
      description,
      address,
      city,
      district,
      latitude,
      longitude,
      phone,
      imageUrl,
      categoryId,
    } = req.body;

    const business = await Business.create({
      ownerId: req.user.id,
      categoryId,
      name,
      description,
      address,
      city,
      district,
      latitude,
      longitude,
      phone,
      imageUrl,
    });

    await cacheService.invalidateNamespace('businesses:list');

    res.status(201).json({
      message: "İşletme oluşturuldu",
      business,
    });
  } catch (error) {
    next(error);
  }
};

exports.update = async (req, res, next) => {
  try {
    const business = await Business.findByPk(req.params.id);

    if (!business) {
      return res.status(404).json({ message: "İşletme bulunamadı" });
    }

    if (business.ownerId !== req.user.id && req.user.role !== "admin") {
      return res
        .status(403)
        .json({ message: "Bu işletmeyi güncelleme yetkiniz yok" });
    }

    const {
      name,
      description,
      address,
      city,
      district,
      latitude,
      longitude,
      phone,
      imageUrl,
      categoryId,
      isActive,
    } = req.body;

    await sequelize.transaction(async (transaction) => {
      await business.reload({ transaction, lock: true });
      if (business.isSuspended && isActive === true && req.user.role !== 'admin') {
        throw Object.assign(new Error('İşletme yönetici tarafından askıya alınmış'), { statusCode: 403 });
      }
      await business.update({
      name,
      description,
      address,
      city,
      district,
      latitude,
      longitude,
      phone,
      imageUrl,
      categoryId,
      isActive,
      }, { transaction });

    });
    await cacheService.invalidateNamespace('packages:list');
    await cacheService.invalidateNamespace('businesses:list');

    res.json({
      message: "İşletme güncellendi",
      business,
    });
  } catch (error) {
    next(error);
  }
};

exports.remove = async (req, res, next) => {
  try {
    const business = await Business.findByPk(req.params.id);

    if (!business) {
      return res.status(404).json({ message: "İşletme bulunamadı" });
    }

    if (business.ownerId !== req.user.id && req.user.role !== "admin") {
      return res
        .status(403)
        .json({ message: "Bu işletmeyi silme yetkiniz yok" });
    }

    await sequelize.transaction(async (transaction) => {
      await business.reload({ transaction, lock: true });
      const packages = await SurprisePackage.findAll({ where: { businessId: business.id }, attributes: ['id'], paranoid: false, transaction });
      const active = await Order.count({ where: { packageId: { [Op.in]: packages.map(p => p.id) },
        [Op.or]: [{ status: { [Op.in]: ['awaiting_payment', 'pending', 'confirmed'] } },
          { refundStatus: { [Op.in]: ['pending', 'processing', 'review'] } }] }, transaction });
      if (active) throw Object.assign(new Error('Aktif sipariş veya tamamlanmamış iade bulunan işletme silinemez'), { statusCode: 409 });
      await business.destroy({ transaction });
    });
    await cacheService.invalidateNamespace('packages:list');

    await cacheService.invalidateNamespace('businesses:list');

    res.json({ message: "İşletme silindi" });
  } catch (error) {
    next(error);
  }
};

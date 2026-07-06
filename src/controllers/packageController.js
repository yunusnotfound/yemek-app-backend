const { SurprisePackage, Business, Category, Order } = require('../models');
const { Op } = require('sequelize');
const { paginate, paginatedResponse, haversineDistance } = require('../utils/helpers');
const cacheService = require('../services/cacheService');

exports.getAll = async (req, res, next) => {
  try {
    const { city, district, categoryId, maxPrice, lat, lng, radius, excludeExpired } = req.query;
    const { page, limit, offset } = paginate(req.query);
    const useGeoFilter = lat && lng && radius;

    // Hard cap on candidate rows fetched for geo-filtering so we never load the
    // whole active-package table into memory for the JS Haversine pass.
    const GEO_CANDIDATE_LIMIT = 500;

    // Build a cache key that rounds coordinates to ~3 decimals (~110m precision)
    // so nearby requests share a cache entry instead of producing a unique key
    // for every exact coordinate.
    const cacheKeyParts = { city, district, categoryId, maxPrice, excludeExpired, page, limit };
    if (useGeoFilter) {
      cacheKeyParts.lat = parseFloat(lat).toFixed(3);
      cacheKeyParts.lng = parseFloat(lng).toFixed(3);
      cacheKeyParts.radius = radius;
    }
    const cacheKey = `packages:list:${JSON.stringify(cacheKeyParts)}`;
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

    const userLat = parseFloat(lat);
    const userLng = parseFloat(lng);
    const maxRadius = parseFloat(radius);

    // Bounding-box pre-filter: compute min/max lat & lng from the center + radius
    // (radius is in km) and push it into SQL so the DB only returns business
    // candidates inside the box. The precise Haversine filter runs afterwards in JS.
    if (useGeoFilter) {
      const latDelta = maxRadius / 111.32; // ~111.32 km per degree of latitude
      const cosLat = Math.cos((userLat * Math.PI) / 180);
      // Guard against division by ~0 near the poles (not relevant for Turkey, but safe).
      const lngDelta = maxRadius / (111.32 * Math.max(Math.abs(cosLat), 1e-6));

      businessWhere.latitude = { [Op.between]: [userLat - latDelta, userLat + latDelta] };
      businessWhere.longitude = { [Op.between]: [userLng - lngDelta, userLng + lngDelta] };
    }

    const queryOptions = {
      where: packageWhere,
      include: [
        {
          model: Business,
          as: 'business',
          where: businessWhere,
          attributes: ['id', 'name', 'address', 'city', 'district', 'latitude', 'longitude', 'imageUrl', 'rating'],
          include: [{ model: Category, as: 'category', attributes: ['id', 'name', 'slug'] }],
        },
      ],
      order: [['pickupDate', 'ASC'], ['pickupStart', 'ASC']],
    };

    if (useGeoFilter) {
      // Bounding box already trims the rows in SQL; cap candidates to a sane hard
      // limit, then Haversine-filter + distance-sort + paginate in memory below.
      queryOptions.limit = GEO_CANDIDATE_LIMIT;
    } else {
      queryOptions.limit = limit;
      queryOptions.offset = offset;
    }

    const { count, rows: packages } = await SurprisePackage.findAndCountAll(queryOptions);

    let resultPackages = packages;
    let totalCount = count;

    if (useGeoFilter) {
      resultPackages = packages.filter(pkg => {
        if (!pkg.business.latitude || !pkg.business.longitude) return false;
        const distance = haversineDistance(userLat, userLng, parseFloat(pkg.business.latitude), parseFloat(pkg.business.longitude));
        pkg.business.setDataValue('distance', distance);
        return distance <= maxRadius;
      });

      resultPackages.sort((a, b) => a.business.getDataValue('distance') - b.business.getDataValue('distance'));

      totalCount = resultPackages.length;
      resultPackages = resultPackages.slice(offset, offset + limit);
    }

    const responseData = paginatedResponse(resultPackages, totalCount, page, limit);
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

    await cacheService.delPattern('packages:list:*');

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

    await cacheService.delPattern('packages:list:*');

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

    await cacheService.delPattern('packages:list:*');

    res.json({ message: 'Paket silindi' });
  } catch (error) {
    next(error);
  }
};

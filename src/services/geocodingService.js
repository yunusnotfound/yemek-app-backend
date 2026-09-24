const axios = require('axios');
const logger = require('./logger');
const coalesce = require('./requestCoalescer');
const { availablePackageWhere, hasAvailablePackages, pickupStartAt, pickupEndAt,
  availabilityCacheTtl, AVAILABILITY_ATTRIBUTES } = require('../utils/packageAvailability');

const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY;

/**
 * Adresi koordinatlara çevirir (Geocoding)
 * @param {string} address - Tam adres
 * @returns {Promise<{lat: number, lng: number}|null>}
 */
const geocodeAddress = async (address) => {
  try {
    const response = await axios.get('https://maps.googleapis.com/maps/api/geocode/json', {
      params: {
        address: `${address}, Turkey`,
        key: GOOGLE_MAPS_API_KEY,
        language: 'tr',
      },
    });

    if (response.data.status === 'OK' && response.data.results.length > 0) {
      const { lat, lng } = response.data.results[0].geometry.location;
      return { lat, lng };
    }
    return null;
  } catch (error) {
    logger.error('Geocoding error:', { error: error.message });
    return null;
  }
};

/**
 * Koordinatları adrese çevirir (Reverse Geocoding)
 * @param {number} lat - Enlem
 * @param {number} lng - Boylam
 * @returns {Promise<string|null>} - Formatlanmış adres
 */
const reverseGeocode = async (lat, lng) => {
  try {
    const response = await axios.get('https://maps.googleapis.com/maps/api/geocode/json', {
      params: {
        latlng: `${lat},${lng}`,
        key: GOOGLE_MAPS_API_KEY,
        language: 'tr',
      },
    });

    if (response.data.status === 'OK' && response.data.results.length > 0) {
      return response.data.results[0].formatted_address;
    }
    return null;
  } catch (error) {
    logger.error('Reverse geocoding error:', { error: error.message });
    return null;
  }
};

/**
 * İki nokta arası mesafe ve süre hesaplar (Directions API)
 * @param {number} originLat - Başlangıç enlem
 * @param {number} originLng - Başlangıç boylam
 * @param {number} destLat - Hedef enlem
 * @param {number} destLng - Hedef boylam
 * @returns {Promise<{distance: string, duration: string}|null>}
 */
const getDirections = async (originLat, originLng, destLat, destLng) => {
  try {
    const response = await axios.get('https://maps.googleapis.com/maps/api/directions/json', {
      params: {
        origin: `${originLat},${originLng}`,
        destination: `${destLat},${destLng}`,
        mode: 'driving',
        key: GOOGLE_MAPS_API_KEY,
        language: 'tr',
      },
    });

    if (response.data.status === 'OK' && response.data.routes.length > 0) {
      const leg = response.data.routes[0].legs[0];
      return {
        distance: leg.distance.text,
        distanceValue: leg.distance.value, // metre cinsinden
        duration: leg.duration.text,
        durationValue: leg.duration.value, // saniye cinsinden
        polyline: response.data.routes[0].overview_polyline.points,
      };
    }
    return null;
  } catch (error) {
    logger.error('Directions error:', { error: error.message });
    return null;
  }
};

/**
 * Yakındaki işletmeleri bulur (Places API yerine kendi DB'mizden)
 * @param {number} lat - Kullanıcı enlem
 * @param {number} lng - Kullanıcı boylam
 * @param {number} radius - Arama yarıçapı (km)
 * @returns {Promise<Array>} - Yakındaki işletmeler
 */
const GEO_CANDIDATE_LIMIT = 500;
const NEARBY_CACHE_TTL = 60; // sn — availableNow zamana duyarlı olduğundan kısa tutulur

const findNearbyBusinesses = async (lat, lng, radius = 5) => {
  const { Business, Category, SurprisePackage, sequelize } = require('../models');
  const { Op } = require('sequelize');
  const { haversineSql } = require('../utils/helpers');
  const cacheService = require('./cacheService');

  const userLat = parseFloat(lat);
  const userLng = parseFloat(lng);
  const maxRadius = parseFloat(radius);

  // Mesafe SQL ifadesine sayı olarak gömüldüğünden sonlu olmaları zorunlu.
  if (!Number.isFinite(userLat) || !Number.isFinite(userLng) || !Number.isFinite(maxRadius) || maxRadius <= 0) {
    return [];
  }

  // The response contains exact distances and live package counts. Use exact
  // coordinates and both namespaces so stock/business changes invalidate it.
  const [businessVersion, packageVersion] = await Promise.all([
    cacheService.getVersion('businesses:list'),
    cacheService.getVersion('packages:list'),
  ]);
  const cacheKey = businessVersion == null || packageVersion == null ? null
    : `maps:nearby:v3:${businessVersion}:${packageVersion}:${userLat}:${userLng}:${maxRadius}`;
  const cached = await cacheService.get(cacheKey);
  if (cached && cached.every((business) =>
    business.packages.length > 0 && business.packages.every((pkg) => pickupEndAt(pkg) > new Date()))) return cached;

  return coalesce(cacheKey, async () => {

  // Bounding-box ön filtresi (idx_businesses_lat_lng): indeksten faydalanmak için
  // önce kutuyla daralt. BETWEEN, latitude/longitude'u NULL olan satırları da eler.
  const latDelta = maxRadius / 111.32;
  const cosLat = Math.cos((userLat * Math.PI) / 180);
  const lngDelta = maxRadius / (111.32 * Math.max(Math.abs(cosLat), 1e-6));

  // Kesin dairesel filtre + sıralama + LIMIT artık SQL'de. Eskiden kutudan 500 aday
  // çekilip mesafe JS'te hesaplanıyordu; yoğun bir bölgede en yakın işletmeler
  // aday penceresine hiç giremeyebiliyordu.
  const distanceSql = haversineSql(userLat, userLng, '"Business"."latitude"', '"Business"."longitude"');

  // Yalnız public alanlar (bkz. Business.PUBLIC_ATTRIBUTES) + hesaplanan mesafe.
  // AÇIK liste: `{ include: [...] }` biçimi tüm kolonları geri getirir ve
  // iban/identityNumber gibi alanları yeniden sızdırırdı.
  const businesses = await Business.findAll({
    attributes: [
      ...Business.PUBLIC_ATTRIBUTES,
      [sequelize.literal(distanceSql), 'distance'],
    ],
    where: {
      [Op.and]: [
        {
          isActive: true,
          isApproved: true,
          isSuspended: false,
          latitude: { [Op.between]: [userLat - latDelta, userLat + latDelta] },
          longitude: { [Op.between]: [userLng - lngDelta, userLng + lngDelta] },
        },
        sequelize.where(sequelize.literal(distanceSql), { [Op.lte]: maxRadius }),
        hasAvailablePackages(),
      ],
    },
    include: [{ model: Category, as: 'category', attributes: ['id', 'name', 'slug'] }],
    order: [[sequelize.literal(distanceSql), 'ASC']],
    limit: GEO_CANDIDATE_LIMIT,
  });

  const nearbyBusinesses = businesses.map((business) => business.toJSON());

  if (nearbyBusinesses.length === 0) {
    await cacheService.set(cacheKey, nearbyBusinesses, NEARBY_CACHE_TTL);
    return nearbyBusinesses;
  }

  const ids = nearbyBusinesses.map((b) => b.id);
  const packages = await SurprisePackage.findAll({
    attributes: AVAILABILITY_ATTRIBUTES,
    where: { ...availablePackageWhere(), businessId: { [Op.in]: ids } },
    raw: true,
  });

  const now = new Date();
  const byBusiness = new Map();
  for (const pkg of packages) {
    // The clock may cross a boundary between the SQL query and serialization.
    if (!(pickupEndAt(pkg) > now)) continue;
    const items = byBusiness.get(pkg.businessId) || [];
    items.push(pkg);
    byBusiness.set(pkg.businessId, items);
  }

  const result = nearbyBusinesses.filter((b) => byBusiness.has(b.id)).map((b) => {
    const available = byBusiness.get(b.id);
    return {
      ...b,
      packages: available,
      packageCount: available.length,
      availableNow: available.some((pkg) => pickupStartAt(pkg) <= now),
    };
  });
  const ttl = availabilityCacheTtl(packages, NEARBY_CACHE_TTL);
  if (ttl > 0) await cacheService.set(cacheKey, result, ttl);
  return result;
  });
};

module.exports = {
  geocodeAddress,
  reverseGeocode,
  getDirections,
  findNearbyBusinesses,
};

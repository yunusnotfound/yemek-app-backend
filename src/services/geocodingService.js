const axios = require('axios');
const logger = require('./logger');

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
  const { Business, Category, SurprisePackage } = require('../models');
  const { Op } = require('sequelize');
  const { haversineDistance } = require('../utils/helpers');
  const cacheService = require('./cacheService');

  const userLat = parseFloat(lat);
  const userLng = parseFloat(lng);
  const maxRadius = parseFloat(radius);

  // Kısa TTL cache. Koordinat 3 haneye (~110 m hücre) yuvarlanır ki yakın konumlar
  // aynı anahtarı paylaşsın (Redis anahtar patlamasını önler).
  const cacheKey = `maps:nearby:${userLat.toFixed(3)}:${userLng.toFixed(3)}:${maxRadius}`;
  const cached = await cacheService.get(cacheKey);
  if (cached) return cached;

  // Bounding-box ön filtresi (idx_businesses_lat_lng): merkez + yarıçaptan min/max
  // lat/lng hesaplanır ve SQL'e itilir; kesin Haversine filtresi JS'te sonra koşar.
  // BETWEEN, latitude/longitude'u NULL olan satırları da eler.
  const latDelta = maxRadius / 111.32;
  const cosLat = Math.cos((userLat * Math.PI) / 180);
  const lngDelta = maxRadius / (111.32 * Math.max(Math.abs(cosLat), 1e-6));

  const businesses = await Business.findAll({
    where: {
      isActive: true,
      isApproved: true,
      latitude: { [Op.between]: [userLat - latDelta, userLat + latDelta] },
      longitude: { [Op.between]: [userLng - lngDelta, userLng + lngDelta] },
    },
    include: [{ model: Category, as: 'category', attributes: ['id', 'name', 'slug'] }],
    limit: GEO_CANDIDATE_LIMIT,
  });

  // Mesafe hesapla ve filtrele
  const nearbyBusinesses = businesses
    .map((business) => {
      const distance = haversineDistance(
        userLat,
        userLng,
        business.latitude,
        business.longitude
      );
      return { ...business.toJSON(), distance };
    })
    .filter((b) => b.distance <= maxRadius)
    .sort((a, b) => a.distance - b.distance);

  if (nearbyBusinesses.length === 0) {
    await cacheService.set(cacheKey, nearbyBusinesses, NEARBY_CACHE_TTL);
    return nearbyBusinesses;
  }

  // Her işletme için müsait (aktif, stoklu, bugünden ileri) paketleri çek.
  // Filtre, packageController.getAll'daki "müsait paket" desenini yansıtır.
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const ids = nearbyBusinesses.map((b) => b.id);
  const packages = await SurprisePackage.findAll({
    attributes: ['businessId', 'pickupDate', 'pickupStart', 'pickupEnd'],
    where: {
      businessId: { [Op.in]: ids },
      isActive: true,
      remainingQuantity: { [Op.gt]: 0 },
      pickupDate: { [Op.gte]: today },
    },
    raw: true,
  });

  // "Şimdi alınabilir mi" için referans an: Europe/Istanbul.
  const istNow = new Date();
  const todayStr = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Istanbul',
  }).format(istNow); // YYYY-MM-DD
  const nowTime = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/Istanbul',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).format(istNow); // HH:MM:SS

  // İşletme başına paket sayısı + "şimdi alınabilir" bayrağını topla.
  const agg = {};
  for (const p of packages) {
    const a = agg[p.businessId] || { count: 0, availableNow: false };
    a.count += 1;
    // pickupDate bugünse ve şu anki saat [pickupStart, pickupEnd] aralığındaysa.
    // TIME alanları 'HH:MM:SS' string olduğundan sözlük sırası karşılaştırması doğrudur.
    if (
      String(p.pickupDate) === todayStr &&
      p.pickupStart <= nowTime &&
      nowTime <= p.pickupEnd
    ) {
      a.availableNow = true;
    }
    agg[p.businessId] = a;
  }

  const result = nearbyBusinesses.map((b) => ({
    ...b,
    packageCount: agg[b.id] ? agg[b.id].count : 0,
    availableNow: agg[b.id] ? agg[b.id].availableNow : false,
  }));
  await cacheService.set(cacheKey, result, NEARBY_CACHE_TTL);
  return result;
};

module.exports = {
  geocodeAddress,
  reverseGeocode,
  getDirections,
  findNearbyBusinesses,
};

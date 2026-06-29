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
const findNearbyBusinesses = async (lat, lng, radius = 5) => {
  const { Business, Category, SurprisePackage } = require('../models');
  const { Op, fn, col } = require('sequelize');
  const { haversineDistance } = require('../utils/helpers');

  const businesses = await Business.findAll({
    where: {
      isActive: true,
      isApproved: true,
      latitude: { [Op.ne]: null },
      longitude: { [Op.ne]: null },
    },
    include: [{ model: Category, as: 'category', attributes: ['id', 'name', 'slug'] }],
  });

  // Mesafe hesapla ve filtrele
  const nearbyBusinesses = businesses
    .map((business) => {
      const distance = haversineDistance(
        lat,
        lng,
        business.latitude,
        business.longitude
      );
      return { ...business.toJSON(), distance };
    })
    .filter((b) => b.distance <= radius)
    .sort((a, b) => a.distance - b.distance);

  if (nearbyBusinesses.length === 0) return nearbyBusinesses;

  // Her işletme için müsait (aktif, stoklu, bugünden ileri) paket sayısını ekle.
  // Filtre, packageController.getAll'daki "müsait paket" desenini yansıtır.
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const ids = nearbyBusinesses.map((b) => b.id);
  const counts = await SurprisePackage.findAll({
    attributes: ['businessId', [fn('COUNT', col('id')), 'count']],
    where: {
      businessId: { [Op.in]: ids },
      isActive: true,
      remainingQuantity: { [Op.gt]: 0 },
      pickupDate: { [Op.gte]: today },
    },
    group: ['businessId'],
    raw: true,
  });
  const countMap = Object.fromEntries(
    counts.map((c) => [c.businessId, Number(c.count)])
  );

  return nearbyBusinesses.map((b) => ({
    ...b,
    packageCount: countMap[b.id] || 0,
  }));
};

module.exports = {
  geocodeAddress,
  reverseGeocode,
  getDirections,
  findNearbyBusinesses,
};

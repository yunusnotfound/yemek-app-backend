const crypto = require('crypto');
const { Op } = require('sequelize');
const { Order } = require('../models');

const generatePickupCode = async () => {
  const maxAttempts = 10;
  let attempts = 0;

  while (attempts < maxAttempts) {
    // 6 haneli güvenli rastgele kod (100000-999999), personel girişi için sayısal
    const code = crypto.randomInt(100000, 1000000).toString();

    // Benzersizliği yalnızca aktif (terminal olmayan) siparişlere göre kontrol et.
    // Tamamlanmış/iptal edilmiş eski siparişlerin kodları yeniden kullanılabilir.
    const existingOrder = await Order.findOne({
      where: {
        pickupCode: code,
        status: { [Op.in]: ['pending', 'confirmed'] },
      },
    });
    if (!existingOrder) {
      return code;
    }

    attempts++;
  }

  // 10 denemeden sonra hata fırlat (DB unique constraint son güvence olarak kalır)
  throw new Error('Benzersiz teslim alma kodu oluşturulamadı');
};

const paginate = (query) => {
  const page = Math.max(1, parseInt(query.page) || 1);
  const limit = Math.min(50, Math.max(1, parseInt(query.limit) || 10));
  const offset = (page - 1) * limit;
  return { page, limit, offset };
};

const paginatedResponse = (data, count, page, limit) => ({
  data,
  pagination: {
    total: count,
    page,
    limit,
    totalPages: Math.ceil(count / limit),
  },
});

const haversineDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
    Math.cos((lat2 * Math.PI) / 180) *
    Math.sin(dLon / 2) *
    Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

const generateToken = () => {
  return crypto.randomBytes(32).toString('hex');
};

const getSortOptions = (query, allowedFields) => {
  const sortBy = allowedFields.includes(query.sortBy) ? query.sortBy : 'createdAt';
  const sortOrder = query.sortOrder === 'ASC' ? 'ASC' : 'DESC';
  return [[sortBy, sortOrder]];
};

module.exports = {
  generatePickupCode,
  paginate,
  paginatedResponse,
  haversineDistance,
  generateToken,
  getSortOptions,
};

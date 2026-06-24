const { Business, SurprisePackage, Order, User, Review, Category, Notification, sequelize } = require('../models');
const { Op, Sequelize } = require('sequelize');
const { paginate, paginatedResponse } = require('../utils/helpers');
const iyzicoService = require('../services/iyzicoService');
const settlementService = require('../services/settlementService');
const logger = require('../services/logger');

// IBAN'ı panelde maskeli göster (KVKK) — yalnız son 4 hane.
const maskIban = (iban) => {
  if (!iban) return null;
  const s = String(iban);
  return s.length > 8 ? `${s.slice(0, 6)}••••${s.slice(-4)}` : s;
};

// İşletme Dashboard İstatistikleri
exports.getDashboardStats = async (req, res, next) => {
  try {
    const { businessId } = req.params;

    const business = await Business.findOne({
      where: { id: businessId, ownerId: req.user.id },
    });

    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı veya yetkiniz yok' });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const thisWeekStart = new Date(today);
    thisWeekStart.setDate(thisWeekStart.getDate() - 7);

    const thisMonthStart = new Date(today);
    thisMonthStart.setMonth(thisMonthStart.getMonth() - 1);

    const packages = await SurprisePackage.findAll({
      where: { businessId },
      attributes: ['id'],
    });
    const packageIds = packages.map((p) => p.id);

    if (packageIds.length === 0) {
      return res.json({
        stats: {
          totalPackages: 0,
          activePackages: 0,
          todayOrders: 0,
          todayRevenue: 0,
          pendingOrders: 0,
          totalOrders: 0,
          totalRevenue: 0,
          averageRating: 0,
          weeklyRevenue: 0,
          monthlyRevenue: 0,
        },
        dailyStats: [],
      });
    }

    // Yalnız ödenmiş (paid) siparişler gelire/sayıma dahil — awaiting_payment sızmaz.
    const paidBase = { packageId: { [Op.in]: packageIds }, paymentStatus: 'paid' };

    const [
      totalPackages,
      activePackages,
      todayOrders,
      todayRevenue,
      pendingOrders,
      totalOrders,
      totalRevenue,
      averageRating,
      weeklyRevenue,
      monthlyRevenue,
    ] = await Promise.all([
      SurprisePackage.count({ where: { businessId } }),

      SurprisePackage.count({
        where: { businessId, isActive: true, remainingQuantity: { [Op.gt]: 0 } },
      }),

      Order.count({
        where: { ...paidBase, createdAt: { [Op.gte]: today }, status: { [Op.ne]: 'cancelled' } },
      }),

      Order.sum('totalPrice', {
        where: { ...paidBase, createdAt: { [Op.gte]: today }, status: { [Op.ne]: 'cancelled' } },
      }),

      Order.count({
        where: { ...paidBase, status: 'pending' },
      }),

      Order.count({
        where: { ...paidBase, status: { [Op.ne]: 'cancelled' } },
      }),

      Order.sum('totalPrice', {
        where: { ...paidBase, status: { [Op.ne]: 'cancelled' } },
      }),

      Review.findOne({
        where: { businessId },
        attributes: [[Sequelize.fn('AVG', Sequelize.col('rating')), 'avgRating']],
        raw: true,
      }),

      Order.sum('totalPrice', {
        where: { ...paidBase, createdAt: { [Op.gte]: thisWeekStart }, status: { [Op.ne]: 'cancelled' } },
      }),

      Order.sum('totalPrice', {
        where: { ...paidBase, createdAt: { [Op.gte]: thisMonthStart }, status: { [Op.ne]: 'cancelled' } },
      }),
    ]);

    const last7Days = [];
    for (let i = 6; i >= 0; i--) {
      const date = new Date(today);
      date.setDate(date.getDate() - i);
      last7Days.push(date);
    }

    const startDate = last7Days[0];
    const endDate = new Date(today);
    endDate.setDate(endDate.getDate() + 1);

    const dailyStatsRaw = await Order.findAll({
      where: {
        ...paidBase,
        createdAt: { [Op.gte]: startDate, [Op.lt]: endDate },
        status: { [Op.ne]: 'cancelled' },
      },
      attributes: [
        [sequelize.fn('DATE', sequelize.col('Order.createdAt')), 'date'],
        [sequelize.fn('COUNT', sequelize.col('Order.id')), 'orderCount'],
        [sequelize.fn('COALESCE', sequelize.fn('SUM', sequelize.col('totalPrice')), 0), 'revenue'],
      ],
      group: [sequelize.fn('DATE', sequelize.col('Order.createdAt'))],
      raw: true,
    });

    const statsMap = new Map(dailyStatsRaw.map((s) => [s.date, s]));
    const dailyStats = last7Days.map((date) => {
      const dateStr = date.toISOString().split('T')[0];
      const stat = statsMap.get(dateStr);
      return {
        date: dateStr,
        orders: stat ? parseInt(stat.orderCount) : 0,
        revenue: stat ? parseFloat(stat.revenue) : 0,
      };
    });

    res.json({
      stats: {
        totalPackages,
        activePackages,
        todayOrders,
        todayRevenue: todayRevenue || 0,
        pendingOrders,
        totalOrders,
        totalRevenue: totalRevenue || 0,
        averageRating: averageRating?.avgRating
          ? Math.round(parseFloat(averageRating.avgRating) * 10) / 10
          : 0,
        weeklyRevenue: weeklyRevenue || 0,
        monthlyRevenue: monthlyRevenue || 0,
      },
      dailyStats,
    });
  } catch (error) {
    next(error);
  }
};

// İşletmenin siparişlerini getir (yalnız ödenmiş/iade — awaiting_payment gösterilmez)
exports.getBusinessOrders = async (req, res, next) => {
  try {
    const { businessId } = req.params;
    const { page, limit, offset } = paginate(req.query);
    const statusFilter = req.query.status; // paginate status döndürmez -> query'den al

    const business = await Business.findOne({
      where: { id: businessId, ownerId: req.user.id },
    });

    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı veya yetkiniz yok' });
    }

    const packages = await SurprisePackage.findAll({
      where: { businessId },
      attributes: ['id'],
    });
    const packageIds = packages.map((p) => p.id);

    if (packageIds.length === 0) {
      return res.json(paginatedResponse([], 0, page, limit));
    }

    // paymentStatus IN (paid, refunded, partially_refunded) -> ödenmemiş hold'ları dışlar.
    const where = {
      packageId: { [Op.in]: packageIds },
      paymentStatus: { [Op.in]: ['paid', 'refunded', 'partially_refunded'] },
    };
    if (statusFilter) where.status = statusFilter;

    const { count, rows: orders } = await Order.findAndCountAll({
      where,
      include: [
        {
          model: SurprisePackage,
          as: 'package',
          attributes: ['id', 'title', 'pickupDate', 'pickupStart', 'pickupEnd'],
        },
        { model: User, as: 'user', attributes: ['id', 'name', 'phone'] },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json(paginatedResponse(orders, count, page, limit));
  } catch (error) {
    next(error);
  }
};

// İşletmenin paketlerini getir
exports.getBusinessPackages = async (req, res, next) => {
  try {
    const { businessId } = req.params;
    const { page, limit, offset } = paginate(req.query);

    const business = await Business.findOne({
      where: { id: businessId, ownerId: req.user.id },
    });

    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı veya yetkiniz yok' });
    }

    const { count, rows: packages } = await SurprisePackage.findAndCountAll({
      where: { businessId },
      include: [
        {
          model: Order,
          as: 'orders',
          // Satış istatistiği yalnız ödenmiş & iptal olmayan siparişlerden.
          where: { paymentStatus: 'paid', status: { [Op.ne]: 'cancelled' } },
          required: false,
          attributes: ['id', 'status', 'totalPrice'],
        },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    const packagesWithStats = packages.map((pkg) => {
      const pkgData = pkg.toJSON();
      const soldQuantity = pkgData.orders?.length || 0;
      const totalRevenue = pkgData.orders?.reduce((sum, o) => sum + parseFloat(o.totalPrice), 0) || 0;

      return {
        ...pkgData,
        soldQuantity,
        totalRevenue,
        remainingQuantity: pkgData.remainingQuantity,
      };
    });

    res.json(paginatedResponse(packagesWithStats, count, page, limit));
  } catch (error) {
    next(error);
  }
};

// İşletmenin değerlendirmelerini getir
exports.getBusinessReviews = async (req, res, next) => {
  try {
    const { businessId } = req.params;
    const { page, limit, offset } = paginate(req.query);

    const business = await Business.findOne({
      where: { id: businessId, ownerId: req.user.id },
    });

    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı veya yetkiniz yok' });
    }

    const { count, rows: reviews } = await Review.findAndCountAll({
      where: { businessId },
      include: [
        { model: User, as: 'user', attributes: ['id', 'name'] },
        { model: Order, as: 'order', attributes: ['id', 'createdAt'] },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json(paginatedResponse(reviews, count, page, limit));
  } catch (error) {
    next(error);
  }
};

// QR Kod ile sipariş doğrulama -> teslim al + satıcı fonlarını serbest bırak (iyzico approval)
exports.verifyOrderByPickupCode = async (req, res, next) => {
  try {
    const { businessId } = req.params;
    const { pickupCode } = req.body;

    const business = await Business.findOne({
      where: { id: businessId, ownerId: req.user.id },
    });

    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı veya yetkiniz yok' });
    }

    const packages = await SurprisePackage.findAll({
      where: { businessId },
      attributes: ['id'],
    });
    const packageIds = packages.map((p) => p.id);

    const order = await Order.findOne({
      where: {
        packageId: { [Op.in]: packageIds },
        pickupCode,
        status: { [Op.in]: ['pending', 'confirmed'] },
        paymentStatus: 'paid', // ödenmemiş hold asla teslim edilemez
      },
      include: [
        {
          model: SurprisePackage,
          as: 'package',
          attributes: ['id', 'title', 'pickupDate', 'pickupStart', 'pickupEnd'],
        },
        { model: User, as: 'user', attributes: ['id', 'name', 'phone'] },
      ],
    });

    if (!order) {
      return res.status(404).json({ message: 'Sipariş bulunamadı veya kod hatalı' });
    }

    // Koşullu (status guard) -> eşzamanlı değişime karşı idempotent
    const [n] = await Order.update(
      { status: 'picked_up' },
      { where: { id: order.id, status: order.status } }
    );
    if (n === 0) {
      return res.status(409).json({ message: 'Sipariş durumu değişmiş, tekrar deneyin' });
    }

    // Teslim edildi -> satıcı fonlarını serbest bırak (best-effort; başarısızsa retry cron dener)
    await order.reload();
    await settlementService.approveOnPickup(order);

    await Notification.create({
      userId: order.userId,
      title: 'Sipariş Teslim Alındı',
      message: `${business.name} işletmesinden siparişiniz teslim alındı.`,
      type: 'order_status',
      data: { orderId: order.id, status: 'picked_up' },
    });

    res.json({
      message: 'Sipariş başarıyla doğrulandı ve teslim alındı',
      order,
    });
  } catch (error) {
    next(error);
  }
};

// İşletme sahibinin işletmelerini listele
exports.getMyBusinesses = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query);

    const { count, rows: businesses } = await Business.findAndCountAll({
      where: { ownerId: req.user.id },
      include: [
        { model: Category, as: 'category', attributes: ['id', 'name', 'slug'] },
        {
          model: SurprisePackage,
          as: 'packages',
          where: { isActive: true },
          required: false,
          limit: 1,
        },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    const businessIds = businesses.map((b) => b.id);

    const [activePackageCounts, pendingPackageRows] = await Promise.all([
      SurprisePackage.findAll({
        where: {
          businessId: { [Op.in]: businessIds },
          isActive: true,
          remainingQuantity: { [Op.gt]: 0 },
        },
        attributes: ['businessId', [Sequelize.fn('COUNT', Sequelize.col('id')), 'count']],
        group: ['businessId'],
        raw: true,
      }),
      SurprisePackage.findAll({
        where: { businessId: { [Op.in]: businessIds } },
        attributes: ['id', 'businessId'],
        raw: true,
      }),
    ]);

    const activeMap = new Map(activePackageCounts.map((r) => [r.businessId, parseInt(r.count)]));
    const pkgIdToBizId = new Map(pendingPackageRows.map((r) => [r.id, r.businessId]));
    const allPkgIds = pendingPackageRows.map((r) => r.id);

    const pendingOrderCounts = allPkgIds.length > 0
      ? await Order.findAll({
          where: { packageId: { [Op.in]: allPkgIds }, status: 'pending', paymentStatus: 'paid' },
          attributes: ['packageId', [Sequelize.fn('COUNT', Sequelize.col('id')), 'count']],
          group: ['packageId'],
          raw: true,
        })
      : [];

    const pendingMap = new Map();
    for (const row of pendingOrderCounts) {
      const bizId = pkgIdToBizId.get(row.packageId);
      if (bizId) pendingMap.set(bizId, (pendingMap.get(bizId) || 0) + parseInt(row.count));
    }

    const businessesWithStats = businesses.map((business) => ({
      ...business.toJSON(),
      activePackages: activeMap.get(business.id) || 0,
      pendingOrders: pendingMap.get(business.id) || 0,
    }));

    res.json(paginatedResponse(businessesWithStats, count, page, limit));
  } catch (error) {
    next(error);
  }
};

// --- iyzico Pazaryeri: alt üye işyeri onboarding + kazanç görünümü ---

// POST /business-dashboard/:businessId/submerchant — alt üye işyeri oluştur/güncelle
exports.upsertSubMerchant = async (req, res, next) => {
  try {
    const { businessId } = req.params;
    const business = await Business.findOne({
      where: { id: businessId, ownerId: req.user.id },
      include: [{ model: User, as: 'owner', attributes: ['email'] }],
    });

    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı veya yetkiniz yok' });
    }
    if (!iyzicoService.isConfigured()) {
      return res.status(503).json({ message: 'Ödeme sağlayıcı yapılandırılmamış' });
    }

    const {
      subMerchantType, iban, gsmNumber, contactName, contactSurname,
      identityNumber, legalCompanyTitle, taxOffice, taxNumber,
    } = req.body;

    // Alanları yaz (iyzico request builder bunları okur)
    business.subMerchantType = subMerchantType;
    business.iban = iban;
    business.gsmNumber = gsmNumber;
    business.contactName = contactName || null;
    business.contactSurname = contactSurname || null;
    business.identityNumber = identityNumber || null;
    business.legalCompanyTitle = legalCompanyTitle || null;
    business.taxOffice = taxOffice || null;
    business.taxNumber = taxNumber || null;

    try {
      if (business.subMerchantKey) {
        await iyzicoService.updateSubMerchant(business);
      } else {
        const result = await iyzicoService.createSubMerchant(business);
        if (result.subMerchantKey) business.subMerchantKey = result.subMerchantKey;
      }
      business.subMerchantStatus = 'active';
      business.subMerchantError = null;
      await business.save();
      return res.json({
        message: 'Ödeme hesabı kaydedildi',
        submerchant: {
          status: 'active',
          hasKey: Boolean(business.subMerchantKey),
          type: business.subMerchantType,
          iban: maskIban(business.iban),
        },
      });
    } catch (e) {
      business.subMerchantStatus = 'error';
      business.subMerchantError = String(e.message).slice(0, 500);
      await business.save();
      logger.error(`[submerchant] kayıt hatası (business ${business.id}): ${e.message}`);
      return res.status(400).json({ message: e.message || 'Ödeme hesabı kaydedilemedi' });
    }
  } catch (error) {
    next(error);
  }
};

// GET /business-dashboard/:businessId/earnings — kazanç özeti (orders'tan türetilir)
exports.getEarnings = async (req, res, next) => {
  try {
    const { businessId } = req.params;
    const business = await Business.findOne({ where: { id: businessId, ownerId: req.user.id } });

    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı veya yetkiniz yok' });
    }

    const submerchant = {
      status: business.subMerchantStatus || 'none',
      hasKey: Boolean(business.subMerchantKey),
      type: business.subMerchantType,
      iban: maskIban(business.iban),
      error: business.subMerchantError,
    };

    const packages = await SurprisePackage.findAll({ where: { businessId }, attributes: ['id'] });
    const packageIds = packages.map((p) => p.id);

    if (packageIds.length === 0) {
      return res.json({
        submerchant,
        earnings: { totalSales: 0, commission: 0, netHeld: 0, netApproved: 0, refunded: 0, currency: 'TRY' },
      });
    }

    const paidBase = { packageId: { [Op.in]: packageIds }, paymentStatus: 'paid' };

    const [totalSales, commission, netHeld, netApproved, refunded] = await Promise.all([
      Order.sum('paidPrice', { where: paidBase }),
      Order.sum('commissionAmount', { where: paidBase }),
      // Teslim bekleyen (henüz onaylanmamış) satıcı payı
      Order.sum('subMerchantPrice', { where: { ...paidBase, settlementStatus: 'held' } }),
      // Onaylanan -> iyzico öder
      Order.sum('subMerchantPrice', { where: { ...paidBase, settlementStatus: 'approved' } }),
      Order.sum('refundAmount', {
        where: { packageId: { [Op.in]: packageIds }, paymentStatus: { [Op.in]: ['refunded', 'partially_refunded'] } },
      }),
    ]);

    res.json({
      submerchant,
      earnings: {
        totalSales: totalSales || 0,
        commission: commission || 0,
        netHeld: netHeld || 0,
        netApproved: netApproved || 0,
        refunded: refunded || 0,
        currency: 'TRY',
        commissionRate: iyzicoService.COMMISSION_RATE,
      },
    });
  } catch (error) {
    next(error);
  }
};

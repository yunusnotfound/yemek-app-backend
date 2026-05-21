const { Business, SurprisePackage, Order, User, Review, Category, Notification, sequelize } = require('../models');
const { Op, Sequelize } = require('sequelize');
const { paginate, paginatedResponse } = require('../utils/helpers');
const { notifyOrderStatus } = require('../services/notificationService');

// İşletme Dashboard İstatistikleri
exports.getDashboardStats = async (req, res, next) => {
  try {
    const { businessId } = req.params;

    // İşletmenin sahibi mi kontrol et
    const business = await Business.findOne({
      where: { id: businessId, ownerId: req.user.id },
    });

    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı veya yetkiniz yok' });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    const thisWeekStart = new Date(today);
    thisWeekStart.setDate(thisWeekStart.getDate() - 7);

    const thisMonthStart = new Date(today);
    thisMonthStart.setMonth(thisMonthStart.getMonth() - 1);

    // İşletmeye ait paket ID'lerini al
    const packages = await SurprisePackage.findAll({
      where: { businessId },
      attributes: ['id'],
    });
    const packageIds = packages.map((p) => p.id);

    // Paket yoksa boş istatistik döndür
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

    // İstatistikleri hesapla
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
      // Toplam paket sayısı
      SurprisePackage.count({ where: { businessId } }),

      // Aktif paket sayısı
      SurprisePackage.count({
        where: {
          businessId,
          isActive: true,
          remainingQuantity: { [Op.gt]: 0 },
        },
      }),

      // Bugünkü siparişler
      Order.count({
        where: {
          packageId: { [Op.in]: packageIds },
          createdAt: { [Op.gte]: today },
          status: { [Op.ne]: 'cancelled' },
        },
      }),

      // Bugünkü kazanç
      Order.sum('totalPrice', {
        where: {
          packageId: { [Op.in]: packageIds },
          createdAt: { [Op.gte]: today },
          status: { [Op.ne]: 'cancelled' },
        },
      }),

      // Bekleyen siparişler
      Order.count({
        where: {
          packageId: { [Op.in]: packageIds },
          status: 'pending',
        },
      }),

      // Toplam sipariş
      Order.count({
        where: {
          packageId: { [Op.in]: packageIds },
          status: { [Op.ne]: 'cancelled' },
        },
      }),

      // Toplam kazanç
      Order.sum('totalPrice', {
        where: {
          packageId: { [Op.in]: packageIds },
          status: { [Op.ne]: 'cancelled' },
        },
      }),

      // Ortalama puan
      Review.findOne({
        where: { businessId },
        attributes: [[Sequelize.fn('AVG', Sequelize.col('rating')), 'avgRating']],
        raw: true,
      }),

      // Haftalık kazanç
      Order.sum('totalPrice', {
        where: {
          packageId: { [Op.in]: packageIds },
          createdAt: { [Op.gte]: thisWeekStart },
          status: { [Op.ne]: 'cancelled' },
        },
      }),

      // Aylık kazanç
      Order.sum('totalPrice', {
        where: {
          packageId: { [Op.in]: packageIds },
          createdAt: { [Op.gte]: thisMonthStart },
          status: { [Op.ne]: 'cancelled' },
        },
      }),
    ]);

    // Günlük sipariş grafiği için son 7 gün
    const last7Days = [];
    for (let i = 6; i >= 0; i--) {
      const date = new Date(today);
      date.setDate(date.getDate() - i);
      last7Days.push(date);
    }

    const startDate = last7Days[0];
    const endDate = new Date(today);
    endDate.setDate(endDate.getDate() + 1);

    // Single aggregated query to get daily stats (fixes N+1)
    const dailyStatsRaw = await Order.findAll({
      where: {
        packageId: { [Op.in]: packageIds },
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

    // Map results to fill in zeros for days with no orders
    const statsMap = new Map(dailyStatsRaw.map(s => [s.date, s]));
    const dailyStats = last7Days.map(date => {
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

// İşletmenin siparişlerini getir
exports.getBusinessOrders = async (req, res, next) => {
  try {
    const { businessId } = req.params;
    const { status, page, limit, offset } = paginate(req.query);

    // İşletmenin sahibi mi kontrol et
    const business = await Business.findOne({
      where: { id: businessId, ownerId: req.user.id },
    });

    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı veya yetkiniz yok' });
    }

    // İşletmeye ait paket ID'lerini al
    const packages = await SurprisePackage.findAll({
      where: { businessId },
      attributes: ['id'],
    });
    const packageIds = packages.map((p) => p.id);

    // Paket yoksa boş liste döndür
    if (packageIds.length === 0) {
      return res.json(paginatedResponse([], 0, page, limit));
    }

    const where = { packageId: { [Op.in]: packageIds } };
    if (status) where.status = status;

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

    // İşletmenin sahibi mi kontrol et
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
          where: { status: { [Op.ne]: 'cancelled' } },
          required: false,
          attributes: ['id', 'status', 'totalPrice'],
        },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    // Her paket için satış istatistikleri ekle
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

    // İşletmenin sahibi mi kontrol et
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

// QR Kod ile sipariş doğrulama
exports.verifyOrderByPickupCode = async (req, res, next) => {
  try {
    const { businessId } = req.params;
    const { pickupCode } = req.body;

    // İşletmenin sahibi mi kontrol et
    const business = await Business.findOne({
      where: { id: businessId, ownerId: req.user.id },
    });

    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı veya yetkiniz yok' });
    }

    // İşletmeye ait paket ID'lerini al
    const packages = await SurprisePackage.findAll({
      where: { businessId },
      attributes: ['id'],
    });
    const packageIds = packages.map((p) => p.id);

    // Siparişi bul
    const order = await Order.findOne({
      where: {
        packageId: { [Op.in]: packageIds },
        pickupCode,
        status: { [Op.in]: ['pending', 'confirmed'] },
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

    // Siparişi teslim alındı olarak işaretle
    await order.update({ status: 'picked_up' });

    // Müşteriye bildirim gönder
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

    // Batch queries instead of N+1
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
          where: { packageId: { [Op.in]: allPkgIds }, status: 'pending' },
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

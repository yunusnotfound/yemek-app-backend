const { assertAccountCanClose } = require('../services/accountClosureService');
const { cancelOrder, cancellationMessage } = require('../services/orderCancellationService');
const { User, Business, Order, SurprisePackage, Review, Category, AdminAuditLog, sequelize } = require('../models');
const { Op } = require('sequelize');
const { paginate, paginatedResponse } = require('../utils/helpers');
const settlementService = require('../services/settlementService');
const auditService = require('../services/auditService');
const cacheService = require('../services/cacheService');
const { notifyOrderStatus } = require('../services/notificationService');
const logger = require('../services/logger');

const USER_SAFE_EXCLUDE = ['password', 'emailVerificationToken', 'passwordResetToken', 'passwordResetExpires'];

// KVKK maskeleme — ham hassas veri admin'e de dönmez.
const maskIban = (s) => (s ? `${String(s).slice(0, 6)}••••${String(s).slice(-4)}` : null);
const maskTail = (s) => (s ? `••••${String(s).slice(-4)}` : null);

// ── Dashboard ─────────────────────────────────────────────────────────────────
exports.getDashboardStats = async (req, res, next) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const paid = { paymentStatus: 'paid' };

    const [
      totalUsers, totalBusinesses, totalOrders, totalPackages,
      pendingBusinesses, activeBusinesses, todayOrders, todayRevenue,
      gmv, commissionTotal, refundedTotal, customers, businessOwners, admins,
    ] = await Promise.all([
      User.count(),
      Business.count(),
      Order.count(),
      SurprisePackage.count(),
      Business.count({ where: { approvalStatus: 'pending' } }),
      Business.count({ where: { isActive: true } }),
      Order.count({ where: { ...paid, createdAt: { [Op.gte]: today } } }),
      Order.sum('paidPrice', { where: { ...paid, createdAt: { [Op.gte]: today } } }),
      Order.sum('paidPrice', { where: paid }),
      Order.sum('commissionAmount', { where: paid }),
      Order.sum('refundAmount', { where: { paymentStatus: { [Op.in]: ['refunded', 'partially_refunded'] } } }),
      User.count({ where: { role: 'customer' } }),
      User.count({ where: { role: 'business_owner' } }),
      User.count({ where: { role: 'admin' } }),
    ]);

    res.json({
      stats: {
        totalUsers, totalBusinesses, totalOrders, totalPackages,
        pendingBusinesses, activeBusinesses,
        todayOrders, todayRevenue: todayRevenue || 0,
        gmv: gmv || 0, commissionTotal: commissionTotal || 0, refundedTotal: refundedTotal || 0,
        customers, businessOwners, admins,
      },
    });
  } catch (error) {
    next(error);
  }
};

// ── Kullanıcılar ──────────────────────────────────────────────────────────────
exports.getAllUsers = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query);
    const { search, role } = req.query;

    const where = {};
    if (search) {
      where[Op.or] = [
        { name: { [Op.iLike]: `%${search}%` } },
        { email: { [Op.iLike]: `%${search}%` } },
      ];
    }
    if (role) where.role = role;

    const { count, rows: users } = await User.findAndCountAll({
      where,
      attributes: { exclude: USER_SAFE_EXCLUDE },
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json(paginatedResponse(users, count, page, limit));
  } catch (error) {
    next(error);
  }
};

exports.getUserById = async (req, res, next) => {
  try {
    const user = await User.findByPk(req.params.id, {
      attributes: { exclude: USER_SAFE_EXCLUDE },
      include: [
        { model: Business, as: 'businesses', attributes: { exclude: ['iban', 'identityNumber', 'taxNumber'] } },
        { model: Order, as: 'orders', limit: 10, order: [['createdAt', 'DESC']] },
      ],
    });

    if (!user) {
      return res.status(404).json({ message: 'Kullanıcı bulunamadı' });
    }

    res.json({ user });
  } catch (error) {
    next(error);
  }
};

exports.updateUser = async (req, res, next) => {
  try {
    const user = await User.findByPk(req.params.id);
    if (!user) {
      return res.status(404).json({ message: 'Kullanıcı bulunamadı' });
    }

    const { name, phone, role, isEmailVerified } = req.body;

    // Kendi admin yetkini düşüremezsin
    if (user.id === req.user.id && role && role !== 'admin') {
      return res.status(400).json({ message: 'Kendi admin yetkinizi kaldıramazsınız' });
    }
    // Sistemdeki son admin'i düşüremezsin
    if (user.role === 'admin' && role && role !== 'admin') {
      const adminCount = await User.count({ where: { role: 'admin' } });
      if (adminCount <= 1) {
        return res.status(400).json({ message: 'Sistemdeki son admin yetkisi kaldırılamaz' });
      }
    }

    const before = { name: user.name, phone: user.phone, role: user.role, isEmailVerified: user.isEmailVerified };
    const updates = {};
    if (name !== undefined) updates.name = name;
    if (phone !== undefined) updates.phone = phone;
    if (role !== undefined) updates.role = role;
    if (isEmailVerified !== undefined) updates.isEmailVerified = isEmailVerified;

    await sequelize.transaction(async (transaction) => {
      await sequelize.query('SELECT pg_advisory_xact_lock(190001)', { transaction });
      await user.reload({ transaction, lock: true });
      if (user.role === 'admin' && role && role !== 'admin' &&
          await User.count({ where: { role: 'admin' }, transaction }) <= 1) {
        throw Object.assign(new Error('Sistemdeki son admin yetkisi kaldırılamaz'), { statusCode: 409 });
      }
      await user.update({ ...updates,
        ...((role !== undefined || isEmailVerified !== undefined) ? { authVersion: user.authVersion + 1 } : {}) }, { transaction });
    });

    await auditService.record({
      req,
      action: role && role !== before.role ? 'user.role_change' : 'user.update',
      targetType: 'user',
      targetId: user.id,
      metadata: { before, after: updates },
    });

    const safe = await User.findByPk(user.id, { attributes: { exclude: USER_SAFE_EXCLUDE } });
    res.json({ message: 'Kullanıcı güncellendi', user: safe });
  } catch (error) {
    next(error);
  }
};

exports.deleteUser = async (req, res, next) => {
  try {
    const user = await User.findByPk(req.params.id);
    if (!user) {
      return res.status(404).json({ message: 'Kullanıcı bulunamadı' });
    }

    if (user.id === req.user.id) {
      return res.status(400).json({ message: 'Kendi hesabınızı silemezsiniz' });
    }
    if (user.role === 'admin') {
      const adminCount = await User.count({ where: { role: 'admin' } });
      if (adminCount <= 1) {
        return res.status(400).json({ message: 'Sistemdeki son admin silinemez' });
      }
    }

    await sequelize.transaction(async (transaction) => {
      await sequelize.query('SELECT pg_advisory_xact_lock(190001)', { transaction });
      await assertAccountCanClose(user.id, transaction);
      await user.reload({ transaction, lock: true });
      if (user.role === 'admin' && await User.count({ where: { role: 'admin' }, transaction }) <= 1) {
        throw Object.assign(new Error('Sistemdeki son admin silinemez'), { statusCode: 409 });
      }
      await Business.update({ isActive: false, isApproved: false, isSuspended: true }, { where: { ownerId: user.id }, transaction });
      await user.update({ cardUserKey: null, authVersion: user.authVersion + 1 }, { transaction });
      await user.destroy({ transaction });
    });
    await cacheService.invalidateNamespace('businesses:list');
    await cacheService.invalidateNamespace('packages:list');
    await auditService.record({
      req, action: 'user.delete', targetType: 'user', targetId: user.id,
      metadata: { email: user.email, role: user.role },
    });

    res.json({ message: 'Kullanıcı silindi' });
  } catch (error) {
    next(error);
  }
};

// ── İşletmeler ────────────────────────────────────────────────────────────────
exports.getAllBusinesses = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query);
    const { search, city, approvalStatus, isActive, subMerchantStatus } = req.query;

    const where = {};
    if (search) where.name = { [Op.iLike]: `%${search}%` };
    if (city) where.city = city;
    if (approvalStatus) where.approvalStatus = approvalStatus;
    if (isActive === 'true') where.isActive = true;
    if (isActive === 'false') where.isActive = false;
    if (subMerchantStatus) where.subMerchantStatus = subMerchantStatus;

    const { count, rows } = await Business.findAndCountAll({
      where,
      attributes: { exclude: ['iban', 'identityNumber', 'taxNumber'] },
      include: [
        { model: User, as: 'owner', attributes: ['id', 'name', 'email'] },
        { model: Category, as: 'category', attributes: ['id', 'name'] },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json(paginatedResponse(rows, count, page, limit));
  } catch (error) {
    next(error);
  }
};

exports.getBusinessById = async (req, res, next) => {
  try {
    const business = await Business.findByPk(req.params.id, {
      include: [
        { model: User, as: 'owner', attributes: ['id', 'name', 'email', 'phone'] },
        { model: Category, as: 'category', attributes: ['id', 'name'] },
      ],
    });
    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı' });
    }

    const pkgs = await SurprisePackage.findAll({ where: { businessId: business.id }, attributes: ['id'] });
    const packageIds = pkgs.map((p) => p.id);

    const [packageCount, orderCount, gmv, commission] = await Promise.all([
      SurprisePackage.count({ where: { businessId: business.id } }),
      packageIds.length ? Order.count({ where: { packageId: { [Op.in]: packageIds }, paymentStatus: 'paid' } }) : 0,
      packageIds.length ? Order.sum('paidPrice', { where: { packageId: { [Op.in]: packageIds }, paymentStatus: 'paid' } }) : 0,
      packageIds.length ? Order.sum('commissionAmount', { where: { packageId: { [Op.in]: packageIds }, paymentStatus: 'paid' } }) : 0,
    ]);

    // toOwnerJSON: Business.toJSON hassas alanları varsayılan olarak düşürür.
    // Burada ham kayda bilerek erişiyoruz, çünkü admin görünümü IBAN'ı MASKELİ
    // göstermek istiyor — alan silinmiş gelseydi maskIban(undefined) döner ve
    // panelde bilgi hiç görünmezdi. Maskeleme + eleme aşağıda aynen korunuyor.
    const json = business.toOwnerJSON();
    json.iban = maskIban(json.iban);
    delete json.identityNumber;
    delete json.taxNumber;

    res.json({
      business: json,
      stats: { packageCount, orderCount, gmv: gmv || 0, commission: commission || 0 },
    });
  } catch (error) {
    next(error);
  }
};

exports.setBusinessActive = async (req, res, next) => {
  try {
    const business = await Business.findByPk(req.params.id);
    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı' });
    }

    const { isActive } = req.body;
    await business.update({ isActive, isSuspended: !isActive });
    await auditService.record({
      req, action: 'business.active', targetType: 'business', targetId: business.id, metadata: { isActive },
    });
    await cacheService.invalidateNamespace('businesses:list');
    await cacheService.invalidateNamespace('packages:list');

    res.json({
      message: isActive ? 'İşletme aktifleştirildi' : 'İşletme askıya alındı',
      business,
    });
  } catch (error) {
    next(error);
  }
};

// Business Approval
exports.getPendingBusinesses = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query);

    const { count, rows: businesses } = await Business.findAndCountAll({
      where: { approvalStatus: 'pending' },
      attributes: { exclude: ['iban', 'identityNumber', 'taxNumber'] },
      include: [
        { model: User, as: 'owner', attributes: ['id', 'name', 'email'] },
        { model: Category, as: 'category', attributes: ['id', 'name'] },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json(paginatedResponse(businesses, count, page, limit));
  } catch (error) {
    next(error);
  }
};

exports.approveBusiness = async (req, res, next) => {
  try {
    const business = await Business.findByPk(req.params.id);
    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı' });
    }

    await business.update({ isApproved: true, approvalStatus: 'approved', approvedAt: new Date() });
    await auditService.record({ req, action: 'business.approve', targetType: 'business', targetId: business.id });
    await cacheService.invalidateNamespace('businesses:list');
    // Paket listesi de isApproved'a bağlı — onay sonrası paketler görünür olsun.
    await cacheService.invalidateNamespace('packages:list');

    res.json({ message: 'İşletme onaylandı', business });
  } catch (error) {
    next(error);
  }
};

exports.rejectBusiness = async (req, res, next) => {
  try {
    const business = await Business.findByPk(req.params.id);
    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı' });
    }

    await business.update({ isApproved: false, approvalStatus: 'rejected', rejectedAt: new Date() });
    await auditService.record({ req, action: 'business.reject', targetType: 'business', targetId: business.id });
    await cacheService.invalidateNamespace('businesses:list');
    // Paket listesi de isApproved'a bağlı — ret sonrası paketler listeden düşsün.
    await cacheService.invalidateNamespace('packages:list');

    res.json({ message: 'İşletme reddedildi', business });
  } catch (error) {
    next(error);
  }
};

// ── Siparişler ────────────────────────────────────────────────────────────────
exports.getAllOrders = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query);
    const { status, paymentStatus, refundStatus, businessId, search, startDate, endDate } = req.query;

    const where = {};
    if (status) where.status = status;
    if (paymentStatus) where.paymentStatus = paymentStatus;
    if (refundStatus) where.refundStatus = refundStatus;
    if (search) where.pickupCode = search;
    if (startDate && endDate) {
      where.createdAt = { [Op.between]: [new Date(startDate), new Date(endDate)] };
    }
    if (businessId) {
      const pkgs = await SurprisePackage.findAll({ where: { businessId }, attributes: ['id'] });
      where.packageId = { [Op.in]: pkgs.map((p) => p.id) };
    }

    const { count, rows: orders } = await Order.findAndCountAll({
      where,
      include: [
        {
          model: SurprisePackage,
          as: 'package',
          include: [{ model: Business, as: 'business', attributes: ['id', 'name'] }],
        },
        { model: User, as: 'user', attributes: ['id', 'name', 'email'] },
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

exports.getOrderById = async (req, res, next) => {
  try {
    const order = await Order.findByPk(req.params.id, {
      include: [
        {
          model: SurprisePackage,
          as: 'package',
          include: [{ model: Business, as: 'business', attributes: ['id', 'name', 'phone'] }],
        },
        { model: User, as: 'user', attributes: ['id', 'name', 'email', 'phone'] },
      ],
    });
    if (!order) {
      return res.status(404).json({ message: 'Sipariş bulunamadı' });
    }

    const json = order.toJSON();
    json.paymentTransactionId = maskTail(json.paymentTransactionId);
    json.paymentId = maskTail(json.paymentId);
    json.paymentToken = undefined;

    res.json({ order: json });
  } catch (error) {
    next(error);
  }
};

// Admin iadesi — orderController.cancel'ın para-güvenli akışını yeniden kullanır.
exports.refundOrder = async (req, res, next) => {
  try {
    const order = await Order.findByPk(req.params.id);
    if (!order) {
      return res.status(404).json({ message: 'Sipariş bulunamadı' });
    }
    if (order.paymentStatus !== 'paid') {
      return res.status(400).json({ message: 'İade edilecek ödeme yok veya zaten iade edilmiş' });
    }

    const cancelled = await cancelOrder(order.id, { ip: req.ip, allowPickedUp: true });
    const refundedAmount = Number(cancelled.refundAmount);
    await auditService.record({
      req, action: 'order.refund', targetType: 'order', targetId: order.id,
      metadata: { amount: refundedAmount, reason: req.body?.reason },
    });
    try { await notifyOrderStatus(order.userId, order.id, 'cancelled'); } catch (_) { /* yut */ }

    const fresh = await Order.findByPk(order.id);
    res.json({ message: cancellationMessage(cancelled), order: fresh });
  } catch (error) {
    next(error);
  }
};

// ── Paketler ──────────────────────────────────────────────────────────────────
exports.getAllPackages = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query);
    const { businessId, isActive, search } = req.query;

    const where = {};
    if (businessId) where.businessId = businessId;
    if (isActive === 'true') where.isActive = true;
    if (isActive === 'false') where.isActive = false;
    if (search) where.title = { [Op.iLike]: `%${search}%` };

    const { count, rows } = await SurprisePackage.findAndCountAll({
      where,
      include: [{ model: Business, as: 'business', attributes: ['id', 'name'] }],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json(paginatedResponse(rows, count, page, limit));
  } catch (error) {
    next(error);
  }
};

exports.setPackageActive = async (req, res, next) => {
  try {
    const pkg = await SurprisePackage.findByPk(req.params.id);
    if (!pkg) {
      return res.status(404).json({ message: 'Paket bulunamadı' });
    }

    const { isActive } = req.body;
    await pkg.update({ isActive, isSuspended: !isActive });
    await auditService.record({
      req, action: 'package.active', targetType: 'package', targetId: pkg.id, metadata: { isActive },
    });
    await cacheService.invalidateNamespace('packages:list');

    res.json({ message: isActive ? 'Paket aktifleştirildi' : 'Paket pasifleştirildi', package: pkg });
  } catch (error) {
    next(error);
  }
};

// ── Değerlendirmeler ──────────────────────────────────────────────────────────
exports.getAllReviews = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query);
    const { businessId, minRating } = req.query;

    const where = {};
    if (businessId) where.businessId = businessId;
    if (minRating) where.rating = { [Op.gte]: minRating };

    const { count, rows } = await Review.findAndCountAll({
      where,
      include: [
        { model: User, as: 'user', attributes: ['id', 'name'] },
        { model: Business, as: 'business', attributes: ['id', 'name'] },
        { model: Order, as: 'order', attributes: ['id', 'createdAt'] },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json(paginatedResponse(rows, count, page, limit));
  } catch (error) {
    next(error);
  }
};

exports.deleteReview = async (req, res, next) => {
  try {
    const review = await Review.findByPk(req.params.id);
    if (!review) {
      return res.status(404).json({ message: 'Değerlendirme bulunamadı' });
    }

    const businessId = review.businessId;
    await review.destroy();

    // İşletme ortalama puanını yeniden hesapla.
    const remaining = await Review.findAll({ where: { businessId } });
    const avg = remaining.length ? remaining.reduce((s, r) => s + r.rating, 0) / remaining.length : 0;
    await Business.update({ rating: Math.round(avg * 10) / 10 }, { where: { id: businessId } });

    await auditService.record({
      req, action: 'review.delete', targetType: 'review', targetId: review.id,
      metadata: { businessId, rating: review.rating },
    });

    res.json({ message: 'Değerlendirme silindi' });
  } catch (error) {
    next(error);
  }
};

// ── Ödeme / Mutabakat gözetimi ──────────────────────────────────────────────
exports.getSettlementSummary = async (req, res, next) => {
  try {
    const paid = { paymentStatus: 'paid' };
    const [gmv, commission, refunded, held, approved, heldCount, approvedCount] = await Promise.all([
      Order.sum('paidPrice', { where: paid }),
      Order.sum('commissionAmount', { where: paid }),
      Order.sum('refundAmount', { where: { paymentStatus: { [Op.in]: ['refunded', 'partially_refunded'] } } }),
      Order.sum('subMerchantPrice', { where: { ...paid, settlementStatus: 'held' } }),
      Order.sum('subMerchantPrice', { where: { ...paid, settlementStatus: 'approved' } }),
      Order.count({ where: { ...paid, settlementStatus: 'held' } }),
      Order.count({ where: { ...paid, settlementStatus: 'approved' } }),
    ]);

    res.json({
      summary: {
        gmv: gmv || 0,
        commission: commission || 0,
        refunded: refunded || 0,
        held: held || 0,
        approved: approved || 0,
        heldCount,
        approvedCount,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getSubMerchants = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query);
    const { subMerchantStatus } = req.query;

    const where = {};
    if (subMerchantStatus) where.subMerchantStatus = subMerchantStatus;

    const { count, rows } = await Business.findAndCountAll({
      where,
      attributes: ['id', 'name', 'city', 'subMerchantStatus', 'subMerchantKey', 'subMerchantType', 'iban', 'subMerchantError', 'updatedAt'],
      order: [['updatedAt', 'DESC']],
      limit,
      offset,
    });

    const data = rows.map((b) => {
      const j = b.toJSON();
      j.iban = maskIban(j.iban);
      j.hasKey = Boolean(j.subMerchantKey);
      delete j.subMerchantKey;
      return j;
    });

    res.json(paginatedResponse(data, count, page, limit));
  } catch (error) {
    next(error);
  }
};

// ── Denetim kaydı ─────────────────────────────────────────────────────────────
exports.getAuditLog = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query);
    const { action, targetType, adminId } = req.query;

    const where = {};
    if (action) where.action = action;
    if (targetType) where.targetType = targetType;
    if (adminId) where.adminId = adminId;

    const { count, rows } = await AdminAuditLog.findAndCountAll({
      where,
      include: [{ model: User, as: 'admin', attributes: ['id', 'name', 'email'] }],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json(paginatedResponse(rows, count, page, limit));
  } catch (error) {
    next(error);
  }
};

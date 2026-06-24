const { Order, SurprisePackage, Business, Category, User, Notification, Coupon, sequelize } = require('../models');
const { Op, UniqueConstraintError } = require('sequelize');
const { v4: uuidv4 } = require('uuid');
const { generatePickupCode, paginate, paginatedResponse } = require('../utils/helpers');
const { notifyNewOrder, notifyOrderStatus } = require('../services/notificationService');
const cacheService = require('../services/cacheService');
const iyzicoService = require('../services/iyzicoService');
const settlementService = require('../services/settlementService');
const logger = require('../services/logger');

const HOLD_MINUTES = (() => {
  const m = parseInt(process.env.IYZICO_HOLD_MINUTES, 10);
  return Number.isFinite(m) && m > 0 ? m : 20;
})();

// iyzico checkout başlatılamazsa hold'u telafi et (iptal + stok iade), idempotent.
const releaseHoldCompensation = async (order) => {
  const t = await sequelize.transaction();
  try {
    const [n] = await Order.update(
      { status: 'cancelled', paymentStatus: 'failed', paymentError: 'checkout_init_failed' },
      { where: { id: order.id, status: 'awaiting_payment' }, transaction: t }
    );
    if (n === 1) {
      await SurprisePackage.update(
        { remainingQuantity: sequelize.literal(`"remainingQuantity" + ${parseInt(order.quantity)}`) },
        { where: { id: order.packageId }, transaction: t }
      );
    }
    await t.commit();
    await cacheService.delPattern('packages:list:*');
  } catch (e) {
    await t.rollback();
    logger.error(`[orders] hold telafi hatası (order ${order.id}): ${e.message}`);
  }
};

exports.create = async (req, res, next) => {
  const t = await sequelize.transaction();

  try {
    const { packageId, quantity, couponCode } = req.body;
    const orderQuantity = quantity || 1;

    const pkg = await SurprisePackage.findByPk(packageId, { transaction: t, lock: true });
    if (!pkg) {
      await t.rollback();
      return res.status(404).json({ message: 'Paket bulunamadı' });
    }

    if (!pkg.isActive) {
      await t.rollback();
      return res.status(400).json({ message: 'Bu paket artık aktif değil' });
    }

    let totalPrice = parseFloat(pkg.discountedPrice) * orderQuantity;
    let finalPrice = totalPrice;
    let couponId = null;
    let discountAmount = 0;

    // Kupon uygulama (mevcut mantık korunur)
    if (couponCode) {
      const coupon = await Coupon.findOne({
        where: {
          code: couponCode.toUpperCase(),
          isActive: true,
          expiresAt: { [Op.gt]: new Date() },
        },
        transaction: t,
        lock: true,
      });

      if (!coupon) {
        await t.rollback();
        return res.status(404).json({ message: 'Geçersiz kupon kodu' });
      }

      if (coupon.currentUsage >= coupon.maxUsage) {
        await t.rollback();
        return res.status(400).json({ message: 'Kupon kullanım limiti dolmuş' });
      }

      if (totalPrice < parseFloat(coupon.minOrderAmount)) {
        await t.rollback();
        return res.status(400).json({
          message: `Bu kupon minimum ${coupon.minOrderAmount} TL siparişte geçerlidir`,
        });
      }

      if (coupon.discountType === 'percentage') {
        discountAmount = (totalPrice * parseFloat(coupon.discountValue)) / 100;
      } else {
        discountAmount = parseFloat(coupon.discountValue);
      }

      finalPrice = Math.max(0, totalPrice - discountAmount);
      couponId = coupon.id;

      await coupon.update(
        { currentUsage: coupon.currentUsage + 1 },
        { transaction: t }
      );
    }

    const isFree = finalPrice <= 0;

    // İşletme + kategori (basketItem.category1 için)
    const business = await Business.findByPk(pkg.businessId, {
      include: [{ model: Category, as: 'category', attributes: ['id', 'name'] }],
      transaction: t,
    });
    if (!business) {
      await t.rollback();
      return res.status(404).json({ message: 'İşletme bulunamadı' });
    }

    // Ücretli sipariş normalde işletmenin alt üye işyeri (sub-merchant) kaydı tamamlanmadan alınamaz.
    // TEST modu (IYZICO_TEST_DIRECT_CHARGE=true): Pazaryeri aktif olmadan ödeme AKIŞINI denemek için
    // submerchant olmadan DÜZ tahsilat yapılır (komisyon split + approval YOK). Prod'da kapalı tutun.
    const hasSubMerchant = Boolean(business.subMerchantKey) && business.subMerchantStatus === 'active';
    const allowDirectCharge = process.env.IYZICO_TEST_DIRECT_CHARGE === 'true';
    if (!isFree && !hasSubMerchant && !allowDirectCharge) {
      await t.rollback();
      return res.status(400).json({ message: 'İşletme henüz ödeme almaya hazır değil' });
    }

    const useMarketplace = !isFree && hasSubMerchant;
    // Komisyon kırılımı yalnız gerçek pazaryeri (submerchant) ödemelerinde.
    const subMerchantPrice = useMarketplace ? Number(iyzicoService.calcSubMerchantPrice(finalPrice)) : null;
    const commissionAmount =
      useMarketplace && subMerchantPrice != null ? Number((finalPrice - subMerchantPrice).toFixed(2)) : 0;

    // id'yi önceden üret -> conversationId = order.id
    const orderId = uuidv4();

    // Teslim alma kodu oluştur + benzersiz indeks ihlali durumunda yeniden dene
    let order;
    const maxCodeAttempts = 5;
    for (let codeAttempt = 0; codeAttempt < maxCodeAttempts; codeAttempt++) {
      const pickupCode = await generatePickupCode();
      try {
        order = await Order.create({
          id: orderId,
          userId: req.user.id,
          packageId,
          quantity: orderQuantity,
          totalPrice,
          finalPrice,
          discountAmount,
          couponId,
          pickupCode,
          conversationId: orderId,
          paymentProvider: isFree ? null : 'iyzico',
          status: isFree ? 'pending' : 'awaiting_payment',
          paymentStatus: isFree ? 'paid' : 'pending',
          paidPrice: isFree ? 0 : null,
          paidAt: isFree ? new Date() : null,
          settlementStatus: 'none',
          subMerchantKey: useMarketplace ? business.subMerchantKey : null,
          subMerchantPrice,
          commissionAmount,
          paymentHoldExpiresAt: isFree ? null : new Date(Date.now() + HOLD_MINUTES * 60 * 1000),
        }, { transaction: t });
        break;
      } catch (err) {
        const isPickupCodeConflict =
          err instanceof UniqueConstraintError &&
          (err.fields && (err.fields.pickupCode !== undefined || Object.keys(err.fields).some((f) => /pickupcode/i.test(f))));
        if (isPickupCodeConflict && codeAttempt < maxCodeAttempts - 1) {
          continue;
        }
        throw err;
      }
    }

    // Atomic stok decrement (yarış koruması) — hold da ücretsiz de stok düşürür.
    const [affectedRows] = await SurprisePackage.update(
      { remainingQuantity: sequelize.literal(`"remainingQuantity" - ${parseInt(orderQuantity)}`) },
      {
        where: {
          id: packageId,
          remainingQuantity: { [Op.gte]: orderQuantity }
        },
        transaction: t
      }
    );

    if (affectedRows === 0) {
      await t.rollback();
      return res.status(400).json({ message: 'Yetersiz stok' });
    }

    await t.commit();
    await cacheService.delPattern('packages:list:*');

    // --- Ücretsiz sipariş: ödeme yok, doğrudan onaylı ---
    if (isFree) {
      await notifyNewOrder(business.ownerId, business.name, {
        orderId: order.id,
        packageTitle: pkg.title,
        pickupCode: order.pickupCode,
        totalPrice: order.totalPrice,
      });
      return res.status(201).json({
        message: 'Sipariş oluşturuldu',
        order,
        payment: { required: false },
      });
    }

    // --- Ücretli sipariş: hold commit edildi, şimdi iyzico checkout başlat ---
    const buyer = await User.findByPk(req.user.id);
    try {
      const cf = await iyzicoService.initializeCheckoutForm({
        order,
        user: buyer,
        business,
        pkg,
        categoryName: business.category?.name,
        ip: req.ip,
      });
      await order.update({ paymentToken: cf.token });

      return res.status(201).json({
        message: 'Ödeme başlatıldı',
        order,
        payment: {
          required: true,
          provider: 'iyzico',
          token: cf.token,
          checkoutFormContent: cf.checkoutFormContent,
          paymentPageUrl: cf.paymentPageUrl,
          conversationId: order.conversationId,
          holdExpiresAt: order.paymentHoldExpiresAt,
        },
      });
    } catch (e) {
      logger.error(`[orders] checkout init başarısız (order ${order.id}): ${e.message}`);
      await releaseHoldCompensation(order);
      return res.status(502).json({ message: 'Ödeme başlatılamadı, lütfen tekrar deneyin' });
    }
  } catch (error) {
    try { await t.rollback(); } catch (_) { /* zaten kapanmış */ }
    next(error);
  }
};

exports.getAll = async (req, res, next) => {
  try {
    const where = {};

    if (req.user.role === 'customer') {
      where.userId = req.user.id;
    }

    const { page, limit, offset } = paginate(req.query);

    const { count, rows: orders } = await Order.findAndCountAll({
      where,
      include: [
        {
          model: SurprisePackage,
          as: 'package',
          include: [{ model: Business, as: 'business', attributes: ['id', 'name', 'address', 'phone'] }],
        },
        { model: User, as: 'user', attributes: ['id', 'name', 'email', 'phone'] },
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

exports.getById = async (req, res, next) => {
  try {
    const order = await Order.findByPk(req.params.id, {
      include: [
        {
          model: SurprisePackage,
          as: 'package',
          include: [{ model: Business, as: 'business' }],
        },
        { model: User, as: 'user', attributes: ['id', 'name', 'email', 'phone'] },
      ],
    });

    if (!order) {
      return res.status(404).json({ message: 'Sipariş bulunamadı' });
    }

    const isCustomer = order.userId === req.user.id;
    const isAdmin = req.user.role === 'admin';
    const isBusinessOwner = req.user.role === 'business_owner';

    let isOwnerOfBusiness = false;
    if (isBusinessOwner) {
      const pkg = await SurprisePackage.findByPk(order.packageId, {
        include: [{ model: Business, as: 'business' }],
      });
      isOwnerOfBusiness = pkg && pkg.business.ownerId === req.user.id;
    }

    if (!isCustomer && !isAdmin && !isOwnerOfBusiness) {
      return res.status(403).json({ message: 'Bu siparişi görme yetkiniz yok' });
    }

    res.json({ order });
  } catch (error) {
    next(error);
  }
};

// İzin verilen sipariş durumu geçişleri (durum makinesi). awaiting_payment yalnız
// finalize servisi tarafından 'pending'e taşınır; manuel updateStatus bunu yapamaz.
const ORDER_STATUS_TRANSITIONS = {
  awaiting_payment: ['pending', 'cancelled'],
  pending: ['confirmed', 'cancelled'],
  confirmed: ['picked_up', 'cancelled'],
  picked_up: [],
  cancelled: [],
};

exports.updateStatus = async (req, res, next) => {
  try {
    const { status } = req.body;

    // awaiting_payment manuel set EDİLEMEZ (yalnız sistem finalize eder).
    const validStatuses = ['pending', 'confirmed', 'picked_up', 'cancelled'];
    if (!status || !validStatuses.includes(status)) {
      return res.status(400).json({ message: 'Geçersiz sipariş durumu' });
    }

    const order = await Order.findByPk(req.params.id, {
      include: [{ model: SurprisePackage, as: 'package', include: [{ model: Business, as: 'business' }] }],
    });

    if (!order) {
      return res.status(404).json({ message: 'Sipariş bulunamadı' });
    }

    const isOwner = order.package.business.ownerId === req.user.id;
    const isAdmin = req.user.role === 'admin';
    if (!isOwner && !isAdmin) {
      return res.status(403).json({ message: 'Bu siparişin durumunu güncelleme yetkiniz yok' });
    }

    // Ödenmemiş hold'a işletme/admin dokunamaz (reaper temizler).
    if (order.status === 'awaiting_payment') {
      return res.status(409).json({ message: 'Ödeme bekleniyor, bu sipariş henüz işlenemez' });
    }

    const allowedTargets = ORDER_STATUS_TRANSITIONS[order.status] || [];
    if (!allowedTargets.includes(status)) {
      return res.status(400).json({
        message: `Sipariş durumu '${order.status}' durumundan '${status}' durumuna güncellenemez`,
      });
    }

    // İptal + ödenmiş -> ÖNCE iade (para güvenliği), sonra DB.
    let refundedAmount = 0;
    if (status === 'cancelled' && order.paymentStatus === 'paid') {
      try {
        const r = await settlementService.refundOrder(order, req.ip);
        if (r.refunded) refundedAmount = r.amount;
      } catch (e) {
        logger.error(`[orders] iade başarısız (order ${order.id}): ${e.message}`);
        return res.status(502).json({ message: 'İade işlemi başarısız, lütfen tekrar deneyin' });
      }
    }

    const t = await sequelize.transaction();
    try {
      const updateFields = { status };
      if (status === 'cancelled' && refundedAmount > 0) {
        updateFields.paymentStatus = 'refunded';
        updateFields.settlementStatus = 'refunded';
        updateFields.refundAmount = refundedAmount;
      }
      // Koşullu (status guard) -> eşzamanlı değişime karşı idempotent
      const [n] = await Order.update(updateFields, {
        where: { id: order.id, status: order.status },
        transaction: t,
      });
      if (n === 0) {
        await t.rollback();
        if (refundedAmount > 0) {
          logger.error(`[orders] iade yapıldı ama durum değişmiş (order ${order.id}) - manuel mutabakat gerekli`);
        }
        return res.status(409).json({ message: 'Sipariş durumu değişmiş, tekrar deneyin' });
      }
      if (status === 'cancelled') {
        await SurprisePackage.update(
          { remainingQuantity: sequelize.literal(`"remainingQuantity" + ${order.quantity}`) },
          { where: { id: order.packageId }, transaction: t }
        );
      }
      await t.commit();
    } catch (e) {
      await t.rollback();
      throw e;
    }

    if (status === 'cancelled') {
      await cacheService.delPattern('packages:list:*');
    }

    // Teslim -> satıcı fonlarını serbest bırak (iyzico approval).
    if (status === 'picked_up') {
      await order.reload();
      await settlementService.approveOnPickup(order);
    }

    await notifyOrderStatus(order.userId, order.id, status);

    const fresh = await Order.findByPk(order.id);
    res.json({
      message: 'Sipariş durumu güncellendi',
      order: fresh,
    });
  } catch (error) {
    next(error);
  }
};

exports.cancel = async (req, res, next) => {
  try {
    const order = await Order.findByPk(req.params.id);

    if (!order) {
      return res.status(404).json({ message: 'Sipariş bulunamadı' });
    }

    if (order.userId !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Bu siparişi iptal etme yetkiniz yok' });
    }

    if (order.status === 'picked_up') {
      return res.status(400).json({ message: 'Teslim alınmış sipariş iptal edilemez' });
    }

    if (order.status === 'cancelled') {
      return res.status(400).json({ message: 'Sipariş zaten iptal edilmiş' });
    }

    // Ödenmiş ise ÖNCE iade. (awaiting_payment hold'da paymentStatus 'pending' -> iade yok, sadece stok geri.)
    let refundedAmount = 0;
    if (order.paymentStatus === 'paid') {
      try {
        const r = await settlementService.refundOrder(order, req.ip);
        if (r.refunded) refundedAmount = r.amount;
      } catch (e) {
        logger.error(`[orders] müşteri iptal iadesi başarısız (order ${order.id}): ${e.message}`);
        return res.status(502).json({ message: 'İade işlemi başarısız, lütfen daha sonra tekrar deneyin' });
      }
    }

    const t = await sequelize.transaction();
    try {
      const updateFields = { status: 'cancelled' };
      if (refundedAmount > 0) {
        updateFields.paymentStatus = 'refunded';
        updateFields.settlementStatus = 'refunded';
        updateFields.refundAmount = refundedAmount;
      }
      const [n] = await Order.update(updateFields, {
        where: { id: order.id, status: order.status },
        transaction: t,
      });
      if (n === 0) {
        await t.rollback();
        if (refundedAmount > 0) {
          logger.error(`[orders] iade yapıldı ama durum değişmiş (order ${order.id}) - manuel mutabakat gerekli`);
        }
        return res.status(409).json({ message: 'Sipariş durumu değişmiş' });
      }
      await SurprisePackage.update(
        { remainingQuantity: sequelize.literal(`"remainingQuantity" + ${order.quantity}`) },
        { where: { id: order.packageId }, transaction: t }
      );
      await t.commit();
    } catch (e) {
      await t.rollback();
      throw e;
    }

    await cacheService.delPattern('packages:list:*');

    const pkg = await SurprisePackage.findByPk(order.packageId);
    const business = pkg ? await Business.findByPk(pkg.businessId) : null;
    if (business) {
      await Notification.create({
        userId: business.ownerId,
        title: 'Sipariş İptal Edildi',
        message: `${business.name} işletmenizdeki bir sipariş iptal edildi.`,
        type: 'order_status',
        data: { orderId: order.id, status: 'cancelled' },
      });
    }

    const fresh = await Order.findByPk(order.id);
    res.json({
      message: 'Sipariş iptal edildi',
      order: fresh,
    });
  } catch (error) {
    next(error);
  }
};

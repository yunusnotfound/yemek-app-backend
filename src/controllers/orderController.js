const { Order, SurprisePackage, Business, User, Notification, Coupon, sequelize } = require('../models');
const { Op, UniqueConstraintError } = require('sequelize');
const { generatePickupCode, paginate, paginatedResponse } = require('../utils/helpers');
const { notifyNewOrder } = require('../services/notificationService');
const cacheService = require('../services/cacheService');

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

    // Kupon uygulama
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

      // İndirim hesaplama
      if (coupon.discountType === 'percentage') {
        discountAmount = (totalPrice * parseFloat(coupon.discountValue)) / 100;
      } else {
        discountAmount = parseFloat(coupon.discountValue);
      }

      finalPrice = Math.max(0, totalPrice - discountAmount);
      couponId = coupon.id;

      // Kupon kullanımını artır
      await coupon.update(
        { currentUsage: coupon.currentUsage + 1 },
        { transaction: t }
      );
    }

    // Teslim alma kodu oluştur + benzersiz indeks ihlali durumunda yeniden dene (TOCTOU yarışını kapatır)
    let order;
    const maxCodeAttempts = 5;
    for (let codeAttempt = 0; codeAttempt < maxCodeAttempts; codeAttempt++) {
      const pickupCode = await generatePickupCode();
      try {
        order = await Order.create({
          userId: req.user.id,
          packageId,
          quantity: orderQuantity,
          totalPrice,
          finalPrice,
          discountAmount,
          couponId,
          pickupCode,
        }, { transaction: t });
        break;
      } catch (err) {
        // Aktif siparişler üzerindeki kısmi benzersiz indeks ihlali -> yeni kod ile tekrar dene
        const isPickupCodeConflict =
          err instanceof UniqueConstraintError &&
          (err.fields && (err.fields.pickupCode !== undefined || Object.keys(err.fields).some((f) => /pickupcode/i.test(f))));
        if (isPickupCodeConflict && codeAttempt < maxCodeAttempts - 1) {
          continue;
        }
        throw err;
      }
    }

    // Atomic stock decrement to prevent race conditions
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

    // Stok değişti -> paket listesi önbelleğini geçersiz kıl
    await cacheService.delPattern('packages:list:*');

    // İşletme sahibine bildirim gönder
    const business = await Business.findByPk(pkg.businessId);
    if (business) {
      await notifyNewOrder(business.ownerId, business.name, {
        orderId: order.id,
        packageTitle: pkg.title,
        pickupCode: order.pickupCode,
        totalPrice: order.totalPrice,
      });
    }

    res.status(201).json({
      message: 'Sipariş oluşturuldu',
      order,
    });
  } catch (error) {
    await t.rollback();
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

    // Yetki kontrolü
    const isCustomer = order.userId === req.user.id;
    const isAdmin = req.user.role === 'admin';
    const isBusinessOwner = req.user.role === 'business_owner';
    
    // İşletme sahibi ise kendi işletmesinin siparişi mi kontrol et
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

// İzin verilen sipariş durumu geçişleri (durum makinesi)
const ORDER_STATUS_TRANSITIONS = {
  pending: ['confirmed', 'cancelled'],
  confirmed: ['picked_up', 'cancelled'],
  picked_up: [],
  cancelled: [],
};

exports.updateStatus = async (req, res, next) => {
  const t = await sequelize.transaction();

  try {
    const { status } = req.body;

    // Geçerli durum değeri kontrolü (schemas.js dışında inline doğrulama)
    const validStatuses = ['pending', 'confirmed', 'picked_up', 'cancelled'];
    if (!status || !validStatuses.includes(status)) {
      await t.rollback();
      return res.status(400).json({ message: 'Geçersiz sipariş durumu' });
    }

    const order = await Order.findByPk(req.params.id, {
      include: [{ model: SurprisePackage, as: 'package', include: [{ model: Business, as: 'business' }] }],
      transaction: t,
      lock: true,
    });

    if (!order) {
      await t.rollback();
      return res.status(404).json({ message: 'Sipariş bulunamadı' });
    }

    const isOwner = order.package.business.ownerId === req.user.id;
    const isAdmin = req.user.role === 'admin';

    if (!isOwner && !isAdmin) {
      await t.rollback();
      return res.status(403).json({ message: 'Bu siparişin durumunu güncelleme yetkiniz yok' });
    }

    // Durum geçişini doğrula
    const allowedTargets = ORDER_STATUS_TRANSITIONS[order.status] || [];
    if (!allowedTargets.includes(status)) {
      await t.rollback();
      return res.status(400).json({
        message: `Sipariş durumu '${order.status}' durumundan '${status}' durumuna güncellenemez`,
      });
    }

    // İptale geçişte paket stoğunu geri yükle (mevcut cancel akışıyla aynı)
    if (status === 'cancelled') {
      await SurprisePackage.update(
        { remainingQuantity: sequelize.literal(`"remainingQuantity" + ${order.quantity}`) },
        { where: { id: order.packageId }, transaction: t }
      );
    }

    await order.update({ status }, { transaction: t });

    await t.commit();

    // İptalde stok geri yüklendi -> paket listesi önbelleğini geçersiz kıl
    if (status === 'cancelled') {
      await cacheService.delPattern('packages:list:*');
    }

    // Müşteriye durum değişikliği bildirimi gönder
    const { notifyOrderStatus } = require('../services/notificationService');
    await notifyOrderStatus(order.userId, order.id, status);

    res.json({
      message: 'Sipariş durumu güncellendi',
      order,
    });
  } catch (error) {
    await t.rollback();
    next(error);
  }
};

exports.cancel = async (req, res, next) => {
  const t = await sequelize.transaction();

  try {
    const order = await Order.findByPk(req.params.id, { transaction: t });

    if (!order) {
      await t.rollback();
      return res.status(404).json({ message: 'Sipariş bulunamadı' });
    }

    if (order.userId !== req.user.id && req.user.role !== 'admin') {
      await t.rollback();
      return res.status(403).json({ message: 'Bu siparişi iptal etme yetkiniz yok' });
    }

    if (order.status === 'picked_up') {
      await t.rollback();
      return res.status(400).json({ message: 'Teslim alınmış sipariş iptal edilemez' });
    }

    if (order.status === 'cancelled') {
      await t.rollback();
      return res.status(400).json({ message: 'Sipariş zaten iptal edilmiş' });
    }

    await order.update({ status: 'cancelled' }, { transaction: t });

    const pkg = await SurprisePackage.findByPk(order.packageId, { transaction: t });
    await SurprisePackage.update(
      { remainingQuantity: sequelize.literal(`"remainingQuantity" + ${order.quantity}`) },
      { where: { id: order.packageId }, transaction: t }
    );

    await t.commit();

    // Stok geri yüklendi -> paket listesi önbelleğini geçersiz kıl
    await cacheService.delPattern('packages:list:*');

    // İşletme sahibine iptal bildirimi gönder
    const business = await Business.findByPk(pkg.businessId);
    if (business) {
      await Notification.create({
        userId: business.ownerId,
        title: 'Sipariş İptal Edildi',
        message: `${business.name} işletmenizdeki bir sipariş iptal edildi.`,
        type: 'order_status',
        data: { orderId: order.id, status: 'cancelled' },
      });
    }

    res.json({
      message: 'Sipariş iptal edildi',
      order,
    });
  } catch (error) {
    await t.rollback();
    next(error);
  }
};

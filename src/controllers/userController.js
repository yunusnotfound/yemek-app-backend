const { User, Order, Review, Favorite, Business, SurprisePackage, sequelize } = require('../models');
const { Op } = require('sequelize');

exports.getProfile = async (req, res, next) => {
  try {
    res.json({ user: req.user });
  } catch (error) {
    next(error);
  }
};

exports.deleteAccount = async (req, res, next) => {
  const t = await sequelize.transaction();
  try {
    const userId = req.user.id;

    // 1) Cancel active (pending/confirmed) orders AND restock each package,
    //    mirroring the restock logic in orderController.cancelOrder.
    const activeOrders = await Order.findAll({
      where: { userId, status: { [Op.in]: ['pending', 'confirmed'] } },
      transaction: t,
    });

    for (const order of activeOrders) {
      await order.update({ status: 'cancelled' }, { transaction: t });
      await SurprisePackage.update(
        { remainingQuantity: sequelize.literal(`"remainingQuantity" + ${order.quantity}`) },
        { where: { id: order.packageId }, transaction: t }
      );
    }

    // 2) Remove favorites
    await Favorite.destroy({ where: { userId }, transaction: t });

    // 3) If the user owns businesses, deactivate them so orphaned active
    //    businesses don't stay visible to customers. Do NOT hard-delete.
    if (req.user.role === 'business_owner') {
      await Business.update(
        { isActive: false, isApproved: false, approvalStatus: 'rejected' },
        { where: { ownerId: userId }, transaction: t }
      );
    }

    // 4) Anonymize PII on the user row, then soft-delete (paranoid).
    //    Using only existing columns; replace identifying fields with
    //    anonymized placeholders and clear all auth/reset secrets.
    //    hooks:false so the beforeUpdate password-hash hook doesn't run on the
    //    cleared (null) password.
    await User.update(
      {
        name: 'Silinmiş Kullanıcı',
        email: `deleted_${userId}@deleted.local`,
        phone: null,
        password: null,
        passwordResetToken: null,
        passwordResetExpires: null,
        emailVerificationToken: null,
        emailVerificationExpires: null,
        isEmailVerified: false,
        googleId: null,
        appleId: null,
        latitude: null,
        longitude: null,
      },
      { where: { id: userId }, transaction: t, hooks: false }
    );

    // Soft-delete the user (paranoid mode). Reload first so the destroy targets
    // the row correctly after the raw anonymizing update.
    await req.user.destroy({ transaction: t });

    await t.commit();

    res.json({ message: 'Hesabınız başarıyla silindi' });
  } catch (error) {
    await t.rollback();
    next(error);
  }
};

exports.updateProfile = async (req, res, next) => {
  try {
    const { name, phone, latitude, longitude } = req.body;

    await req.user.update({ name, phone, latitude, longitude });

    res.json({
      message: 'Profil güncellendi',
      user: req.user,
    });
  } catch (error) {
    next(error);
  }
};

const { User, Favorite, Business, sequelize } = require('../models');
const { assertAccountCanClose } = require('../services/accountClosureService');

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

    if (req.user.role === 'admin') {
      await t.rollback();
      return res.status(409).json({ message: 'Yönetici hesabını başka bir yönetici yönetim panelinden kapatmalıdır' });
    }
    await assertAccountCanClose(userId, t);

    // 2) Remove favorites
    await Favorite.destroy({ where: { userId }, transaction: t });

    // 3) If the user owns businesses, deactivate them so orphaned active
    //    businesses don't stay visible to customers. Do NOT hard-delete.
    {
      await Business.update(
        { isActive: false, isApproved: false, approvalStatus: 'rejected' },
        { where: { ownerId: userId }, transaction: t }
      );
    }

    // 4) Anonymize PII on the user row, then soft-delete (paranoid).
    //    Replace identifying fields with
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
        cardUserKey: null,
        authVersion: sequelize.literal('"authVersion" + 1'),
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

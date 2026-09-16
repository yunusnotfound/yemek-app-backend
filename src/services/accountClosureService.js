const { User, Business, SurprisePackage, Order } = require('../models');
const { Op } = require('sequelize');

// Same lock order as order creation; account/business closure cannot miss a
// concurrently created payment hold. Shared by customer and admin deletion.
const assertAccountCanClose = async (userId, transaction) => {
  const user = await User.findByPk(userId, { transaction, lock: true });
  if (!user) throw Object.assign(new Error('Kullanıcı bulunamadı'), { statusCode: 404 });
  const owned = await Business.findAll({ where: { ownerId: userId }, transaction, lock: true });
  const packages = owned.length ? await SurprisePackage.findAll({
    where: { businessId: { [Op.in]: owned.map(b => b.id) } }, attributes: ['id'], paranoid: false, transaction,
  }) : [];
  const outstanding = await Order.count({ where: {
    [Op.and]: [
      { [Op.or]: [{ userId }, { packageId: { [Op.in]: packages.map(p => p.id) } }] },
      { [Op.or]: [{ status: { [Op.in]: ['awaiting_payment', 'pending', 'confirmed'] } },
        { refundStatus: { [Op.in]: ['pending', 'processing', 'review'] } },
        { status: 'picked_up', settlementStatus: 'held' }] },
    ],
  }, transaction });
  if (outstanding) throw Object.assign(new Error('Hesabı silmeden önce aktif sipariş ve bekleyen iadeleri tamamlayın veya iptal edin.'), { statusCode: 409 });
  return user;
};

module.exports = { assertAccountCanClose };

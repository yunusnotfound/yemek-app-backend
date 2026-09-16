'use strict';

module.exports = {
  async up(q, S) {
    await q.sequelize.transaction(async (transaction) => {
      const options = { transaction };
      const fields = {
        title: { type: S.STRING(100), allowNull: true },
        firstOrderOnly: { type: S.BOOLEAN, allowNull: false, defaultValue: false },
        perUserLimit: { type: S.INTEGER, allowNull: true },
        maxDiscountAmount: { type: S.DECIMAL(10, 2), allowNull: true },
        budgetLimit: { type: S.DECIMAL(12, 2), allowNull: true },
        isDiscoverable: { type: S.BOOLEAN, allowNull: false, defaultValue: false },
        businessIds: { type: S.ARRAY(S.UUID), allowNull: false, defaultValue: [] },
        merchantConsentConfirmed: { type: S.BOOLEAN, allowNull: false, defaultValue: false },
      };
      for (const [name, field] of Object.entries(fields)) await q.addColumn('Coupons', name, field, options);
      await q.addColumn('Orders', 'originalTotal', { type: S.DECIMAL(10, 2), allowNull: true }, options);
      await q.addColumn('Orders', 'couponReleased', { type: S.BOOLEAN, allowNull: false, defaultValue: false }, options);
      // Historical list prices cannot be reconstructed from today's package price.
      // Preserve payment evidence; only mark clearly unpaid cancellations released.
      await q.sequelize.query(`UPDATE "Orders" SET "couponReleased" = true
        WHERE status = 'cancelled' AND "paidAt" IS NULL AND COALESCE("paidPrice", 0) = 0`, options);
      await q.addIndex('Orders', ['couponId', 'userId', 'couponReleased'], { ...options, name: 'orders_coupon_usage' });
    });
  },
  async down(q) {
    await q.sequelize.transaction(async (transaction) => {
      const options = { transaction };
      await q.removeIndex('Orders', 'orders_coupon_usage', options);
      for (const field of ['originalTotal', 'couponReleased']) await q.removeColumn('Orders', field, options);
      for (const field of ['title', 'firstOrderOnly', 'perUserLimit', 'maxDiscountAmount', 'budgetLimit',
        'isDiscoverable', 'businessIds', 'merchantConsentConfirmed']) await q.removeColumn('Coupons', field, options);
    });
  },
};

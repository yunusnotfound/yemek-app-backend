'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      const options = { transaction };
      await queryInterface.addColumn('Users', 'authVersion', { type: Sequelize.INTEGER, allowNull: false, defaultValue: 0 }, options);
      await queryInterface.addColumn('Users', 'passwordResetAttempts', { type: Sequelize.INTEGER, allowNull: false, defaultValue: 0 }, options);
      for (const table of ['Businesses', 'SurprisePackages']) {
        await queryInterface.addColumn(table, 'isSuspended', { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: false }, options);
      }
      // Preserve prior admin suspensions (including owner reactivation attempts)
      // using the last explicit admin activation decision in the audit trail.
      for (const [table, action] of [['Businesses', 'business.active'], ['SurprisePackages', 'package.active']]) {
        await queryInterface.sequelize.query(`UPDATE "${table}" AS target SET "isSuspended" = true, "isActive" = false
          FROM (SELECT DISTINCT ON ("targetId") "targetId", metadata FROM "AdminAuditLogs"
            WHERE action = :action ORDER BY "targetId", "createdAt" DESC, id DESC) AS last_action
          WHERE target.id::text = last_action."targetId" AND last_action.metadata->>'isActive' = 'false'`,
        { ...options, replacements: { action } });
      }
      await queryInterface.addColumn('Orders', 'refundStatus', { type: Sequelize.STRING(20), allowNull: false, defaultValue: 'none' }, options);
      await queryInterface.addColumn('Orders', 'refundRequestedAt', { type: Sequelize.DATE, allowNull: true }, options);
      await queryInterface.addColumn('Orders', 'refundAttemptedAt', { type: Sequelize.DATE, allowNull: true }, options);
      await queryInterface.addColumn('Orders', 'fraudReview', { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: false }, options);
      await queryInterface.addColumn('Orders', 'paymentCheckedAt', { type: Sequelize.DATE, allowNull: true }, options);
      // Fail on historical duplicates instead of silently deleting payment evidence.
      for (const [field, name] of [
        ['paymentId', 'orders_payment_id_unique'],
        ['paymentTransactionId', 'orders_payment_transaction_unique'],
        ['paymentToken', 'orders_payment_token_unique'],
      ]) await queryInterface.addIndex('Orders', [field], { ...options, unique: true, name });
      // Existing cancelled-but-paid rows need reconciliation, not a blind retry.
      await queryInterface.sequelize.query(`UPDATE "Orders" SET "refundStatus" = 'review',
        "refundRequestedAt" = NOW() WHERE status = 'cancelled' AND "paymentStatus" = 'paid'
        AND COALESCE("paidPrice", "finalPrice") > 0`, options);
    });
  },
  async down(queryInterface) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      const options = { transaction };
      for (const name of ['orders_payment_id_unique', 'orders_payment_transaction_unique', 'orders_payment_token_unique']) {
        await queryInterface.removeIndex('Orders', name, options);
      }
      for (const field of ['refundStatus', 'refundRequestedAt', 'refundAttemptedAt', 'fraudReview', 'paymentCheckedAt']) {
        await queryInterface.removeColumn('Orders', field, options);
      }
      for (const table of ['Businesses', 'SurprisePackages']) await queryInterface.removeColumn(table, 'isSuspended', options);
      for (const field of ['authVersion', 'passwordResetAttempts']) await queryInterface.removeColumn('Users', field, options);
    });
  },
};

'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // 1) Mevcut Orders.status enum'una 'awaiting_payment' değerini ekle.
    //    (sequelize-cli migration'ı transaction içinde sarmaz; ADD VALUE güvenli çalışır.)
    await queryInterface.sequelize.query(
      `ALTER TYPE "enum_Orders_status" ADD VALUE IF NOT EXISTS 'awaiting_payment';`
    );

    // 2) Yeni ödeme kolonları (hepsi nullable/defaultlu -> mevcut satırlar bozulmaz).
    await queryInterface.addColumn('Orders', 'paymentStatus', {
      type: Sequelize.ENUM('unpaid', 'pending', 'paid', 'failed', 'refunded', 'partially_refunded'),
      allowNull: false,
      defaultValue: 'unpaid',
    });
    await queryInterface.addColumn('Orders', 'paymentProvider', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await queryInterface.addColumn('Orders', 'conversationId', {
      type: Sequelize.STRING(64),
      allowNull: true,
    });
    await queryInterface.addColumn('Orders', 'paymentToken', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await queryInterface.addColumn('Orders', 'paymentId', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await queryInterface.addColumn('Orders', 'paymentTransactionId', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await queryInterface.addColumn('Orders', 'subMerchantKey', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await queryInterface.addColumn('Orders', 'subMerchantPrice', {
      type: Sequelize.DECIMAL(10, 2),
      allowNull: true,
    });
    await queryInterface.addColumn('Orders', 'commissionAmount', {
      type: Sequelize.DECIMAL(10, 2),
      allowNull: false,
      defaultValue: 0,
    });
    await queryInterface.addColumn('Orders', 'settlementStatus', {
      type: Sequelize.ENUM('none', 'held', 'approved', 'disapproved', 'refunded'),
      allowNull: false,
      defaultValue: 'none',
    });
    await queryInterface.addColumn('Orders', 'paidPrice', {
      type: Sequelize.DECIMAL(10, 2),
      allowNull: true,
    });
    await queryInterface.addColumn('Orders', 'refundAmount', {
      type: Sequelize.DECIMAL(10, 2),
      allowNull: false,
      defaultValue: 0,
    });
    await queryInterface.addColumn('Orders', 'paidAt', {
      type: Sequelize.DATE,
      allowNull: true,
    });
    await queryInterface.addColumn('Orders', 'paymentHoldExpiresAt', {
      type: Sequelize.DATE,
      allowNull: true,
    });
    await queryInterface.addColumn('Orders', 'paymentError', {
      type: Sequelize.STRING(500),
      allowNull: true,
    });

    // 3) Reaper sorgusu için index (status + hold süresi).
    await queryInterface.addIndex('Orders', ['status', 'paymentHoldExpiresAt'], {
      name: 'idx_orders_status_holdExpires',
    });

    // 4) conversationId benzersiz (NULL'lar hariç) — idempotency.
    await queryInterface.sequelize.query(`
      CREATE UNIQUE INDEX "idx_orders_conversationId_unique"
      ON "Orders" ("conversationId")
      WHERE "conversationId" IS NOT NULL AND "deletedAt" IS NULL;
    `);

    // 5) pickupCode kısmi benzersiz indeksini 'awaiting_payment'i de kapsayacak şekilde
    //    yeniden oluştur (hold'lar arası ve hold->paid kod çakışmasını engeller).
    await queryInterface.sequelize.query(`DROP INDEX IF EXISTS "idx_orders_pickupCode_active_unique";`);
    await queryInterface.sequelize.query(`
      CREATE UNIQUE INDEX "idx_orders_pickupCode_active_unique"
      ON "Orders" ("pickupCode")
      WHERE "status" IN ('awaiting_payment', 'pending', 'confirmed') AND "deletedAt" IS NULL;
    `);
  },

  async down(queryInterface, Sequelize) {
    // pickupCode indeksini eski (awaiting_payment'siz) haline döndür.
    await queryInterface.sequelize.query(`DROP INDEX IF EXISTS "idx_orders_pickupCode_active_unique";`);
    await queryInterface.sequelize.query(`
      CREATE UNIQUE INDEX "idx_orders_pickupCode_active_unique"
      ON "Orders" ("pickupCode")
      WHERE "status" IN ('pending', 'confirmed') AND "deletedAt" IS NULL;
    `);

    await queryInterface.sequelize.query(`DROP INDEX IF EXISTS "idx_orders_conversationId_unique";`);
    await queryInterface.removeIndex('Orders', 'idx_orders_status_holdExpires');

    for (const col of [
      'paymentStatus', 'paymentProvider', 'conversationId', 'paymentToken', 'paymentId',
      'paymentTransactionId', 'subMerchantKey', 'subMerchantPrice', 'commissionAmount',
      'settlementStatus', 'paidPrice', 'refundAmount', 'paidAt', 'paymentHoldExpiresAt', 'paymentError',
    ]) {
      await queryInterface.removeColumn('Orders', col);
    }

    // Yeni enum tiplerini temizle (Postgres). status enum'una eklenen 'awaiting_payment'
    // değeri Postgres'te kolayca geri alınamaz; bilinçli olarak bırakılır.
    await queryInterface.sequelize.query(`DROP TYPE IF EXISTS "enum_Orders_paymentStatus";`);
    await queryInterface.sequelize.query(`DROP TYPE IF EXISTS "enum_Orders_settlementStatus";`);
  },
};

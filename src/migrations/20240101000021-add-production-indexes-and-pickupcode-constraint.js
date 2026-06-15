'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // pickupCode artık 6 haneli üretiliyor; kolon VARCHAR(4) -> VARCHAR(6) genişletilmeli,
    // aksi halde 6 haneli kod insert'leri başarısız olur. Mevcut 4 haneli kodlar geçerli kalır.
    await queryInterface.changeColumn('Orders', 'pickupCode', {
      type: Sequelize.STRING(6),
      allowNull: false,
    });

    // SurprisePackages indexes
    await queryInterface.addIndex('SurprisePackages', ['pickupDate'], {
      name: 'idx_surprisepackages_pickupDate',
    });
    await queryInterface.addIndex('SurprisePackages', ['isActive', 'pickupDate'], {
      name: 'idx_surprisepackages_isActive_pickupDate',
    });

    // Businesses indexes
    await queryInterface.addIndex('Businesses', ['city'], {
      name: 'idx_businesses_city',
    });
    await queryInterface.addIndex('Businesses', ['district'], {
      name: 'idx_businesses_district',
    });
    // Geo bounding-box sorgusu (packageController) latitude/longitude üzerinde filtreliyor.
    await queryInterface.addIndex('Businesses', ['latitude', 'longitude'], {
      name: 'idx_businesses_lat_lng',
    });

    // Orders couponId index
    await queryInterface.addIndex('Orders', ['couponId'], {
      name: 'idx_orders_couponId',
    });

    // Reviews orderId index
    await queryInterface.addIndex('Reviews', ['orderId'], {
      name: 'idx_reviews_orderId',
    });

    // Aktif siparişler üzerinde pickupCode için kısmi benzersiz indeks (TOCTOU yarışına karşı son güvence).
    // Postgres kolon adı büyük/küçük harf duyarlı olduğundan çift tırnakla alıntılanır.
    await queryInterface.sequelize.query(`
      CREATE UNIQUE INDEX "idx_orders_pickupCode_active_unique"
      ON "Orders" ("pickupCode")
      WHERE "status" IN ('pending', 'confirmed') AND "deletedAt" IS NULL;
    `);
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.sequelize.query(`
      DROP INDEX IF EXISTS "idx_orders_pickupCode_active_unique";
    `);
    await queryInterface.removeIndex('Reviews', 'idx_reviews_orderId');
    await queryInterface.removeIndex('Orders', 'idx_orders_couponId');
    await queryInterface.removeIndex('Businesses', 'idx_businesses_lat_lng');
    await queryInterface.removeIndex('Businesses', 'idx_businesses_district');
    await queryInterface.removeIndex('Businesses', 'idx_businesses_city');
    await queryInterface.removeIndex('SurprisePackages', 'idx_surprisepackages_isActive_pickupDate');
    await queryInterface.removeIndex('SurprisePackages', 'idx_surprisepackages_pickupDate');
  },
};

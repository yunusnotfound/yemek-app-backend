'use strict';

const { v4: uuidv4 } = require('uuid');

module.exports = {
  async up(queryInterface) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('Seed verisi production ortamında çalıştırılamaz (örnek/demo veri).');
    }
    const existing = await queryInterface.sequelize.query(
      'SELECT id FROM "Coupons" LIMIT 1',
      { type: queryInterface.sequelize.QueryTypes.SELECT }
    );
    if (existing.length > 0) return;

    const futureDate = new Date();
    futureDate.setMonth(futureDate.getMonth() + 3);

    await queryInterface.bulkInsert('Coupons', [
      {
        id: uuidv4(),
        code: 'INDIRIM20',
        discountType: 'percentage',
        discountValue: 20.00,
        minOrderAmount: 100.00,
        maxUsage: 100,
        currentUsage: 5,
        expiresAt: futureDate,
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        code: 'HOSEGELDIN50',
        discountType: 'fixed',
        discountValue: 50.00,
        minOrderAmount: 150.00,
        maxUsage: 50,
        currentUsage: 12,
        expiresAt: futureDate,
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        code: 'YUZDE10',
        discountType: 'percentage',
        discountValue: 10.00,
        minOrderAmount: 50.00,
        maxUsage: 200,
        currentUsage: 45,
        expiresAt: futureDate,
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        code: 'TATLI30',
        discountType: 'fixed',
        discountValue: 30.00,
        minOrderAmount: 80.00,
        maxUsage: 75,
        currentUsage: 8,
        expiresAt: futureDate,
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ]);
  },

  async down(queryInterface) {
    await queryInterface.bulkDelete('Coupons', null, {});
  },
};

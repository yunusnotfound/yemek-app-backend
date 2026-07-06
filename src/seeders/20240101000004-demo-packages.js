'use strict';

const { v4: uuidv4 } = require('uuid');

module.exports = {
  async up(queryInterface) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('Seed verisi production ortamında çalıştırılamaz (örnek/demo veri).');
    }
    const existing = await queryInterface.sequelize.query(
      'SELECT id FROM "SurprisePackages" LIMIT 1',
      { type: queryInterface.sequelize.QueryTypes.SELECT }
    );
    if (existing.length > 0) return;

    // İşletme ID'lerini al
    const businesses = await queryInterface.sequelize.query(
      `SELECT id, name FROM "Businesses"`,
      { type: queryInterface.sequelize.QueryTypes.SELECT }
    );

    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = tomorrow.toISOString().split('T')[0];

    const dayAfter = new Date();
    dayAfter.setDate(dayAfter.getDate() + 2);
    const dayAfterStr = dayAfter.toISOString().split('T')[0];

    await queryInterface.bulkInsert('SurprisePackages', [
      {
        id: uuidv4(),
        businessId: businesses[0]?.id || uuidv4(),
        title: 'Sürpriz Akşam Yemeği Paketi',
        description: '2 kişilik akşam yemeği menüsü - Çorba, ana yemek, tatlı',
        originalPrice: 250.00,
        discountedPrice: 149.90,
        quantity: 10,
        remainingQuantity: 7,
        pickupStart: '18:00',
        pickupEnd: '21:00',
        pickupDate: tomorrowStr,
        imageUrl: 'https://picsum.photos/seed/package1/400/300',
        isActive: true,
        isRecurring: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        businessId: businesses[0]?.id || uuidv4(),
        title: 'Öğle Yemeği Fırsatı',
        description: '1 kişilik öğle yemeği - Ana yemek, içecek, tatlı',
        originalPrice: 180.00,
        discountedPrice: 99.90,
        quantity: 15,
        remainingQuantity: 12,
        pickupStart: '12:00',
        pickupEnd: '15:00',
        pickupDate: tomorrowStr,
        imageUrl: 'https://picsum.photos/seed/package2/400/300',
        isActive: true,
        isRecurring: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        businessId: businesses[1]?.id || uuidv4(),
        title: 'Tatlı Kutu Fırsatı',
        description: 'Karışık mini tatlı kutusu - 6 adet',
        originalPrice: 120.00,
        discountedPrice: 69.90,
        quantity: 20,
        remainingQuantity: 15,
        pickupStart: '10:00',
        pickupEnd: '20:00',
        pickupDate: tomorrowStr,
        imageUrl: 'https://picsum.photos/seed/package3/400/300',
        isActive: true,
        isRecurring: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        businessId: businesses[1]?.id || uuidv4(),
        title: 'Pasta Sürprizi',
        description: '4-6 kişilik günlük pasta',
        originalPrice: 350.00,
        discountedPrice: 199.90,
        quantity: 5,
        remainingQuantity: 3,
        pickupStart: '09:00',
        pickupEnd: '19:00',
        pickupDate: dayAfterStr,
        imageUrl: 'https://picsum.photos/seed/package4/400/300',
        isActive: true,
        isRecurring: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        businessId: businesses[2]?.id || uuidv4(),
        title: 'Kahve ve Atıştırmalık',
        description: '2 kahve + 2 tatlı',
        originalPrice: 160.00,
        discountedPrice: 89.90,
        quantity: 12,
        remainingQuantity: 8,
        pickupStart: '08:00',
        pickupEnd: '22:00',
        pickupDate: tomorrowStr,
        imageUrl: 'https://picsum.photos/seed/package5/400/300',
        isActive: true,
        isRecurring: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        businessId: businesses[3]?.id || uuidv4(),
        title: 'Ekmek ve Poğaça Paketi',
        description: '2 ekmek + 4 poğaça',
        originalPrice: 80.00,
        discountedPrice: 49.90,
        quantity: 30,
        remainingQuantity: 25,
        pickupStart: '07:00',
        pickupEnd: '11:00',
        pickupDate: tomorrowStr,
        imageUrl: 'https://picsum.photos/seed/package6/400/300',
        isActive: true,
        isRecurring: true,
        recurringDays: [1, 2, 3, 4, 5],
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ]);
  },

  async down(queryInterface) {
    await queryInterface.bulkDelete('SurprisePackages', null, {});
  },
};

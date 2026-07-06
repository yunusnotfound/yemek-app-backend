'use strict';

const { v4: uuidv4 } = require('uuid');

module.exports = {
  async up(queryInterface) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('Seed verisi production ortamında çalıştırılamaz (örnek/demo veri).');
    }
    const existing = await queryInterface.sequelize.query(
      'SELECT id FROM "Businesses" LIMIT 1',
      { type: queryInterface.sequelize.QueryTypes.SELECT }
    );
    if (existing.length > 0) return;

    // Önce kullanıcı ID'lerini al
    const users = await queryInterface.sequelize.query(
      `SELECT id, email FROM "Users" WHERE role = 'business_owner'`,
      { type: queryInterface.sequelize.QueryTypes.SELECT }
    );
    
    const owner1 = users.find(u => u.email === 'owner1@bitiryemek.com');
    const owner2 = users.find(u => u.email === 'owner2@bitiryemek.com');

    await queryInterface.bulkInsert('Businesses', [
      {
        id: uuidv4(),
        ownerId: owner1?.id || uuidv4(),
        categoryId: 1,
        name: 'Lezzet Durağı Restaurant',
        description: 'Ev yemekleri ve kebap çeşitleri',
        address: 'İstiklal Caddesi No:123',
        city: 'İstanbul',
        district: 'Beyoğlu',
        latitude: 41.0369,
        longitude: 28.9857,
        phone: '2125551111',
        imageUrl: 'https://example.com/images/business1.jpg',
        rating: 4.5,
        isActive: true,
        isApproved: true,
        approvalStatus: 'approved',
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        ownerId: owner1?.id || uuidv4(),
        categoryId: 3,
        name: 'Tatlı Düşler Pastanesi',
        description: 'Taze pastalar ve tatlılar',
        address: 'Bağdat Caddesi No:456',
        city: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9823,
        longitude: 29.0240,
        phone: '2165552222',
        imageUrl: 'https://picsum.photos/seed/business2/400/300',
        rating: 4.8,
        isActive: true,
        isApproved: true,
        approvalStatus: 'approved',
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        ownerId: owner2?.id || uuidv4(),
        categoryId: 5,
        name: 'Kahve Molası Kafe',
        description: 'Özel kahve çeşitleri ve atıştırmalıklar',
        address: 'Moda Caddesi No:78',
        city: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9789,
        longitude: 29.0254,
        phone: '2165553333',
        imageUrl: 'https://picsum.photos/seed/business3/400/300',
        rating: 4.3,
        isActive: true,
        isApproved: true,
        approvalStatus: 'approved',
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        ownerId: owner2?.id || uuidv4(),
        categoryId: 2,
        name: 'Ekmek Teknesi Fırın',
        description: 'Taze ekmek ve unlu mamuller',
        address: 'Cumhuriyet Caddesi No:90',
        city: 'İstanbul',
        district: 'Şişli',
        latitude: 41.0504,
        longitude: 28.9877,
        phone: '2125554444',
        imageUrl: 'https://picsum.photos/seed/business4/400/300',
        rating: 4.6,
        isActive: true,
        isApproved: true,
        approvalStatus: 'approved',
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ]);
  },

  async down(queryInterface) {
    await queryInterface.bulkDelete('Businesses', null, {});
  },
};

'use strict';

module.exports = {
  async up(queryInterface) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('Seed verisi production ortamında çalıştırılamaz (örnek/demo veri). Kategorileri admin panelinden ekleyin.');
    }
    const existing = await queryInterface.sequelize.query(
      'SELECT id FROM "Categories" LIMIT 1',
      { type: queryInterface.sequelize.QueryTypes.SELECT }
    );
    if (existing.length > 0) return;

    await queryInterface.bulkInsert('Categories', [
      { id: 1, name: 'Restoran', slug: 'restoran', createdAt: new Date(), updatedAt: new Date() },
      { id: 2, name: 'Fırın', slug: 'firin', createdAt: new Date(), updatedAt: new Date() },
      { id: 3, name: 'Pastane', slug: 'pastane', createdAt: new Date(), updatedAt: new Date() },
      { id: 4, name: 'Market', slug: 'market', createdAt: new Date(), updatedAt: new Date() },
      { id: 5, name: 'Kafe', slug: 'kafe', createdAt: new Date(), updatedAt: new Date() },
      { id: 6, name: 'Manav', slug: 'manav', createdAt: new Date(), updatedAt: new Date() },
      { id: 7, name: 'Kasap', slug: 'kasap', createdAt: new Date(), updatedAt: new Date() },
      { id: 8, name: 'Büfe', slug: 'bufe', createdAt: new Date(), updatedAt: new Date() },
    ]);
  },

  async down(queryInterface) {
    await queryInterface.bulkDelete('Categories', null, {});
  },
};

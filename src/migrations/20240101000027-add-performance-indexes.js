'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface) {
    // Admin gösterge paneli ve işletme paneli agregasyonları paymentStatus='paid'
    // üzerinde COUNT/SUM yapıyor (adminController, businessDashboardController).
    // İndekssiz sorgu tüm Orders tablosunu tarıyordu.
    await queryInterface.addIndex('Orders', ['paymentStatus'], {
      name: 'idx_orders_paymentStatus',
    });

    // Sipariş listeleri createdAt DESC ile sıralanıyor; özellikle admin'in filtresiz
    // listesi tüm tabloyu sıralıyordu.
    await queryInterface.addIndex('Orders', ['createdAt'], {
      name: 'idx_orders_createdAt',
    });

    // Mobil uygulama okunmamış bildirim rozetini sık poll ediyor:
    // WHERE "userId" = ? AND "isRead" = false. Tek kolonlu userId indeksi yetersizdi.
    await queryInterface.addIndex('Notifications', ['userId', 'isRead'], {
      name: 'idx_notifications_userId_isRead',
    });
  },

  async down(queryInterface) {
    await queryInterface.removeIndex('Notifications', 'idx_notifications_userId_isRead');
    await queryInterface.removeIndex('Orders', 'idx_orders_createdAt');
    await queryInterface.removeIndex('Orders', 'idx_orders_paymentStatus');
  },
};

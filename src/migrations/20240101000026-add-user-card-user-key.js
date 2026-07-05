'use strict';

/**
 * iyzico kart saklama: kullanıcının iyzico'daki kart cüzdanı anahtarı.
 * PAN/kart bilgisi BİZDE TUTULMAZ — kartlar iyzico'da, biz yalnız cüzdan anahtarını saklarız.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('Users', 'cardUserKey', {
      type: Sequelize.STRING,
      allowNull: true,
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('Users', 'cardUserKey');
  },
};

'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('Businesses', 'subMerchantKey', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await queryInterface.addColumn('Businesses', 'subMerchantType', {
      type: Sequelize.ENUM('PERSONAL', 'PRIVATE_COMPANY', 'LIMITED_OR_JOINT_STOCK_COMPANY'),
      allowNull: true,
    });
    await queryInterface.addColumn('Businesses', 'iban', {
      type: Sequelize.STRING(34),
      allowNull: true,
    });
    await queryInterface.addColumn('Businesses', 'legalCompanyTitle', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await queryInterface.addColumn('Businesses', 'taxOffice', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await queryInterface.addColumn('Businesses', 'taxNumber', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await queryInterface.addColumn('Businesses', 'identityNumber', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await queryInterface.addColumn('Businesses', 'contactName', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await queryInterface.addColumn('Businesses', 'contactSurname', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await queryInterface.addColumn('Businesses', 'gsmNumber', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await queryInterface.addColumn('Businesses', 'subMerchantStatus', {
      type: Sequelize.ENUM('none', 'active', 'error'),
      allowNull: false,
      defaultValue: 'none',
    });
    await queryInterface.addColumn('Businesses', 'subMerchantError', {
      type: Sequelize.STRING(500),
      allowNull: true,
    });
  },

  async down(queryInterface, Sequelize) {
    for (const col of [
      'subMerchantKey', 'subMerchantType', 'iban', 'legalCompanyTitle', 'taxOffice',
      'taxNumber', 'identityNumber', 'contactName', 'contactSurname', 'gsmNumber',
      'subMerchantStatus', 'subMerchantError',
    ]) {
      await queryInterface.removeColumn('Businesses', col);
    }
    await queryInterface.sequelize.query(`DROP TYPE IF EXISTS "enum_Businesses_subMerchantType";`);
    await queryInterface.sequelize.query(`DROP TYPE IF EXISTS "enum_Businesses_subMerchantStatus";`);
  },
};

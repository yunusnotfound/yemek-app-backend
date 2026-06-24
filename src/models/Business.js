const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Business = sequelize.define('Business', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  ownerId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'Users', key: 'id' },
  },
  categoryId: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'Categories', key: 'id' },
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  address: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  city: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  district: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  latitude: {
    type: DataTypes.FLOAT,
    allowNull: false,
  },
  longitude: {
    type: DataTypes.FLOAT,
    allowNull: false,
  },
  phone: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  imageUrl: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  rating: {
    type: DataTypes.FLOAT,
    defaultValue: 0,
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  isApproved: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  approvalStatus: {
    type: DataTypes.ENUM('pending', 'approved', 'rejected'),
    defaultValue: 'pending',
  },
  approvedAt: {
    type: DataTypes.DATE,
    allowNull: true,
  },
  rejectedAt: {
    type: DataTypes.DATE,
    allowNull: true,
  },

  // --- iyzico Pazaryeri (alt üye işyeri / sub-merchant) ---
  // createSubMerchant sonrası dönen anahtar; ödeme kırılımında bu işletmeyi tanımlar.
  subMerchantKey: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  subMerchantType: {
    type: DataTypes.ENUM('PERSONAL', 'PRIVATE_COMPANY', 'LIMITED_OR_JOINT_STOCK_COMPANY'),
    allowNull: true,
  },
  // KVKK: iban / identityNumber hassas veridir, loglanmaz.
  iban: {
    type: DataTypes.STRING(34),
    allowNull: true,
  },
  legalCompanyTitle: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  taxOffice: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  taxNumber: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  identityNumber: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  contactName: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  contactSurname: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  gsmNumber: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  subMerchantStatus: {
    type: DataTypes.ENUM('none', 'active', 'error'),
    defaultValue: 'none',
  },
  subMerchantError: {
    type: DataTypes.STRING(500),
    allowNull: true,
  },
}, {
  timestamps: true,
  paranoid: true,
});

module.exports = Business;

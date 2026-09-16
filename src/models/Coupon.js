const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Coupon = sequelize.define('Coupon', {
  title: { type: DataTypes.STRING(100), allowNull: true },
  firstOrderOnly: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
  perUserLimit: { type: DataTypes.INTEGER, allowNull: true },
  maxDiscountAmount: { type: DataTypes.DECIMAL(10, 2), allowNull: true },
  budgetLimit: { type: DataTypes.DECIMAL(12, 2), allowNull: true },
  isDiscoverable: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
  businessIds: { type: DataTypes.ARRAY(DataTypes.UUID), allowNull: false, defaultValue: [] },
  merchantConsentConfirmed: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  code: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
  },
  discountType: {
    type: DataTypes.ENUM('percentage', 'fixed'),
    allowNull: false,
  },
  discountValue: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
  },
  minOrderAmount: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0,
  },
  maxUsage: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 100,
  },
  currentUsage: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
  },
  expiresAt: {
    type: DataTypes.DATE,
    allowNull: false,
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
}, {
  timestamps: true,
});

module.exports = Coupon;

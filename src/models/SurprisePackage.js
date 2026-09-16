const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const SurprisePackage = sequelize.define('SurprisePackage', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  businessId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'Businesses', key: 'id' },
  },
  title: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  originalPrice: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
  },
  discountedPrice: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
  },
  quantity: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 1,
  },
  remainingQuantity: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 1,
  },
  pickupStart: {
    type: DataTypes.TIME,
    allowNull: false,
  },
  pickupEnd: {
    type: DataTypes.TIME,
    allowNull: false,
  },
  pickupDate: {
    type: DataTypes.DATEONLY,
    allowNull: false,
  },
  imageUrl: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  isSuspended: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  isRecurring: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  recurringDays: {
    type: DataTypes.ARRAY(DataTypes.INTEGER),
    allowNull: true,
  },
}, {
  timestamps: true,
  paranoid: true,
});

module.exports = SurprisePackage;

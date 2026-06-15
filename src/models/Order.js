const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Order = sequelize.define('Order', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  userId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'Users', key: 'id' },
  },
  packageId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'SurprisePackages', key: 'id' },
  },
  couponId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: { model: 'Coupons', key: 'id' },
  },
  quantity: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 1,
  },
  totalPrice: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
  },
  discountAmount: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0,
  },
  finalPrice: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
  },
  status: {
    type: DataTypes.ENUM('pending', 'confirmed', 'picked_up', 'cancelled'),
    defaultValue: 'pending',
  },
  pickupCode: {
    type: DataTypes.STRING(6),
    allowNull: false,
  },
}, {
  timestamps: true,
  paranoid: true,
});

module.exports = Order;

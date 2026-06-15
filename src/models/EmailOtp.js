const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

// Short-lived email login codes (OTP). Only the SHA-256 hash of the code is
// stored; the raw 6-digit code is emailed to the user and never persisted.
const EmailOtp = sequelize.define('EmailOtp', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  email: {
    type: DataTypes.STRING,
    allowNull: false,
    validate: { isEmail: true },
  },
  codeHash: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  expiresAt: {
    type: DataTypes.DATE,
    allowNull: false,
  },
  attempts: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },
}, {
  timestamps: true,
  indexes: [{ fields: ['email'] }],
});

module.exports = EmailOtp;

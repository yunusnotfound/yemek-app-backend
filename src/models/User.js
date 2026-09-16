const { DataTypes } = require('sequelize');
const passwordService = require('../services/passwordService');
const sequelize = require('../config/database');

const User = sequelize.define('User', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  email: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
    validate: { isEmail: true },
  },
  password: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  phone: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  role: {
    type: DataTypes.ENUM('customer', 'business_owner', 'admin'),
    defaultValue: 'customer',
  },
  latitude: {
    type: DataTypes.FLOAT,
    allowNull: true,
  },
  longitude: {
    type: DataTypes.FLOAT,
    allowNull: true,
  },
  isEmailVerified: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  emailVerificationToken: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  passwordResetToken: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  passwordResetExpires: {
    type: DataTypes.DATE,
    allowNull: true,
  },
  passwordResetAttempts: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 },
  authVersion: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 },
  emailVerificationExpires: {
    type: DataTypes.DATE,
    allowNull: true,
  },
  googleId: {
    type: DataTypes.STRING,
    allowNull: true,
    unique: true,
  },
  appleId: {
    type: DataTypes.STRING,
    allowNull: true,
    unique: true,
  },
  // iyzico kart cüzdanı anahtarı — yalnız sunucu tarafı, client'a asla dönmez.
  cardUserKey: {
    type: DataTypes.STRING,
    allowNull: true,
  },
}, {
  timestamps: true,
  paranoid: true,
  hooks: {
    beforeCreate: async (user) => {
      if (user.password) {
        user.password = await passwordService.hash(user.password);
      }
    },
    beforeUpdate: async (user) => {
      if (user.changed('password') && user.password) {
        user.password = await passwordService.hash(user.password);
      }
    },
  },
});

User.prototype.comparePassword = async function (candidatePassword) {
  return this.password ? passwordService.compare(candidatePassword, this.password) : false;
};

User.prototype.toJSON = function () {
  const values = { ...this.get() };
  delete values.password;
  delete values.googleId;
  delete values.appleId;
  delete values.emailVerificationToken;
  delete values.emailVerificationExpires;
  delete values.passwordResetToken;
  delete values.passwordResetExpires;
  delete values.cardUserKey;
  delete values.authVersion;
  delete values.passwordResetAttempts;
  return values;
};

module.exports = User;

const sequelize = require('../config/database');
const User = require('./User');
const Category = require('./Category');
const Business = require('./Business');
const SurprisePackage = require('./SurprisePackage');
const Order = require('./Order');
const Review = require('./Review');
const Favorite = require('./Favorite');
const Notification = require('./Notification');
const Coupon = require('./Coupon');
const BusinessHours = require('./BusinessHours');
const EmailOtp = require('./EmailOtp');

// User <-> Business
User.hasMany(Business, { foreignKey: 'ownerId', as: 'businesses' });
Business.belongsTo(User, { foreignKey: 'ownerId', as: 'owner' });

// Category <-> Business
Category.hasMany(Business, { foreignKey: 'categoryId', as: 'businesses' });
Business.belongsTo(Category, { foreignKey: 'categoryId', as: 'category' });

// Business <-> SurprisePackage
Business.hasMany(SurprisePackage, { foreignKey: 'businessId', as: 'packages' });
SurprisePackage.belongsTo(Business, { foreignKey: 'businessId', as: 'business' });

// User <-> Order
User.hasMany(Order, { foreignKey: 'userId', as: 'orders' });
Order.belongsTo(User, { foreignKey: 'userId', as: 'user' });

// SurprisePackage <-> Order
SurprisePackage.hasMany(Order, { foreignKey: 'packageId', as: 'orders' });
Order.belongsTo(SurprisePackage, { foreignKey: 'packageId', as: 'package' });

// Coupon <-> Order
Coupon.hasMany(Order, { foreignKey: 'couponId', as: 'orders' });
Order.belongsTo(Coupon, { foreignKey: 'couponId', as: 'coupon' });

// User <-> Review
User.hasMany(Review, { foreignKey: 'userId', as: 'reviews' });
Review.belongsTo(User, { foreignKey: 'userId', as: 'user' });

// Business <-> Review
Business.hasMany(Review, { foreignKey: 'businessId', as: 'reviews' });
Review.belongsTo(Business, { foreignKey: 'businessId', as: 'business' });

// Order <-> Review (1-1)
Order.hasOne(Review, { foreignKey: 'orderId', as: 'review' });
Review.belongsTo(Order, { foreignKey: 'orderId', as: 'order' });

// User <-> Favorite <-> Business
User.hasMany(Favorite, { foreignKey: 'userId', as: 'favorites' });
Favorite.belongsTo(User, { foreignKey: 'userId', as: 'user' });
Business.hasMany(Favorite, { foreignKey: 'businessId', as: 'favorites' });
Favorite.belongsTo(Business, { foreignKey: 'businessId', as: 'business' });

// User <-> Notification
User.hasMany(Notification, { foreignKey: 'userId', as: 'notifications' });
Notification.belongsTo(User, { foreignKey: 'userId', as: 'user' });

// Business <-> BusinessHours
Business.hasMany(BusinessHours, { foreignKey: 'businessId', as: 'workingHours' });
BusinessHours.belongsTo(Business, { foreignKey: 'businessId', as: 'business' });

module.exports = {
  sequelize,
  User,
  Category,
  Business,
  SurprisePackage,
  Order,
  Review,
  Favorite,
  Notification,
  Coupon,
  BusinessHours,
  EmailOtp,
};

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
  // 'awaiting_payment' = ödeme bekleyen (stok hold edildi, henüz ödenmedi). Bu durumdaki
  // siparişler işletmeye GÖSTERİLMEZ; yalnız ödeme başarılı olunca 'pending'e geçer.
  status: {
    type: DataTypes.ENUM('awaiting_payment', 'pending', 'confirmed', 'picked_up', 'cancelled'),
    defaultValue: 'pending',
  },
  pickupCode: {
    type: DataTypes.STRING(6),
    allowNull: false,
  },

  // --- Ödeme (iyzico) ---
  // unpaid = ücretsiz/eski sipariş (ödeme gerekmedi); pending = checkout başlatıldı, callback bekleniyor.
  paymentStatus: {
    type: DataTypes.ENUM('unpaid', 'pending', 'paid', 'failed', 'refunded', 'partially_refunded'),
    defaultValue: 'unpaid',
  },
  paymentProvider: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  // iyzico'ya gönderdiğimiz idempotency anahtarı (= order.id). retrieve/finalize bununla eşlenir.
  conversationId: {
    type: DataTypes.STRING(64),
    allowNull: true,
  },
  // CheckoutFormInitialize'dan dönen token (retrieve için).
  paymentToken: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  // iyzico paymentId (cancel/refund için).
  paymentId: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  // Pazaryeri kırılımı: satıcının (alt üye işyeri) ödeme transaction id'si (approval için).
  paymentTransactionId: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  // Bu siparişte kullanılan alt üye işyeri anahtarı (snapshot).
  subMerchantKey: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  // Satıcıya ayrılan tutar (= finalPrice * (1 - komisyon)).
  subMerchantPrice: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: true,
  },
  // Platform komisyonu (= finalPrice - subMerchantPrice).
  commissionAmount: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0,
  },
  // iyzico fon durumu: none(ödeme yok) -> held(havuzda) -> approved(serbest) | disapproved | refunded.
  settlementStatus: {
    type: DataTypes.ENUM('none', 'held', 'approved', 'disapproved', 'refunded'),
    defaultValue: 'none',
  },
  // iyzico'nun gerçekten tahsil ettiği tutar (doğrulama için).
  paidPrice: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: true,
  },
  refundAmount: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0,
  },
  paidAt: {
    type: DataTypes.DATE,
    allowNull: true,
  },
  // Stok hold'unun son geçerlilik anı; reaper bunu kullanır.
  paymentHoldExpiresAt: {
    type: DataTypes.DATE,
    allowNull: true,
  },
  paymentError: {
    type: DataTypes.STRING(500),
    allowNull: true,
  },
}, {
  timestamps: true,
  paranoid: true,
});

module.exports = Order;

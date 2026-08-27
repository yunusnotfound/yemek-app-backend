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

/**
 * Müşteri/public uçlarda döndürülmesi GÜVENLİ olan alanlar.
 *
 * Bu model iyzico Pazaryeri için iban, identityNumber (TC kimlik), gsmNumber,
 * contactName/contactSurname, subMerchantKey, taxNumber gibi alanlar tutuyor.
 * Bunlar YALNIZCA işletme sahibinin kendi paneline ve admin'e aittir.
 * Public/müşteri sorgularında `attributes: Business.PUBLIC_ATTRIBUTES` kullanın —
 * filtresiz bir findAll/findByPk tüm satırı JSON'a çevirip dışarı sızdırır.
 *
 * Yeni bir hassas kolon eklenince buraya EKLEMEYİN; liste allowlist mantığıyla
 * çalışır, eklenmeyen alan dışarı çıkmaz.
 */
Business.PUBLIC_ATTRIBUTES = [
  'id', 'name', 'description', 'address', 'city', 'district',
  'latitude', 'longitude', 'phone', 'imageUrl', 'rating',
  'isActive', 'isApproved', 'approvalStatus', 'categoryId',
  'createdAt', 'updatedAt',
];

/**
 * Yalnızca işletme sahibine ve admin'e ait, dışarı çıkmaması gereken alanlar.
 * Aşağıdaki `toJSON` bunları serileştirmeden düşürür.
 */
Business.SENSITIVE_FIELDS = [
  'iban',
  'identityNumber',
  'taxNumber',
  'taxOffice',
  'legalCompanyTitle',
  'gsmNumber',
  'contactName',
  'contactSurname',
  'subMerchantKey',
  'subMerchantType',
  'subMerchantError',
];

/**
 * Varsayılan JSON serileştirmesinden hassas alanları düşürür.
 *
 * NEDEN: `PUBLIC_ATTRIBUTES` whitelist'i her sorguda ELLE yazılmak zorunda,
 * yani unutulmaya açık — nitekim beş ayrı uçtan sızdı. `User` modeli hiç
 * sızmadı çünkü korumasi tam olarak burada, modelin içinde
 * (bkz. User.prototype.toJSON). Aynı simetriyi Business'a getiriyoruz:
 * bir sorguda whitelist unutulsa bile satır JSON'a çevrilirken temizlenir.
 *
 * ÖNEMLİ: Bu yalnızca JSON'a çevirmeyi etkiler, ÖZELLİK ERİŞİMİNİ DEĞİL.
 * `business.iban` gibi doğrudan okumalar çalışmaya devam eder — iyzico
 * sub-merchant akışı (services/iyzicoService.js) ve işletme paneli
 * güncellemeleri bu şekilde okuduğu için etkilenmez.
 *
 * Sahibin/admin'in kendi hassas verisini görmesi gereken yerlerde
 * [toOwnerJSON] kullanın.
 */
Business.prototype.toJSON = function () {
  const values = { ...this.get() };
  for (const field of Business.SENSITIVE_FIELDS) {
    delete values[field];
  }
  return values;
};

/**
 * Hassas alanlar DAHİL tam kayıt.
 *
 * Yalnızca işletme sahibinin kendi kaydını ya da admin'in yönetim ekranını
 * beslerken kullanılır. İsmi bilerek açıktır: kazara çağrılmasın, çağrıldığında
 * kod incelemesinde göze çarpsın.
 */
Business.prototype.toOwnerJSON = function () {
  return this.get({ plain: true });
};

module.exports = Business;

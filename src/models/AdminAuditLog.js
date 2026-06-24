const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

// Append-only admin işlem denetim kaydı (kim, neyi, ne zaman). Yalnız createdAt.
const AdminAuditLog = sequelize.define('AdminAuditLog', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  adminId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'Users', key: 'id' },
  },
  // örn: 'user.role_change', 'business.approve', 'order.refund', 'category.delete'
  action: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  // 'user' | 'business' | 'order' | 'category' | 'coupon' | 'package' | 'review'
  targetType: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  targetId: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  // before/after, reason, amount... — hassas anahtarlar auditService.sanitize ile maskelenir.
  metadata: {
    type: DataTypes.JSONB,
    allowNull: true,
  },
  ip: {
    type: DataTypes.STRING,
    allowNull: true,
  },
}, {
  timestamps: true,
  updatedAt: false,
});

module.exports = AdminAuditLog;

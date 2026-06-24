'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('AdminAuditLogs', {
      id: {
        type: Sequelize.UUID,
        defaultValue: Sequelize.UUIDV4,
        primaryKey: true,
      },
      adminId: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'Users', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      action: { type: Sequelize.STRING, allowNull: false },
      targetType: { type: Sequelize.STRING, allowNull: true },
      targetId: { type: Sequelize.STRING, allowNull: true },
      metadata: { type: Sequelize.JSONB, allowNull: true },
      ip: { type: Sequelize.STRING, allowNull: true },
      createdAt: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.fn('now') },
    });

    await queryInterface.addIndex('AdminAuditLogs', ['adminId'], { name: 'idx_audit_adminId' });
    await queryInterface.addIndex('AdminAuditLogs', ['action'], { name: 'idx_audit_action' });
    await queryInterface.addIndex('AdminAuditLogs', ['createdAt'], { name: 'idx_audit_createdAt' });
    await queryInterface.addIndex('AdminAuditLogs', ['targetType', 'targetId'], { name: 'idx_audit_target' });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('AdminAuditLogs');
  },
};

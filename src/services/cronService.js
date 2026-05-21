const cron = require('node-cron');
const { Notification, SurprisePackage } = require('../models');
const { Op } = require('sequelize');
const logger = require('./logger');

// Runs daily at 3 AM — deletes read notifications older than 30 days
const startNotificationCleanupJob = () => {
  cron.schedule('0 3 * * *', async () => {
    try {
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const deletedCount = await Notification.destroy({
        where: {
          isRead: true,
          createdAt: { [Op.lt]: thirtyDaysAgo },
        },
      });

      logger.info(`${deletedCount} eski bildirim silindi`);
    } catch (error) {
      logger.error('Bildirim temizleme hatası:', error);
    }
  });

  logger.info('Bildirim temizleme jobu başlatıldı');
};

// Runs daily at midnight — creates today's instances from recurring package templates
const startRecurringPackagesJob = () => {
  cron.schedule('0 0 * * *', async () => {
    try {
      const today = new Date();
      const todayStr = today.toISOString().split('T')[0];
      const dayOfWeek = today.getDay(); // 0=Sunday ... 6=Saturday

      const recurringPackages = await SurprisePackage.findAll({
        where: {
          isRecurring: true,
          isActive: true,
          recurringDays: { [Op.contains]: [dayOfWeek] },
        },
      });

      let created = 0;
      for (const template of recurringPackages) {
        const existing = await SurprisePackage.findOne({
          where: {
            businessId: template.businessId,
            title: template.title,
            pickupDate: todayStr,
            isRecurring: false,
          },
        });

        if (!existing) {
          await SurprisePackage.create({
            businessId: template.businessId,
            title: template.title,
            description: template.description,
            originalPrice: template.originalPrice,
            discountedPrice: template.discountedPrice,
            quantity: template.quantity,
            remainingQuantity: template.quantity,
            pickupStart: template.pickupStart,
            pickupEnd: template.pickupEnd,
            pickupDate: todayStr,
            imageUrl: template.imageUrl,
            isActive: true,
            isRecurring: false,
          });
          created++;
        }
      }

      if (created > 0) {
        logger.info(`${created} tekrarlayan paket bugün için oluşturuldu`);
      }
    } catch (error) {
      logger.error('Tekrarlayan paket oluşturma hatası:', error);
    }
  });

  logger.info('Tekrarlayan paket jobu başlatıldı');
};

module.exports = { startNotificationCleanupJob, startRecurringPackagesJob };

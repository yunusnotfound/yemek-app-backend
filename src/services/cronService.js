const cron = require('node-cron');
const { Notification, SurprisePackage, Order } = require('../models');
const { Op } = require('sequelize');
const logger = require('./logger');
const iyzicoService = require('./iyzicoService');
const paymentFinalizeService = require('./paymentFinalizeService');
const settlementService = require('./settlementService');

// Single backend instance (one VPS) — these cron jobs run exactly once per
// schedule, so no distributed lock is needed.
const TIMEZONE = 'Europe/Istanbul';

// Returns the current local (Europe/Istanbul) date as a YYYY-MM-DD string and
// the local day-of-week (0=Sunday..6=Saturday), independent of the server's
// process timezone (which may be UTC).
const getIstanbulDateParts = () => {
  const now = new Date();
  // en-CA gives ISO-style YYYY-MM-DD; force the Istanbul zone for the local date.
  const dateStr = now.toLocaleDateString('en-CA', { timeZone: TIMEZONE });
  const weekdayName = now.toLocaleDateString('en-US', { timeZone: TIMEZONE, weekday: 'short' });
  const dayMap = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };
  return { dateStr, dayOfWeek: dayMap[weekdayName] };
};

// Runs daily at 3 AM (Europe/Istanbul) — deletes read notifications older than 30 days
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
  }, { timezone: TIMEZONE });

  logger.info('Bildirim temizleme jobu başlatıldı');
};

// Runs daily at midnight (Europe/Istanbul) — creates today's instances from recurring package templates
const startRecurringPackagesJob = () => {
  cron.schedule('0 0 * * *', async () => {
    try {
      // Use Istanbul local date so "today" matches Turkey, not UTC.
      const { dateStr: todayStr, dayOfWeek } = getIstanbulDateParts(); // dayOfWeek: 0=Sunday..6=Saturday

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
  }, { timezone: TIMEZONE });

  logger.info('Tekrarlayan paket jobu başlatıldı');
};

// Her 2 dakikada bir — süresi dolan ödenmemiş hold'ları temizle.
// Serbest bırakmadan ÖNCE iyzico'dan kontrol et (kayıp callback yedeği): ödenmişse finalize et.
const startPaymentReaperJob = () => {
  cron.schedule('*/2 * * * *', async () => {
    try {
      if (!iyzicoService.isConfigured()) return;

      const expired = await Order.findAll({
        where: {
          status: 'awaiting_payment',
          paymentHoldExpiresAt: { [Op.lt]: new Date() },
        },
        limit: 100,
        order: [['paymentHoldExpiresAt', 'ASC']],
      });

      let released = 0;
      let recovered = 0;
      for (const order of expired) {
        try {
          // Kayıp callback yedeği: iyzico'da gerçekten ödenmiş mi?
          if (order.paymentToken) {
            const r = await paymentFinalizeService.finalize({
              token: order.paymentToken,
              conversationId: order.conversationId,
              source: 'reaper',
              ip: '0.0.0.0',
            });
            if (r.outcome === 'paid' || r.outcome === 'already_paid') {
              recovered++;
              continue;
            }
          } else if (order.paymentProvider === 'iyzico') {
            // 3DS siparişi (token yok) -> payment.retrieve ile kontrol.
            // SUCCESS değilse (3DS yarıda bırakıldı / reddedildi) aşağıda hold serbest bırakılır.
            const result = await iyzicoService.retrievePayment({ conversationId: order.conversationId }).catch(() => null);
            if (result?.status === 'success') {
              const r = await paymentFinalizeService.finalize({
                retrieveResult: result,
                conversationId: order.conversationId,
                source: 'reaper',
                ip: '0.0.0.0',
              });
              if (r.outcome === 'paid' || r.outcome === 'already_paid') {
                recovered++;
                continue;
              }
            }
          }
          // Ödenmemiş -> hold'u serbest bırak (sonradan ödeme gelirse finalize otomatik iade eder).
          const ok = await paymentFinalizeService.expireUnpaidHold(order.id);
          if (ok) released++;
        } catch (e) {
          logger.error(`[reaper] sipariş ${order.id} işlenemedi: ${e.message}`);
        }
      }

      if (released || recovered) {
        logger.info(`[reaper] ${released} hold serbest bırakıldı, ${recovered} kurtarıldı`);
      }
    } catch (error) {
      logger.error('Ödeme reaper hatası:', error);
    }
  }, { timezone: TIMEZONE });

  logger.info('Ödeme reaper jobu başlatıldı');
};

// Her 15 dakikada bir — teslim edilmiş ama onaylanamamış (held) satıcı fonlarını tekrar onayla.
const startApprovalRetryJob = () => {
  cron.schedule('*/15 * * * *', async () => {
    try {
      if (!iyzicoService.isConfigured()) return;
      await settlementService.retryHeldApprovals();
    } catch (error) {
      logger.error('Approval retry hatası:', error);
    }
  }, { timezone: TIMEZONE });

  logger.info('Approval retry jobu başlatıldı');
};

module.exports = {
  startNotificationCleanupJob,
  startRecurringPackagesJob,
  startPaymentReaperJob,
  startApprovalRetryJob,
};

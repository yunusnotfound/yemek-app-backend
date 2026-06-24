const router = require('express').Router();
const businessDashboardController = require('../controllers/businessDashboardController');
const { authenticate } = require('../middlewares/auth');
const { authorize } = require('../middlewares/role');
const { validateQuery, validateParams, validate } = require('../middlewares/validate');
const { paginationSchema, businessIdParamSchema, subMerchantSchema } = require('../validations/schemas');
const { z } = require('zod');

/**
 * @swagger
 * tags:
 *   name: Business Dashboard
 *   description: İşletme sahibi paneli işlemleri
 */

// Tüm route'lar için auth ve business_owner rolü gerekli
router.use(authenticate, authorize('business_owner', 'admin'));

/**
 * @swagger
 * /business-dashboard/my-businesses:
 *   get:
 *     summary: Benim işletmelerim
 *     tags: [Business Dashboard]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: İşletme listesi
 *       403:
 *         description: Yetkisiz işlem
 */
router.get('/my-businesses', businessDashboardController.getMyBusinesses);

/**
 * @swagger
 * /business-dashboard/{businessId}/dashboard:
 *   get:
 *     summary: İşletme dashboard istatistikleri
 *     tags: [Business Dashboard]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: businessId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Dashboard istatistikleri
 *       403:
 *         description: Yetkisiz işlem
 *       404:
 *         description: İşletme bulunamadı
 */
router.get('/:businessId/dashboard', validateParams(businessIdParamSchema), businessDashboardController.getDashboardStats);

/**
 * @swagger
 * /business-dashboard/{businessId}/orders:
 *   get:
 *     summary: İşletme siparişleri
 *     tags: [Business Dashboard]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: businessId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [pending, confirmed, picked_up, cancelled]
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Sipariş listesi
 *       403:
 *         description: Yetkisiz işlem
 */
router.get('/:businessId/orders', validateParams(businessIdParamSchema), validateQuery(paginationSchema), businessDashboardController.getBusinessOrders);

/**
 * @swagger
 * /business-dashboard/{businessId}/packages:
 *   get:
 *     summary: İşletme paketleri
 *     tags: [Business Dashboard]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: businessId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Paket listesi
 *       403:
 *         description: Yetkisiz işlem
 */
router.get('/:businessId/packages', validateParams(businessIdParamSchema), validateQuery(paginationSchema), businessDashboardController.getBusinessPackages);

/**
 * @swagger
 * /business-dashboard/{businessId}/reviews:
 *   get:
 *     summary: İşletme değerlendirmeleri
 *     tags: [Business Dashboard]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: businessId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Değerlendirme listesi
 *       403:
 *         description: Yetkisiz işlem
 */
router.get('/:businessId/reviews', validateParams(businessIdParamSchema), validateQuery(paginationSchema), businessDashboardController.getBusinessReviews);

// QR Kod ile sipariş doğrulama
const verifyOrderSchema = z.object({
  pickupCode: z.string().min(4, 'Teslim alma kodu gerekli'),
});

/**
 * @swagger
 * /business-dashboard/{businessId}/verify-order:
 *   post:
 *     summary: QR Kod ile sipariş doğrula
 *     tags: [Business Dashboard]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: businessId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - pickupCode
 *             properties:
 *               pickupCode:
 *                 type: string
 *                 example: "1234"
 *     responses:
 *       200:
 *         description: Sipariş doğrulandı
 *       403:
 *         description: Yetkisiz işlem
 *       404:
 *         description: Sipariş bulunamadı
 */
router.post('/:businessId/verify-order', validateParams(businessIdParamSchema), validate(verifyOrderSchema), businessDashboardController.verifyOrderByPickupCode);

/**
 * @swagger
 * /business-dashboard/{businessId}/submerchant:
 *   post:
 *     summary: iyzico alt üye işyeri (ödeme hesabı) oluştur/güncelle
 *     tags: [Business Dashboard]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: businessId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Ödeme hesabı kaydedildi
 *       400:
 *         description: Doğrulama / iyzico hatası
 */
router.post('/:businessId/submerchant', validateParams(businessIdParamSchema), validate(subMerchantSchema), businessDashboardController.upsertSubMerchant);

/**
 * @swagger
 * /business-dashboard/{businessId}/earnings:
 *   get:
 *     summary: İşletme kazanç özeti (satış, komisyon, net, onay durumu)
 *     tags: [Business Dashboard]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: businessId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Kazanç özeti
 */
router.get('/:businessId/earnings', validateParams(businessIdParamSchema), businessDashboardController.getEarnings);

module.exports = router;

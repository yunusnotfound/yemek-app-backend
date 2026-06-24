const router = require('express').Router();
const adminController = require('../controllers/adminController');
const categoryController = require('../controllers/categoryController');
const { authenticate } = require('../middlewares/auth');
const { authorize } = require('../middlewares/role');
const { validate, validateQuery, validateParams } = require('../middlewares/validate');
const {
  paginationSchema, idParamSchema, intIdParamSchema,
  categoryCreateSchema, categoryUpdateSchema, adminUserUpdateSchema,
  businessActiveSchema, packageActiveSchema, adminOrderRefundSchema,
  adminUserQuerySchema, adminBusinessQuerySchema, adminOrderQuerySchema,
  adminPackageQuerySchema, adminReviewQuerySchema, subMerchantQuerySchema, auditQuerySchema,
} = require('../validations/schemas');

/**
 * @swagger
 * tags:
 *   name: Admin
 *   description: Admin işlemleri
 */

// All routes require admin role
router.use(authenticate, authorize('admin'));

/**
 * @swagger
 * /admin/dashboard:
 *   get:
 *     summary: Admin dashboard istatistikleri
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Dashboard verileri
 *       403:
 *         description: Yetkisiz işlem
 */
router.get('/dashboard', adminController.getDashboardStats);

/**
 * @swagger
 * /admin/users:
 *   get:
 *     summary: Tüm kullanıcıları listele
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
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
 *         description: Kullanıcı listesi
 *       403:
 *         description: Yetkisiz işlem
 */
router.get('/users', validateQuery(adminUserQuerySchema), adminController.getAllUsers);

/**
 * @swagger
 * /admin/users/{id}:
 *   get:
 *     summary: Kullanıcı detayı getir
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Kullanıcı detayı
 *       403:
 *         description: Yetkisiz işlem
 *       404:
 *         description: Kullanıcı bulunamadı
 */
router.get('/users/:id', validateParams(idParamSchema), adminController.getUserById);

/**
 * @swagger
 * /admin/users/{id}:
 *   put:
 *     summary: Kullanıcı güncelle
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
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
 *             properties:
 *               name:
 *                 type: string
 *               role:
 *                 type: string
 *                 enum: [customer, business_owner, admin]
 *               isEmailVerified:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Kullanıcı güncellendi
 *       403:
 *         description: Yetkisiz işlem
 *       404:
 *         description: Kullanıcı bulunamadı
 */
router.put('/users/:id', validateParams(idParamSchema), validate(adminUserUpdateSchema), adminController.updateUser);

/**
 * @swagger
 * /admin/users/{id}:
 *   delete:
 *     summary: Kullanıcı sil
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Kullanıcı silindi
 *       403:
 *         description: Yetkisiz işlem
 *       404:
 *         description: Kullanıcı bulunamadı
 */
router.delete('/users/:id', validateParams(idParamSchema), adminController.deleteUser);

/**
 * @swagger
 * /admin/businesses/pending:
 *   get:
 *     summary: Onay bekleyen işletmeleri listele
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
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
 *         description: Onay bekleyen işletme listesi
 *       403:
 *         description: Yetkisiz işlem
 */
router.get('/businesses/pending', validateQuery(paginationSchema), adminController.getPendingBusinesses);

/**
 * @swagger
 * /admin/businesses/{id}/approve:
 *   patch:
 *     summary: İşletme onayla
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: İşletme onaylandı
 *       403:
 *         description: Yetkisiz işlem
 *       404:
 *         description: İşletme bulunamadı
 */
router.patch('/businesses/:id/approve', validateParams(idParamSchema), adminController.approveBusiness);

/**
 * @swagger
 * /admin/businesses/{id}/reject:
 *   patch:
 *     summary: İşletme reddet
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: İşletme reddedildi
 *       403:
 *         description: Yetkisiz işlem
 *       404:
 *         description: İşletme bulunamadı
 */
router.patch('/businesses/:id/reject', validateParams(idParamSchema), adminController.rejectBusiness);

/**
 * @swagger
 * /admin/orders:
 *   get:
 *     summary: Tüm siparişleri listele
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
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
router.get('/orders', validateQuery(adminOrderQuerySchema), adminController.getAllOrders);
router.get('/orders/:id', validateParams(idParamSchema), adminController.getOrderById);
router.post('/orders/:id/refund', validateParams(idParamSchema), validate(adminOrderRefundSchema), adminController.refundOrder);

// ── Kategoriler (CRUD) ──────────────────────────────────────────────────────
router.post('/categories', validate(categoryCreateSchema), categoryController.create);
router.put('/categories/:id', validateParams(intIdParamSchema), validate(categoryUpdateSchema), categoryController.update);
router.delete('/categories/:id', validateParams(intIdParamSchema), categoryController.remove);

// ── İşletmeler (tümü / detay / aktiflik) ────────────────────────────────────
router.get('/businesses', validateQuery(adminBusinessQuerySchema), adminController.getAllBusinesses);
router.get('/businesses/:id', validateParams(idParamSchema), adminController.getBusinessById);
router.patch('/businesses/:id/active', validateParams(idParamSchema), validate(businessActiveSchema), adminController.setBusinessActive);

// ── Paketler (moderasyon) ───────────────────────────────────────────────────
router.get('/packages', validateQuery(adminPackageQuerySchema), adminController.getAllPackages);
router.patch('/packages/:id/active', validateParams(idParamSchema), validate(packageActiveSchema), adminController.setPackageActive);

// ── Değerlendirmeler (moderasyon) ───────────────────────────────────────────
router.get('/reviews', validateQuery(adminReviewQuerySchema), adminController.getAllReviews);
router.delete('/reviews/:id', validateParams(idParamSchema), adminController.deleteReview);

// ── Ödeme / Mutabakat gözetimi ──────────────────────────────────────────────
router.get('/settlement/summary', adminController.getSettlementSummary);
router.get('/sub-merchants', validateQuery(subMerchantQuerySchema), adminController.getSubMerchants);

// ── Denetim kaydı ───────────────────────────────────────────────────────────
router.get('/audit-log', validateQuery(auditQuerySchema), adminController.getAuditLog);

module.exports = router;

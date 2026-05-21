const router = require('express').Router();
const couponController = require('../controllers/couponController');
const { authenticate } = require('../middlewares/auth');
const { authorize } = require('../middlewares/role');
const { validate, validateQuery, validateParams } = require('../middlewares/validate');
const { paginationSchema, idParamSchema } = require('../validations/schemas');
const { z } = require('zod');

const validateCouponSchema = z.object({
  code: z.string().min(1, 'Kupon kodu gerekli'),
  orderAmount: z.number().optional(),
});

const createCouponSchema = z.object({
  code: z.string().min(1, 'Kupon kodu gerekli'),
  discountType: z.enum(['percentage', 'fixed']),
  discountValue: z.number().min(0),
  minOrderAmount: z.number().min(0).optional(),
  maxUsage: z.number().int().min(1).optional(),
  expiresAt: z.string().datetime(),
});

/**
 * @swagger
 * tags:
 *   name: Coupons
 *   description: Kupon işlemleri
 */

/**
 * @swagger
 * /coupons/validate:
 *   post:
 *     summary: Kupon doğrula
 *     tags: [Coupons]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - code
 *             properties:
 *               code:
 *                 type: string
 *                 example: "INDIRIM20"
 *               orderAmount:
 *                 type: number
 *                 example: 150.00
 *     responses:
 *       200:
 *         description: Kupon geçerli
 *       404:
 *         description: Geçersiz kupon
 */
router.post('/validate', authenticate, validate(validateCouponSchema), couponController.validate);

/**
 * @swagger
 * /coupons:
 *   get:
 *     summary: Tüm kuponları listele (Admin)
 *     tags: [Coupons]
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
 *       - in: query
 *         name: active
 *         schema:
 *           type: string
 *           enum: ['true', 'false']
 *     responses:
 *       200:
 *         description: Kupon listesi
 *       403:
 *         description: Yetkisiz işlem
 */
router.get('/', authenticate, authorize('admin'), validateQuery(paginationSchema), couponController.getAll);

/**
 * @swagger
 * /coupons/{id}:
 *   get:
 *     summary: Kupon detayı getir (Admin)
 *     tags: [Coupons]
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
 *         description: Kupon detayı
 *       403:
 *         description: Yetkisiz işlem
 *       404:
 *         description: Kupon bulunamadı
 */
router.get('/:id', authenticate, authorize('admin'), validateParams(idParamSchema), couponController.getById);

/**
 * @swagger
 * /coupons:
 *   post:
 *     summary: Yeni kupon oluştur (Admin)
 *     tags: [Coupons]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - code
 *               - discountType
 *               - discountValue
 *               - expiresAt
 *             properties:
 *               code:
 *                 type: string
 *                 example: "INDIRIM20"
 *               discountType:
 *                 type: string
 *                 enum: [percentage, fixed]
 *               discountValue:
 *                 type: number
 *                 example: 20
 *               minOrderAmount:
 *                 type: number
 *                 example: 100
 *               maxUsage:
 *                 type: integer
 *                 example: 100
 *               expiresAt:
 *                 type: string
 *                 format: date-time
 *     responses:
 *       201:
 *         description: Kupon oluşturuldu
 *       403:
 *         description: Yetkisiz işlem
 *       409:
 *         description: Kupon kodu zaten kullanımda
 */
router.post('/', authenticate, authorize('admin'), validate(createCouponSchema), couponController.create);

/**
 * @swagger
 * /coupons/{id}:
 *   put:
 *     summary: Kupon güncelle (Admin)
 *     tags: [Coupons]
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
 *               discountType:
 *                 type: string
 *                 enum: [percentage, fixed]
 *               discountValue:
 *                 type: number
 *               isActive:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Kupon güncellendi
 *       403:
 *         description: Yetkisiz işlem
 *       404:
 *         description: Kupon bulunamadı
 */
router.put('/:id', authenticate, authorize('admin'), validateParams(idParamSchema), couponController.update);

/**
 * @swagger
 * /coupons/{id}:
 *   delete:
 *     summary: Kupon sil (Admin)
 *     tags: [Coupons]
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
 *         description: Kupon silindi
 *       403:
 *         description: Yetkisiz işlem
 *       404:
 *         description: Kupon bulunamadı
 */
router.delete('/:id', authenticate, authorize('admin'), validateParams(idParamSchema), couponController.remove);

module.exports = router;

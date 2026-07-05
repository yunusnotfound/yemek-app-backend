const router = require("express").Router();
const cardController = require("../controllers/cardController");
const { authenticate } = require("../middlewares/auth");
const { authorize } = require("../middlewares/role");
const { validate, validateParams } = require("../middlewares/validate");
const {
  cardCreateSchema,
  cardTokenParamSchema,
} = require("../validations/schemas");

/**
 * @swagger
 * tags:
 *   name: Cards
 *   description: Kayıtlı kart işlemleri (iyzico kart saklama — kart bilgisi sunucuda tutulmaz)
 */

/**
 * @swagger
 * /cards:
 *   get:
 *     summary: Kayıtlı kartlarımı listele
 *     tags: [Cards]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Maskeli kart listesi
 */
router.get("/", authenticate, cardController.list);

/**
 * @swagger
 * /cards:
 *   post:
 *     summary: Yeni kart kaydet
 *     tags: [Cards]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - cardHolderName
 *               - cardNumber
 *               - expireMonth
 *               - expireYear
 *             properties:
 *               cardHolderName:
 *                 type: string
 *               cardNumber:
 *                 type: string
 *               expireMonth:
 *                 type: string
 *                 example: "12"
 *               expireYear:
 *                 type: string
 *                 example: "2030"
 *               cardAlias:
 *                 type: string
 *     responses:
 *       201:
 *         description: Kart kaydedildi (maskeli görünüm)
 */
router.post(
  "/",
  authenticate,
  authorize("customer"),
  validate(cardCreateSchema),
  cardController.create,
);

/**
 * @swagger
 * /cards/{cardToken}:
 *   delete:
 *     summary: Kayıtlı kartı sil
 *     tags: [Cards]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: cardToken
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Kart silindi
 */
router.delete(
  "/:cardToken",
  authenticate,
  authorize("customer"),
  validateParams(cardTokenParamSchema),
  cardController.remove,
);

module.exports = router;

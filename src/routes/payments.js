const router = require('express').Router();
const paymentController = require('../controllers/paymentController');
const { authenticate } = require('../middlewares/auth');
const { validateParams } = require('../middlewares/validate');
const { conversationIdParamSchema } = require('../validations/schemas');

/**
 * @swagger
 * tags:
 *   name: Payments
 *   description: iyzico ödeme işlemleri
 */

// iyzico -> backend callback (auth yok; istek iyzico'dan gelir).
router.post('/iyzico/callback', paymentController.iyzicoCallback);

// iyzico webhook yedeği (imza app.js'te raw body ile doğrulanır).
router.post('/iyzico/webhook', paymentController.iyzicoWebhook);

// Webview landing sayfası.
router.get('/result', paymentController.paymentResult);

// Mobil ödeme durumu poll (auth + ownership).
router.get(
  '/:conversationId/status',
  authenticate,
  validateParams(conversationIdParamSchema),
  paymentController.getStatus
);

module.exports = router;

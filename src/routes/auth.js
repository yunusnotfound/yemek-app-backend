const router = require('express').Router();
const { z } = require('zod');
const authController = require('../controllers/authController');
const { validate, validateQuery } = require('../middlewares/validate');
const { registerSchema, loginSchema, forgotPasswordSchema, resetPasswordSchema } = require('../validations/schemas');

/**
 * @swagger
 * /auth/register:
 *   post:
 *     summary: Yeni kullanıcı kaydı
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *               - email
 *               - password
 *             properties:
 *               name:
 *                 type: string
 *                 example: "Ahmet Yılmaz"
 *               email:
 *                 type: string
 *                 format: email
 *                 example: "ahmet@example.com"
 *               password:
 *                 type: string
 *                 minLength: 6
 *                 example: "123456"
 *               phone:
 *                 type: string
 *                 example: "5551234567"
 *               role:
 *                 type: string
 *                 enum: [customer, business_owner]
 *                 example: "customer"
 *     responses:
 *       201:
 *         description: Kayıt başarılı
 *       409:
 *         description: E-posta zaten kayıtlı
 */
router.post('/register', validate(registerSchema), authController.register);

/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: Kullanıcı girişi
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: "ahmet@example.com"
 *               password:
 *                 type: string
 *                 example: "123456"
 *     responses:
 *       200:
 *         description: Giriş başarılı
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 accessToken:
 *                   type: string
 *                 refreshToken:
 *                   type: string
 *                 user:
 *                   type: object
 *       401:
 *         description: Geçersiz kimlik bilgileri
 */
router.post('/login', validate(loginSchema), authController.login);

/**
 * @swagger
 * /auth/refresh:
 *   post:
 *     summary: Access token yenileme
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - refreshToken
 *             properties:
 *               refreshToken:
 *                 type: string
 *                 example: "eyJhbGciOiJIUzI1NiIs..."
 *     responses:
 *       200:
 *         description: Token yenilendi
 *       401:
 *         description: Geçersiz refresh token
 */
router.post('/refresh', authController.refreshToken);

// Email verification
router.get('/verify-email', validateQuery(z.object({ token: z.string() })), authController.verifyEmail);
router.post('/resend-verification', authController.resendVerification);

// Password reset
router.post('/forgot-password', validate(forgotPasswordSchema), authController.forgotPassword);
router.post('/reset-password', validate(resetPasswordSchema), authController.resetPassword);

// Google Sign-In
router.post('/google', authController.googleLogin);

// Apple Sign-In
router.post('/apple', authController.appleLogin);

// Logout (revokes refresh token)
router.post('/logout', authController.logout);

module.exports = router;

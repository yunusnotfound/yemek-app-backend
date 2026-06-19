const router = require('express').Router();
const upload = require('../config/multer');
const { authenticate } = require('../middlewares/auth');
const { authorize } = require('../middlewares/role');

/**
 * @swagger
 * tags:
 *   name: Upload
 *   description: Görsel yükleme
 */

/**
 * @swagger
 * /upload:
 *   post:
 *     summary: Görsel yükle (işletme/paket)
 *     tags: [Upload]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *     responses:
 *       201:
 *         description: Yüklenen görselin mutlak URL'i ({ url })
 *       400:
 *         description: Geçersiz dosya
 *       401:
 *         description: Yetkilendirme hatası
 */
router.post('/', authenticate, authorize('business_owner', 'admin'), (req, res) => {
  upload.single('file')(req, res, (err) => {
    if (err) {
      // Multer (boyut) ve fileFilter (format) hataları — 400 olarak döndür.
      return res.status(400).json({ message: err.message || 'Görsel yüklenemedi' });
    }
    if (!req.file) {
      return res.status(400).json({ message: 'Görsel dosyası gerekli (file alanı)' });
    }

    // Tarayıcıda gösterilebilir mutlak URL. Reverse proxy/Docker arkasında istekten
    // türetilen host iç ağ adı olabileceğinden, prod'da PUBLIC_API_URL kullanılır.
    const base =
      (process.env.PUBLIC_API_URL || '').replace(/\/$/, '') ||
      `${req.protocol}://${req.get('host')}`;
    const url = `${base}/uploads/${req.file.filename}`;

    res.status(201).json({ url });
  });
});

module.exports = router;

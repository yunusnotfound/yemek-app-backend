const router = require('express').Router();
const fs = require('fs');
const upload = require('../config/multer');
const { authenticate } = require('../middlewares/auth');
const { authorize } = require('../middlewares/role');

// İlk baytlardan gerçek görsel türünü tespit eder (istemci Content-Type'ına güvenmez).
// null => tanınan bir raster görsel değil.
const sniffImageType = (buf) => {
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'jpeg';
  if (
    buf.length >= 8 &&
    buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47 &&
    buf[4] === 0x0d && buf[5] === 0x0a && buf[6] === 0x1a && buf[7] === 0x0a
  ) return 'png';
  if (
    buf.length >= 12 &&
    buf.toString('ascii', 0, 4) === 'RIFF' &&
    buf.toString('ascii', 8, 12) === 'WEBP'
  ) return 'webp';
  return null;
};

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
  upload.single('file')(req, res, async (err) => {
    if (err) {
      // Multer (boyut) ve fileFilter (format) hataları — 400 olarak döndür.
      return res.status(400).json({ message: err.message || 'Görsel yüklenemedi' });
    }
    if (!req.file) {
      return res.status(400).json({ message: 'Görsel dosyası gerekli (file alanı)' });
    }

    // Magic-byte doğrulaması: istemci "image/png" deyip .svg/.html içerik yükleyemesin.
    // Uzantı zaten multer'da MIME'dan türetiliyor; burada içeriğin gerçekten raster
    // görsel olduğunu doğrularız (stored-XSS önlemi). Uymayan dosya diskten silinir.
    try {
      const fd = await fs.promises.open(req.file.path, 'r');
      try {
        const { buffer } = await fd.read(Buffer.alloc(12), 0, 12, 0);
        if (!sniffImageType(buffer)) {
          await fs.promises.unlink(req.file.path).catch(() => {});
          return res.status(400).json({ message: 'Geçersiz görsel içeriği (yalnız JPEG, PNG, WebP)' });
        }
      } finally {
        await fd.close();
      }
    } catch (e) {
      await fs.promises.unlink(req.file.path).catch(() => {});
      return res.status(400).json({ message: 'Görsel doğrulanamadı' });
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

const multer = require('multer');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

// Uzantı, istemcinin gönderdiği dosya adından DEĞİL, izin verilen MIME türünden
// türetilir. Aksi halde image/png beyanıyla ".svg"/".html" uzantılı dosya yüklenip
// /uploads'tan servis edilerek stored-XSS'e yol açardı.
const MIME_EXT = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
};

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, path.join(__dirname, '../../uploads'));
  },
  filename: (req, file, cb) => {
    const ext = MIME_EXT[file.mimetype] || '';
    cb(null, `${uuidv4()}${ext}`);
  },
});

const fileFilter = (req, file, cb) => {
  if (MIME_EXT[file.mimetype]) {
    cb(null, true);
  } else {
    cb(new Error('Sadece JPEG, PNG ve WebP formatları desteklenir'), false);
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 },
});

module.exports = upload;

const jwt = require('jsonwebtoken');
const { User } = require('../models');

const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ message: 'Yetkilendirme token\'ı gerekli' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] });

    const user = await User.findByPk(decoded.id);
    if (!user || (decoded.type && decoded.type !== 'access') ||
        (decoded.version ?? 0) !== user.authVersion) {
      return res.status(401).json({ message: 'Kullanıcı bulunamadı' });
    }

    if (!user.isEmailVerified) {
      return res.status(403).json({ message: 'Lütfen önce e-posta adresinizi doğrulayın' });
    }

    req.user = user;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ message: 'Token süresi dolmuş' });
    }
    if (error.name === 'JsonWebTokenError' || error.name === 'NotBeforeError') {
      return res.status(401).json({ message: 'Geçersiz token' });
    }
    // A database/network failure does not invalidate an otherwise valid session.
    // Let the error handler return 5xx instead of making clients sign out.
    return next(error);
  }
};

module.exports = { authenticate };

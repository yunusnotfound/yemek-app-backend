const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const axios = require('axios');
const { Op } = require('sequelize');
const { OAuth2Client } = require('google-auth-library');
const { User } = require('../models');
const { generateToken } = require('../utils/helpers');
const { sendVerificationEmail, sendPasswordResetEmail } = require('../services/emailService');
const logger = require('../services/logger');
const { isRedisAvailable, storeRefreshToken, revokeRefreshToken, isRefreshTokenStored } = require('../services/cacheService');

const hashToken = (token) => crypto.createHash('sha256').update(token).digest('hex');

const getRefreshTtl = () => {
  const expiresIn = process.env.JWT_REFRESH_EXPIRES_IN || '7d';
  const match = String(expiresIn).match(/^(\d+)([smhd])$/);
  if (!match) return 604800;
  const multipliers = { s: 1, m: 60, h: 3600, d: 86400 };
  return parseInt(match[1]) * (multipliers[match[2]] || 86400);
};

const generateTokens = (user) => {
  const accessToken = jwt.sign(
    { id: user.id, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN }
  );

  const refreshToken = jwt.sign(
    { id: user.id },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN }
  );

  return { accessToken, refreshToken };
};

exports.register = async (req, res, next) => {
  try {
    const { name, email, password, phone, role } = req.body;

    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      return res.status(409).json({ message: 'Bu e-posta adresi zaten kayıtlı' });
    }

    const user = await User.create({ name, email, password, phone, role });
    
    logger.info('New user registered', { userId: user.id, email, role });
    
    // Send verification email (token valid 24 hours)
    const verificationToken = generateToken();
    const verificationExpires = new Date(Date.now() + 24 * 60 * 60 * 1000);
    await user.update({ emailVerificationToken: verificationToken, emailVerificationExpires: verificationExpires });
    await sendVerificationEmail(email, verificationToken);

    const tokens = generateTokens(user);
    await storeRefreshToken(hashToken(tokens.refreshToken), user.id, getRefreshTtl());

    res.status(201).json({
      message: 'Kayıt başarılı. Lütfen e-postanızı doğrulayın.',
      user,
      ...tokens,
    });
  } catch (error) {
    next(error);
  }
};

exports.login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ where: { email } });
    if (!user) {
      logger.warn('Failed login attempt', { email });
      return res.status(401).json({ message: 'E-posta veya şifre hatalı' });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      logger.warn('Failed login attempt', { email });
      return res.status(401).json({ message: 'E-posta veya şifre hatalı' });
    }

    if (!user.isEmailVerified) {
      return res.status(403).json({ message: 'Lütfen önce e-posta adresinizi doğrulayın' });
    }

    const tokens = generateTokens(user);
    await storeRefreshToken(hashToken(tokens.refreshToken), user.id, getRefreshTtl());

    logger.info('User login successful', { userId: user.id, email });

    res.json({
      message: 'Giriş başarılı',
      user,
      ...tokens,
    });
  } catch (error) {
    next(error);
  }
};

exports.refreshToken = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ message: 'Refresh token gerekli' });
    }

    // If Redis is available, validate token is not revoked and rotate it
    const tokenHash = hashToken(refreshToken);
    if (isRedisAvailable()) {
      const stored = await isRefreshTokenStored(tokenHash);
      if (!stored) {
        return res.status(401).json({ message: 'Geçersiz refresh token' });
      }
      await revokeRefreshToken(tokenHash);
    }

    const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
    const user = await User.findByPk(decoded.id);
    if (!user) {
      return res.status(401).json({ message: 'Kullanıcı bulunamadı' });
    }

    const tokens = generateTokens(user);
    await storeRefreshToken(hashToken(tokens.refreshToken), user.id, getRefreshTtl());

    res.json({
      message: 'Token yenilendi',
      ...tokens,
    });
  } catch (error) {
    return res.status(401).json({ message: 'Geçersiz refresh token' });
  }
};

exports.logout = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (refreshToken) {
      await revokeRefreshToken(hashToken(refreshToken));
    }
    res.json({ message: 'Çıkış başarılı' });
  } catch (error) {
    next(error);
  }
};

// Email Verification
exports.verifyEmail = async (req, res, next) => {
  try {
    const { token } = req.query;
    
    if (!token) {
      return res.status(400).json({ message: 'Token gerekli' });
    }

    const user = await User.findOne({
      where: {
        emailVerificationToken: token,
        emailVerificationExpires: { [Op.gt]: new Date() },
      },
    });
    if (!user) {
      return res.status(400).json({ message: 'Geçersiz veya süresi dolmuş token' });
    }

    await user.update({
      isEmailVerified: true,
      emailVerificationToken: null,
      emailVerificationExpires: null,
    });

    res.json({ message: 'E-posta adresiniz başarıyla doğrulandı' });
  } catch (error) {
    next(error);
  }
};

// Resend verification email
exports.resendVerification = async (req, res, next) => {
  try {
    const { email } = req.body;
    
    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(404).json({ message: 'Kullanıcı bulunamadı' });
    }

    if (user.isEmailVerified) {
      return res.status(400).json({ message: 'E-posta adresiniz zaten doğrulanmış' });
    }

    const verificationToken = generateToken();
    const verificationExpires = new Date(Date.now() + 24 * 60 * 60 * 1000);
    await user.update({ emailVerificationToken: verificationToken, emailVerificationExpires: verificationExpires });
    await sendVerificationEmail(email, verificationToken);

    res.json({ message: 'Doğrulama e-postası tekrar gönderildi' });
  } catch (error) {
    next(error);
  }
};

// Forgot Password
exports.forgotPassword = async (req, res, next) => {
  try {
    const { email } = req.body;
    
    const user = await User.findOne({ where: { email } });
    if (!user) {
      // Return success regardless to prevent email enumeration
      return res.json({ message: 'Şifre sıfırlama kodu e-posta adresinize gönderildi' });
    }

    const resetToken = Math.floor(100000 + Math.random() * 900000).toString();
    const resetExpires = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

    await user.update({ 
      passwordResetToken: resetToken, 
      passwordResetExpires: resetExpires 
    });

    await sendPasswordResetEmail(email, resetToken);

    res.json({ message: 'Şifre sıfırlama kodu e-posta adresinize gönderildi' });
  } catch (error) {
    next(error);
  }
};

// Reset Password
exports.resetPassword = async (req, res, next) => {
  try {
    const { token, password } = req.body;
    
    if (!token || !password) {
      return res.status(400).json({ message: 'Token ve şifre gerekli' });
    }

    const user = await User.findOne({ 
      where: { 
        passwordResetToken: token,
        passwordResetExpires: { [Op.gt]: new Date() }
      } 
    });

    if (!user) {
      return res.status(400).json({ message: 'Geçersiz veya süresi dolmuş token' });
    }

    await user.update({ 
      password,
      passwordResetToken: null,
      passwordResetExpires: null
    });

    res.json({ message: 'Şifreniz başarıyla değiştirildi' });
  } catch (error) {
    next(error);
  }
};

// Google Sign-In
exports.googleLogin = async (req, res, next) => {
  try {
    const { idToken, role } = req.body;

    if (!idToken) {
      return res.status(400).json({ message: 'Google ID token gerekli' });
    }

    // Verify the Google ID token
    const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
    let ticket;
    try {
      ticket = await client.verifyIdToken({
        idToken,
        audience: process.env.GOOGLE_CLIENT_ID,
      });
    } catch (err) {
      logger.warn('Invalid Google ID token', { error: err.message });
      return res.status(401).json({ message: 'Geçersiz Google token' });
    }

    const payload = ticket.getPayload();
    const { sub: googleId, email, name, email_verified } = payload;

    if (!email) {
      return res.status(400).json({ message: 'Google hesabında e-posta bulunamadı' });
    }

    // Find existing user by googleId or email — include soft-deleted rows
    let user = await User.findOne({ where: { googleId }, paranoid: false });

    if (!user) {
      user = await User.findOne({ where: { email }, paranoid: false });

      if (user) {
        // Restore soft-deleted account and link Google
        if (user.deletedAt) {
          await user.restore();
          logger.info('Restored soft-deleted user via Google login', { userId: user.id, email });
        }
        await user.update({ googleId, isEmailVerified: true });
        logger.info('Google account linked to existing user', { userId: user.id, email });
      } else {
        // Create new user
        const userRole = role === 'business_owner' ? 'business_owner' : 'customer';
        user = await User.create({
          name: name || email.split('@')[0],
          email,
          googleId,
          role: userRole,
          isEmailVerified: true,
        });
        logger.info('New user registered via Google', { userId: user.id, email, role: userRole });
      }
    } else if (user.deletedAt) {
      // Found by googleId but soft-deleted — restore
      await user.restore();
      await user.update({ isEmailVerified: true });
      logger.info('Restored soft-deleted user via Google login', { userId: user.id, email });
    }

    const tokens = generateTokens(user);
    await storeRefreshToken(hashToken(tokens.refreshToken), user.id, getRefreshTtl());

    logger.info('Google login successful', { userId: user.id, email });

    res.json({
      message: 'Google ile giriş başarılı',
      user,
      ...tokens,
    });
  } catch (error) {
    next(error);
  }
};

// Apple Sign-In
exports.appleLogin = async (req, res, next) => {
  try {
    const { identityToken, userIdentifier, email: clientEmail, fullName, role } = req.body;

    if (!identityToken) {
      return res.status(400).json({ message: 'Apple identity token gerekli' });
    }

    // Decode and verify Apple identity token (JWT)
    let decoded;
    try {
      // Decode the token header to get the key id (kid)
      const header = JSON.parse(
        Buffer.from(identityToken.split('.')[0], 'base64').toString()
      );

      // Fetch Apple's public keys
      const { data: jwks } = await axios.get('https://appleid.apple.com/auth/keys');
      const appleKey = jwks.keys.find((k) => k.kid === header.kid);

      if (!appleKey) {
        return res.status(401).json({ message: 'Geçersiz Apple token' });
      }

      // Import Apple's public key directly from JWK (Node 11.6+)
      const publicKey = crypto.createPublicKey({ key: appleKey, format: 'jwk' });

      decoded = jwt.verify(identityToken, publicKey, {
        algorithms: ['RS256'],
        issuer: 'https://appleid.apple.com',
      });
    } catch (err) {
      logger.warn('Invalid Apple identity token', { error: err.message });
      return res.status(401).json({ message: 'Geçersiz Apple token' });
    }

    const appleId = decoded.sub || userIdentifier;
    const email = decoded.email || clientEmail;

    if (!appleId) {
      return res.status(400).json({ message: 'Apple kullanıcı kimliği alınamadı' });
    }

    // Find existing user by appleId or email — include soft-deleted rows
    let user = await User.findOne({ where: { appleId }, paranoid: false });

    if (!user) {
      if (email) {
        user = await User.findOne({ where: { email }, paranoid: false });
      }

      if (user) {
        // Restore soft-deleted account and link Apple
        if (user.deletedAt) {
          await user.restore();
          logger.info('Restored soft-deleted user via Apple login', { userId: user.id, email });
        }
        await user.update({ appleId, isEmailVerified: true });
        logger.info('Apple account linked to existing user', { userId: user.id, email });
      } else {
        // Create new user
        const userRole = role === 'business_owner' ? 'business_owner' : 'customer';
        const userName = fullName || (email ? email.split('@')[0] : `Apple User`);
        user = await User.create({
          name: userName,
          email: email || `apple_${appleId}@privaterelay.appleid.com`,
          appleId,
          role: userRole,
          isEmailVerified: true,
        });
        logger.info('New user registered via Apple', { userId: user.id, email: user.email, role: userRole });
      }
    } else if (user.deletedAt) {
      // Found by appleId but soft-deleted — restore
      await user.restore();
      await user.update({ isEmailVerified: true });
      logger.info('Restored soft-deleted user via Apple login', { userId: user.id, email: user.email });
    }

    const tokens = generateTokens(user);
    await storeRefreshToken(hashToken(tokens.refreshToken), user.id, getRefreshTtl());

    logger.info('Apple login successful', { userId: user.id, email: user.email });

    res.json({
      message: 'Apple ile giriş başarılı',
      user,
      ...tokens,
    });
  } catch (error) {
    next(error);
  }
};

// Helper: Convert JWK to PEM format

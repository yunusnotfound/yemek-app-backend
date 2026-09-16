const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const axios = require('axios');
const { Op } = require('sequelize');
const { OAuth2Client } = require('google-auth-library');
const { User, EmailOtp, sequelize } = require('../models');
const { generateToken } = require('../utils/helpers');
const { sendVerificationEmail, sendPasswordResetEmail, sendOtpEmail } = require('../services/emailService');
const logger = require('../services/logger');
const { storeRefreshToken, revokeRefreshToken, consumeRefreshToken, limitAuthIdentity } = require('../services/cacheService');

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
    { id: user.id, role: user.role, version: user.authVersion, type: 'access' },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '15m', jwtid: crypto.randomUUID(), algorithm: 'HS256' }
  );

  const refreshToken = jwt.sign(
    { id: user.id, version: user.authVersion, type: 'refresh' },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d', jwtid: crypto.randomUUID(), algorithm: 'HS256' }
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
    
    // Send verification email (token valid 24 hours). Store only the hash;
    // the raw token is emailed to the user and never persisted in plaintext.
    const verificationToken = generateToken();
    const verificationExpires = new Date(Date.now() + 24 * 60 * 60 * 1000);
    await user.update({ emailVerificationToken: hashToken(verificationToken), emailVerificationExpires: verificationExpires });
    await sendVerificationEmail(email, verificationToken);

    res.status(201).json({
      message: 'Kayıt başarılı. Lütfen e-postanızı doğrulayın.',
      user,
    });
  } catch (error) {
    next(error);
  }
};

exports.login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!await limitAuthIdentity(email, 'password-login', 10)) {
      return res.status(429).json({ message: 'Çok fazla giriş denemesi. Lütfen daha sonra tekrar deneyin.' });
    }

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

// Passwordless OTP — Step 1: request a login code by email
exports.requestOtp = async (req, res, next) => {
  try {
    const { email } = req.body;
    if (!await limitAuthIdentity(email, 'otp-request')) {
      return res.status(429).json({ message: 'Çok fazla istek. Lütfen daha sonra tekrar deneyin.' });
    }

    // Cryptographically secure 6-digit numeric code.
    const code = crypto.randomInt(100000, 1000000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // One active code per email — drop any previous codes before issuing a new one.
    await sequelize.transaction(async (transaction) => {
      await lockEmail(email, transaction);
      await EmailOtp.destroy({ where: { email }, transaction });
      await EmailOtp.create({ email, codeHash: hashToken(code), expiresAt, attempts: 0 }, { transaction });
    });

    await sendOtpEmail(email, code);

    // Tell the client whether this email already has an account so it can decide
    // whether to collect a name. Acceptable enumeration trade-off for a consumer
    // login screen; attempts are capped by the auth rate-limiter.
    const existingUser = await User.findOne({ where: { email } });

    logger.info('OTP requested', { email, isNewUser: !existingUser });

    res.json({
      message: 'Giriş kodu e-posta adresinize gönderildi',
      isNewUser: !existingUser,
    });
  } catch (error) {
    next(error);
  }
};

// Passwordless OTP — Step 2: verify the code, then log in or create the account
// This lock also serializes first-time signup, when no user row exists yet.
const lockEmail = (email, transaction) => sequelize.query(
  'SELECT pg_advisory_xact_lock(hashtextextended(:email, 0))',
  { replacements: { email }, transaction }
);

// A verified mailbox may claim an unverified registration, but must discard
// credentials that someone else could have planted before verification.
const verifiedIdentityFields = (user) => user.isEmailVerified ? {} : {
  password: null, googleId: null, appleId: null, cardUserKey: null,
  emailVerificationToken: null, emailVerificationExpires: null,
  passwordResetToken: null, passwordResetExpires: null,
  authVersion: user.authVersion + 1,
};

exports.verifyOtp = async (req, res, next) => {
  try {
    const { email, code, name, phone, role } = req.body;
    const outcome = await sequelize.transaction(async (transaction) => {
      await lockEmail(email, transaction);
      const otp = await EmailOtp.findOne({ where: { email }, transaction, lock: true });
      if (!otp || otp.expiresAt <= new Date()) return { error: 400 };
      if (otp.attempts >= 5) return { error: 429 };
      await otp.increment('attempts', { transaction });
      if (otp.codeHash !== hashToken(code)) return { error: 400 };

      let user = await User.findOne({ where: { email }, paranoid: false, transaction, lock: true });
      if (user?.deletedAt) return { error: 403 };
      if (!user && !name) return { error: 400 };
      await otp.destroy({ transaction });
      if (user) {
        await user.update({ ...verifiedIdentityFields(user), isEmailVerified: true }, { transaction });
      } else {
        user = await User.create({ name, email, phone,
          role: role === 'business_owner' ? 'business_owner' : 'customer',
          isEmailVerified: true }, { transaction });
      }
      return { user };
    });
    if (outcome.error) return res.status(outcome.error).json({
      message: outcome.error === 403 ? 'Bu hesap kullanıma kapalı' :
        outcome.error === 429 ? 'Çok fazla deneme yapıldı. Yeni bir kod isteyin.' : 'Geçersiz veya süresi dolmuş kod',
    });
    const user = outcome.user;
    const tokens = generateTokens(user);
    await storeRefreshToken(hashToken(tokens.refreshToken), user.id, getRefreshTtl());
    res.json({ message: 'Giriş başarılı', user, ...tokens });
  } catch (error) { next(error); }
};

exports.refreshToken = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ message: 'Refresh token gerekli' });
    }

    const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET, { algorithms: ['HS256'] });
    const user = await User.findByPk(decoded.id);
    if (!user || !user.isEmailVerified || (decoded.type && decoded.type !== 'refresh') ||
        (decoded.version ?? 0) !== user.authVersion) {
      return res.status(401).json({ message: 'Geçersiz refresh token' });
    }
    const stored = await consumeRefreshToken(hashToken(refreshToken));
    if (!stored || stored.userId !== user.id) {
      return res.status(401).json({ message: 'Geçersiz refresh token' });
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
        emailVerificationToken: hashToken(token),
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
    if (!await limitAuthIdentity(email, 'verification-request')) {
      return res.status(429).json({ message: 'Çok fazla istek. Lütfen daha sonra tekrar deneyin.' });
    }
    
    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(404).json({ message: 'Kullanıcı bulunamadı' });
    }

    if (user.isEmailVerified) {
      return res.status(400).json({ message: 'E-posta adresiniz zaten doğrulanmış' });
    }

    const verificationToken = generateToken();
    const verificationExpires = new Date(Date.now() + 24 * 60 * 60 * 1000);
    await user.update({ emailVerificationToken: hashToken(verificationToken), emailVerificationExpires: verificationExpires });
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
    if (!await limitAuthIdentity(email, 'reset-request')) {
      return res.status(429).json({ message: 'Çok fazla istek. Lütfen daha sonra tekrar deneyin.' });
    }
    
    const user = await User.findOne({ where: { email } });
    if (!user) {
      // Return success regardless to prevent email enumeration
      return res.json({ message: 'Şifre sıfırlama kodu e-posta adresinize gönderildi' });
    }

    // Cryptographically secure 6-digit numeric code (mobile enters it as a code).
    const resetToken = crypto.randomInt(100000, 1000000).toString();
    // Short-lived expiry (15 min) limits brute-force window; the global auth
    // rate-limiter caps attempts per account. Only the hash is persisted.
    const resetExpires = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    await user.update({
      passwordResetToken: hashToken(resetToken),
      passwordResetExpires: resetExpires,
      passwordResetAttempts: 0
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
    const { email, token, password } = req.body;
    const changed = await sequelize.transaction(async (transaction) => {
      const user = await User.findOne({ where: { email }, transaction, lock: true });
      if (!user || !user.passwordResetToken || user.passwordResetExpires <= new Date() ||
          user.passwordResetAttempts >= 5) return false;
      await user.increment('passwordResetAttempts', { transaction });
      if (user.passwordResetToken !== hashToken(token)) return false;
      await user.update({ password, passwordResetToken: null, passwordResetExpires: null,
        emailVerificationToken: null, emailVerificationExpires: null,
        isEmailVerified: true, authVersion: user.authVersion + 1 }, { transaction });
      return true;
    });
    if (!changed) return res.status(400).json({ message: 'Geçersiz veya süresi dolmuş kod' });
    res.json({ message: 'Şifreniz başarıyla değiştirildi' });
  } catch (error) { next(error); }
};

// Provider identities are linked only from verified, provider-authoritative claims.
const socialUser = async ({ provider, subject, email, name, role, canLinkEmail }) =>
  sequelize.transaction(async (transaction) => {
    await lockEmail(email || `${provider}:${subject}`, transaction);
    let user = await User.findOne({ where: { [provider]: subject }, paranoid: false, transaction, lock: true });
    if (!user && email) {
      user = await User.findOne({ where: { email }, paranoid: false, transaction, lock: true });
      if (user && (!canLinkEmail || (user[provider] && user[provider] !== subject))) {
        throw Object.assign(new Error('Bu e-posta için giriş kodu ile doğrulama gerekli'), { statusCode: 403 });
      }
    }
    if (user?.deletedAt) throw Object.assign(new Error('Bu hesap kullanıma kapalı'), { statusCode: 403 });
    if (user) {
      await user.update({ ...verifiedIdentityFields(user), [provider]: subject, isEmailVerified: true }, { transaction });
    } else {
      if (!email || !canLinkEmail) throw Object.assign(new Error('Giriş kodu ile e-posta doğrulaması gerekli'), { statusCode: 403 });
      user = await User.create({ name: name || email.split('@')[0], email, [provider]: subject,
        role: role === 'business_owner' ? 'business_owner' : 'customer', isEmailVerified: true }, { transaction });
    }
    return user;
  });

// Google Sign-In
exports.googleLogin = async (req, res, next) => {
  try {
    const { idToken, role } = req.body;

    if (!idToken) {
      return res.status(400).json({ message: 'Google ID token gerekli' });
    }

    if (!process.env.GOOGLE_CLIENT_ID) return res.status(503).json({ message: 'Google ile giriş yapılandırılmamış' });

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
    const { sub: googleId, email, name, email_verified, hd } = payload;
    if (!googleId || !email || email_verified !== true) {
      return res.status(401).json({ message: 'Doğrulanmış Google hesabı gerekli' });
    }
    const user = await socialUser({ provider: 'googleId', subject: googleId, email, name, role,
      canLinkEmail: email.toLowerCase().endsWith('@gmail.com') || Boolean(hd) });

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
    const { identityToken, fullName, role } = req.body;

    if (!identityToken) {
      return res.status(400).json({ message: 'Apple identity token gerekli' });
    }

    // Apple audience must be pinned so tokens minted for other apps are rejected.
    if (!process.env.APPLE_CLIENT_ID) {
      logger.error('Apple login misconfigured: APPLE_CLIENT_ID is not set');
      return res.status(500).json({ message: 'Apple ile giriş yapılandırması eksik' });
    }

    // Decode and verify Apple identity token (JWT)
    let decoded;
    try {
      // Decode the token header to get the key id (kid)
      const header = JSON.parse(
        Buffer.from(identityToken.split('.')[0], 'base64').toString()
      );

      // Fetch Apple's public keys
      const { data: jwks } = await axios.get('https://appleid.apple.com/auth/keys', { timeout: 5000, maxContentLength: 100000 });
      const appleKey = jwks.keys.find((k) => k.kid === header.kid);

      if (!appleKey) {
        return res.status(401).json({ message: 'Geçersiz Apple token' });
      }

      // Import Apple's public key directly from JWK (Node 11.6+)
      const publicKey = crypto.createPublicKey({ key: appleKey, format: 'jwk' });

      decoded = jwt.verify(identityToken, publicKey, {
        algorithms: ['RS256'],
        issuer: 'https://appleid.apple.com',
        audience: process.env.APPLE_CLIENT_ID,
      });
    } catch (err) {
      logger.warn('Invalid Apple identity token', { error: err.message });
      return res.status(401).json({ message: 'Geçersiz Apple token' });
    }

    const appleId = decoded.sub;
    const email = decoded.email;
    if (!appleId) return res.status(401).json({ message: 'Geçersiz Apple token' });
    const user = await socialUser({ provider: 'appleId', subject: appleId, email, name: fullName, role,
      canLinkEmail: decoded.email_verified === true || decoded.email_verified === 'true' });

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

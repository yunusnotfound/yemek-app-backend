jest.mock('../src/services/emailService', () => ({
  sendVerificationEmail: jest.fn().mockResolvedValue(),
  sendPasswordResetEmail: jest.fn().mockResolvedValue(),
  sendOtpEmail: jest.fn().mockResolvedValue(),
}));
jest.mock('google-auth-library', () => ({ OAuth2Client: jest.fn() }));
jest.mock('axios', () => ({ get: jest.fn() }));

const request = require('supertest');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const app = require('../src/app');
const { User, EmailOtp } = require('../src/models');
const emailService = require('../src/services/emailService');
const cache = require('../src/services/cacheService');
const { resetDb, closeDb, createUser, authHeader } = require('./helpers');

beforeEach(async () => { await resetDb(); jest.clearAllMocks(); });
afterAll(closeDb);

const login = (user) => request(app).post('/api/auth/login').send({ email: user.email, password: 'password123' });
const otp = async (email) => {
  const res = await request(app).post('/api/auth/otp/request').send({ email });
  expect(res.status).toBe(200);
  return emailService.sendOtpEmail.mock.calls.at(-1)[1];
};

test('OTP claims an unverified registration without inheriting planted credentials or sessions', async () => {
  const user = await createUser({ isEmailVerified: false });
  const oldHeader = authHeader(user);
  expect((await request(app).get('/api/users/profile').set(oldHeader)).status).toBe(403);
  const code = await otp(user.email);
  const verified = await request(app).post('/api/auth/otp/verify').send({ email: user.email, code });
  expect(verified.status).toBe(200);
  await user.reload();
  expect(user.password).toBeNull();
  expect((await login(user)).status).toBe(401);
  expect((await request(app).get('/api/users/profile').set(oldHeader)).status).toBe(401);
  expect((await request(app).get('/api/users/profile').set('Authorization', `Bearer ${verified.body.accessToken}`)).status).toBe(200);
});

test('OTP cannot restore a deleted account', async () => {
  const user = await createUser();
  await user.destroy();
  const code = await otp(user.email);
  expect((await request(app).post('/api/auth/otp/verify').send({ email: user.email, code })).status).toBe(403);
  expect(await User.findByPk(user.id)).toBeNull();
});

test('concurrent OTP attempts cannot exceed the five-attempt budget', async () => {
  const user = await createUser();
  await otp(user.email);
  const results = await Promise.all(Array.from({ length: 15 }, () =>
    request(app).post('/api/auth/otp/verify').send({ email: user.email, code: '000000' })));
  expect(results.filter(r => r.status === 400)).toHaveLength(5);
  expect(results.filter(r => r.status === 429)).toHaveLength(10);
  expect((await EmailOtp.findOne({ where: { email: user.email } })).attempts).toBe(5);
});

test('valid OTP can be consumed only once, including concurrent submissions', async () => {
  const user = await createUser();
  const code = await otp(user.email);
  const responses = await Promise.all([1, 2].map(() => request(app).post('/api/auth/otp/verify').send({ email: user.email, code })));
  expect(responses.map(r => r.status).sort()).toEqual([200, 400]);
});

test('refresh rotation is atomic and tokens differ even within the same second', async () => {
  const user = await createUser();
  const session = await login(user);
  const responses = await Promise.all([1, 2].map(() => request(app).post('/api/auth/refresh').send({ refreshToken: session.body.refreshToken })));
  expect(responses.map(r => r.status).sort()).toEqual([200, 401]);
  expect(responses.find(r => r.status === 200).body.refreshToken).not.toBe(session.body.refreshToken);
});

test('revoked refresh token cannot renew a session', async () => {
  const user = await createUser();
  const session = await login(user);
  expect((await request(app).post('/api/auth/logout').send({ refreshToken: session.body.refreshToken })).status).toBe(200);
  expect((await request(app).post('/api/auth/refresh').send({ refreshToken: session.body.refreshToken })).status).toBe(401);
});

test('password reset is bound to email and invalidates all old sessions', async () => {
  const a = await createUser();
  const b = await createUser();
  const session = await login(b);
  const hash = crypto.createHash('sha256').update('456789').digest('hex');
  for (const user of [a, b]) await user.update({ passwordResetToken: hash, passwordResetExpires: new Date(Date.now() + 60000) });
  const missingEmail = await request(app).post('/api/auth/reset-password').send({ token: '456789', password: 'NewPassword123' });
  expect(missingEmail.status).toBe(400);
  const reset = await request(app).post('/api/auth/reset-password').send({ email: b.email, token: '456789', password: 'NewPassword123' });
  expect(reset.status).toBe(200);
  await a.reload(); await b.reload();
  expect(await a.comparePassword('password123')).toBe(true);
  expect(await b.comparePassword('NewPassword123')).toBe(true);
  expect((await request(app).get('/api/users/profile').set('Authorization', `Bearer ${session.body.accessToken}`)).status).toBe(401);
  expect((await request(app).post('/api/auth/refresh').send({ refreshToken: session.body.refreshToken })).status).toBe(401);
});

test('reset code brute force is capped per account, even with concurrent requests', async () => {
  const user = await createUser();
  await request(app).post('/api/auth/forgot-password').send({ email: user.email });
  const code = emailService.sendPasswordResetEmail.mock.calls.at(-1)[1];
  await Promise.all(Array.from({ length: 12 }, () => request(app).post('/api/auth/reset-password').send({ email: user.email, token: '000000', password: 'NewPassword123' })));
  expect((await request(app).post('/api/auth/reset-password').send({ email: user.email, token: code, password: 'NewPassword123' })).status).toBe(400);
  await user.reload();
  expect(user.passwordResetAttempts).toBe(5);
});

test('refresh store failure cannot silently mint a usable refresh session', async () => {
  const user = await createUser();
  const session = await login(user);
  // Removing the allowlist entry simulates revocation/missing state, even in dev/test.
  await cache.revokeRefreshToken(crypto.createHash('sha256').update(session.body.refreshToken).digest('hex'));
  expect((await request(app).post('/api/auth/refresh').send({ refreshToken: session.body.refreshToken })).status).toBe(401);
});

test('Google requires configured audience and verified authoritative email before linking', async () => {
  process.env.GOOGLE_CLIENT_ID = 'test-client';
  const user = await createUser({ email: 'victim@external.test' });
  require('google-auth-library').OAuth2Client.mockImplementation(() => ({
    verifyIdToken: jest.fn().mockResolvedValue({ getPayload: () => ({ sub: 'attacker-google', email: user.email, email_verified: true }) }),
  }));
  expect((await request(app).post('/api/auth/google').send({ idToken: 'provider-token' })).status).toBe(403);
  await user.reload();
  expect(user.googleId).toBeNull();
});

test('Apple ignores client-supplied email when the signed token has none', async () => {
  process.env.APPLE_CLIENT_ID = 'test-apple-client';
  const victim = await createUser();
  const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
  require('axios').get.mockResolvedValue({ data: { keys: [{ ...publicKey.export({ format: 'jwk' }), kid: 'test-key' }] } });
  const identityToken = jwt.sign({ sub: 'attacker-apple' }, privateKey, {
    algorithm: 'RS256', keyid: 'test-key', issuer: 'https://appleid.apple.com', audience: process.env.APPLE_CLIENT_ID, expiresIn: '5m',
  });
  const res = await request(app).post('/api/auth/apple').send({ identityToken, email: victim.email, userIdentifier: victim.id });
  expect(res.status).toBe(403);
  await victim.reload();
  expect(victim.appleId).toBeNull();
});

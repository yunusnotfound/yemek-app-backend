// E-posta gönderimi mock'lanır (gerçek e-posta gitmez; OTP kodunu yakalarız).
jest.mock('../src/services/emailService', () => ({
  sendMail: jest.fn().mockResolvedValue(),
  sendVerificationEmail: jest.fn().mockResolvedValue(),
  sendPasswordResetEmail: jest.fn().mockResolvedValue(),
  sendOtpEmail: jest.fn().mockResolvedValue(),
  sendOrderStatusEmail: jest.fn().mockResolvedValue(),
}));

const request = require('supertest');
const app = require('../src/app');
const emailService = require('../src/services/emailService');
const cacheService = require('../src/services/cacheService');
const { resetDb, closeDb, createUser } = require('./helpers');

let redisUp = false;
beforeAll(async () => {
  redisUp = await cacheService.ping();
});
beforeEach(async () => {
  await resetDb();
  jest.clearAllMocks();
});
afterAll(closeDb);

describe('POST /api/auth/register + login', () => {
  test('register 201 + token döner', async () => {
    const res = await request(app).post('/api/auth/register').send({
      name: 'Yeni Kullanıcı',
      email: 'newuser@test.local',
      password: 'password123',
      phone: '5551112233',
      role: 'customer',
    });
    expect(res.status).toBe(201);
    expect(res.body.accessToken).toBeTruthy();
    expect(res.body.refreshToken).toBeTruthy();
  });

  test('doğrulanmamış e-posta ile login 403', async () => {
    const user = await createUser({ email: 'unv@test.local', isEmailVerified: false });
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: user.email, password: 'password123' });
    expect(res.status).toBe(403);
  });

  test('doğru şifre ile login 200 + token', async () => {
    const user = await createUser({ email: 'ok@test.local', isEmailVerified: true });
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: user.email, password: 'password123' });
    expect(res.status).toBe(200);
    expect(res.body.accessToken).toBeTruthy();
    expect(res.body.refreshToken).toBeTruthy();
  });

  test('yanlış şifre 401', async () => {
    const user = await createUser({ email: 'bad@test.local' });
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: user.email, password: 'wrong-password' });
    expect(res.status).toBe(401);
  });
});

describe('POST /api/auth/refresh — rotasyon & revocation', () => {
  test('refresh yeni token verir; eski token (Redis varsa) revoke edilir', async () => {
    const user = await createUser({ email: 'refresh@test.local' });
    const login = await request(app)
      .post('/api/auth/login')
      .send({ email: user.email, password: 'password123' });
    const oldRefresh = login.body.refreshToken;

    // JWT iat/exp saniye çözünürlüğünde; aynı saniyede imzalanan refresh token'lar
    // birebir aynı olur. Rotasyonun (farklı token + eski hash'in revoke'u)
    // gözlemlenebilmesi için 1 saniyeden fazla bekle.
    await new Promise((r) => setTimeout(r, 1100));

    const first = await request(app).post('/api/auth/refresh').send({ refreshToken: oldRefresh });
    expect(first.status).toBe(200);
    expect(first.body.refreshToken).toBeTruthy();
    expect(first.body.refreshToken).not.toBe(oldRefresh);

    // Eski refresh tekrar kullanılırsa: Redis varsa revoke -> 401; yoksa fail-open (non-prod).
    const replay = await request(app).post('/api/auth/refresh').send({ refreshToken: oldRefresh });
    if (redisUp) {
      expect(replay.status).toBe(401);
    } else {
      expect([200, 401]).toContain(replay.status);
    }
  });
});

describe('POST /api/auth/otp — deneme kilidi', () => {
  test('doğru kodla OTP girişi 200 + yeni kullanıcı', async () => {
    const email = 'otp-ok@test.local';
    const reqRes = await request(app).post('/api/auth/otp/request').send({ email });
    expect(reqRes.status).toBe(200);
    const code = emailService.sendOtpEmail.mock.calls.at(-1)[1];

    const verify = await request(app)
      .post('/api/auth/otp/verify')
      .send({ email, code, name: 'OTP Kullanıcı' });
    expect(verify.status).toBe(200);
    expect(verify.body.accessToken).toBeTruthy();
  });

  test('5 yanlış denemeden sonra 6. deneme 429 (kilit)', async () => {
    const email = 'otp-lock@test.local';
    await request(app).post('/api/auth/otp/request').send({ email });

    for (let i = 0; i < 5; i++) {
      const r = await request(app).post('/api/auth/otp/verify').send({ email, code: '000000' });
      expect(r.status).toBe(400);
    }
    const sixth = await request(app).post('/api/auth/otp/verify').send({ email, code: '000000' });
    expect(sixth.status).toBe(429);
  });
});

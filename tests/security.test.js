const fs = require('fs');
const path = require('path');
const request = require('supertest');
const app = require('../src/app');
const {
  resetDb,
  closeDb,
  createUser,
  createBusiness,
  createPackage,
  authHeader,
} = require('./helpers');

const UPLOADS_DIR = path.join(__dirname, '..', 'uploads');
// Geçerli PNG imzası (ilk 12 bayt) — magic-byte kontrolünü geçer.
const PNG_HEADER = Buffer.from([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
]);

beforeAll(() => {
  // multer diskStorage hedefi mevcut olmalı (temiz checkout'ta uploads/ yok).
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
});
beforeEach(resetDb);
afterAll(closeDb);

describe('POST /api/upload — içerik doğrulama (stored-XSS önlemi)', () => {
  test('geçerli PNG içeriği kabul edilir (201)', async () => {
    const owner = await createUser({ role: 'business_owner' });
    const res = await request(app)
      .post('/api/upload')
      .set(authHeader(owner))
      .attach('file', PNG_HEADER, { filename: 'x.png', contentType: 'image/png' });
    expect(res.status).toBe(201);
    expect(res.body.url).toMatch(/\/uploads\/.+\.png$/);
    // Yazılan test dosyasını temizle.
    const fname = res.body.url.split('/uploads/')[1];
    if (fname) await fs.promises.unlink(path.join(UPLOADS_DIR, fname)).catch(() => {});
  });

  test('image/png beyanıyla SVG içerik reddedilir (400) ve dosya diskte kalmaz', async () => {
    const owner = await createUser({ role: 'business_owner' });
    const before = fs.readdirSync(UPLOADS_DIR).length;
    const svg = Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>');
    const res = await request(app)
      .post('/api/upload')
      .set(authHeader(owner))
      .attach('file', svg, { filename: 'x.svg', contentType: 'image/png' });
    expect(res.status).toBe(400);
    const after = fs.readdirSync(UPLOADS_DIR).length;
    expect(after).toBe(before); // reddedilen içerik diskte tutulmaz
  });

  test('yetkisiz kullanıcı upload edemez (401)', async () => {
    const res = await request(app)
      .post('/api/upload')
      .attach('file', PNG_HEADER, { filename: 'x.png', contentType: 'image/png' });
    expect(res.status).toBe(401);
  });
});

describe('Onaysız işletme herkese görünmez (KRİTİK moderasyon kapısı)', () => {
  test('paket listesi yalnız onaylı işletmelerin paketlerini içerir', async () => {
    const approved = await createBusiness({ isApproved: true });
    const unapproved = await createBusiness({ isApproved: false });
    const p1 = await createPackage({ businessId: approved.id, title: 'Onaylı Paket' });
    await createPackage({ businessId: unapproved.id, title: 'Onaysız Paket' });

    const res = await request(app).get('/api/packages');
    expect(res.status).toBe(200);
    const ids = res.body.data.map((p) => p.id);
    expect(ids).toContain(p1.id);
    const titles = res.body.data.map((p) => p.title);
    expect(titles).not.toContain('Onaysız Paket');
  });

  test('onaysız işletmenin paket detayı 404', async () => {
    const unapproved = await createBusiness({ isApproved: false });
    const pkg = await createPackage({ businessId: unapproved.id });
    const res = await request(app).get(`/api/packages/${pkg.id}`);
    expect(res.status).toBe(404);
  });

  test('onaysız işletme detayı 404', async () => {
    const unapproved = await createBusiness({ isApproved: false });
    const res = await request(app).get(`/api/businesses/${unapproved.id}`);
    expect(res.status).toBe(404);
  });
});

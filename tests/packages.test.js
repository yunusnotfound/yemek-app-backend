const request = require('supertest');
const app = require('../src/app');
const {
  resetDb,
  closeDb,
  createBusiness,
  createPackage,
} = require('./helpers');

beforeEach(resetDb);
afterAll(closeDb);

// Taksim referans alınır; mesafeler kabaca kuzeye doğru artacak şekilde seçildi.
const MERKEZ = { lat: 41.0369, lng: 28.9850 };

/** Merkezden ~kmKuzey kilometre kuzeyde bir işletme + paketi oluşturur. */
async function paketOlustur(kmKuzey, baslik) {
  const business = await createBusiness({
    name: `Isletme ${baslik}`,
    latitude: MERKEZ.lat + kmKuzey / 111.32, // 1 derece enlem ~111.32 km
    longitude: MERKEZ.lng,
  });
  return createPackage({ businessId: business.id, title: baslik });
}

describe('GET /api/packages — coğrafi filtre SQL tarafında', () => {
  test('yarıçap dışındaki paketler listeye girmez', async () => {
    await paketOlustur(1, 'Yakin');
    await paketOlustur(30, 'Uzak');

    const res = await request(app).get(
      `/api/packages?lat=${MERKEZ.lat}&lng=${MERKEZ.lng}&radius=5`,
    );

    expect(res.status).toBe(200);
    const titles = res.body.data.map((p) => p.title);
    expect(titles).toContain('Yakin');
    expect(titles).not.toContain('Uzak');
  });

  test('sonuçlar mesafeye göre artan sıralı gelir', async () => {
    // Bilerek karışık sırada oluştur — sıralama ekleme sırasından gelmesin.
    await paketOlustur(6, 'Ucuncu');
    await paketOlustur(2, 'Birinci');
    await paketOlustur(4, 'Ikinci');

    const res = await request(app).get(
      `/api/packages?lat=${MERKEZ.lat}&lng=${MERKEZ.lng}&radius=20&limit=10`,
    );

    expect(res.status).toBe(200);
    expect(res.body.data.map((p) => p.title)).toEqual([
      'Birinci',
      'Ikinci',
      'Ucuncu',
    ]);

    // Mesafe işletme nesnesinin içinde dönmeli (istemci orada arıyor) ve artmalı.
    const mesafeler = res.body.data.map((p) => p.business.distance);
    mesafeler.forEach((d) => expect(typeof d).toBe('number'));
    expect(mesafeler).toEqual([...mesafeler].sort((a, b) => a - b));
  });

  test('sayfalama: total gerçek toplamı verir ve sayfalar örtüşmez', async () => {
    for (let i = 1; i <= 5; i++) {
      await paketOlustur(i, `P${i}`);
    }

    const sayfa1 = await request(app).get(
      `/api/packages?lat=${MERKEZ.lat}&lng=${MERKEZ.lng}&radius=20&page=1&limit=2`,
    );
    const sayfa2 = await request(app).get(
      `/api/packages?lat=${MERKEZ.lat}&lng=${MERKEZ.lng}&radius=20&page=2&limit=2`,
    );

    expect(sayfa1.body.pagination.total).toBe(5);
    expect(sayfa1.body.pagination.totalPages).toBe(3);
    expect(sayfa1.body.data.map((p) => p.title)).toEqual(['P1', 'P2']);
    expect(sayfa2.body.data.map((p) => p.title)).toEqual(['P3', 'P4']);
  });

  test('coğrafi filtre yokken de liste çalışır (regresyon)', async () => {
    await paketOlustur(1, 'Herhangi');

    const res = await request(app).get('/api/packages');

    expect(res.status).toBe(200);
    expect(res.body.data.map((p) => p.title)).toContain('Herhangi');
  });

  // Mesafe SQL ifadesine sayı olarak gömüldüğü için koordinatların sayı olması
  // kritik. İki katman koruyor: (1) query şeması sayı olmayanı 400 ile eler,
  // (2) controller ayrıca Number.isFinite kontrolü yapıp geo filtresini atlar.
  // Bu test birinci katmanın yerinde durduğunu sabitler.
  test('sayı olmayan koordinat şema katmanında 400 ile reddedilir', async () => {
    await paketOlustur(1, 'Herhangi');

    const res = await request(app).get('/api/packages?lat=abc&lng=xyz&radius=5');

    expect(res.status).toBe(400);
  });
});

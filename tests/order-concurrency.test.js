jest.mock('../src/services/notificationService', () => ({
  notifyNewOrder: jest.fn().mockResolvedValue(),
  notifyOrderStatus: jest.fn().mockResolvedValue(),
  createNotification: jest.fn().mockResolvedValue(),
}));

const request = require('supertest');
const crypto = require('node:crypto');
const app = require('../src/app');
const { User, Order, SurprisePackage } = require('../src/models');
const { resetDb, closeDb, createBusiness, createPackage, authHeader } = require('./helpers');

beforeEach(resetDb);
afterAll(closeDb);

test.each([1, 5])('50 simultaneous reservations across %i businesses preserve stock without pool starvation', async (businessCount) => {
  const packages = [];
  for (let index = 0; index < businessCount; index++) {
    const business = await createBusiness();
    packages.push(await createPackage({ businessId: business.id, discountedPrice: 0, quantity: 10, remainingQuantity: 10 }));
  }
  const users = await User.bulkCreate(Array.from({ length: 50 }, () => ({
    name: 'Concurrency Test',
    email: `load-${crypto.randomUUID()}@test.local`,
    isEmailVerified: true,
  })));

  const responses = await Promise.all(users.map((user, index) => request(app)
    .post('/api/orders').set(authHeader(user))
    .send({ packageId: packages[index % businessCount].id, quantity: 1 })
    // Catch the old 30-second pool deadlock without a long/hanging regression.
    .timeout({ response: 10000, deadline: 12000 })));

  expect(responses.filter((response) => response.status === 201)).toHaveLength(businessCount * 10);
  const failures = responses.filter((response) => response.status !== 201);
  expect(failures).toHaveLength(50 - businessCount * 10);
  for (const response of failures) {
    expect(response.status).toBe(400);
    expect(response.body.message).toMatch(/Yetersiz stok/i);
  }
  expect(await Order.count()).toBe(businessCount * 10);
  for (const pkg of packages) expect((await SurprisePackage.findByPk(pkg.id)).remainingQuantity).toBe(0);
});

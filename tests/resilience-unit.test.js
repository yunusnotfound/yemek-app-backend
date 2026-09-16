jest.mock('../src/models', () => ({
  Order: { findOne: jest.fn() },
  User: { findByPk: jest.fn() },
}));

const jwt = require('jsonwebtoken');
const { Order, User } = require('../src/models');
const { generatePickupCode } = require('../src/utils/helpers');
const { authenticate } = require('../src/middlewares/auth');

beforeEach(() => jest.clearAllMocks());

test('pickup-code collision retries reuse the reservation transaction', async () => {
  const transaction = { id: 'already-acquired-connection' };
  Order.findOne.mockResolvedValueOnce({ id: 'conflict' }).mockResolvedValueOnce(null);
  expect(await generatePickupCode(transaction)).toMatch(/^[1-9]\d{5}$/);
  expect(Order.findOne).toHaveBeenCalledTimes(2);
  for (const [options] of Order.findOne.mock.calls) expect(options.transaction).toBe(transaction);
});

test('pickup-code exhaustion is bounded and never falls back to an unchecked code', async () => {
  Order.findOne.mockResolvedValue({ id: 'conflict' });
  await expect(generatePickupCode({})).rejects.toThrow('Benzersiz teslim alma kodu');
  expect(Order.findOne).toHaveBeenCalledTimes(10);
});

const authenticateWith = async (token) => {
  const req = { headers: { authorization: `Bearer ${token}` } };
  const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
  const next = jest.fn();
  await authenticate(req, res, next);
  return { req, res, next };
};

test('a valid JWT with a database failure goes to the server-error handler, not 401', async () => {
  const error = Object.assign(new Error('pool exhausted'), { name: 'SequelizeConnectionAcquireTimeoutError' });
  User.findByPk.mockRejectedValue(error);
  const { res, next } = await authenticateWith(jwt.sign({ id: 'user' }, process.env.JWT_SECRET));
  expect(next).toHaveBeenCalledWith(error);
  expect(res.status).not.toHaveBeenCalled();
});

test.each([
  ['invalid', () => 'invalid-token'],
  ['expired', () => jwt.sign({ id: 'user', exp: 1 }, process.env.JWT_SECRET)],
  ['not active yet', () => jwt.sign({ id: 'user', nbf: Math.floor(Date.now() / 1000) + 3600 }, process.env.JWT_SECRET)],
])('%s JWT still fails authentication', async (_, makeToken) => {
  const { res, next } = await authenticateWith(makeToken());
  expect(res.status).toHaveBeenCalledWith(401);
  expect(User.findByPk).not.toHaveBeenCalled();
  expect(next).not.toHaveBeenCalled();
});

test('revoked token versions still fail authentication', async () => {
  User.findByPk.mockResolvedValue({ authVersion: 2, isEmailVerified: true });
  const { res, next } = await authenticateWith(jwt.sign({ id: 'user', version: 1 }, process.env.JWT_SECRET));
  expect(res.status).toHaveBeenCalledWith(401);
  expect(next).not.toHaveBeenCalled();
});

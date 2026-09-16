const bcrypt = require('bcryptjs');
const passwordService = require('../src/services/passwordService');

afterAll(async () => passwordService.close());

test('worker hashes preserve bcrypt cost and compatibility with existing stored passwords', async () => {
  const hash = await passwordService.hash('Yeni-Parola123');
  expect(bcrypt.getRounds(hash)).toBe(10);
  expect(bcrypt.compareSync('Yeni-Parola123', hash)).toBe(true);
  const existingHash = bcrypt.hashSync('Eski-Parola123', 10);
  expect(await passwordService.compare('Eski-Parola123', existingHash)).toBe(true);
  expect(await passwordService.compare('wrong-password', existingHash)).toBe(false);
});

test('simultaneous password jobs retain their matching result', async () => {
  const hash = bcrypt.hashSync('matching-password', 10);
  const results = await Promise.all(Array.from({ length: 12 }, (_, index) =>
    passwordService.compare(index % 2 ? 'wrong-password' : 'matching-password', hash)));
  expect(results).toEqual(Array.from({ length: 12 }, (_, index) => index % 2 === 0));
});

test('the password queue is bounded and overload rejects instead of weakening verification', async () => {
  const jobs = Array.from({ length: 110 }, () => passwordService.hash('queued-password'));
  const resultsPromise = Promise.allSettled(jobs);
  await passwordService.close();
  const results = await resultsPromise;
  expect(results.some((result) => result.status === 'rejected' && result.reason.statusCode === 503)).toBe(true);
  expect(results.every((result) => result.status === 'rejected')).toBe(true);
});

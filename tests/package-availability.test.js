const { pickupStartAt, pickupEndAt, availabilityCacheTtl } = require('../src/utils/packageAvailability');

const window = (pickupStart, pickupEnd, pickupDate = '2026-09-24') => ({
  pickupDate, pickupStart, pickupEnd,
});

test('pickup timestamps use Istanbul time regardless of the server timezone', () => {
  const pkg = window('12:00:00', '15:00:00');
  expect(pickupStartAt(pkg).toISOString()).toBe('2026-09-24T09:00:00.000Z');
  expect(pickupEndAt(pkg).toISOString()).toBe('2026-09-24T12:00:00.000Z');
});

test.each([
  ['23:00:00', '01:00:00', '2026-09-24T22:00:00.000Z'],
  ['10:00:00', '10:00:00', '2026-09-25T07:00:00.000Z'],
])('overnight %s–%s pickup ends the next Istanbul day', (start, end, expectedEnd) => {
  expect(pickupEndAt(window(start, end)).toISOString()).toBe(expectedEnd);
});

test('cache lifetime reaches zero at the exact pickup end and never rounds beyond it', () => {
  const pkg = window('12:00:00', '12:00:02');
  const now = Date.parse('2026-09-24T09:00:00Z');
  expect(availabilityCacheTtl([pkg], 300, now)).toBe(2);
  expect(availabilityCacheTtl([pkg], 300, now + 1001)).toBe(0);
  expect(availabilityCacheTtl([pkg], 300, now + 2000)).toBe(0);
  expect(availabilityCacheTtl([pkg], 300, now + 3000)).toBe(0);
});

test('cache lifetime respects the earliest pickup boundary and its maximum', () => {
  const now = Date.parse('2026-09-24T09:00:00Z');
  const current = window('11:00:00', '13:00:00');
  const startsSoon = window('12:00:10', '14:00:00');
  expect(availabilityCacheTtl([current, startsSoon], 300, now)).toBe(10);
  expect(availabilityCacheTtl([current, startsSoon], 5, now)).toBe(5);
  expect(availabilityCacheTtl([window('23:00:00', '12:00:05', '2026-09-23')], 300, now)).toBe(5);
});

test('invalid pickup data cannot leave a cached offer visible', () => {
  expect(availabilityCacheTtl([window('12:00:00', 'invalid')], 300)).toBe(0);
});

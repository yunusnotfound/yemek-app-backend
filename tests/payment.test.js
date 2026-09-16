// paymentFinalizeService.finalize'ı doğrudan test eder (iyzico retrieve OTORİTE
// sonucu mock'lanır). Ödeme kesinleştirmenin idempotency + tutar bütünlüğü mantığı.
jest.mock('../src/services/iyzicoService', () => ({
  verifyWebhookSignature: jest.requireActual('../src/services/iyzicoService').verifyWebhookSignature,
  refundItem: jest.fn().mockResolvedValue({}),
  retrieveCheckoutForm: jest.fn(),
  retrievePayment: jest.fn(),
  completeThreeDS: jest.fn(),
  approveItem: jest.fn(),
  calcSubMerchantPrice: (p) => Number((Number(p) * 0.9).toFixed(2)),
}));
jest.mock('../src/services/notificationService', () => ({
  notifyNewOrder: jest.fn().mockResolvedValue(),
  notifyOrderStatus: jest.fn().mockResolvedValue(),
  createNotification: jest.fn().mockResolvedValue(),
}));

const finalizeService = require('../src/services/paymentFinalizeService');
const iyzicoService = require('../src/services/iyzicoService');
const { Order, SurprisePackage } = require('../src/models');
const { resetDb, closeDb, createUser, createPackage } = require('./helpers');
const request = require('supertest');
const crypto = require('crypto');
const app = require('../src/app');
const { authHeader } = require('./helpers');
const { cancelOrder } = require('../src/services/orderCancellationService');
const settlementService = require('../src/services/settlementService');

beforeEach(async () => {
  await resetDb();
  jest.clearAllMocks();
});
afterAll(closeDb);

let convSeq = 0;
async function createAwaitingOrder({ finalPrice = 90, quantity = 1, remainingQuantity = 4 } = {}) {
  const pkg = await createPackage({ discountedPrice: finalPrice, quantity: 5, remainingQuantity });
  const user = await createUser();
  convSeq += 1;
  const order = await Order.create({
    userId: user.id,
    packageId: pkg.id,
    quantity,
    totalPrice: finalPrice,
    finalPrice,
    pickupCode: String(100000 + convSeq),
    conversationId: `conv-${convSeq}`,
    paymentToken: `token-${convSeq}`,
    paymentProvider: 'iyzico',
    status: 'awaiting_payment',
    paymentStatus: 'pending',
    settlementStatus: 'none',
    paymentHoldExpiresAt: new Date(Date.now() + 20 * 60 * 1000),
  });
  return { order, pkg };
}

function successResult(paidPrice, order) {
  return {
    status: 'success',
    paymentStatus: 'SUCCESS',
    fraudStatus: 1,
    currency: 'TRY',
    paidPrice,
    basketId: order.conversationId,
    paymentId: `pay_${order.id}`,
    itemTransactions: [{ itemId: order.packageId, paymentTransactionId: `ptx_${order.id}` }],
  };
}

describe('paymentFinalizeService.finalize', () => {
  test('SUCCESS + doğru tutar -> paid', async () => {
    const { order } = await createAwaitingOrder({ finalPrice: 90 });
    const res = await finalizeService.finalize({
      conversationId: order.conversationId,
      retrieveResult: successResult(90, order),
      source: 'test',
    });
    expect(res.outcome).toBe('paid');
    const fresh = await Order.findByPk(order.id);
    expect(fresh.paymentStatus).toBe('paid');
    expect(fresh.status).toBe('pending');
    expect(iyzicoService.refundItem).not.toHaveBeenCalled();
  });

  test('idempotent: ikinci finalize -> already_paid, çift işlem yok', async () => {
    const { order } = await createAwaitingOrder({ finalPrice: 90 });
    const first = await finalizeService.finalize({
      conversationId: order.conversationId,
      retrieveResult: successResult(90, order),
      source: 'test',
    });
    expect(first.outcome).toBe('paid');

    const second = await finalizeService.finalize({
      conversationId: order.conversationId,
      retrieveResult: successResult(90, order),
      source: 'test',
    });
    expect(second.outcome).toBe('already_paid');
  });

  test('tutar uyuşmazlığı -> amount_mismatch, iptal + stok iadesi + refund çağrısı', async () => {
    const { order, pkg } = await createAwaitingOrder({ finalPrice: 90, remainingQuantity: 4 });
    const res = await finalizeService.finalize({
      conversationId: order.conversationId,
      retrieveResult: successResult(45, order), // beklenen 90, gelen 45
      source: 'test',
    });
    expect(res.outcome).toBe('amount_mismatch');

    const fresh = await Order.findByPk(order.id);
    expect(fresh.status).toBe('cancelled');
    expect(fresh.paymentStatus).toBe('refunded');
    expect(iyzicoService.refundItem).toHaveBeenCalledTimes(1);

    const freshPkg = await SurprisePackage.findByPk(pkg.id);
    expect(freshPkg.remainingQuantity).toBe(5); // 4 + iade edilen 1
  });

  test('terminal FAILURE -> failed, stok iadesi', async () => {
    const { order, pkg } = await createAwaitingOrder({ finalPrice: 90, remainingQuantity: 4 });
    const res = await finalizeService.finalize({
      conversationId: order.conversationId,
      retrieveResult: { status: 'success', basketId: order.conversationId, paymentStatus: 'FAILURE', currency: 'TRY' },
      source: 'test',
    });
    expect(res.outcome).toBe('failed');
    const fresh = await Order.findByPk(order.id);
    expect(fresh.status).toBe('cancelled');
    const freshPkg = await SurprisePackage.findByPk(pkg.id);
    expect(freshPkg.remainingQuantity).toBe(5);
  });
});

test('a paid token cannot mark another same-price order as paid', async () => {
  const { order: a } = await createAwaitingOrder();
  const { order: b } = await createAwaitingOrder();
  iyzicoService.retrieveCheckoutForm.mockResolvedValueOnce(successResult(90, a));
  const result = await finalizeService.finalize({ token: a.paymentToken, conversationId: b.conversationId });
  expect(result.outcome).toBe('unknown');
  expect((await b.reload()).paymentStatus).toBe('pending');
  expect(iyzicoService.refundItem).not.toHaveBeenCalled();
});

test('mismatched item or basket is rejected before any money or stock mutation', async () => {
  const { order } = await createAwaitingOrder();
  const result = successResult(90, order);
  result.itemTransactions[0].itemId = crypto.randomUUID();
  expect((await finalizeService.finalize({ retrieveResult: result, conversationId: order.conversationId })).outcome).toBe('unknown');
  expect((await order.reload()).paymentStatus).toBe('pending');
});

test('even a one-kurus mismatch cannot pass because of floating point rounding', async () => {
  const { order } = await createAwaitingOrder({ finalPrice: 90.02 });
  expect((await finalizeService.finalize({ retrieveResult: successResult(90.01, order) })).outcome).toBe('amount_mismatch');
  expect((await order.reload()).paymentStatus).toBe('refunded');
});

test('fraud review cannot deliver or expire a captured payment', async () => {
  const { order, pkg } = await createAwaitingOrder();
  const result = { ...successResult(90, order), fraudStatus: 0 };
  expect((await finalizeService.finalize({ retrieveResult: result, conversationId: order.conversationId })).outcome).toBe('review');
  expect((await order.reload()).status).toBe('awaiting_payment');
  expect(order.fraudReview).toBe(true);
  expect(await finalizeService.expireUnpaidHold(order.id)).toBe(false);
  expect((await pkg.reload()).remainingQuantity).toBe(4);
  result.fraudStatus = 1;
  expect((await finalizeService.finalize({ retrieveResult: result, conversationId: order.conversationId })).outcome).toBe('paid');
});

test('an unauthenticated fabricated 3DS failure cannot cancel a reservation', async () => {
  const { order, pkg } = await createAwaitingOrder();
  await order.update({ paymentToken: null, paymentId: 'stored-3ds-payment' });
  const res = await request(app).post('/api/payments/iyzico/3ds-callback').type('form').send({ conversationId: order.conversationId, status: 'failure', mdStatus: '0' });
  expect(res.status).toBe(302);
  expect((await order.reload()).status).toBe('awaiting_payment');
  expect((await pkg.reload()).remainingQuantity).toBe(4);
  expect(iyzicoService.completeThreeDS).not.toHaveBeenCalled();
});

test('lookup failure is not treated as proof of a failed payment', async () => {
  const { order } = await createAwaitingOrder();
  iyzicoService.retrieveCheckoutForm.mockResolvedValueOnce({ status: 'failure', errorMessage: 'not found yet' });
  expect((await finalizeService.finalize({ token: order.paymentToken })).outcome).toBe('pending');
  expect((await order.reload()).status).toBe('awaiting_payment');
});

test('late payment refund timeout persists evidence and cannot trigger a duplicate refund', async () => {
  const { order } = await createAwaitingOrder();
  await finalizeService.expireUnpaidHold(order.id);
  iyzicoService.refundItem.mockRejectedValueOnce(new Error('network timeout'));
  const args = { retrieveResult: successResult(90, order), conversationId: order.conversationId };
  expect((await finalizeService.finalize(args)).outcome).toBe('refund_pending');
  await order.reload();
  expect(order.refundStatus).toBe('review');
  expect(order.paymentStatus).toBe('paid');
  expect(order.paymentTransactionId).toBeTruthy();
  await finalizeService.finalize(args);
  await settlementService.retryPendingRefunds();
  expect(iyzicoService.refundItem).toHaveBeenCalledTimes(1);
});

test('lost callbacks after cancellation are recovered by reconciliation', async () => {
  const { order } = await createAwaitingOrder();
  await finalizeService.expireUnpaidHold(order.id);
  iyzicoService.retrieveCheckoutForm.mockResolvedValueOnce(successResult(90, order));
  await finalizeService.reconcileCancelledPayments();
  await order.reload();
  expect(order.paymentStatus).toBe('refunded');
  expect(order.paymentCheckedAt).toBeTruthy();
  expect(iyzicoService.refundItem).toHaveBeenCalledTimes(1);
});

test('cancelled fraud-review payments wait for approval before refunding', async () => {
  const { order } = await createAwaitingOrder();
  await finalizeService.finalize({ retrieveResult: { ...successResult(90, order), fraudStatus: 0 } });
  await cancelOrder(order.id);
  expect((await order.reload()).refundStatus).toBe('review');
  expect(iyzicoService.refundItem).not.toHaveBeenCalled();
  await finalizeService.finalize({ retrieveResult: successResult(90, order) });
  expect((await order.reload()).paymentStatus).toBe('refunded');
  expect(iyzicoService.refundItem).toHaveBeenCalledTimes(1);
});

test('delivery and concurrent cancellation cannot race a refund', async () => {
  const { order, pkg } = await createAwaitingOrder();
  await finalizeService.finalize({ retrieveResult: successResult(90, order), conversationId: order.conversationId });
  await order.reload();
  await order.update({ status: 'confirmed' });
  const business = await pkg.getBusiness();
  const owner = await business.getOwner();
  let completeRefund;
  let started;
  const providerStarted = new Promise(resolve => { started = resolve; });
  iyzicoService.refundItem.mockImplementationOnce(() => {
    started();
    return new Promise(resolve => { completeRefund = resolve; });
  });
  const cancellation = cancelOrder(order.id);
  await providerStarted;
  const delivered = await request(app).patch(`/api/orders/${order.id}/status`).set(authHeader(owner)).send({ status: 'picked_up' });
  expect(delivered.status).toBe(400);
  await cancelOrder(order.id); // retry while provider request is still in flight
  expect(iyzicoService.refundItem).toHaveBeenCalledTimes(1);
  completeRefund({ status: 'success' });
  await cancellation;
  expect((await order.reload()).paymentStatus).toBe('refunded');
  expect((await pkg.reload()).remainingQuantity).toBe(5);
  expect(iyzicoService.approveItem).not.toHaveBeenCalled();
});

test('database rejects the same provider payment on two different orders', async () => {
  const { order: a } = await createAwaitingOrder();
  const { order: b } = await createAwaitingOrder();
  await a.update({ paymentId: 'unique-provider-payment' });
  await expect(b.update({ paymentId: 'unique-provider-payment' })).rejects.toMatchObject({ name: 'SequelizeUniqueConstraintError' });
});

test.each(['direct', 'hpp'])('webhook V3 validates the official %s signing format', async (format) => {
  process.env.IYZICO_SECRET_KEY = 'synthetic-webhook-secret';
  const payload = { iyziEventType: 'API_AUTH', paymentId: 123, paymentConversationId: 'test-conversation', status: 'SUCCESS' };
  let values = [payload.iyziEventType, payload.paymentId, payload.paymentConversationId, payload.status];
  if (format === 'hpp') {
    payload.token = 'checkout-token'; payload.iyziPaymentId = 123; payload.iyziEventType = 'CHECKOUT_FORM_AUTH';
    values = [payload.iyziEventType, payload.iyziPaymentId, payload.token, payload.paymentConversationId, payload.status];
  }
  const signature = crypto.createHmac('sha256', process.env.IYZICO_SECRET_KEY)
    .update(process.env.IYZICO_SECRET_KEY + values.join('')).digest('hex');
  const raw = Buffer.from(JSON.stringify(payload));
  expect(iyzicoService.verifyWebhookSignature(raw, signature).valid).toBe(true);
  expect(iyzicoService.verifyWebhookSignature(raw, 'bad').valid).toBe(false);
  payload.status = 'FAILURE';
  expect(iyzicoService.verifyWebhookSignature(Buffer.from(JSON.stringify(payload)), signature).valid).toBe(false);
});

test('unsigned webhook is rejected even when the old optional flag is false', async () => {
  process.env.IYZICO_WEBHOOK_ENFORCE = 'false';
  const res = await request(app).post('/api/payments/iyzico/webhook').send({ paymentConversationId: 'forged' });
  expect(res.status).toBe(401);
  expect(iyzicoService.retrievePayment).not.toHaveBeenCalled();
});

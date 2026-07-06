// paymentFinalizeService.finalize'ı doğrudan test eder (iyzico retrieve OTORİTE
// sonucu mock'lanır). Ödeme kesinleştirmenin idempotency + tutar bütünlüğü mantığı.
jest.mock('../src/services/iyzicoService', () => ({
  refundItem: jest.fn().mockResolvedValue({}),
  retrieveCheckoutForm: jest.fn(),
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
    paymentProvider: 'iyzico',
    status: 'awaiting_payment',
    paymentStatus: 'pending',
    settlementStatus: 'none',
    paymentHoldExpiresAt: new Date(Date.now() + 20 * 60 * 1000),
  });
  return { order, pkg };
}

function successResult(paidPrice) {
  return {
    status: 'success',
    paymentStatus: 'SUCCESS',
    fraudStatus: 1,
    currency: 'TRY',
    paidPrice,
    paymentId: 'pay_1',
    itemTransactions: [{ paymentTransactionId: 'ptx_1' }],
  };
}

describe('paymentFinalizeService.finalize', () => {
  test('SUCCESS + doğru tutar -> paid', async () => {
    const { order } = await createAwaitingOrder({ finalPrice: 90 });
    const res = await finalizeService.finalize({
      conversationId: order.conversationId,
      retrieveResult: successResult(90),
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
      retrieveResult: successResult(90),
      source: 'test',
    });
    expect(first.outcome).toBe('paid');

    const second = await finalizeService.finalize({
      conversationId: order.conversationId,
      retrieveResult: successResult(90),
      source: 'test',
    });
    expect(second.outcome).toBe('already_paid');
  });

  test('tutar uyuşmazlığı -> amount_mismatch, iptal + stok iadesi + refund çağrısı', async () => {
    const { order, pkg } = await createAwaitingOrder({ finalPrice: 90, remainingQuantity: 4 });
    const res = await finalizeService.finalize({
      conversationId: order.conversationId,
      retrieveResult: successResult(45), // beklenen 90, gelen 45
      source: 'test',
    });
    expect(res.outcome).toBe('amount_mismatch');

    const fresh = await Order.findByPk(order.id);
    expect(fresh.status).toBe('cancelled');
    expect(fresh.paymentStatus).toBe('failed');
    expect(iyzicoService.refundItem).toHaveBeenCalledTimes(1);

    const freshPkg = await SurprisePackage.findByPk(pkg.id);
    expect(freshPkg.remainingQuantity).toBe(5); // 4 + iade edilen 1
  });

  test('terminal FAILURE -> failed, stok iadesi', async () => {
    const { order, pkg } = await createAwaitingOrder({ finalPrice: 90, remainingQuantity: 4 });
    const res = await finalizeService.finalize({
      conversationId: order.conversationId,
      retrieveResult: { status: 'success', paymentStatus: 'FAILURE', currency: 'TRY' },
      source: 'test',
    });
    expect(res.outcome).toBe('failed');
    const fresh = await Order.findByPk(order.id);
    expect(fresh.status).toBe('cancelled');
    const freshPkg = await SurprisePackage.findByPk(pkg.id);
    expect(freshPkg.remainingQuantity).toBe(5);
  });
});

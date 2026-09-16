const { Coupon, Order, Business, SurprisePackage, sequelize } = require('../models');
const { Op, Sequelize } = require('sequelize');
const { paginate, paginatedResponse } = require('../utils/helpers');
const coupons = require('../services/couponService');
const { couponSettingsSchema } = require('../validations/coupons');

exports.getAll = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query);
    const where = req.query.active === 'true' ? { isActive: true, expiresAt: { [Op.gt]: new Date() },
      currentUsage: { [Op.lt]: Sequelize.col('maxUsage') } } : {};
    const { count, rows } = await Coupon.findAndCountAll({ where, order: [['createdAt', 'DESC']], limit, offset });
    const usage = await coupons.usageMany(rows.map((coupon) => coupon.id));
    const data = rows.map((coupon) => ({ ...coupon.toJSON(), ...usage.get(coupon.id) }));
    res.json(paginatedResponse(data, count, page, limit));
  } catch (error) { next(error); }
};

exports.getById = async (req, res, next) => {
  try {
    const coupon = await Coupon.findByPk(req.params.id);
    if (!coupon) throw coupons.problem('Kupon bulunamadı', 404);
    res.json({ coupon: { ...coupon.toJSON(), ...await coupons.usage(coupon.id) } });
  } catch (error) { next(error); }
};

exports.mine = async (req, res, next) => {
  try {
    const rows = await Coupon.findAll({ where: { isActive: true, isDiscoverable: true,
      expiresAt: { [Op.gt]: new Date() } }, order: [['firstOrderOnly', 'DESC'], ['expiresAt', 'ASC']], limit: 100 });
    const eligibility = await coupons.eligibilityForMany(rows, req.user.id);
    const data = rows.map((coupon, index) => ({ ...coupons.present(coupon), ...eligibility[index] }));
    const [stats] = await sequelize.query(`SELECT
      COALESCE(SUM(quantity), 0)::int AS "rescuedPackages",
      COALESCE(SUM(GREATEST(COALESCE("originalTotal", "totalPrice") - "finalPrice", 0)), 0) AS "totalSaved"
      FROM "Orders" WHERE "userId" = :userId AND status = 'picked_up'
      AND "paymentStatus" IN ('paid', 'unpaid')`, { replacements: { userId: req.user.id }, type: Sequelize.QueryTypes.SELECT });
    res.json({ coupons: data, savings: { rescuedPackages: stats.rescuedPackages, totalSaved: Number(stats.totalSaved) } });
  } catch (error) { next(error); }
};

exports.validate = async (req, res, next) => {
  try {
    const { code, packageId, quantity = 1, orderAmount } = req.body;
    const coupon = await Coupon.findOne({ where: { code: code.trim().toUpperCase() } });
    const pkg = packageId ? await SurprisePackage.findByPk(packageId) : null;
    if (packageId && !pkg) throw coupons.problem('Paket bulunamadı', 404);
    if (coupon?.businessIds.length && !pkg) throw coupons.problem('Kuponu kullanmak için bir paket seçin');
    const quote = await coupons.check(coupon, req.user.id, {
      total: pkg ? coupons.cents(pkg.discountedPrice) * quantity / 100 : orderAmount, businessId: pkg?.businessId,
    });
    res.json({ valid: true, coupon: coupons.present(coupon), ...quote });
  } catch (error) { next(error); }
};

exports.packages = async (req, res, next) => {
  try {
    const coupon = await Coupon.findByPk(req.params.id);
    if (!coupon?.isDiscoverable) throw coupons.problem('Kampanya bulunamadı', 404);
    await coupons.check(coupon, req.user.id);
    req.campaign = coupon;
    return require('./packageController').getAll(req, res, next);
  } catch (error) { next(error); }
};

const validateSettings = async (input, transaction) => {
  const parsed = couponSettingsSchema.safeParse(input);
  if (!parsed.success) throw coupons.problem(parsed.error.issues[0].message);
  const values = parsed.data;
  if (values.businessIds.length) {
    const found = await Business.count({ where: { id: values.businessIds }, transaction });
    if (found !== values.businessIds.length) throw coupons.problem('Seçili işletmelerden biri artık mevcut değil');
  }
  return values;
};

exports.create = async (req, res, next) => {
  try {
    const values = await validateSettings(req.body);
    if (await Coupon.findOne({ where: { code: values.code } })) throw coupons.problem('Bu kupon kodu zaten kullanımda', 409);
    const coupon = await Coupon.create(values);
    res.status(201).json({ message: 'Kupon oluşturuldu', coupon });
  } catch (error) { next(error); }
};

exports.update = async (req, res, next) => {
  try {
    const coupon = await sequelize.transaction(async (transaction) => {
      const current = await Coupon.findByPk(req.params.id, { transaction, lock: true });
      if (!current) throw coupons.problem('Kupon bulunamadı', 404);
      const values = await validateSettings({ ...current.toJSON(), ...req.body, code: current.code }, transaction);
      const used = await Order.count({ where: { couponId: current.id }, paranoid: false, transaction });
      if (used) {
        const before = couponSettingsSchema.parse(current.toJSON());
        for (const key of ['discountType', 'discountValue', 'minOrderAmount', 'maxDiscountAmount', 'firstOrderOnly', 'perUserLimit', 'businessIds']) {
          if (JSON.stringify(values[key]) !== JSON.stringify(before[key])) {
            throw coupons.problem('Kullanılmış kampanyanın indirim ve katılım koşulları değiştirilemez; yeni kupon oluşturun', 409);
          }
        }
      }
      const budgetUsed = await coupons.budgetUsed(current.id, transaction);
      if (values.maxUsage < current.currentUsage || (values.budgetLimit != null && coupons.cents(values.budgetLimit) < coupons.cents(budgetUsed))) {
        throw coupons.problem('Limitler ayrılmış kullanım veya bütçenin altına indirilemez');
      }
      return current.update(values, { transaction });
    });
    res.json({ message: 'Kupon güncellendi', coupon });
  } catch (error) { next(error); }
};

exports.remove = async (req, res, next) => {
  try {
    const coupon = await Coupon.findByPk(req.params.id);
    if (!coupon) throw coupons.problem('Kupon bulunamadı', 404);
    await coupon.update({ isActive: false, isDiscoverable: false });
    res.json({ message: 'Kupon arşivlendi' });
  } catch (error) { next(error); }
};

const { User, Business, Order, SurprisePackage, Review } = require('../models');
const { Op } = require('sequelize');
const { paginate, paginatedResponse } = require('../utils/helpers');

// Dashboard Statistics
exports.getDashboardStats = async (req, res, next) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [
      totalUsers,
      totalBusinesses,
      totalOrders,
      totalPackages,
      pendingBusinesses,
      todayOrders,
      todayRevenue,
    ] = await Promise.all([
      User.count(),
      Business.count(),
      Order.count(),
      SurprisePackage.count(),
      Business.count({ where: { isApproved: false } }),
      Order.count({ where: { createdAt: { [Op.gte]: today } } }),
      Order.sum('totalPrice', { where: { createdAt: { [Op.gte]: today } } }),
    ]);

    res.json({
      stats: {
        totalUsers,
        totalBusinesses,
        totalOrders,
        totalPackages,
        pendingBusinesses,
        todayOrders,
        todayRevenue: todayRevenue || 0,
      },
    });
  } catch (error) {
    next(error);
  }
};

// User Management
exports.getAllUsers = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query);
    const { search, role } = req.query;

    const where = {};
    if (search) {
      where[Op.or] = [
        { name: { [Op.iLike]: `%${search}%` } },
        { email: { [Op.iLike]: `%${search}%` } },
      ];
    }
    if (role) where.role = role;

    const { count, rows: users } = await User.findAndCountAll({
      where,
      attributes: { exclude: ['password', 'emailVerificationToken', 'passwordResetToken', 'passwordResetExpires'] },
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json(paginatedResponse(users, count, page, limit));
  } catch (error) {
    next(error);
  }
};

exports.getUserById = async (req, res, next) => {
  try {
    const user = await User.findByPk(req.params.id, {
      attributes: { exclude: ['password', 'emailVerificationToken', 'passwordResetToken', 'passwordResetExpires'] },
      include: [
        { model: Business, as: 'businesses' },
        { model: Order, as: 'orders', limit: 5 },
      ],
    });

    if (!user) {
      return res.status(404).json({ message: 'Kullanıcı bulunamadı' });
    }

    res.json({ user });
  } catch (error) {
    next(error);
  }
};

exports.updateUser = async (req, res, next) => {
  try {
    const user = await User.findByPk(req.params.id);

    if (!user) {
      return res.status(404).json({ message: 'Kullanıcı bulunamadı' });
    }

    const { name, phone, role, isEmailVerified } = req.body;

    await user.update({ name, phone, role, isEmailVerified });

    res.json({
      message: 'Kullanıcı güncellendi',
      user,
    });
  } catch (error) {
    next(error);
  }
};

exports.deleteUser = async (req, res, next) => {
  try {
    const user = await User.findByPk(req.params.id);

    if (!user) {
      return res.status(404).json({ message: 'Kullanıcı bulunamadı' });
    }

    if (user.id === req.user.id) {
      return res.status(400).json({ message: 'Kendi hesabınızı silemezsiniz' });
    }

    await user.destroy();

    res.json({ message: 'Kullanıcı silindi' });
  } catch (error) {
    next(error);
  }
};

// Business Approval
exports.getPendingBusinesses = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query);

    const { count, rows: businesses } = await Business.findAndCountAll({
      where: { isApproved: false },
      include: [
        { model: User, as: 'owner', attributes: ['id', 'name', 'email'] },
        { model: require('../models/Category'), as: 'category', attributes: ['id', 'name'] },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json(paginatedResponse(businesses, count, page, limit));
  } catch (error) {
    next(error);
  }
};

exports.approveBusiness = async (req, res, next) => {
  try {
    const business = await Business.findByPk(req.params.id);

    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı' });
    }

    await business.update({ isApproved: true, approvalStatus: 'approved', approvedAt: new Date() });

    res.json({
      message: 'İşletme onaylandı',
      business,
    });
  } catch (error) {
    next(error);
  }
};

exports.rejectBusiness = async (req, res, next) => {
  try {
    const business = await Business.findByPk(req.params.id);

    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı' });
    }

    await business.update({ isApproved: false, approvalStatus: 'rejected', rejectedAt: new Date() });

    res.json({
      message: 'İşletme reddedildi',
      business,
    });
  } catch (error) {
    next(error);
  }
};

// Order Management
exports.getAllOrders = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query);
    const { status, startDate, endDate } = req.query;

    const where = {};
    if (status) where.status = status;
    if (startDate && endDate) {
      where.createdAt = {
        [Op.between]: [new Date(startDate), new Date(endDate)],
      };
    }

    const { count, rows: orders } = await Order.findAndCountAll({
      where,
      include: [
        {
          model: SurprisePackage,
          as: 'package',
          include: [{ model: Business, as: 'business', attributes: ['id', 'name'] }],
        },
        { model: User, as: 'user', attributes: ['id', 'name', 'email'] },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json(paginatedResponse(orders, count, page, limit));
  } catch (error) {
    next(error);
  }
};

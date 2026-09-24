const { Favorite, Business, Category, SurprisePackage } = require('../models');
const { paginate, paginatedResponse } = require('../utils/helpers');
const { availablePackageWhere, AVAILABILITY_ATTRIBUTES } = require('../utils/packageAvailability');

exports.getAll = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query);

    const { count, rows: favorites } = await Favorite.findAndCountAll({
      where: { userId: req.user.id },
      include: [
        {
          model: Business,
          as: 'business',
          where: { isActive: true, isApproved: true, isSuspended: false },
          attributes: ['id', 'name', 'address', 'city', 'district', 'imageUrl', 'rating'],
          include: [
            { model: Category, as: 'category', attributes: ['id', 'name', 'slug'] },
            // Keep the saved relationship while the business has no offers.
            // A separate query keeps favorite pagination/counts unduplicated.
            { model: SurprisePackage, as: 'packages', separate: true,
              attributes: AVAILABILITY_ATTRIBUTES, where: availablePackageWhere() },
          ],
        },
      ],
      order: [['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json(paginatedResponse(favorites, count, page, limit));
  } catch (error) {
    next(error);
  }
};

exports.add = async (req, res, next) => {
  try {
    const { businessId } = req.body;

    const existing = await Favorite.findOne({
      where: { userId: req.user.id, businessId },
    });

    if (existing) {
      return res.status(409).json({ message: 'Bu işletme zaten favorilerinizde' });
    }

    const favorite = await Favorite.create({
      userId: req.user.id,
      businessId,
    });

    res.status(201).json({
      message: 'Favorilere eklendi',
      favorite,
    });
  } catch (error) {
    next(error);
  }
};

exports.remove = async (req, res, next) => {
  try {
    const { businessId } = req.params;

    const favorite = await Favorite.findOne({
      where: { userId: req.user.id, businessId },
    });

    if (!favorite) {
      return res.status(404).json({ message: 'Favori bulunamadı' });
    }

    await favorite.destroy();

    res.json({ message: 'Favorilerden kaldırıldı' });
  } catch (error) {
    next(error);
  }
};

exports.check = async (req, res, next) => {
  try {
    const { businessId } = req.params;

    const favorite = await Favorite.findOne({
      where: { userId: req.user.id, businessId },
    });

    res.json({ isFavorite: !!favorite });
  } catch (error) {
    next(error);
  }
};

const { Op } = require('sequelize');
const { Category, Business } = require('../models');
const auditService = require('../services/auditService');
const cacheService = require('../services/cacheService');

// Türkçe karakterleri sadeleştirip URL-dostu slug üret.
const slugify = (s) =>
  String(s || '')
    .toLowerCase()
    .trim()
    .replace(/ı/g, 'i').replace(/ş/g, 's').replace(/ğ/g, 'g')
    .replace(/ü/g, 'u').replace(/ö/g, 'o').replace(/ç/g, 'c')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

exports.create = async (req, res, next) => {
  try {
    const { name } = req.body;
    const slug = slugify(req.body.slug || name);

    const existing = await Category.findOne({ where: { [Op.or]: [{ name }, { slug }] } });
    if (existing) {
      return res.status(409).json({ message: 'Bu kategori adı veya slug zaten kullanılıyor' });
    }

    const category = await Category.create({ name, slug });
    await auditService.record({
      req, action: 'category.create', targetType: 'category', targetId: category.id, metadata: { name, slug },
    });
    await cacheService.delPattern('businesses:list:*');

    res.status(201).json({ message: 'Kategori oluşturuldu', category });
  } catch (error) {
    next(error);
  }
};

exports.update = async (req, res, next) => {
  try {
    const category = await Category.findByPk(req.params.id);
    if (!category) {
      return res.status(404).json({ message: 'Kategori bulunamadı' });
    }

    const updates = {};
    if (req.body.name !== undefined) updates.name = req.body.name;
    if (req.body.slug !== undefined) updates.slug = slugify(req.body.slug);

    if (updates.name || updates.slug) {
      const orClauses = [];
      if (updates.name) orClauses.push({ name: updates.name });
      if (updates.slug) orClauses.push({ slug: updates.slug });
      const clash = await Category.findOne({
        where: { id: { [Op.ne]: category.id }, [Op.or]: orClauses },
      });
      if (clash) {
        return res.status(409).json({ message: 'Bu kategori adı veya slug zaten kullanılıyor' });
      }
    }

    await category.update(updates);
    await auditService.record({
      req, action: 'category.update', targetType: 'category', targetId: category.id, metadata: updates,
    });
    await cacheService.delPattern('businesses:list:*');

    res.json({ message: 'Kategori güncellendi', category });
  } catch (error) {
    next(error);
  }
};

exports.remove = async (req, res, next) => {
  try {
    const category = await Category.findByPk(req.params.id);
    if (!category) {
      return res.status(404).json({ message: 'Kategori bulunamadı' });
    }

    const inUse = await Business.count({ where: { categoryId: category.id } });
    if (inUse > 0) {
      return res.status(409).json({ message: `Bu kategoriye bağlı ${inUse} işletme var, silinemez` });
    }

    await category.destroy();
    await auditService.record({
      req, action: 'category.delete', targetType: 'category', targetId: category.id, metadata: { name: category.name },
    });
    await cacheService.delPattern('businesses:list:*');

    res.json({ message: 'Kategori silindi' });
  } catch (error) {
    next(error);
  }
};

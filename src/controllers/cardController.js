const { User } = require('../models');
const iyzicoService = require('../services/iyzicoService');
const logger = require('../services/logger');

// Client'a dönen maskeli kart görünümü — cardUserKey ve PAN asla dönmez.
const toCardDto = (c) => ({
  cardToken: c.cardToken,
  cardAlias: c.cardAlias || null,
  binNumber: c.binNumber || null,
  lastFourDigits: c.lastFourDigits || null,
  cardAssociation: c.cardAssociation || null,
  cardFamily: c.cardFamily || null,
  cardBankName: c.cardBankName || null,
});

exports.list = async (req, res, next) => {
  try {
    const user = await User.findByPk(req.user.id);
    if (!user?.cardUserKey) {
      return res.json({ cards: [] });
    }
    const cards = await iyzicoService.listCards(user.cardUserKey, user.id);
    res.json({ cards: cards.map(toCardDto) });
  } catch (error) {
    logger.error(`[cards] listeleme başarısız (user ${req.user.id}): ${error.message}`);
    res.status(502).json({ message: 'Kartlar alınamadı, lütfen tekrar deneyin' });
  }
};

exports.create = async (req, res, next) => {
  try {
    // req.user snapshot'ı bayat olabilir — cardUserKey için fresh yükle.
    const user = await User.findByPk(req.user.id);
    const { cardHolderName, cardNumber, expireMonth, expireYear, cardAlias } = req.body;

    let result;
    try {
      result = await iyzicoService.createCard({
        user,
        card: {
          cardHolderName,
          cardNumber,
          expireMonth,
          expireYear,
          ...(cardAlias ? { cardAlias } : {}),
        },
      });
    } catch (e) {
      // iyzico hata detayı BIN geçerliliği sızdırabilir — generic mesaj dön.
      return res.status(502).json({ message: 'Kart kaydedilemedi, bilgilerinizi kontrol edip tekrar deneyin' });
    }

    if (!user.cardUserKey && result.cardUserKey) {
      // İki eşzamanlı "ilk kart" kaydına karşı guarded update: yalnız hâlâ boşsa yaz.
      await User.update(
        { cardUserKey: result.cardUserKey },
        { where: { id: user.id, cardUserKey: null } }
      );
    }

    res.status(201).json({ message: 'Kart kaydedildi', card: toCardDto(result) });
  } catch (error) {
    next(error);
  }
};

exports.remove = async (req, res, next) => {
  try {
    const user = await User.findByPk(req.user.id);
    if (!user?.cardUserKey) {
      return res.status(404).json({ message: 'Kayıtlı kart bulunamadı' });
    }
    try {
      await iyzicoService.deleteCard(user.cardUserKey, req.params.cardToken, user.id);
    } catch (e) {
      // iyzico "kart bulunamadı" → 404; diğer hatalar → 502
      if (/bulunamadı|not found/i.test(e.message || '')) {
        return res.status(404).json({ message: 'Kayıtlı kart bulunamadı' });
      }
      logger.error(`[cards] silme başarısız (user ${user.id}): ${e.message}`);
      return res.status(502).json({ message: 'Kart silinemedi, lütfen tekrar deneyin' });
    }
    res.json({ message: 'Kart silindi' });
  } catch (error) {
    next(error);
  }
};

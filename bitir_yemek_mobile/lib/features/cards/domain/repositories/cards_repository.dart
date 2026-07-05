import '../../data/models/saved_card_model.dart';

abstract class CardsRepository {
  Future<List<SavedCardModel>> getCards();
  Future<SavedCardModel> addCard({
    required String cardHolderName,
    required String cardNumber,
    required String expireMonth,
    required String expireYear,
    String? cardAlias,
  });
  Future<void> deleteCard(String cardToken);
}

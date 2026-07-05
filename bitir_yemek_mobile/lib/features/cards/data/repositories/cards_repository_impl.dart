import '../../domain/repositories/cards_repository.dart';
import '../datasources/cards_remote_datasource.dart';
import '../models/saved_card_model.dart';

// Kart listesi CACHE'LENMEZ — kartlar iyzico'da yaşar, liste her zaman canlı çekilir.
class CardsRepositoryImpl implements CardsRepository {
  final CardsRemoteDataSource _remoteDataSource;

  CardsRepositoryImpl({required CardsRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  @override
  Future<List<SavedCardModel>> getCards() async {
    try {
      final cards = await _remoteDataSource.getCards();
      return cards.map(SavedCardModel.fromJson).toList();
    } on CardsException {
      rethrow;
    } catch (e) {
      throw CardsException(message: 'Kartlar yuklenirken bir hata olustu');
    }
  }

  @override
  Future<SavedCardModel> addCard({
    required String cardHolderName,
    required String cardNumber,
    required String expireMonth,
    required String expireYear,
    String? cardAlias,
  }) async {
    try {
      final data = await _remoteDataSource.addCard(
        cardHolderName: cardHolderName,
        cardNumber: cardNumber,
        expireMonth: expireMonth,
        expireYear: expireYear,
        cardAlias: cardAlias,
      );
      return SavedCardModel.fromJson(data['card'] as Map<String, dynamic>);
    } on CardsException {
      rethrow;
    } catch (e) {
      throw CardsException(message: 'Kart kaydedilirken bir hata olustu');
    }
  }

  @override
  Future<void> deleteCard(String cardToken) async {
    try {
      await _remoteDataSource.deleteCard(cardToken);
    } on CardsException {
      rethrow;
    } catch (e) {
      throw CardsException(message: 'Kart silinirken bir hata olustu');
    }
  }
}

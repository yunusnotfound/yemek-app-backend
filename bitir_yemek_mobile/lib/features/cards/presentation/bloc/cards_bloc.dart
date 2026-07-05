import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/saved_card_model.dart';
import '../../domain/repositories/cards_repository.dart';

part 'cards_event.dart';
part 'cards_state.dart';

class CardsBloc extends Bloc<CardsEvent, CardsState> {
  final CardsRepository _repository;
  List<SavedCardModel> _cards = [];

  CardsBloc({required CardsRepository repository})
    : _repository = repository,
      super(const CardsInitial()) {
    on<LoadCards>(_onLoadCards);
    on<AddCard>(_onAddCard);
    on<DeleteCard>(_onDeleteCard);
  }

  Future<void> _onLoadCards(LoadCards event, Emitter<CardsState> emit) async {
    if (!event.silent) emit(const CardsLoading());
    try {
      _cards = await _repository.getCards();
      emit(CardsLoaded(cards: _cards));
    } catch (e) {
      emit(CardsError(message: e.toString()));
    }
  }

  Future<void> _onAddCard(AddCard event, Emitter<CardsState> emit) async {
    emit(CardAdding(cards: _cards));
    try {
      final card = await _repository.addCard(
        cardHolderName: event.cardHolderName,
        cardNumber: event.cardNumber,
        expireMonth: event.expireMonth,
        expireYear: event.expireYear,
        cardAlias: event.cardAlias,
      );
      _cards = [card, ..._cards];
      emit(CardAdded(card: card));
      emit(CardsLoaded(cards: _cards));
    } catch (e) {
      emit(CardActionError(message: e.toString()));
      emit(CardsLoaded(cards: _cards));
    }
  }

  Future<void> _onDeleteCard(DeleteCard event, Emitter<CardsState> emit) async {
    // Optimistik silme: hata olursa geri alınır.
    final previous = _cards;
    _cards = _cards.where((c) => c.cardToken != event.cardToken).toList();
    emit(CardsLoaded(cards: _cards));
    try {
      await _repository.deleteCard(event.cardToken);
    } catch (e) {
      _cards = previous;
      emit(CardActionError(message: e.toString()));
      emit(CardsLoaded(cards: _cards));
    }
  }
}

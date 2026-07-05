part of 'cards_bloc.dart';

abstract class CardsState extends Equatable {
  const CardsState();

  @override
  List<Object?> get props => [];
}

class CardsInitial extends CardsState {
  const CardsInitial();
}

class CardsLoading extends CardsState {
  const CardsLoading();
}

class CardsLoaded extends CardsState {
  final List<SavedCardModel> cards;

  const CardsLoaded({required this.cards});

  @override
  List<Object?> get props => [cards];
}

class CardsError extends CardsState {
  final String message;

  const CardsError({required this.message});

  @override
  List<Object?> get props => [message];
}

class CardAdding extends CardsState {
  final List<SavedCardModel> cards;

  const CardAdding({required this.cards});

  @override
  List<Object?> get props => [cards];
}

class CardAdded extends CardsState {
  final SavedCardModel card;

  const CardAdded({required this.card});

  @override
  List<Object?> get props => [card];
}

class CardActionError extends CardsState {
  final String message;

  const CardActionError({required this.message});

  @override
  List<Object?> get props => [message];
}

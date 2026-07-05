part of 'cards_bloc.dart';

abstract class CardsEvent extends Equatable {
  const CardsEvent();

  @override
  List<Object?> get props => [];
}

class LoadCards extends CardsEvent {
  /// true ise Loading emit edilmez (arka planda sessiz yenileme).
  final bool silent;

  const LoadCards({this.silent = false});

  @override
  List<Object?> get props => [silent];
}

class AddCard extends CardsEvent {
  final String cardHolderName;
  final String cardNumber;
  final String expireMonth;
  final String expireYear;
  final String? cardAlias;

  const AddCard({
    required this.cardHolderName,
    required this.cardNumber,
    required this.expireMonth,
    required this.expireYear,
    this.cardAlias,
  });

  @override
  List<Object?> get props => [
    cardHolderName,
    cardNumber,
    expireMonth,
    expireYear,
    cardAlias,
  ];
}

class DeleteCard extends CardsEvent {
  final String cardToken;

  const DeleteCard({required this.cardToken});

  @override
  List<Object?> get props => [cardToken];
}

part of 'reservation_bloc.dart';

abstract class ReservationEvent extends Equatable {
  const ReservationEvent();

  @override
  List<Object?> get props => [];
}

class CreateReservation extends ReservationEvent {
  final String packageId;
  final int quantity;
  final String? couponCode;

  /// Native 3DS ödemesi için kart seçimi: {savedCardToken} veya
  /// {cardHolderName, cardNumber, expireMonth, expireYear, cvc, saveCard}.
  /// null ise backend eski Checkout Form akışına düşer.
  final Map<String, dynamic>? paymentCard;

  const CreateReservation({
    required this.packageId,
    this.quantity = 1,
    this.couponCode,
    this.paymentCard,
  });

  @override
  List<Object?> get props => [packageId, quantity, couponCode, paymentCard];
}

class ValidateCoupon extends ReservationEvent {
  final String code;
  final double orderTotal;

  const ValidateCoupon({required this.code, required this.orderTotal});

  @override
  List<Object?> get props => [code, orderTotal];
}

class ClearCoupon extends ReservationEvent {
  const ClearCoupon();
}

class ResetReservation extends ReservationEvent {
  const ResetReservation();
}

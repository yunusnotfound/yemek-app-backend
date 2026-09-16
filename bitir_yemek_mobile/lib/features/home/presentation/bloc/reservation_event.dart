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
  final double? expectedFinalPrice;

  /// Native 3DS ödemesi için kart seçimi: {savedCardToken} veya
  /// {cardHolderName, cardNumber, expireMonth, expireYear, cvc, saveCard}.
  /// null ise backend eski Checkout Form akışına düşer.
  final Map<String, dynamic>? paymentCard;

  const CreateReservation({
    required this.packageId,
    this.quantity = 1,
    this.couponCode,
    this.expectedFinalPrice,
    this.paymentCard,
  });

  @override
  List<Object?> get props => [
    packageId,
    quantity,
    couponCode,
    paymentCard,
    expectedFinalPrice,
  ];
}

class ValidateCoupon extends ReservationEvent {
  final String code;
  final double orderTotal;
  final String? packageId;
  final int quantity;

  const ValidateCoupon({
    required this.code,
    required this.orderTotal,
    this.packageId,
    this.quantity = 1,
  });

  @override
  List<Object?> get props => [code, orderTotal, packageId, quantity];
}

class ClearCoupon extends ReservationEvent {
  const ClearCoupon();
}

class ResetReservation extends ReservationEvent {
  const ResetReservation();
}

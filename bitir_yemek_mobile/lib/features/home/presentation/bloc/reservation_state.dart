part of 'reservation_bloc.dart';

abstract class ReservationState extends Equatable {
  const ReservationState();

  @override
  List<Object?> get props => [];
}

class ReservationInitial extends ReservationState {
  const ReservationInitial();
}

class ReservationLoading extends ReservationState {
  const ReservationLoading();
}

class ReservationSuccess extends ReservationState {
  final ReservationModel reservation;
  final PaymentInit? payment;
  final String? message;

  const ReservationSuccess({required this.reservation, this.payment, this.message});

  @override
  List<Object?> get props => [reservation, payment, message];
}

class ReservationError extends ReservationState {
  final String message;

  const ReservationError({required this.message});

  @override
  List<Object?> get props => [message];
}

class CouponValidating extends ReservationState {
  const CouponValidating();
}

class CouponValidated extends ReservationState {
  final CouponModel coupon;
  final double discount;

  const CouponValidated({required this.coupon, required this.discount});

  @override
  List<Object?> get props => [coupon, discount];
}

class CouponError extends ReservationState {
  final String message;

  const CouponError({required this.message});

  @override
  List<Object?> get props => [message];
}

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/reservation_model.dart';
import '../../domain/repositories/businesses_repository.dart';

part 'reservation_event.dart';
part 'reservation_state.dart';

class ReservationBloc extends Bloc<ReservationEvent, ReservationState> {
  final BusinessesRepository _repository;

  ReservationBloc({required BusinessesRepository repository})
      : _repository = repository,
        super(const ReservationInitial()) {
    on<CreateReservation>(_onCreateReservation);
    on<ValidateCoupon>(_onValidateCoupon);
    on<ClearCoupon>(_onClearCoupon);
    on<ResetReservation>(_onResetReservation);
  }

  Future<void> _onCreateReservation(
    CreateReservation event,
    Emitter<ReservationState> emit,
  ) async {
    emit(const ReservationLoading());

    final result = await _repository.createReservation(
      packageId: event.packageId,
      quantity: event.quantity,
      couponCode: event.couponCode,
    );

    if (result.isSuccess) {
      emit(
        ReservationSuccess(
          reservation: result.reservation!,
          message: result.message,
        ),
      );
    } else {
      emit(ReservationError(message: result.error!));
    }
  }

  Future<void> _onValidateCoupon(
    ValidateCoupon event,
    Emitter<ReservationState> emit,
  ) async {
    emit(const CouponValidating());

    final result = await _repository.validateCoupon(code: event.code);

    if (result.isSuccess) {
      final coupon = result.coupon!;
      if (event.orderTotal < coupon.minOrderAmount) {
        emit(
          CouponError(
            message:
                'Minimum siparis tutari: ₺${coupon.minOrderAmount.toStringAsFixed(0)}',
          ),
        );
      } else {
        final discount = coupon.calculateDiscount(event.orderTotal);
        emit(CouponValidated(coupon: coupon, discount: discount));
      }
    } else {
      emit(CouponError(message: result.error!));
    }
  }

  void _onClearCoupon(ClearCoupon event, Emitter<ReservationState> emit) {
    emit(const ReservationInitial());
  }

  void _onResetReservation(
    ResetReservation event,
    Emitter<ReservationState> emit,
  ) {
    emit(const ReservationInitial());
  }
}

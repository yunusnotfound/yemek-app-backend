import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/reservation_model.dart';
import '../../domain/repositories/businesses_repository.dart';
import '../../../payment/data/models/payment_init_model.dart';

part 'reservation_event.dart';
part 'reservation_state.dart';

class ReservationBloc extends Bloc<ReservationEvent, ReservationState> {
  final BusinessesRepository _repository;
  int _couponGeneration = 0;

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
    if (state is ReservationLoading || state is ReservationSuccess) return;
    _couponGeneration++;
    emit(const ReservationLoading());

    final result = await _repository.createReservation(
      packageId: event.packageId,
      quantity: event.quantity,
      couponCode: event.couponCode,
      paymentCard: event.paymentCard,
      expectedFinalPrice: event.expectedFinalPrice,
    );

    if (emit.isDone) return;
    if (result.isSuccess) {
      emit(
        ReservationSuccess(
          reservation: result.reservation!,
          payment: result.payment,
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
    if (state is ReservationLoading) return;
    final generation = ++_couponGeneration;
    emit(const CouponValidating());

    final result = await _repository.validateCoupon(
      code: event.code,
      packageId: event.packageId,
      orderAmount: event.orderTotal,
      quantity: event.quantity,
    );

    if (emit.isDone || generation != _couponGeneration) return;
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
        final discount =
            result.discount ?? coupon.calculateDiscount(event.orderTotal);
        emit(CouponValidated(coupon: coupon, discount: discount));
      }
    } else {
      emit(CouponError(message: result.error!));
    }
  }

  void _onClearCoupon(ClearCoupon event, Emitter<ReservationState> emit) {
    _couponGeneration++;
    if (state is ReservationLoading) return;
    emit(const ReservationInitial());
  }

  void _onResetReservation(
    ResetReservation event,
    Emitter<ReservationState> emit,
  ) {
    _couponGeneration++;
    if (state is ReservationLoading) return;
    emit(const ReservationInitial());
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/payment_status_model.dart';
import '../../domain/repositories/payment_repository.dart';

part 'payment_event.dart';
part 'payment_state.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final PaymentRepository _repository;
  final String conversationId;

  PaymentBloc({required PaymentRepository repository, required this.conversationId})
      : _repository = repository,
        super(const PaymentWebViewActive()) {
    on<PaymentVerificationRequested>(_onVerify);
  }

  // Artan aralıklı poll gecikmeleri (toplam ~35s). Backend callback/webhook ile sonucu yazar.
  static const List<Duration> _delays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 3),
    Duration(seconds: 4),
    Duration(seconds: 4),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 6),
  ];

  Future<void> _onVerify(
    PaymentVerificationRequested event,
    Emitter<PaymentState> emit,
  ) async {
    // WebView callback/result URL'ine birden çok kez ulaşabilir -> tek sefer çalıştır.
    if (state is PaymentVerifying ||
        state is PaymentSucceeded ||
        state is PaymentFailedState) {
      return;
    }
    emit(const PaymentVerifying());

    for (var i = 0; i < _delays.length; i++) {
      await Future.delayed(_delays[i]);
      final result = await _repository.getStatus(
        conversationId,
        // İlk ve son denemede backend'e iyzico retrieve tetikletip senkronize et.
        sync: i == 0 || i == _delays.length - 1,
      );
      if (!result.isSuccess || result.status == null) continue;

      final s = result.status!;
      if (s.isPaid) {
        emit(PaymentSucceeded(status: s));
        return;
      }
      if (s.isFailed) {
        emit(const PaymentFailedState(message: 'Ödeme tamamlanamadı veya iptal edildi'));
        return;
      }
    }

    // Süre doldu, hâlâ pending -> kullanıcıya "doğrulanıyor" mesajı (webhook/reaper çözecek).
    emit(const PaymentPendingState());
  }
}

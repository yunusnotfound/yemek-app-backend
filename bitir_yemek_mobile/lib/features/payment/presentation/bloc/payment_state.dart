part of 'payment_bloc.dart';

abstract class PaymentState extends Equatable {
  const PaymentState();

  @override
  List<Object?> get props => [];
}

/// WebView'de iyzico ödeme formu gösteriliyor.
class PaymentWebViewActive extends PaymentState {
  const PaymentWebViewActive();
}

/// Callback alındı, backend'den sonuç doğrulanıyor (poll).
class PaymentVerifying extends PaymentState {
  const PaymentVerifying();
}

/// Ödeme başarılı.
class PaymentSucceeded extends PaymentState {
  final PaymentStatusModel status;
  const PaymentSucceeded({required this.status});

  @override
  List<Object?> get props => [status];
}

/// Ödeme başarısız / iptal.
class PaymentFailedState extends PaymentState {
  final String message;
  const PaymentFailedState({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Süre doldu, sonuç hâlâ belirsiz (webhook/reaper çözecek). Kullanıcı siparişlerinden takip eder.
class PaymentPendingState extends PaymentState {
  const PaymentPendingState();
}

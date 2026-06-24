part of 'payment_bloc.dart';

abstract class PaymentEvent extends Equatable {
  const PaymentEvent();

  @override
  List<Object?> get props => [];
}

/// WebView, backend callback/result URL'ine ulaştığında tetiklenir -> durum poll'u başlar.
class PaymentVerificationRequested extends PaymentEvent {
  const PaymentVerificationRequested();
}

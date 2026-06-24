import 'package:equatable/equatable.dart';

/// Backend'in `POST /orders` cevabındaki `payment` bloğu.
/// required=false ise ödeme gerekmez (ücretsiz sipariş) -> doğrudan başarı ekranı.
class PaymentInit extends Equatable {
  final bool required;
  final String? provider;
  final String? token;
  final String? checkoutFormContent;
  final String? paymentPageUrl;
  final String? conversationId;
  final DateTime? holdExpiresAt;

  const PaymentInit({
    required this.required,
    this.provider,
    this.token,
    this.checkoutFormContent,
    this.paymentPageUrl,
    this.conversationId,
    this.holdExpiresAt,
  });

  factory PaymentInit.fromJson(Map<String, dynamic> json) {
    return PaymentInit(
      required: json['required'] as bool? ?? false,
      provider: json['provider'] as String?,
      token: json['token'] as String?,
      checkoutFormContent: json['checkoutFormContent'] as String?,
      paymentPageUrl: json['paymentPageUrl'] as String?,
      conversationId: json['conversationId'] as String?,
      holdExpiresAt: json['holdExpiresAt'] != null
          ? DateTime.tryParse(json['holdExpiresAt'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props =>
      [required, provider, token, paymentPageUrl, conversationId, holdExpiresAt];
}

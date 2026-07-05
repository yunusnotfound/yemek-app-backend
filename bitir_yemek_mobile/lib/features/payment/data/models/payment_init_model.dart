import 'package:equatable/equatable.dart';

/// Backend'in `POST /orders` cevabındaki `payment` bloğu.
/// required=false ise ödeme gerekmez (ücretsiz sipariş) -> doğrudan başarı ekranı.
class PaymentInit extends Equatable {
  final bool required;
  final String? provider;

  /// '3ds' -> native kartlı ödeme, WebView yalnız banka 3DS sayfasını gösterir.
  final String? method;
  final String? token;
  final String? checkoutFormContent;
  final String? paymentPageUrl;

  /// Native 3DS akışında bankanın doğrulama sayfası (decode edilmiş HTML).
  final String? threeDSHtmlContent;
  final String? conversationId;
  final DateTime? holdExpiresAt;

  const PaymentInit({
    required this.required,
    this.provider,
    this.method,
    this.token,
    this.checkoutFormContent,
    this.paymentPageUrl,
    this.threeDSHtmlContent,
    this.conversationId,
    this.holdExpiresAt,
  });

  factory PaymentInit.fromJson(Map<String, dynamic> json) {
    return PaymentInit(
      required: json['required'] as bool? ?? false,
      provider: json['provider'] as String?,
      method: json['method'] as String?,
      token: json['token'] as String?,
      checkoutFormContent: json['checkoutFormContent'] as String?,
      paymentPageUrl: json['paymentPageUrl'] as String?,
      threeDSHtmlContent: json['threeDSHtmlContent'] as String?,
      conversationId: json['conversationId'] as String?,
      holdExpiresAt: json['holdExpiresAt'] != null
          ? DateTime.tryParse(json['holdExpiresAt'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [
    required,
    provider,
    method,
    token,
    paymentPageUrl,
    threeDSHtmlContent,
    conversationId,
    holdExpiresAt,
  ];
}

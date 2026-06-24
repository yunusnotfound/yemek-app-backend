import 'package:equatable/equatable.dart';

/// `GET /payments/:conversationId/status` cevabı.
class PaymentStatusModel extends Equatable {
  final String orderId;
  final String conversationId;
  final String status; // awaiting_payment / pending / confirmed / picked_up / cancelled
  final String paymentStatus; // unpaid / pending / paid / failed / refunded / partially_refunded
  final double finalPrice;
  final double? paidPrice;
  final String? pickupCode;

  const PaymentStatusModel({
    required this.orderId,
    required this.conversationId,
    required this.status,
    required this.paymentStatus,
    required this.finalPrice,
    this.paidPrice,
    this.pickupCode,
  });

  bool get isPaid => paymentStatus == 'paid';

  bool get isFailed =>
      paymentStatus == 'failed' ||
      paymentStatus == 'refunded' ||
      paymentStatus == 'partially_refunded' ||
      status == 'cancelled';

  factory PaymentStatusModel.fromJson(Map<String, dynamic> json) {
    return PaymentStatusModel(
      orderId: json['orderId'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      status: json['status'] as String? ?? 'awaiting_payment',
      paymentStatus: json['paymentStatus'] as String? ?? 'pending',
      finalPrice: _parseDouble(json['finalPrice']),
      paidPrice: json['paidPrice'] != null ? _parseDouble(json['paidPrice']) : null,
      pickupCode: json['pickupCode'] as String?,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  List<Object?> get props =>
      [orderId, conversationId, status, paymentStatus, finalPrice, paidPrice, pickupCode];
}

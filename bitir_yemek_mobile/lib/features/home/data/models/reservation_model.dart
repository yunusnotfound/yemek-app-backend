import 'package:equatable/equatable.dart';

class ReservationModel extends Equatable {
  final String id;
  final String packageId;
  final int quantity;
  final double totalPrice;
  final double discountAmount;
  final double finalPrice;
  final String pickupCode;
  final String status;
  final String paymentStatus;
  final String? couponId;

  const ReservationModel({
    required this.id,
    required this.packageId,
    required this.quantity,
    required this.totalPrice,
    required this.discountAmount,
    required this.finalPrice,
    required this.pickupCode,
    required this.status,
    this.paymentStatus = 'unpaid',
    this.couponId,
  });

  @override
  List<Object?> get props => [
    id,
    packageId,
    quantity,
    totalPrice,
    discountAmount,
    finalPrice,
    pickupCode,
    status,
    paymentStatus,
    couponId,
  ];

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    return ReservationModel(
      id: json['id'] as String? ?? '',
      packageId: json['packageId'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      totalPrice: _parseDouble(json['totalPrice']),
      discountAmount: _parseDouble(json['discountAmount']),
      finalPrice: _parseDouble(json['finalPrice']),
      pickupCode: json['pickupCode'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      paymentStatus: json['paymentStatus'] as String? ?? 'unpaid',
      couponId: json['couponId'] as String?,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class CouponModel extends Equatable {
  final String id, code, discountType;
  final String? title, reason;
  final double discountValue, minOrderAmount;
  final double? maxDiscountAmount;
  final bool firstOrderOnly, eligible;
  final int? perUserLimit;
  final DateTime? expiresAt;
  final List<String> businessIds;

  const CouponModel({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    this.title,
    this.reason,
    this.maxDiscountAmount,
    this.firstOrderOnly = false,
    this.eligible = true,
    this.perUserLimit,
    this.expiresAt,
    this.businessIds = const [],
  });

  @override
  List<Object?> get props => [
    id,
    code,
    discountType,
    discountValue,
    minOrderAmount,
    title,
    reason,
    maxDiscountAmount,
    firstOrderOnly,
    eligible,
    perUserLimit,
    expiresAt,
    businessIds,
  ];

  factory CouponModel.fromJson(Map<String, dynamic> json) => CouponModel(
    id: json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    discountType: json['discountType'] as String? ?? 'percentage',
    discountValue: _number(json['discountValue']),
    minOrderAmount: _number(json['minOrderAmount']),
    title: json['title'] as String?,
    reason: json['reason'] as String?,
    maxDiscountAmount: json['maxDiscountAmount'] == null
        ? null
        : _number(json['maxDiscountAmount']),
    firstOrderOnly: json['firstOrderOnly'] == true,
    eligible: json['eligible'] != false,
    perUserLimit: (json['perUserLimit'] as num?)?.toInt(),
    expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
    businessIds: (json['businessIds'] as List? ?? []).cast<String>(),
  );

  bool fits(String businessId, double total) =>
      eligible &&
      total >= minOrderAmount &&
      (businessIds.isEmpty || businessIds.contains(businessId));

  int minimumQuantity(double unitPrice) => unitPrice <= 0
      ? 1
      : ((minOrderAmount * 100).round() / (unitPrice * 100).round())
            .ceil()
            .clamp(1, 1000000);

  double calculateDiscount(double totalPrice) {
    final total = (totalPrice * 100).round();
    var discount = discountType == 'percentage'
        ? (total * discountValue / 100).round()
        : (discountValue * 100).round();
    if (maxDiscountAmount != null) {
      discount = discount.clamp(0, (maxDiscountAmount! * 100).round());
    }
    return discount.clamp(0, total < 0 ? 0 : total) / 100;
  }

  static double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;
}

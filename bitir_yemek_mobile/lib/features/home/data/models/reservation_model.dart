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

  ReservationModel({
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
  final String id;
  final String code;
  final String discountType;
  final double discountValue;
  final double minOrderAmount;

  CouponModel({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
  });

  @override
  List<Object?> get props => [
    id,
    code,
    discountType,
    discountValue,
    minOrderAmount,
  ];

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      discountType: json['discountType'] as String? ?? 'percentage',
      discountValue: _parseDouble(json['discountValue']),
      minOrderAmount: _parseDouble(json['minOrderAmount']),
    );
  }

  double calculateDiscount(double totalPrice) {
    if (discountType == 'percentage') {
      return (totalPrice * discountValue) / 100;
    }
    return discountValue;
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

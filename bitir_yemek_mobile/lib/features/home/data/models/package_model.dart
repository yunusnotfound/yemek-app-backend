import 'package:equatable/equatable.dart';
import 'business_model.dart';

class PackageModel extends Equatable {
  final String id;
  final String businessId;
  final String title;
  final String? description;
  final double originalPrice;
  final double discountedPrice;
  final int quantity;
  final int remainingQuantity;
  final String pickupStart;
  final String pickupEnd;
  final String pickupDate;
  final String? imageUrl;
  final bool isActive;
  final bool isRecurring;
  final List<int>? recurringDays;
  final BusinessModel business;

  const PackageModel({
    required this.id,
    required this.businessId,
    required this.title,
    this.description,
    required this.originalPrice,
    required this.discountedPrice,
    required this.quantity,
    required this.remainingQuantity,
    required this.pickupStart,
    required this.pickupEnd,
    required this.pickupDate,
    this.imageUrl,
    required this.isActive,
    required this.isRecurring,
    this.recurringDays,
    required this.business,
  });

  @override
  List<Object?> get props => [
    id,
    businessId,
    title,
    description,
    originalPrice,
    discountedPrice,
    quantity,
    remainingQuantity,
    pickupStart,
    pickupEnd,
    pickupDate,
    imageUrl,
    isActive,
    isRecurring,
    recurringDays,
    business,
  ];

  factory PackageModel.fromJson(Map<String, dynamic> json) {
    return PackageModel(
      id: _parseString(json['id']) ?? '',
      businessId: _parseString(json['businessId']) ?? '',
      title: _parseString(json['title']) ?? '',
      description: _parseString(json['description']),
      originalPrice: _parseDouble(json['originalPrice']),
      discountedPrice: _parseDouble(json['discountedPrice']),
      quantity: _parseInt(json['quantity']),
      remainingQuantity: _parseInt(json['remainingQuantity']),
      pickupStart: _parseString(json['pickupStart']) ?? '',
      pickupEnd: _parseString(json['pickupEnd']) ?? '',
      pickupDate: _parseString(json['pickupDate']) ?? '',
      imageUrl: _parseString(json['imageUrl']),
      isActive: _parseBool(json['isActive']),
      isRecurring: _parseBool(json['isRecurring']),
      recurringDays: json['recurringDays'] != null
          ? (json['recurringDays'] as List<dynamic>).cast<int>()
          : null,
      business: BusinessModel.fromJson(
        json['business'] as Map<String, dynamic>,
      ),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false; // Default to false for safety
  }

  static String? _parseString(dynamic value) {
    if (value is String) return value;
    if (value != null) return value.toString();
    return null;
  }

  String get discountPercentage {
    final discount = ((originalPrice - discountedPrice) / originalPrice) * 100;
    return discount.toStringAsFixed(0);
  }

  String get formattedPickupTime {
    return '$pickupStart - $pickupEnd';
  }
}

class PackagesResponse extends Equatable {
  final List<PackageModel> data;
  final PaginationModel pagination;

  const PackagesResponse({required this.data, required this.pagination});

  @override
  List<Object?> get props => [data, pagination];

  factory PackagesResponse.fromJson(Map<String, dynamic> json) {
    final dataList = (json['data'] as List<dynamic>)
        .map((e) => PackageModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return PackagesResponse(
      data: dataList,
      pagination: PaginationModel.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }
}

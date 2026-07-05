import 'package:equatable/equatable.dart';
import 'package_model.dart';
import 'business_model.dart';
import 'category_model.dart';

class BusinessDetailModel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String address;
  final String city;
  final String district;
  final double latitude;
  final double longitude;
  final String? phone;
  final String? imageUrl;
  final double rating;
  final bool isActive;
  final bool isApproved;
  final CategoryModel category;
  final List<ReviewModel> reviews;
  final List<PackageModel> packages;

  const BusinessDetailModel({
    required this.id,
    required this.name,
    this.description,
    required this.address,
    required this.city,
    required this.district,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.imageUrl,
    required this.rating,
    required this.isActive,
    required this.isApproved,
    required this.category,
    required this.reviews,
    required this.packages,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    address,
    city,
    district,
    latitude,
    longitude,
    phone,
    imageUrl,
    rating,
    isActive,
    isApproved,
    category,
    reviews,
    packages,
  ];

  factory BusinessDetailModel.fromJson(Map<String, dynamic> json) {
    final category = CategoryModel.fromJson(
      json['category'] as Map<String, dynamic>,
    );

    // Build a BusinessModel to inject into packages
    final businessForPackages = BusinessModel(
      id: _parseString(json['id']) ?? '',
      name: _parseString(json['name']) ?? '',
      description: _parseString(json['description']),
      address: _parseString(json['address']) ?? '',
      city: _parseString(json['city']) ?? '',
      district: _parseString(json['district']) ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      phone: _parseString(json['phone']),
      imageUrl: _parseString(json['imageUrl']),
      rating: _parseDouble(json['rating']),
      isActive: _parseBool(json['isActive']),
      isApproved: _parseBool(json['isApproved']),
      approvalStatus: _parseString(json['approvalStatus']) ?? 'approved',
      category: category,
    );

    // Parse packages - inject business into each
    final packagesJson = json['packages'] as List<dynamic>? ?? [];
    final packages = packagesJson.map((pkgJson) {
      final pkg = pkgJson as Map<String, dynamic>;
      return PackageModel(
        id: _parseString(pkg['id']) ?? '',
        businessId: _parseString(pkg['businessId']) ?? json['id'] as String,
        title: _parseString(pkg['title']) ?? '',
        description: _parseString(pkg['description']),
        originalPrice: _parseDouble(pkg['originalPrice']),
        discountedPrice: _parseDouble(pkg['discountedPrice']),
        quantity: _parseInt(pkg['quantity']),
        remainingQuantity: _parseInt(pkg['remainingQuantity']),
        pickupStart: _parseString(pkg['pickupStart']) ?? '',
        pickupEnd: _parseString(pkg['pickupEnd']) ?? '',
        pickupDate: _parseString(pkg['pickupDate']) ?? '',
        imageUrl: _parseString(pkg['imageUrl']),
        isActive: _parseBool(pkg['isActive']),
        isRecurring: _parseBool(pkg['isRecurring']),
        business: businessForPackages,
      );
    }).toList();

    // Parse reviews
    final reviewsJson = json['reviews'] as List<dynamic>? ?? [];
    final reviews = reviewsJson
        .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return BusinessDetailModel(
      id: businessForPackages.id,
      name: businessForPackages.name,
      description: businessForPackages.description,
      address: businessForPackages.address,
      city: businessForPackages.city,
      district: businessForPackages.district,
      latitude: businessForPackages.latitude,
      longitude: businessForPackages.longitude,
      phone: businessForPackages.phone,
      imageUrl: businessForPackages.imageUrl,
      rating: businessForPackages.rating,
      isActive: businessForPackages.isActive,
      isApproved: businessForPackages.isApproved,
      category: category,
      reviews: reviews,
      packages: packages,
    );
  }

  String get fullAddress {
    if (district.isNotEmpty && city.isNotEmpty) {
      return '$district, $city';
    }
    if (city.isNotEmpty) return city;
    return address;
  }

  double get averageRating {
    if (reviews.isEmpty) return rating;
    final sum = reviews.fold<double>(0, (prev, r) => prev + r.rating);
    return sum / reviews.length;
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
    return true;
  }

  static String? _parseString(dynamic value) {
    if (value is String) return value;
    if (value != null) return value.toString();
    return null;
  }
}

class ReviewModel extends Equatable {
  final String id;
  final int rating;
  final String? comment;
  final String userName;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.rating,
    this.comment,
    required this.userName,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return ReviewModel(
      id: json['id'] as String? ?? '',
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String?,
      userName: user?['name'] as String? ?? 'Anonim',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, rating, comment, userName, createdAt];
}

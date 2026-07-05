import 'package:equatable/equatable.dart';

class FavoriteModel extends Equatable {
  final String id;
  final String businessId;
  final String businessName;
  final String address;
  final String city;
  final String district;
  final String? imageUrl;
  final double rating;
  final String? categoryName;
  final DateTime createdAt;

  const FavoriteModel({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.address,
    required this.city,
    required this.district,
    this.imageUrl,
    required this.rating,
    this.categoryName,
    required this.createdAt,
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    final business = json['business'] as Map<String, dynamic>? ?? {};
    final category = business['category'] as Map<String, dynamic>?;

    return FavoriteModel(
      id: json['id'] as String? ?? '',
      businessId:
          business['id'] as String? ?? json['businessId'] as String? ?? '',
      businessName: business['name'] as String? ?? '',
      address: business['address'] as String? ?? '',
      city: business['city'] as String? ?? '',
      district: business['district'] as String? ?? '',
      imageUrl: business['imageUrl'] as String?,
      rating: _parseDouble(business['rating']),
      categoryName: category?['name'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    businessId,
    businessName,
    address,
    city,
    district,
    imageUrl,
    rating,
    categoryName,
    createdAt,
  ];

  String get fullAddress {
    if (district.isNotEmpty && city.isNotEmpty) {
      return '$district, $city';
    }
    if (city.isNotEmpty) return city;
    return address;
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class FavoritesResponse extends Equatable {
  final List<FavoriteModel> favorites;
  final int total;
  final int page;
  final int totalPages;

  const FavoritesResponse({
    required this.favorites,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  @override
  List<Object?> get props => [favorites, total, page, totalPages];

  factory FavoritesResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? [];
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    return FavoritesResponse(
      favorites: data
          .map((e) => FavoriteModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: pagination['total'] as int? ?? 0,
      page: pagination['page'] as int? ?? 1,
      totalPages: pagination['totalPages'] as int? ?? 1,
    );
  }
}

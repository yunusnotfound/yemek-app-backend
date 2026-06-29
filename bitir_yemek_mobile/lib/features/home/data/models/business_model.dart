import 'package:equatable/equatable.dart';
import 'category_model.dart';

class BusinessModel extends Equatable {
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
  final String approvalStatus;
  final CategoryModel category;
  final double? distance;
  final int packageCount;
  final bool availableNow;

  BusinessModel({
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
    required this.approvalStatus,
    required this.category,
    this.distance,
    this.packageCount = 0,
    this.availableNow = false,
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
    approvalStatus,
    category,
    distance,
    packageCount,
    availableNow,
  ];

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
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
      category: CategoryModel.fromJson(
        json['category'] as Map<String, dynamic>,
      ),
      distance: json['distance'] != null
          ? _parseDouble(json['distance'])
          : null,
      packageCount: _parseInt(json['packageCount']),
      // _parseBool null'da true döndüğünden burada kullanılamaz; varsayılan false.
      availableNow:
          json['availableNow'] == true || json['availableNow'] == 'true',
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
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

class PaginationModel extends Equatable {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  PaginationModel({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  @override
  List<Object?> get props => [total, page, limit, totalPages];

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    return PaginationModel(
      total: _parseInt(json['total']),
      page: _parseInt(json['page']),
      limit: _parseInt(json['limit']),
      totalPages: _parseInt(json['totalPages']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class BusinessesResponse extends Equatable {
  final List<BusinessModel> data;
  final PaginationModel pagination;

  BusinessesResponse({required this.data, required this.pagination});

  @override
  List<Object?> get props => [data, pagination];

  factory BusinessesResponse.fromJson(Map<String, dynamic> json) {
    final dataList = (json['data'] as List<dynamic>)
        .map((e) => BusinessModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return BusinessesResponse(
      data: dataList,
      pagination: PaginationModel.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }
}

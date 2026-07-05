import 'package:equatable/equatable.dart';

class OrderModel extends Equatable {
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
  final DateTime createdAt;
  final OrderPackageModel? package;

  const OrderModel({
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
    required this.createdAt,
    this.package,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
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
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      package: json['package'] != null
          ? OrderPackageModel.fromJson(json['package'] as Map<String, dynamic>)
          : null,
    );
  }

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
    createdAt,
    package,
  ];

  bool get isAwaitingPayment => status == 'awaiting_payment';
  bool get isActive => status == 'pending' || status == 'confirmed';
  bool get isCompleted => status == 'picked_up';
  bool get isCancelled => status == 'cancelled';
  bool get canCancel => isActive;

  String get statusText {
    switch (status) {
      case 'awaiting_payment':
        return 'Ödeme Bekliyor';
      case 'pending':
        return 'Onay Bekliyor';
      case 'confirmed':
        return 'Onaylandi';
      case 'picked_up':
        return 'Teslim Alindi';
      case 'cancelled':
        return 'Iptal Edildi';
      default:
        return status;
    }
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class OrderPackageModel extends Equatable {
  final String id;
  final String title;
  final double discountedPrice;
  final String? imageUrl;
  final OrderBusinessModel? business;

  const OrderPackageModel({
    required this.id,
    required this.title,
    required this.discountedPrice,
    this.imageUrl,
    this.business,
  });

  @override
  List<Object?> get props => [id, title, discountedPrice, imageUrl, business];

  factory OrderPackageModel.fromJson(Map<String, dynamic> json) {
    return OrderPackageModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      discountedPrice: OrderModel._parseDouble(json['discountedPrice']),
      imageUrl: json['imageUrl'] as String?,
      business: json['business'] != null
          ? OrderBusinessModel.fromJson(
              json['business'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class OrderBusinessModel extends Equatable {
  final String id;
  final String name;
  final String address;
  final String? phone;

  const OrderBusinessModel({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
  });

  @override
  List<Object?> get props => [id, name, address, phone];

  factory OrderBusinessModel.fromJson(Map<String, dynamic> json) {
    return OrderBusinessModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String?,
    );
  }
}

class OrdersResponse extends Equatable {
  final List<OrderModel> orders;
  final int total;
  final int page;
  final int totalPages;

  const OrdersResponse({
    required this.orders,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  @override
  List<Object?> get props => [orders, total, page, totalPages];

  factory OrdersResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? [];
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    return OrdersResponse(
      orders: data
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: pagination['total'] as int? ?? 0,
      page: pagination['page'] as int? ?? 1,
      totalPages: pagination['totalPages'] as int? ?? 1,
    );
  }
}

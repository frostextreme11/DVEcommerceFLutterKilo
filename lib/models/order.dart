import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Order {
  final String id;
  final String userId;
  final String orderNumber;
  final OrderStatus status;
  final double totalAmount;
  final String shippingAddress;
  final String? paymentMethod;
  final PaymentStatus paymentStatus;
  final String? courierInfo;
  final String? notes;
  final String? receiverName;
  final String? receiverPhone;
  final double? additionalCosts;
  final String? additionalCostsNotes;
  final bool isDropship;
  final String? senderName;
  final String? senderPhone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.userId,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    required this.shippingAddress,
    this.paymentMethod,
    required this.paymentStatus,
    this.courierInfo,
    this.notes,
    this.receiverName,
    this.receiverPhone,
    this.additionalCosts,
    this.additionalCostsNotes,
    this.isDropship = false,
    this.senderName,
    this.senderPhone,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json, List<OrderItem> items) {
    return Order(
      id: json['id'],
      userId: json['user_id'],
      orderNumber: json['order_number'],
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => OrderStatus.notPaid,
      ),
      totalAmount: (json['total_amount'] as num).toDouble(),
      shippingAddress: json['shipping_address'],
      paymentMethod: json['payment_method'],
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (json['payment_status'] ?? 'pending'),
        orElse: () => PaymentStatus.pending,
      ),
      courierInfo: json['courier_info'],
      notes: json['notes'],
      receiverName: json['receiver_name'],
      receiverPhone: json['receiver_phone'],
      additionalCosts: (json['additional_costs'] as num?)?.toDouble(),
      additionalCostsNotes: json['additional_costs_notes'],
      isDropship: json['is_dropship'] ?? false,
      senderName: json['sender_name'],
      senderPhone: json['sender_phone'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'order_number': orderNumber,
      'status': status.toString().split('.').last,
      'total_amount': totalAmount,
      'shipping_address': shippingAddress,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus.toString().split('.').last,
      'courier_info': courierInfo,
      'notes': notes,
      'receiver_name': receiverName,
      'receiver_phone': receiverPhone,
      'additional_costs': additionalCosts,
      'additional_costs_notes': additionalCostsNotes,
      'is_dropship': isDropship,
      'sender_name': senderName,
      'sender_phone': senderPhone,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static String generateOrderNumber() {
    final uuid = Uuid();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    return 'ORD-${timestamp}-${uuid.v4().substring(0, 4).toUpperCase()}';
  }

  Order copyWith({
    String? id,
    String? userId,
    String? orderNumber,
    OrderStatus? status,
    double? totalAmount,
    String? shippingAddress,
    String? paymentMethod,
    PaymentStatus? paymentStatus,
    String? courierInfo,
    String? notes,
    String? receiverName,
    String? receiverPhone,
    double? additionalCosts,
    String? additionalCostsNotes,
    bool? isDropship,
    String? senderName,
    String? senderPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<OrderItem>? items,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      courierInfo: courierInfo ?? this.courierInfo,
      notes: notes ?? this.notes,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      additionalCosts: additionalCosts ?? this.additionalCosts,
      additionalCostsNotes: additionalCostsNotes ?? this.additionalCostsNotes,
      isDropship: isDropship ?? this.isDropship,
      senderName: senderName ?? this.senderName,
      senderPhone: senderPhone ?? this.senderPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }
}

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final String? productImageUrl;
  final int quantity;
  final double unitPrice;
  final double? discountPrice;
  final double totalPrice;
  final DateTime createdAt;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.quantity,
    required this.unitPrice,
    this.discountPrice,
    required this.totalPrice,
    required this.createdAt,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      orderId: json['order_id'],
      productId: json['product_id'] ?? '',
      productName: json['product_name'],
      productImageUrl: json['product_image_url'],
      quantity: json['quantity'],
      unitPrice: (json['unit_price'] as num).toDouble(),
      discountPrice: json['discount_price'] != null ? (json['discount_price'] as num).toDouble() : null,
      totalPrice: (json['total_price'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'product_image_url': productImageUrl,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount_price': discountPrice,
      'total_price': totalPrice,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum OrderStatus {
  notPaid,
  paid,
  processing,
  shipped,
  delivered,
  cancelled,
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.notPaid:
        return 'Not Paid';
      case OrderStatus.paid:
        return 'Paid';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.notPaid:
        return const Color(0xFFEF4444); // Red
      case OrderStatus.paid:
        return const Color(0xFF10B981); // Green
      case OrderStatus.processing:
        return const Color(0xFFF97316); // Orange
      case OrderStatus.shipped:
        return const Color(0xFF3B82F6); // Blue
      case OrderStatus.delivered:
        return const Color(0xFF10B981); // Green
      case OrderStatus.cancelled:
        return const Color(0xFF6B7280); // Grey
    }
  }
}

extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.pending:
        return const Color(0xFFF97316); // Orange
      case PaymentStatus.paid:
        return const Color(0xFF10B981); // Green
      case PaymentStatus.failed:
        return const Color(0xFFEF4444); // Red
      case PaymentStatus.refunded:
        return const Color(0xFF3B82F6); // Blue
    }
  }
}
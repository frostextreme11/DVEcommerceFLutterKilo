import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Payment {
  final String id;
  final String orderId;
  final String userId;
  final double amount;
  final PaymentStatus status;
  final String? paymentProofUrl;
  final String? paymentMethod;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.amount,
    required this.status,
    this.paymentProofUrl,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      orderId: json['order_id'],
      userId: json['user_id'],
      amount: (json['amount'] as num).toDouble(),
      status: PaymentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (json['status'] ?? 'pending'),
        orElse: () => PaymentStatus.pending,
      ),
      paymentProofUrl: json['payment_proof_url'],
      paymentMethod: json['payment_method'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'user_id': userId,
      'amount': amount,
      'status': status.toString().split('.').last,
      'payment_proof_url': paymentProofUrl,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static String generatePaymentId() {
    final uuid = Uuid();
    return 'PAY-${DateTime.now().millisecondsSinceEpoch}-${uuid.v4().substring(0, 8).toUpperCase()}';
  }

  Payment copyWith({
    String? id,
    String? orderId,
    String? userId,
    double? amount,
    PaymentStatus? status,
    String? paymentProofUrl,
    String? paymentMethod,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Payment(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum PaymentStatus { pending, completed, failed, refunded }

extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.completed:
        return 'Completed';
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
      case PaymentStatus.completed:
        return const Color(0xFF10B981); // Green
      case PaymentStatus.failed:
        return const Color(0xFFEF4444); // Red
      case PaymentStatus.refunded:
        return const Color(0xFF3B82F6); // Blue
    }
  }
}

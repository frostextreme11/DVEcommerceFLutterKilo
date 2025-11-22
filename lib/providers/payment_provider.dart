import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment.dart';
import '../models/order.dart' as order_model;

class PaymentProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Payment> _payments = [];
  bool _isLoading = false;
  String? _error;

  List<Payment> get payments => _payments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch all payments for a specific order
  Future<List<Payment>> getPaymentsForOrder(String orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('kl_payments')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: false);

      final paymentList = (response as List<dynamic>)
          .map((json) => Payment.fromJson(json))
          .toList();

      _payments = paymentList;
      return paymentList;
    } catch (e) {
      _error = 'Failed to load payments: $e';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submit a new payment
  Future<Payment?> submitPayment({
    required String orderId,
    required String userId,
    required double amount,
    required String paymentProofUrl,
    String? paymentMethod,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final paymentData = {
        'order_id': orderId,
        'user_id': userId,
        'amount': amount,
        'status': 'pending',
        'payment_proof_url': paymentProofUrl,
        'payment_method': paymentMethod ?? 'Bank Transfer',
        'notes': notes ?? 'Payment submitted via app',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('kl_payments')
          .insert(paymentData)
          .select()
          .single();

      if (response != null) {
        final newPayment = Payment.fromJson(response);

        // Add to local list
        _payments.insert(0, newPayment);

        // Update order payment status
        await _updateOrderPaymentStatus(orderId);

        notifyListeners();
        return newPayment;
      }

      return null;
    } catch (e) {
      _error = 'Failed to submit payment: $e';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
    }
  }

  /// Update payment status (for admin use)
  Future<bool> updatePaymentStatus(
    String paymentId,
    PaymentStatus status,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('kl_payments')
          .update({
            'status': status.toString().split('.').last,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentId)
          .select()
          .single();

      if (response != null) {
        // Update local payment
        final updatedPayment = Payment.fromJson(response);
        final index = _payments.indexWhere((p) => p.id == paymentId);
        if (index != -1) {
          _payments[index] = updatedPayment;

          // Update order payment status
          await _updateOrderPaymentStatus(updatedPayment.orderId);
        }

        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _error = 'Failed to update payment status: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// Get total paid amount for an order
  double getTotalPaidForOrder(String orderId) {
    return _payments
        .where(
          (payment) =>
              payment.orderId == orderId &&
              payment.status == PaymentStatus.completed,
        )
        .fold(0.0, (sum, payment) => sum + payment.amount);
  }

  /// Get pending payments for an order
  List<Payment> getPendingPaymentsForOrder(String orderId) {
    return _payments
        .where(
          (payment) =>
              payment.orderId == orderId &&
              payment.status == PaymentStatus.pending,
        )
        .toList();
  }

  /// Get completed payments for an order
  List<Payment> getCompletedPaymentsForOrder(String orderId) {
    return _payments
        .where(
          (payment) =>
              payment.orderId == orderId &&
              payment.status == PaymentStatus.completed,
        )
        .toList();
  }

  /// Calculate payment progress for an order
  PaymentProgress calculatePaymentProgress(String orderId, double orderTotal) {
    final totalPaid = getTotalPaidForOrder(orderId);
    final pendingPayments = getPendingPaymentsForOrder(orderId);
    final completedPayments = getCompletedPaymentsForOrder(orderId);

    double progress = 0.0;
    if (orderTotal > 0) {
      progress = (totalPaid / orderTotal) * 100;
    }

    return PaymentProgress(
      totalPaid: totalPaid,
      orderTotal: orderTotal,
      progress: progress.clamp(0.0, 100.0),
      pendingPayments: pendingPayments,
      completedPayments: completedPayments,
    );
  }

  /// Update order payment status based on payments
  Future<void> _updateOrderPaymentStatus(String orderId) async {
    try {
      // Get order total
      final orderResponse = await _supabase
          .from('kl_orders')
          .select('total_amount, additional_costs')
          .eq('id', orderId)
          .single();

      if (orderResponse != null) {
        final orderTotal = (orderResponse['total_amount'] as num).toDouble();
        final additionalCosts =
            (orderResponse['additional_costs'] as num?)?.toDouble() ?? 0.0;
        final fullTotal = orderTotal;

        // Calculate total paid
        final totalPaid = getTotalPaidForOrder(orderId);

        // Update order status
        String newStatus;
        String newPaymentStatus;

        if (totalPaid >= fullTotal && fullTotal > 0) {
          newStatus = 'lunas';
          newPaymentStatus = 'paid';
        } else if (totalPaid > 0 && totalPaid < fullTotal) {
          newStatus = 'pembayaran_partial';
          newPaymentStatus = 'pending';
        } else {
          newStatus = 'menunggu_pembayaran';
          newPaymentStatus = 'pending';
        }

        // Update order
        await _supabase
            .from('kl_orders')
            .update({
              'status': newStatus,
              'payment_status': newPaymentStatus,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', orderId);
      }
    } catch (e) {
      print('Error updating order payment status: $e');
    }
  }

  /// Clear all data
  void clearData() {
    _payments = [];
    _error = null;
    notifyListeners();
  }

  /// Refresh payments for an order
  Future<void> refreshPaymentsForOrder(String orderId) async {
    await getPaymentsForOrder(orderId);
  }
}

class PaymentProgress {
  final double totalPaid;
  final double orderTotal;
  final double progress;
  final List<Payment> pendingPayments;
  final List<Payment> completedPayments;

  PaymentProgress({
    required this.totalPaid,
    required this.orderTotal,
    required this.progress,
    required this.pendingPayments,
    required this.completedPayments,
  });

  bool get isFullyPaid => progress >= 100.0;
  bool get hasPartialPayment => progress > 0.0 && progress < 100.0;
  double get remainingAmount => orderTotal - totalPaid;
}

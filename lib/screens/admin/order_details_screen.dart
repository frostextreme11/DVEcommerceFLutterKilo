import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase/supabase.dart';
import 'dart:async';
import '../../providers/admin_orders_provider.dart';
import '../../models/order.dart' as order_model;
import '../../models/payment.dart';
import '../../widgets/custom_button.dart';
import '../../services/print_service.dart';
import '../../services/notification_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final order_model.Order? order;
  final String? orderId;

  const OrderDetailsScreen({Key? key, this.order, this.orderId})
    : super(key: key);

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  order_model.Order? _order;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      _order = widget.order;
    } else if (widget.orderId != null) {
      _loadOrderById(widget.orderId!);
    }
  }

  Future<void> _loadOrderById(String orderId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final adminOrdersProvider = context.read<AdminOrdersProvider>();
      _order = await adminOrdersProvider.getOrderById(orderId);

      if (_order == null) {
        setState(() {
          _error =
              'Order not found - The order may have been deleted or the ID is incorrect';
        });
      }
    } catch (e) {
      setState(() {
        _error =
            'Failed to load order details. Please check your connection and try again.';
      });
      print('Error loading order $orderId: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Unable to Load Order',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        if (widget.orderId != null) {
                          _loadOrderById(widget.orderId!);
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Order not found')),
      );
    }

    return _OrderDetailsContent(order: _order!);
  }
}

class _OrderDetailsContent extends StatefulWidget {
  final order_model.Order order;

  const _OrderDetailsContent({required this.order});

  @override
  State<_OrderDetailsContent> createState() => _OrderDetailsContentState();
}

class _OrderDetailsContentState extends State<_OrderDetailsContent> {
  order_model.Order? _currentOrder;
  StreamSubscription? _ordersSubscription;
  UniqueKey _paymentHistoryKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;

    // Listen for changes in AdminOrdersProvider
    _setupOrdersListener();
  }

  @override
  void didUpdateWidget(_OrderDetailsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update current order if widget order changes
    if (oldWidget.order.id != widget.order.id) {
      setState(() {
        _currentOrder = widget.order;
      });
      _setupOrdersListener();
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  void _setupOrdersListener() {
    // Cancel existing subscription
    _ordersSubscription?.cancel();

    // Listen for changes in AdminOrdersProvider
    final adminOrdersProvider = context.read<AdminOrdersProvider>();
    _ordersSubscription = adminOrdersProvider.ordersStream.listen((orders) {
      // Find updated order in the orders list
      final updatedOrder = orders.firstWhere(
        (order) => order.id == widget.order.id,
        orElse: () => widget.order, // Fallback to current order if not found
      );

      // If order data has changed, update the UI
      if (_hasOrderChanged(updatedOrder)) {
        setState(() {
          _currentOrder = updatedOrder;
          // Refresh payment history when order data changes
          _refreshPaymentHistory();
        });
      }
    });
  }

  void _refreshPaymentHistory() {
    // Force rebuild of payment history section by changing the key
    setState(() {
      _paymentHistoryKey = UniqueKey();
    });
  }

  bool _hasOrderChanged(order_model.Order newOrder) {
    if (_currentOrder == null) return true;

    return _currentOrder!.status != newOrder.status ||
        _currentOrder!.paymentStatus != newOrder.paymentStatus ||
        _currentOrder!.courierInfo != newOrder.courierInfo ||
        _currentOrder!.shippingAddress != newOrder.shippingAddress ||
        _currentOrder!.additionalCosts != newOrder.additionalCosts ||
        _currentOrder!.additionalCostsNotes != newOrder.additionalCostsNotes ||
        _currentOrder!.totalAmount != newOrder.totalAmount;
  }

  @override
  Widget build(BuildContext context) {
    final order = _currentOrder!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order ${order.orderNumber}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Order Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildStatusBadge(order.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment Status:'),
                        _buildPaymentStatusBadgeFromOrder(order.paymentStatus),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Customer Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Name', order.receiverName ?? 'N/A'),
                    _buildInfoRow('Phone', order.receiverPhone ?? 'N/A'),
                    _buildAddressRow(context, 'Address', order.shippingAddress),
                    if (order.notes != null)
                      _buildInfoRow('Notes', order.notes!),

                    // Dropship Information
                    if (order.isDropship) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.local_shipping,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Dropship Order',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              'Sender Name',
                              order.senderName ?? 'N/A',
                            ),
                            _buildInfoRow(
                              'Sender Phone',
                              order.senderPhone ?? 'N/A',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Shipping Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shipping Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Courier Info',
                      order.courierInfo ?? 'Not set',
                    ),
                    _buildInfoRow(
                      'Payment Method',
                      order.paymentMethod ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Subtotal',
                      'Rp ${order.totalAmount.toStringAsFixed(0)}',
                    ),
                    if (order.additionalCosts != null &&
                        order.additionalCosts! > 0) ...[
                      _buildInfoRow(
                        'Additional Costs',
                        'Rp ${order.additionalCosts!.toStringAsFixed(0)}',
                      ),
                      _buildInfoRow(
                        'Total Amount',
                        'Rp ${(order.totalAmount + order.additionalCosts!).toStringAsFixed(0)}',
                      ),
                    ] else
                      _buildInfoRow(
                        'Total Amount',
                        'Rp ${order.totalAmount.toStringAsFixed(0)}',
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Additional Costs
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Additional Costs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Additional Costs',
                      order.additionalCosts != null &&
                              order.additionalCosts! > 0
                          ? 'Rp ${order.additionalCosts!.toStringAsFixed(0)}'
                          : 'No additional costs',
                    ),
                    if (order.additionalCostsNotes != null &&
                        order.additionalCostsNotes!.isNotEmpty)
                      _buildInfoRow('Notes', order.additionalCostsNotes!),
                    const SizedBox(height: 16),
                    Consumer<AdminOrdersProvider>(
                      builder: (context, provider, child) {
                        return CustomButton(
                          text: 'Update Additional Costs',
                          onPressed: () {
                            _showAdditionalCostsDialog(context);
                          },
                          backgroundColor: Colors.blue,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Order Items
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...order.items.map((item) => _buildOrderItemCard(item)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Payment History Section (if payments exist)
            _buildPaymentHistorySection(_paymentHistoryKey),

            // Action Buttons
            Consumer<AdminOrdersProvider>(
              builder: (context, provider, child) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Update Status',
                            onPressed: () {
                              _showStatusUpdateDialog(context);
                            },
                            backgroundColor: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomButton(
                            text: 'Update Courier',
                            onPressed: () {
                              _showCourierUpdateDialog(context);
                            },
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Print Address',
                            onPressed: () {
                              _printDeliveryAddress(context);
                            },
                            backgroundColor: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomButton(
                            text: 'Print Preview',
                            onPressed: () {
                              _showPrintPreview(context);
                            },
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<bool>(
                      future: _hasPaymentsForOrder(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }
                        final hasPayments = snapshot.data ?? false;
                        if (hasPayments &&
                            order.paymentStatus ==
                                order_model.PaymentStatus.pending) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomButton(
                                      text: 'Mark as Paid',
                                      onPressed: () {
                                        _markOrderAsPaid(context);
                                      },
                                      backgroundColor: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomButton(
                                      text: 'Send Payment Notification',
                                      onPressed: () {
                                        _showPaymentNotificationDialog(context);
                                      },
                                      backgroundColor: Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        } else if (order.paymentStatus ==
                            order_model.PaymentStatus.pending) {
                          return Row(
                            children: [
                              Expanded(
                                child: CustomButton(
                                  text: 'Send Payment Notification',
                                  onPressed: () {
                                    _showPaymentNotificationDialog(context);
                                  },
                                  backgroundColor: Colors.purple,
                                ),
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(order_model.OrderStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        border: Border.all(color: status.color),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPaymentStatusBadge(PaymentStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        border: Border.all(color: status.color),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPaymentStatusBadgeFromOrder(order_model.PaymentStatus status) {
    Color getStatusColor(order_model.PaymentStatus status) {
      switch (status) {
        case order_model.PaymentStatus.pending:
          return const Color(0xFFF97316); // Orange
        case order_model.PaymentStatus.paid:
          return const Color(0xFF10B981); // Green
        case order_model.PaymentStatus.failed:
          return const Color(0xFFEF4444); // Red
        case order_model.PaymentStatus.refunded:
          return const Color(0xFF3B82F6); // Blue
      }
    }

    String getStatusDisplayName(order_model.PaymentStatus status) {
      switch (status) {
        case order_model.PaymentStatus.pending:
          return 'Pending';
        case order_model.PaymentStatus.paid:
          return 'Paid';
        case order_model.PaymentStatus.failed:
          return 'Failed';
        case order_model.PaymentStatus.refunded:
          return 'Refunded';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: getStatusColor(status).withOpacity(0.1),
        border: Border.all(color: getStatusColor(status)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        getStatusDisplayName(status),
        style: TextStyle(
          color: getStatusColor(status),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildAddressRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '$label:',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    _showEditAddressDialog(context);
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  tooltip: 'Edit Address',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildOrderItemCard(order_model.OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              image: item.productImageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(item.productImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: item.productImageUrl == null
                ? Icon(Icons.image, color: Colors.grey[400], size: 24)
                : null,
          ),
          const SizedBox(width: 12),

          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity} × Rp ${item.unitPrice.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                if (item.discountPrice != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Discount: Rp ${item.discountPrice!.toStringAsFixed(0)}',
                    style: TextStyle(color: Colors.green[600], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),

          // Total Price
          Text(
            'Rp ${item.totalPrice.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistorySection(Key key) {
    return FutureBuilder<List<Payment>>(
      key: key,
      future: _loadPaymentsForOrder(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('Error loading payments: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection and try refreshing the page.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Success state
        final payments = snapshot.data ?? [];
        final totalAmount =
            _currentOrder!.totalAmount + (_currentOrder!.additionalCosts ?? 0);
        final totalPaid = payments
            .where((payment) => payment.status == PaymentStatus.completed)
            .fold<double>(0.0, (sum, payment) => sum + payment.amount);
        final progress = totalAmount > 0
            ? (totalPaid / totalAmount) * 100
            : 0.0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.payment, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Payment History',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Payment Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount:'),
                          Text(
                            'Rp ${totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Paid:'),
                          Text(
                            'Rp ${totalPaid.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: totalPaid >= totalAmount
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Payment Progress:'),
                          Text(
                            '${progress.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: totalPaid >= totalAmount
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          totalPaid >= totalAmount
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Payment List or Empty State
                if (payments.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No Payments Yet',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Customer has not submitted any payments for this order yet.',
                          style: TextStyle(color: Colors.grey.shade700),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ...payments.map(
                    (payment) => _buildPaymentCard(context, payment),
                  ),
                ],

                const SizedBox(height: 16),

                // Payment Actions - Individual verify buttons for each pending payment
                if (payments
                    .where((p) => p.status == PaymentStatus.pending)
                    .isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Pending Payments:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...payments
                      .where(
                        (payment) => payment.status == PaymentStatus.pending,
                      )
                      .map(
                        (payment) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Payment #${payment.id.substring(0, 8)} - Rp ${payment.amount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 100,
                                height: 36,
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _verifyPayment(context, payment),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Verify',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<Payment>> _loadPaymentsForOrder() async {
    try {
      final supabase = Supabase.instance.client;

      // Add timeout and better error handling
      final response = await supabase
          .from('kl_payments')
          .select()
          .eq('order_id', _currentOrder!.id)
          .order('created_at', ascending: false);

      if (response == null) {
        print('No payment data found for order ${_currentOrder!.id}');
        return [];
      }

      final payments = (response as List<dynamic>)
          .map((json) {
            try {
              return Payment.fromJson(json);
            } catch (e) {
              print('Error parsing payment JSON: $e');
              print('Problematic JSON: $json');
              return null;
            }
          })
          .where((payment) => payment != null)
          .cast<Payment>()
          .toList();

      print(
        'Loaded ${payments.length} payments for order ${_currentOrder!.id}',
      );
      return payments;
    } catch (e) {
      print('Error loading payments for order ${_currentOrder!.id}: $e');
      // Return empty list instead of throwing to prevent infinite loading
      return [];
    }
  }

  Future<bool> _hasPaymentsForOrder() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('kl_payments')
          .select('id')
          .eq('order_id', _currentOrder!.id)
          .limit(1);
      return (response as List).isNotEmpty;
    } catch (e) {
      print('Error checking payments for order: $e');
      return false;
    }
  }

  void _markOrderAsPaid(BuildContext context) async {
    try {
      final adminOrdersProvider = context.read<AdminOrdersProvider>();
      final success = await adminOrdersProvider.updatePaymentStatus(
        _currentOrder!.id,
        order_model.PaymentStatus.paid,
      );
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order marked as paid successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to mark order as paid'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking order as paid: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPaymentCard(BuildContext context, Payment payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment #${payment.id.substring(0, 8)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  _buildPaymentStatusBadge(payment.status),
                  if (payment.status == PaymentStatus.completed) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () =>
                            _markPaymentAsPending(context, payment),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          'Mark Pending',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount: Rp ${payment.amount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                _formatPaymentDate(payment.createdAt),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),

          if (payment.paymentMethod != null) ...[
            const SizedBox(height: 4),
            Text(
              'Method: ${payment.paymentMethod}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],

          if (payment.paymentProofUrl != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.image, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Payment proof uploaded',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => _showPaymentProofDialog(
                    context,
                    payment.paymentProofUrl!,
                  ),
                  child: const Text('View'),
                ),
              ],
            ),
          ],

          if (payment.notes != null && payment.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Notes: ${payment.notes}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  void _verifyPayment(BuildContext context, Payment payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Payment'),
        content: const Text(
          'Mark this payment as completed? This will update the order payment status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _updatePaymentStatus(payment.id, PaymentStatus.completed);
                Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment verified successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to verify payment: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _markPaymentAsPending(BuildContext context, Payment payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Payment as Pending'),
        content: const Text(
          'Mark this payment as pending? This will update the payment status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _updatePaymentStatus(payment.id, PaymentStatus.pending);
                Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment marked as pending successfully'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to mark payment as pending: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark Pending'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePaymentStatus(
    String paymentId,
    PaymentStatus status,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Update payment status
      await supabase
          .from('kl_payments')
          .update({
            'status': status.toString().split('.').last,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentId);

      // Update order payment status to match
      final paymentResponse = await supabase
          .from('kl_payments')
          .select('order_id')
          .eq('id', paymentId)
          .single();

      if (paymentResponse != null) {
        final orderId = paymentResponse['order_id'] as String?;
        if (orderId != null) {
          // Map payment status to order payment status
          order_model.PaymentStatus orderStatus;
          if (status == PaymentStatus.completed) {
            orderStatus = order_model.PaymentStatus.paid;
          } else if (status == PaymentStatus.pending) {
            orderStatus = order_model.PaymentStatus.pending;
          } else {
            // For failed or cancelled, set to failed
            orderStatus = order_model.PaymentStatus.failed;
          }

          // Update order payment status via provider for consistency
          final adminOrdersProvider = context.read<AdminOrdersProvider>();
          await adminOrdersProvider.updatePaymentStatus(orderId, orderStatus);
        }
      }

      // If payment is completed, send notifications
      if (status == PaymentStatus.completed) {
        try {
          // Get payment details with proper order information
          final paymentResponse = await supabase
              .from('kl_payments')
              .select(
                'amount, order_id, kl_orders(order_number, kl_users(full_name, id))',
              )
              .eq('id', paymentId)
              .single();

          if (paymentResponse != null) {
            final paymentData = paymentResponse as Map<String, dynamic>;
            final orderId = paymentData['order_id'] as String?;
            final orderData = paymentData['kl_orders'] as Map<String, dynamic>?;
            final userData = orderData?['kl_users'] as Map<String, dynamic>?;

            final orderNumber = orderData?['order_number'] ?? 'Unknown';
            final customerName = userData?['full_name'] ?? 'Customer';
            final customerId = userData?['id'] as String?;
            final amount = paymentData['amount'] ?? 0;

            // Ensure customer_name is never null or empty for database insertion
            final finalCustomerName = customerName.isNotEmpty
                ? customerName
                : 'Customer';

            // Send admin notification (existing functionality)
            // Find admin user
            final adminResponse = await supabase
                .from('kl_users')
                .select('id')
                .eq('role', 'Admin')
                .limit(1)
                .maybeSingle();

            if (adminResponse != null) {
              final adminId = adminResponse['id'];

              // Calculate total quantity from order items
              final totalQuantity = _currentOrder!.items.fold<int>(
                0,
                (sum, item) => sum + item.quantity,
              );

              // Insert admin notification
              await supabase.from('kl_admin_notifications').insert({
                'user_id': adminId,
                'customer_name': finalCustomerName,
                'order_id': orderId,
                'quantity': totalQuantity,
                'title': 'Payment Received',
                'message':
                    'Payment of Rp ${amount.toStringAsFixed(0)} received for order $orderNumber from $finalCustomerName. Please verify the payment.',
                'type': 'payment',
                'is_read': false,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              });

              // Also send push notification to admin
              final adminTokensResponse = await supabase
                  .from('kl_admin_fcm_tokens')
                  .select('fcm_token');

              final adminTokens = (adminTokensResponse as List)
                  .map((token) => token['fcm_token'] as String)
                  .toList();

              // Send push notification to each admin
              for (final adminToken in adminTokens) {
                try {
                  final notificationService = NotificationService();
                  await notificationService.sendOrderNotificationToAdmin(
                    adminToken: adminToken,
                    title: 'Payment Received - $orderNumber',
                    customerName: finalCustomerName,
                    quantity: totalQuantity,
                    totalPrice: amount,
                    orderId: orderId ?? '',
                    orderDate: DateTime.now(),
                  );
                } catch (e) {
                  print(
                    'Error sending push notification to admin $adminToken: $e',
                  );
                }
              }

              print('Admin notification sent successfully');
            }

            // Send customer notification (new functionality)
            if (customerId != null && customerId.isNotEmpty) {
              try {
                await _sendNotificationToCustomer(
                  context,
                  customerId,
                  orderId ?? '',
                  'Pembayaran Diterima',
                  'Pembayaran Anda sebesar Rp ${amount.toStringAsFixed(0)} untuk pesanan $orderNumber telah diverifikasi dan dikonfirmasi. Terima kasih!',
                );
                print('Customer notification sent successfully');
              } catch (customerNotificationError) {
                print(
                  'Error sending customer notification: $customerNotificationError',
                );
                // Continue even if customer notification fails
              }
            }
          }
        } catch (notificationError) {
          print('Error sending notifications: $notificationError');
          // Continue even if notifications fail
        }
      }

      // Refresh the order details and payment history
      setState(() {});
      _refreshPaymentHistory();
    } catch (e) {
      print('Error updating payment status: $e');
      throw e;
    }
  }

  void _showPaymentProofDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Payment Proof',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Image
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        headers: const {'Cache-Control': 'no-cache'},
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading payment proof image: $error');
                          print('Image URL: $imageUrl');
                          print('Stack trace: $stackTrace');

                          String errorMessage = 'Failed to load image';
                          String suggestion =
                              'URL may be expired or inaccessible';

                          // Handle different types of errors
                          if (error.toString().contains('400')) {
                            errorMessage = 'Image not accessible';
                            suggestion =
                                'Payment proof may not exist or bucket not configured';
                          } else if (error.toString().contains('404')) {
                            errorMessage = 'Image not found';
                            suggestion =
                                'Payment proof file may have been deleted';
                          } else if (error.toString().contains('403')) {
                            errorMessage = 'Access denied';
                            suggestion =
                                'Storage permissions not properly configured';
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  errorMessage,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  suggestion,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    // Try to reload the image
                                    Navigator.of(context).pop();
                                    _showPaymentProofDialog(context, imageUrl);
                                  },
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retry'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(
                                      context,
                                    ).primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Footer with action buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          // TODO: Implement download functionality if needed
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Download functionality coming soon',
                              ),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _ensureStorageBucketExists() async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.storage.createBucket(
        'payment-proofs',
        const BucketOptions(
          public: true,
          fileSizeLimit: '5242880',
          allowedMimeTypes: ['image/jpeg', 'image/png', 'image/jpg'],
        ),
      );
      print('Storage bucket created or already exists');
    } catch (e) {
      print('Storage bucket creation result: $e');
      // Bucket might already exist, which is fine
    }
  }

  String _formatPaymentDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showStatusUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: order_model.OrderStatus.values.map((status) {
            return ListTile(
              title: Text(status.displayName),
              leading: Icon(Icons.circle, color: status.color),
              onTap: () async {
                // Update order status
                final success = await context
                    .read<AdminOrdersProvider>()
                    .updateOrderStatus(_currentOrder!.id, status);

                Navigator.pop(context);

                if (context.mounted) {
                  if (success) {
                    // Send notification to customer
                    await _sendNotificationToCustomer(
                      context,
                      _currentOrder!.userId,
                      _currentOrder!.id,
                      'Status Pesanan Diperbarui',
                      'Status pesanan ${_currentOrder!.orderNumber} Anda telah diperbarui menjadi ${status.displayName}.',
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Order status updated to ${status.displayName}',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to update order status'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCourierUpdateDialog(BuildContext context) {
    final courierOptions = [
      'Jne REG',
      'JNT REG',
      'Indah Cargo',
      'SPX',
      'Lion REG',
      'Lion Jago',
      'JTR',
      'Sentral Cargo',
      'Baraka',
      'SPX Resi Otomatis',
      'JNT Resi Otomatis',
    ];

    String? selectedCourier = _currentOrder!.courierInfo;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Courier Info'),
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<String>(
            value: selectedCourier,
            decoration: const InputDecoration(
              labelText: 'Select Courier',
              border: InputBorder.none,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Select Courier'),
              ),
              ...courierOptions.map((courier) {
                return DropdownMenuItem<String>(
                  value: courier,
                  child: Text(courier),
                );
              }),
            ],
            onChanged: (value) {
              selectedCourier = value;
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a courier';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (selectedCourier != null && selectedCourier!.isNotEmpty) {
                // Update courier info
                final success = await context
                    .read<AdminOrdersProvider>()
                    .updateCourierInfo(_currentOrder!.id, selectedCourier!);

                Navigator.pop(context);

                if (context.mounted) {
                  if (success) {
                    // Send notification to customer
                    await _sendNotificationToCustomer(
                      context,
                      _currentOrder!.userId,
                      _currentOrder!.id,
                      'Informasi Kurir Diperbarui',
                      'Informasi kurir untuk pesanan ${_currentOrder!.orderNumber} Anda telah diperbarui menjadi $selectedCourier.',
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Informasi kurir diperbarui menjadi $selectedCourier',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gagal memperbarui informasi kurir'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showAdditionalCostsDialog(BuildContext context) {
    final costController = TextEditingController(
      text: _currentOrder!.additionalCosts?.toString() ?? '',
    );
    final notesController = TextEditingController(
      text:
          _currentOrder!.additionalCostsNotes ??
          (_currentOrder!.status == order_model.OrderStatus.menungguOngkir
              ? 'Ongkir'
              : ''),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Additional Costs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: costController,
              decoration: const InputDecoration(
                labelText: 'Additional Costs (Rp)',
                hintText: 'Enter additional costs amount...',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Enter notes for additional costs...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final costText = costController.text.trim();
              if (costText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter additional costs amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final cost = double.tryParse(costText);
              if (cost == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid cost amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final notes = notesController.text.trim().isEmpty
                  ? null
                  : notesController.text.trim();

              // Update additional costs first
              print(
                'OrderDetailsScreen: Calling updateAdditionalCosts with orderId: ${_currentOrder!.id}, cost: $cost, notes: $notes',
              );
              final success = await context
                  .read<AdminOrdersProvider>()
                  .updateAdditionalCosts(_currentOrder!.id, cost, notes);
              print(
                'OrderDetailsScreen: updateAdditionalCosts returned: $success',
              );

              // Send notification to customer if update was successful and additional costs were added
              if (success && cost > 0) {
                try {
                  await _sendNotificationToCustomer(
                    context,
                    _currentOrder!.userId,
                    _currentOrder!.id,
                    'Harga Pesanan Diperbarui',
                    'Harga pesanan ${_currentOrder!.orderNumber} Anda telah diperbarui. Biaya tambahan: Rp ${cost.toStringAsFixed(0)}. Jumlah total: Rp ${(_currentOrder!.totalAmount + cost).toStringAsFixed(0)}. Silakan selesaikan pembayaran Anda.',
                  );
                } catch (e) {
                  print('Failed to send notification: $e');
                  // Continue even if notification fails
                }
              }

              // Close the dialog
              Navigator.pop(context);

              // Show success/error message after dialog is closed to avoid context issues
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Biaya tambahan berhasil diperbarui'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gagal memperbarui biaya tambahan'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _printDeliveryAddress(BuildContext context) async {
    try {
      await PrintService.printDeliveryAddressesNew([_currentOrder!]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery address sent to printer'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPrintPreview(BuildContext context) async {
    try {
      await PrintService.showPrintPreviewNew(context, [_currentOrder!]);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error showing preview: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditAddressDialog(BuildContext context) {
    final addressController = TextEditingController(
      text: _currentOrder!.shippingAddress,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Shipping Address'),
        content: TextField(
          controller: addressController,
          decoration: const InputDecoration(
            labelText: 'Shipping Address',
            hintText: 'Enter complete shipping address...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newAddress = addressController.text.trim();
              if (newAddress.isNotEmpty) {
                context.read<AdminOrdersProvider>().updateShippingAddress(
                  _currentOrder!.id,
                  newAddress,
                );
                Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Shipping address updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showPaymentNotificationDialog(BuildContext context) {
    // Calculate payment information
    final totalAmount =
        _currentOrder!.totalAmount + (_currentOrder!.additionalCosts ?? 0);

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<Payment>>(
        future: _loadPaymentsForOrder(),
        builder: (context, snapshot) {
          final payments = snapshot.data ?? [];
          final totalPaid = payments
              .where((payment) => payment.status == PaymentStatus.completed)
              .fold<double>(0.0, (sum, payment) => sum + payment.amount);
          final remainingAmount = totalAmount - totalPaid;

          final messageController = TextEditingController(
            text: remainingAmount > 0
                ? 'Mohon selesaikan pembayaran untuk pesanan ${_currentOrder!.orderNumber}. Total: Rp ${totalAmount.toStringAsFixed(0)}, Dibayar: Rp ${totalPaid.toStringAsFixed(0)}, Sisa: Rp ${remainingAmount.toStringAsFixed(0)}.'
                : 'Pengingat pembayaran untuk pesanan ${_currentOrder!.orderNumber}. Total: Rp ${totalAmount.toStringAsFixed(0)}. Terima kasih atas pembayaran Anda!',
          );

          return AlertDialog(
            title: const Text('Send Payment Notification'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Order: ${_currentOrder!.orderNumber}'),
                Text('Customer: ${_currentOrder!.receiverName ?? 'N/A'}'),
                const SizedBox(height: 16),

                // Payment Summary Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount:'),
                          Text(
                            'Rp ${totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Paid:'),
                          Text(
                            'Rp ${totalPaid.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: totalPaid > 0 ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Remaining:'),
                          Text(
                            'Rp ${remainingAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: remainingAmount > 0
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Notification Message',
                    hintText: 'Enter payment notification message...',
                  ),
                  maxLines: 4,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final message = messageController.text.trim();
                  if (message.isNotEmpty) {
                    await _sendNotificationToCustomer(
                      context,
                      _currentOrder!.userId,
                      _currentOrder!.id,
                      'Pembayaran Diingatkan',
                      message,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Send Notification'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sendNotificationToCustomer(
    BuildContext context,
    String userId,
    String orderId,
    String title,
    String message,
  ) async {
    try {
      // Get customer FCM token
      final supabase = Supabase.instance.client;
      final tokenResponse = await supabase
          .from('kl_customer_fcm_tokens')
          .select('fcm_token')
          .eq('user_id', userId)
          .maybeSingle();

      if (tokenResponse == null ||
          tokenResponse['fcm_token'] == null ||
          tokenResponse['fcm_token'].toString().trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Customer FCM token not found for user $userId. Customer needs to login to receive notifications.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      final customerToken = tokenResponse['fcm_token'];

      // Send notification via notification service
      final notificationService = NotificationService();
      await notificationService.sendOrderNotificationToCustomer(
        customerToken: customerToken,
        title: title,
        body: message,
        orderId: orderId,
      );

      // Add notification to customer notifications table via database
      try {
        await supabase.from('kl_customer_notifications').insert({
          'user_id': userId,
          'order_id': orderId,
          'title': title,
          'message': message,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
        print('Customer notification added to database successfully');
      } catch (e) {
        print('Could not add notification to database: $e');
        // Continue without adding to database if it fails
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification sent to customer successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

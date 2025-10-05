import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../models/payment.dart';
import '../../providers/orders_provider.dart';
import '../../providers/payment_provider.dart';
import '../payment/payment_screen.dart';
import '../payment/invoice_preview_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Order order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Future<List<Payment>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _paymentsFuture = _loadPayments();
  }

  Future<List<Payment>> _loadPayments() {
    final paymentProvider = Provider.of<PaymentProvider>(
      context,
      listen: false,
    );
    return paymentProvider.getPaymentsForOrder(widget.order.id);
  }

  Future<void> _refreshData() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final paymentProvider = Provider.of<PaymentProvider>(
      context,
      listen: false,
    );

    await ordersProvider.refreshOrderById(widget.order.id);
    await paymentProvider.refreshPaymentsForOrder(widget.order.id);

    // Reload payments future
    setState(() {
      _paymentsFuture = _loadPayments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final paymentProvider = Provider.of<PaymentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.order.orderNumber}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
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
                      Text(
                        'Order Status',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildOrderStatusTimeline(context, widget.order),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Order Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildOrderDetail(
                        'Order Number',
                        widget.order.orderNumber,
                      ),
                      _buildOrderDetail(
                        'Total Amount',
                        'Rp ${widget.order.totalAmount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                      ),
                      _buildOrderDetail(
                        'Payment Method',
                        widget.order.paymentMethod ?? 'Not specified',
                      ),
                      _buildOrderDetail(
                        'Shipping Address',
                        widget.order.shippingAddress,
                      ),
                      if (widget.order.courierInfo != null &&
                          widget.order.courierInfo!.isNotEmpty)
                        _buildOrderDetail(
                          'Courier Service',
                          widget.order.courierInfo!,
                        ),
                      if (widget.order.notes != null &&
                          widget.order.notes!.isNotEmpty)
                        _buildOrderDetail('Notes', widget.order.notes!),
                      _buildOrderDetail(
                        'Order Date',
                        widget.order.createdAt.toString().split(' ')[0],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Additional Costs Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Costs',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.order.additionalCosts != null &&
                          widget.order.additionalCosts! > 0) ...[
                        _buildOrderDetail(
                          'Additional Amount',
                          'Rp ${widget.order.additionalCosts!.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                        ),
                        if (widget.order.additionalCostsNotes != null &&
                            widget.order.additionalCostsNotes!.isNotEmpty)
                          _buildOrderDetail(
                            'Notes',
                            widget.order.additionalCostsNotes!,
                          ),
                      ] else ...[
                        _buildOrderDetail(
                          'Additional Costs',
                          'No additional costs',
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Payment History Card
              FutureBuilder<List<Payment>>(
                future: _paymentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment History',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading payment history',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    final payments = snapshot.data!;
                    final paymentProgress = paymentProvider
                        .calculatePaymentProgress(
                          widget.order.id,
                          widget.order.totalAmount +
                              (widget.order.additionalCosts ?? 0),
                        );

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment History & Status',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),

                            // Payment Progress
                            _buildPaymentProgress(context, paymentProgress),

                            const SizedBox(height: 16),

                            // Payment Status
                            _buildPaymentStatus(context, widget.order),

                            const SizedBox(height: 16),

                            // Payment History List
                            ...payments.map(
                              (payment) =>
                                  _buildPaymentHistoryItem(context, payment),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    final paymentProgress = paymentProvider
                        .calculatePaymentProgress(
                          widget.order.id,
                          widget.order.totalAmount +
                              (widget.order.additionalCosts ?? 0),
                        );

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment History & Status',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),

                            // Payment Progress (always show)
                            _buildPaymentProgress(context, paymentProgress),

                            const SizedBox(height: 16),

                            // Payment Status (always show)
                            _buildPaymentStatus(context, widget.order),

                            const SizedBox(height: 16),

                            // Payment History or No Payment Message
                            if (paymentProgress.totalPaid > 0) ...[
                              Text(
                                'Payment History',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No payment records found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ] else ...[
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Payment Required',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'You haven\'t submitted any payments yet. Please complete your payment to proceed with the order.',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 16),

              // Order Items Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Items',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...widget.order.items.map(
                        (item) => _buildOrderItem(context, item),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              if (widget.order.status == OrderStatus.barangDikirim) ...[
                // Invoice Print Button for shipped orders
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  InvoicePreviewScreen(order: widget.order),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Print Invoice'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Payment Button for unpaid orders
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to Orders'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (widget.order.status == OrderStatus.menungguOngkir ||
                        widget.order.status == OrderStatus.menungguPembayaran ||
                        widget.order.status == OrderStatus.pembayaranPartial)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    PaymentScreen(order: widget.order),
                              ),
                            );
                          },
                          icon: const Icon(Icons.payment),
                          label: const Text('Pay Now'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderStatusTimeline(BuildContext context, Order order) {
    final statuses = [
      OrderStatus.menungguOngkir,
      OrderStatus.menungguPembayaran,
      OrderStatus.pembayaranPartial,
      OrderStatus.lunas,
      OrderStatus.barangDikirim,
    ];

    final currentStatusIndex = statuses.indexOf(order.status);

    return Column(
      children: statuses.asMap().entries.map((entry) {
        final index = entry.key;
        final status = entry.value;
        final isCompleted = index <= currentStatusIndex;
        final isCurrent = index == currentStatusIndex;

        return Row(
          children: [
            // Status Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? (isCurrent
                          ? Theme.of(context).primaryColor
                          : Colors.green)
                    : Colors.grey.shade300,
              ),
              child: Icon(
                _getStatusIcon(status),
                color: isCompleted ? Colors.white : Colors.grey,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            // Status Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.displayName,
                    style: TextStyle(
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isCurrent
                          ? Theme.of(context).primaryColor
                          : isCompleted
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                  if (isCurrent && order.status == OrderStatus.barangDikirim)
                    Text(
                      'Estimated delivery: 2-3 business days',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                ],
              ),
            ),

            // Connection Line (except for last item)
            if (index < statuses.length - 1)
              Container(
                width: 2,
                height: 30,
                color: index < currentStatusIndex
                    ? Colors.green
                    : Colors.grey.shade300,
                margin: const EdgeInsets.only(left: 19),
              ),
          ],
        );
      }).toList(),
    );
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.menungguOngkir:
        return Icons.local_shipping;
      case OrderStatus.menungguPembayaran:
        return Icons.payment;
      case OrderStatus.pembayaranPartial:
        return Icons.account_balance_wallet;
      case OrderStatus.lunas:
        return Icons.check_circle;
      case OrderStatus.barangDikirim:
        return Icons.done_all;
      default:
        return Icons.help;
    }
  }

  Widget _buildOrderDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(BuildContext context, OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).cardColor,
            ),
            child: (item.productImageUrl?.isNotEmpty ?? false)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.productImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.inventory_2,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.inventory_2,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
          ),

          const SizedBox(width: 12),

          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity}x Rp ${item.unitPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // Item Total
          Text(
            'Rp ${item.totalPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentProgress(
    BuildContext context,
    PaymentProgress paymentProgress,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Payment Progress',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '${paymentProgress.progress.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: paymentProgress.isFullyPaid
                    ? Colors.green
                    : paymentProgress.hasPartialPayment
                    ? Colors.orange
                    : Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: paymentProgress.progress / 100,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(
            paymentProgress.isFullyPaid
                ? Colors.green
                : paymentProgress.hasPartialPayment
                ? Colors.orange
                : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Paid: Rp ${paymentProgress.totalPaid.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
              style: TextStyle(
                color: paymentProgress.totalPaid > 0
                    ? Colors.green
                    : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Total: Rp ${paymentProgress.orderTotal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (paymentProgress.remainingAmount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Remaining: Rp ${paymentProgress.remainingAmount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentStatus(BuildContext context, Order order) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: order.paymentStatus.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: order.paymentStatus.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.payment, color: order.paymentStatus.color),
          const SizedBox(width: 8),
          Text(
            'Payment Status: ${order.paymentStatus.displayName}',
            style: TextStyle(
              color: order.paymentStatus.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryItem(BuildContext context, Payment payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rp ${payment.amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: payment.status.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  payment.status.displayName,
                  style: TextStyle(
                    color: payment.status.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (payment.paymentMethod != null)
            Row(
              children: [
                Icon(Icons.payment, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  payment.paymentMethod!,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                payment.createdAt.toString().split(' ')[0],
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          if (payment.notes != null && payment.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.note, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    payment.notes!,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

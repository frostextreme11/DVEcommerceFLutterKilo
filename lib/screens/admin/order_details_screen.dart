import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_orders_provider.dart';
import '../../models/order.dart';
import '../../widgets/custom_button.dart';
import '../../services/print_service.dart';

class OrderDetailsScreen extends StatelessWidget {
  final Order order;

  const OrderDetailsScreen({Key? key, required this.order}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                        _buildPaymentStatusBadge(order.paymentStatus),
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
                    _buildInfoRow('Address', order.shippingAddress),
                    if (order.notes != null) _buildInfoRow('Notes', order.notes!),

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
                                Icon(Icons.local_shipping, color: Colors.orange, size: 20),
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
                            _buildInfoRow('Sender Name', order.senderName ?? 'N/A'),
                            _buildInfoRow('Sender Phone', order.senderPhone ?? 'N/A'),
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
                    _buildInfoRow('Courier Info', order.courierInfo ?? 'Not set'),
                    _buildInfoRow('Payment Method', order.paymentMethod ?? 'N/A'),
                    _buildInfoRow('Subtotal', 'Rp ${order.totalAmount.toStringAsFixed(0)}'),
                    if (order.additionalCosts != null && order.additionalCosts! > 0) ...[
                      _buildInfoRow('Additional Costs', 'Rp ${order.additionalCosts!.toStringAsFixed(0)}'),
                      _buildInfoRow('Total Amount', 'Rp ${(order.totalAmount + order.additionalCosts!).toStringAsFixed(0)}'),
                    ] else
                      _buildInfoRow('Total Amount', 'Rp ${order.totalAmount.toStringAsFixed(0)}'),
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
                    _buildInfoRow('Additional Costs', order.additionalCosts != null && order.additionalCosts! > 0
                        ? 'Rp ${order.additionalCosts!.toStringAsFixed(0)}'
                        : 'No additional costs'),
                    if (order.additionalCostsNotes != null && order.additionalCostsNotes!.isNotEmpty)
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
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
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
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemCard(OrderItem item) {
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
                ? Icon(
                    Icons.image,
                    color: Colors.grey[400],
                    size: 24,
                  )
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity} × Rp ${item.unitPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                if (item.discountPrice != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Discount: Rp ${item.discountPrice!.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Total Price
          Text(
            'Rp ${item.totalPrice.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: OrderStatus.values.map((status) {
            return ListTile(
              title: Text(status.displayName),
              leading: Icon(
                Icons.circle,
                color: status.color,
              ),
              onTap: () {
                context.read<AdminOrdersProvider>().updateOrderStatus(order.id, status);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Order status updated to ${status.displayName}'),
                    backgroundColor: Colors.green,
                  ),
                );
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

    String? selectedCourier = order.courierInfo;

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
            onPressed: () {
              if (selectedCourier != null && selectedCourier!.isNotEmpty) {
                context.read<AdminOrdersProvider>().updateCourierInfo(order.id, selectedCourier!);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Courier info updated to $selectedCourier'),
                    backgroundColor: Colors.green,
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

  void _showAdditionalCostsDialog(BuildContext context) {
    final costController = TextEditingController(
      text: order.additionalCosts?.toString() ?? '0'
    );
    final notesController = TextEditingController(
      text: order.additionalCostsNotes ?? ''
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
            onPressed: () {
              final cost = double.tryParse(costController.text) ?? 0;
              final notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();

              context.read<AdminOrdersProvider>().updateAdditionalCosts(order.id, cost, notes);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Additional costs updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _printDeliveryAddress(BuildContext context) async {
    try {
      await PrintService.printDeliveryAddressesNew([order]);
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
      await PrintService.showPrintPreviewNew(context, [order]);
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
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_orders_provider.dart';
import '../../models/order.dart';
import '../../widgets/custom_button.dart';
import '../../services/print_service.dart';
import 'order_details_screen.dart';

class OrdersAdminScreen extends StatefulWidget {
  const OrdersAdminScreen({Key? key}) : super(key: key);

  @override
  State<OrdersAdminScreen> createState() => _OrdersAdminScreenState();
}

class _OrdersAdminScreenState extends State<OrdersAdminScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      context.read<AdminOrdersProvider>().setSearchQuery(
        _searchController.text,
      );
    });

    // Load orders when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminOrdersProvider>().loadAllOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search orders...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white,
                          ),
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.white,
                          hintStyle: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildStatusFilter(),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCourierFilterButton('All Orders', null),
                      const SizedBox(width: 8),
                      _buildCourierFilterButton(
                        'Resi Otomatis',
                        'resi_otomatis',
                      ),
                      const SizedBox(width: 8),
                      _buildDateFilterButton(),
                      const SizedBox(width: 8),
                      _buildPrintPreviewButton(),
                      const SizedBox(width: 8),
                      _buildPrintButton(),
                      const SizedBox(width: 8),
                      _buildPdfButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await context.read<AdminOrdersProvider>().loadAllOrders();
              },
              child: Consumer<AdminOrdersProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Error: ${provider.error}',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: 'Retry',
                            onPressed: () => provider.loadAllOrders(),
                          ),
                        ],
                      ),
                    );
                  }

                  final orders = provider.filteredOrders;

                  if (orders.isEmpty) {
                    return const Center(child: Text('No orders found'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _buildOrderCard(order);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Consumer<AdminOrdersProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<OrderStatus?>(
            value: provider.selectedStatus,
            hint: Text(
              'Status',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[300]
                    : Colors.black54,
              ),
            ),
            underline: const SizedBox(),
            dropdownColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.white,
            items: [
              DropdownMenuItem<OrderStatus?>(
                value: null,
                child: Text(
                  'All Status',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[300]
                        : Colors.black,
                  ),
                ),
              ),
              ...OrderStatus.values.map((status) {
                return DropdownMenuItem<OrderStatus?>(
                  value: status,
                  child: Text(
                    status.displayName,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[300]
                          : Colors.black,
                    ),
                  ),
                );
              }),
            ],
            onChanged: (value) {
              provider.setSelectedStatus(value);
            },
          ),
        );
      },
    );
  }

  Widget _buildCourierFilterButton(String label, String? filter) {
    return Consumer<AdminOrdersProvider>(
      builder: (context, provider, child) {
        final isSelected = provider.courierFilter == filter;

        return ElevatedButton(
          onPressed: () {
            provider.setCourierFilter(filter);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected
                ? Colors.white
                : Colors.white.withOpacity(0.3),
            foregroundColor: isSelected
                ? Theme.of(context).primaryColor
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(label),
        );
      },
    );
  }

  Widget _buildDateFilterButton() {
    return Consumer<AdminOrdersProvider>(
      builder: (context, provider, child) {
        final hasDateFilter = provider.dateRange != null;

        return ElevatedButton.icon(
          onPressed: () {
            _showDateRangePicker(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: hasDateFilter
                ? Colors.white
                : Colors.white.withOpacity(0.3),
            foregroundColor: hasDateFilter
                ? Theme.of(context).primaryColor
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          icon: Icon(
            hasDateFilter ? Icons.date_range : Icons.date_range_outlined,
            size: 16,
          ),
          label: Text(
            hasDateFilter
                ? '${provider.dateRange!.start.toString().substring(5, 10)} - ${provider.dateRange!.end.toString().substring(5, 10)}'
                : 'Date Filter',
          ),
        );
      },
    );
  }

  Widget _buildPrintButton() {
    return Consumer<AdminOrdersProvider>(
      builder: (context, provider, child) {
        final orders = provider.filteredOrders;
        final hasOrders = orders.isNotEmpty;

        return ElevatedButton.icon(
          onPressed: hasOrders ? () => _handlePrintNew() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: hasOrders
                ? Colors.white
                : Colors.white.withOpacity(0.3),
            foregroundColor: hasOrders
                ? Theme.of(context).primaryColor
                : Colors.white.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          icon: const Icon(Icons.print, size: 16),
          label: Text('Print (${orders.length})'),
        );
      },
    );
  }

  Widget _buildPdfButton() {
    return Consumer<AdminOrdersProvider>(
      builder: (context, provider, child) {
        final orders = provider.filteredOrders;
        final hasOrders = orders.isNotEmpty;

        return ElevatedButton.icon(
          onPressed: hasOrders ? () => _handlePdfExport() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: hasOrders
                ? Colors.white
                : Colors.white.withOpacity(0.3),
            foregroundColor: hasOrders
                ? Theme.of(context).primaryColor
                : Colors.white.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          icon: const Icon(Icons.picture_as_pdf, size: 16),
          label: Text('PDF (${orders.length})'),
        );
      },
    );
  }

  Widget _buildPrintPreviewButton() {
    return Consumer<AdminOrdersProvider>(
      builder: (context, provider, child) {
        final orders = provider.filteredOrders;
        final hasOrders = orders.isNotEmpty;

        return ElevatedButton.icon(
          onPressed: hasOrders ? () => _handlePrintNew() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: hasOrders
                ? Colors.white
                : Colors.white.withOpacity(0.3),
            foregroundColor: hasOrders
                ? Theme.of(context).primaryColor
                : Colors.white.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          icon: const Icon(Icons.visibility, size: 16),
          label: Text('Preview (${orders.length})'),
        );
      },
    );
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rp ${order.totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(order.status),
              ],
            ),

            const SizedBox(height: 12),

            // Customer Info
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  order.receiverName ?? 'No name',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  order.receiverPhone ?? 'No phone',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Shipping Address
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.shippingAddress,
                    style: TextStyle(color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Courier Info
            if (order.courierInfo != null) ...[
              Row(
                children: [
                  Icon(Icons.local_shipping, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    order.courierInfo!,
                    style: TextStyle(
                      color:
                          order.courierInfo!.toLowerCase().contains(
                            'resi otomatis',
                          )
                          ? Colors.orange
                          : Colors.grey[600],
                      fontWeight:
                          order.courierInfo!.toLowerCase().contains(
                            'resi otomatis',
                          )
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Date
            Text(
              'Created: ${order.createdAt.toString().substring(0, 16)}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),

            const SizedBox(height: 12),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailsScreen(order: order),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('View'),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    _handleOrderAction(value, order);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit_status',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Update Status'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'update_courier',
                      child: Row(
                        children: [
                          Icon(Icons.local_shipping),
                          SizedBox(width: 8),
                          Text('Update Courier'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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

  void _handleOrderAction(String action, Order order) {
    final provider = context.read<AdminOrdersProvider>();

    switch (action) {
      case 'edit_status':
        _showStatusUpdateDialog(order);
        break;
      case 'update_courier':
        _showCourierUpdateDialog(order);
        break;
      case 'delete':
        _showDeleteConfirmation(order);
        break;
    }
  }

  void _showStatusUpdateDialog(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: OrderStatus.values.map((status) {
            return ListTile(
              title: Text(status.displayName),
              leading: Icon(Icons.circle, color: status.color),
              onTap: () {
                context.read<AdminOrdersProvider>().updateOrderStatus(
                  order.id,
                  status,
                );
                Navigator.pop(context);
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

  void _showCourierUpdateDialog(Order order) {
    final controller = TextEditingController(text: order.courierInfo ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Courier Info'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Courier Information',
            hintText: 'Enter courier details...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AdminOrdersProvider>().updateCourierInfo(
                order.id,
                controller.text,
              );
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text(
          'Are you sure you want to delete order "${order.orderNumber}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AdminOrdersProvider>().deleteOrder(order.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDateRangePicker(BuildContext context) async {
    final provider = context.read<AdminOrdersProvider>();

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: provider.dateRange,
    );

    if (picked != null) {
      provider.setDateRange(picked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Date filter applied: ${picked.start.toString().substring(5, 10)} - ${picked.end.toString().substring(5, 10)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handlePrint() async {
    final provider = context.read<AdminOrdersProvider>();
    final orders = provider.filteredOrders;

    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No orders to print'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await PrintService.printDeliveryAddresses(orders);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Printing ${orders.length} orders...'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handlePdfExport() async {
    final provider = context.read<AdminOrdersProvider>();
    final orders = provider.filteredOrders;

    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No orders to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'delivery_addresses_$timestamp.pdf';

      await PrintService.saveDeliveryAddressesAsPdf(orders, filename);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved: $filename'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handlePrintPreview() async {
    final provider = context.read<AdminOrdersProvider>();
    final orders = provider.filteredOrders;

    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No orders to preview'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await PrintService.showPrintPreview(context, orders);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preview failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handlePrintNew() async {
    final provider = context.read<AdminOrdersProvider>();
    final orders = provider.filteredOrders;

    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No orders to print'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await PrintService.printDeliveryAddressesNew(orders);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Printing ${orders.length} orders with new format...'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

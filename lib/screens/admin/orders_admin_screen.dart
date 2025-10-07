import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/admin_orders_provider.dart';
import '../../providers/customer_notification_provider.dart';
import '../../models/order.dart';
import '../../widgets/custom_button.dart';
import '../../services/print_service.dart';
import '../../services/notification_service.dart';
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
      final adminOrdersProvider = context.read<AdminOrdersProvider>();
      adminOrdersProvider.loadAllOrders();

      // Set default "Today" filter
      adminOrdersProvider.setDefaultTodayFilter();

      // Set up notification service context provider
      final notificationService = Provider.of<NotificationService>(
        context,
        listen: false,
      );
      notificationService.setContextProvider(() => context);
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
                      _buildMonthFilterButton(),
                      const SizedBox(width: 8),
                      _buildAllTimeFilterButton(),
                      const SizedBox(width: 8),
                      _buildPrintPreviewButton(),
                      const SizedBox(width: 8),
                      _buildPrintButton(),
                      const SizedBox(width: 8),
                      _buildPdfButton(),
                      const SizedBox(width: 8),
                      _buildBulkNotifyButton(),
                      const SizedBox(width: 8),
                      _buildClearFiltersButton(),
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
        final isTodayFilter =
            hasDateFilter &&
            provider.dateRange!.start.year == DateTime.now().year &&
            provider.dateRange!.start.month == DateTime.now().month &&
            provider.dateRange!.start.day == DateTime.now().day;

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
            isTodayFilter
                ? 'Today'
                : hasDateFilter
                ? '${provider.dateRange!.start.toString().substring(5, 10)} - ${provider.dateRange!.end.toString().substring(5, 10)}'
                : 'Date Filter',
          ),
        );
      },
    );
  }

  Widget _buildMonthFilterButton() {
    return Consumer<AdminOrdersProvider>(
      builder: (context, provider, child) {
        final isSelected = provider.dateFilter == 'month';

        return ElevatedButton(
          onPressed: () {
            context.read<AdminOrdersProvider>().setMonthFilter();
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
          child: const Text('Month'),
        );
      },
    );
  }

  Widget _buildAllTimeFilterButton() {
    return Consumer<AdminOrdersProvider>(
      builder: (context, provider, child) {
        final isSelected = provider.dateFilter == 'all_time';

        return ElevatedButton(
          onPressed: () {
            context.read<AdminOrdersProvider>().setAllTimeFilter();
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
          child: const Text('All Time'),
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
                if (order.paymentStatus == PaymentStatus.pending) ...[
                  TextButton.icon(
                    onPressed: () {
                      _showNotifyCustomerDialog(context, order);
                    },
                    icon: const Icon(Icons.notifications),
                    label: const Text('Notify'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                  const SizedBox(width: 8),
                ],
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
                    if (order.status != OrderStatus.cancelled &&
                        order.status != OrderStatus.barangDikirim) ...[
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'Cancel Order',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ],
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
      case 'cancel':
        _showCancelConfirmation(order);
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
                context.read<AdminOrdersProvider>().updateCourierInfo(
                  order.id,
                  selectedCourier!,
                );
                Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Courier info updated to $selectedCourier'),
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

  void _showCancelConfirmation(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel order "${order.orderNumber}"?',
            ),
            const SizedBox(height: 12),
            Text(
              'This will restore the product quantities back to stock.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              'Order items:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  '• ${item.productName} (${item.quantity} units)',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Order'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await context
                  .read<AdminOrdersProvider>()
                  .cancelOrder(order.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: success
                        ? Text(
                            'Order "${order.orderNumber}" has been cancelled and quantities restored',
                          )
                        : Text('Failed to cancel order "${order.orderNumber}"'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Cancel Order'),
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
      provider.setCustomDateRangeFilter(picked);
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

  void _showClearFiltersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Filters'),
        content: const Text(
          'This will clear all applied filters and show all orders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AdminOrdersProvider>().clearFilters();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All filters cleared'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
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

  Widget _buildBulkNotifyButton() {
    return Consumer<AdminOrdersProvider>(
      builder: (context, provider, child) {
        final unpaidOrders = provider.filteredOrders
            .where((order) => order.paymentStatus == PaymentStatus.pending)
            .toList();
        final hasUnpaidOrders = unpaidOrders.isNotEmpty;

        return ElevatedButton.icon(
          onPressed: hasUnpaidOrders
              ? () => _showBulkNotifyDialog(context)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: hasUnpaidOrders
                ? Colors.orange
                : Colors.orange.withOpacity(0.3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          icon: const Icon(Icons.notifications_active, size: 16),
          label: Text('Notify Unpaid (${unpaidOrders.length})'),
        );
      },
    );
  }

  Widget _buildClearFiltersButton() {
    return Consumer<AdminOrdersProvider>(
      builder: (context, provider, child) {
        final hasActiveFilters =
            provider.searchQuery.isNotEmpty ||
            provider.selectedStatus != null ||
            provider.courierFilter != null ||
            provider.dateFilter != null ||
            provider.dateRange != null;

        return ElevatedButton.icon(
          onPressed: hasActiveFilters
              ? () => _showClearFiltersDialog(context)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: hasActiveFilters
                ? Colors.red
                : Colors.red.withOpacity(0.3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          icon: const Icon(Icons.clear, size: 16),
          label: const Text('Clear Filters'),
        );
      },
    );
  }

  void _showNotifyCustomerDialog(BuildContext context, Order order) {
    final messageController = TextEditingController(
      text:
          'Reminder: Please complete your payment for order ${order.orderNumber}. Total amount: Rp ${order.totalAmount.toStringAsFixed(0)}',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notify Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Order: ${order.orderNumber}'),
            Text('Customer: ${order.receiverName ?? 'N/A'}'),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Enter notification message...',
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
              final message = messageController.text.trim();
              if (message.isNotEmpty) {
                await _sendNotificationToCustomer(
                  context,
                  order.userId,
                  order.id,
                  'Payment Reminder',
                  message,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showBulkNotifyDialog(BuildContext context) {
    final provider = context.read<AdminOrdersProvider>();
    final unpaidOrders = provider.filteredOrders
        .where((order) => order.paymentStatus == PaymentStatus.pending)
        .toList();

    final messageController = TextEditingController(
      text:
          'Reminder: You have ${unpaidOrders.length} unpaid order(s). Please complete your payment to proceed.',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Notify Unpaid Customers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This will send notifications to ${unpaidOrders.length} customers with unpaid orders.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Enter notification message...',
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
              final message = messageController.text.trim();
              if (message.isNotEmpty) {
                await _sendBulkNotifications(context, unpaidOrders, message);
                Navigator.pop(context);
              }
            },
            child: const Text('Send to All'),
          ),
        ],
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

  Future<void> _sendBulkNotifications(
    BuildContext context,
    List<Order> unpaidOrders,
    String message,
  ) async {
    int successCount = 0;
    int failCount = 0;

    for (final order in unpaidOrders) {
      try {
        await _sendNotificationToCustomer(
          context,
          order.userId,
          order.id,
          'Payment Reminder',
          message,
        );
        successCount++;
      } catch (e) {
        failCount++;
        print('Failed to send notification to order ${order.id}: $e');
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bulk notification completed: $successCount sent successfully, $failCount failed',
          ),
          backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }
}

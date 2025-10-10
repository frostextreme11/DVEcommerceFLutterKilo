import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import 'dart:async';

class AdminOrdersProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  OrderStatus? _selectedStatus;
  String? _courierFilter; // 'all', 'resi_otomatis', or null
  DateTimeRange? _dateRange;
  String? _dateFilter; // 'today', 'month', 'all_time', or null for custom range
  String? _paymentFilter; // 'all', 'pending_payment', or null

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  OrderStatus? get selectedStatus => _selectedStatus;
  String? get courierFilter => _courierFilter;
  DateTimeRange? get dateRange => _dateRange;
  String? get dateFilter => _dateFilter;
  String? get paymentFilter => _paymentFilter;

  // Stream for listening to orders changes
  Stream<List<Order>> get ordersStream => Stream.value(_orders);

  // Filtered orders based on search, status, courier filter, and date range
  List<Order> get filteredOrders {
    return _orders.where((order) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          order.orderNumber.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          order.shippingAddress.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (order.receiverName?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false);

      final matchesStatus =
          _selectedStatus == null || order.status == _selectedStatus;

      final matchesCourier =
          _courierFilter == null ||
          _courierFilter == 'all' ||
          (_courierFilter == 'resi_otomatis' &&
              order.courierInfo?.toLowerCase().contains('resi otomatis') ==
                  true);

      final matchesDate = _matchesDateFilter(order.createdAt);

      final matchesPayment = _matchesPaymentFilterSync(order);

      return matchesSearch &&
          matchesStatus &&
          matchesCourier &&
          matchesDate &&
          matchesPayment;
    }).toList();
  }

  // Set default "Today" filter
  void setDefaultTodayFilter() {
    _dateFilter = 'today';
    _dateRange = null;
    notifyListeners();
    // Reload orders with the new filter
    refreshOrders();
  }

  // Set Month filter
  void setMonthFilter() {
    _dateFilter = 'month';
    _dateRange = null;
    notifyListeners();
    // Reload orders with the new filter
    refreshOrders();
  }

  // Set All Time filter
  void setAllTimeFilter() {
    _dateFilter = 'all_time';
    _dateRange = null;
    notifyListeners();
    // Reload orders with the new filter
    refreshOrders();
  }

  // Set custom date range filter
  void setCustomDateRangeFilter(DateTimeRange dateRange) {
    _dateFilter = null;
    _dateRange = dateRange;
    notifyListeners();
    // Reload orders with the new filter
    refreshOrders();
  }

  // Helper method to check if order matches date filter
  bool _matchesDateFilter(DateTime orderDate) {
    final now = DateTime.now();

    switch (_dateFilter) {
      case 'today':
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        return orderDate.isAfter(today) && orderDate.isBefore(tomorrow);

      case 'month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        final startOfNextMonth = DateTime(now.year, now.month + 1, 1);
        return orderDate.isAfter(startOfMonth) &&
            orderDate.isBefore(startOfNextMonth);

      case 'all_time':
        return true; // Show all orders

      default:
        // Custom date range
        if (_dateRange != null) {
          return orderDate.isAfter(_dateRange!.start) &&
              orderDate.isBefore(_dateRange!.end.add(const Duration(days: 1)));
        }
        return true; // No filter applied
    }
  }

  // Helper method to check if order matches payment filter (synchronous)
  bool _matchesPaymentFilterSync(Order order) {
    switch (_paymentFilter) {
      case 'pending_payment':
        // Payment filter is handled in the loading logic (_applyPaymentFilter)
        // So we return true here to not interfere with the async filtering
        return true;

      case 'all':
      default:
        return true; // Show all orders or no filter applied
    }
  }

  // Get orders by status
  List<Order> getOrdersByStatus(OrderStatus status) {
    return _orders.where((order) => order.status == status).toList();
  }

  // Get recent orders (last 10)
  List<Order> get recentOrders => _orders.take(10).toList();

  Future<bool> _isUserAdmin() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      final userResponse = await _supabase
          .from('kl_users')
          .select('role')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (userResponse == null) {
        print('User not found in database');
        return false;
      }

      final userRole = userResponse['role'];
      return userRole == 'admin';
    } catch (e) {
      print('Error checking user role: $e');
      return false;
    }
  }

  Future<void> loadAllOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('AdminOrdersProvider: Starting to load orders...');

      // Check if user is admin first
      if (!await _isUserAdmin()) {
        print('AdminOrdersProvider: User is not admin, skipping order loading');
        _orders = [];
        return;
      }

      // Test database connection first
      try {
        final testResponse = await _supabase
            .from('kl_orders')
            .select('id')
            .limit(1);
        print('AdminOrdersProvider: Database connection test successful');
      } catch (e) {
        print('AdminOrdersProvider: Database connection test failed: $e');
        print('Continuing with empty orders list');
        _orders = [];
        return; // Exit early if database is not available
      }

      // Use filtered loading if any filters are applied, otherwise load all orders
      if (_hasActiveFilters()) {
        await _loadFilteredOrders();
      } else {
        await _loadAllOrdersFromDatabase();
      }
    } catch (e) {
      print(
        'AdminOrdersProvider: Error loading orders (continuing with empty list): $e',
      );
      _orders = []; // Start with empty list if database fails
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check if any filters are currently active
  bool _hasActiveFilters() {
    return _selectedStatus != null ||
        _courierFilter != null ||
        _dateFilter != null ||
        _dateRange != null ||
        _paymentFilter != null ||
        _searchQuery.isNotEmpty;
  }

  // Load all orders from database (original implementation)
  Future<void> _loadAllOrdersFromDatabase() async {
    final ordersResponse = await _supabase
        .from('kl_orders')
        .select()
        .order('created_at', ascending: false);

    final ordersData = ordersResponse as List;
    print('AdminOrdersProvider: Found ${ordersData.length} orders in database');

    // Load order items for each order
    final orders = <Order>[];
    for (final orderData in ordersData) {
      final orderId = orderData['id'];
      print('AdminOrdersProvider: Loading items for order: $orderId');

      try {
        final itemsResponse = await _supabase
            .from('kl_order_items')
            .select()
            .eq('order_id', orderId);

        final items = (itemsResponse as List)
            .map((item) => OrderItem.fromJson(item))
            .toList();

        orders.add(Order.fromJson(orderData, items));
      } catch (e) {
        print(
          'AdminOrdersProvider: Error loading items for order $orderId: $e',
        );
        // Still add the order even if items fail to load
        orders.add(Order.fromJson(orderData, []));
      }
    }

    _orders = orders;
    print('AdminOrdersProvider: Successfully loaded ${_orders.length} orders');

    if (orders.isEmpty) {
      print('AdminOrdersProvider: No orders found in database');
    }
  }

  // Load only filtered orders from database (optimized)
  Future<void> _loadFilteredOrders() async {
    print('AdminOrdersProvider: Loading filtered orders...');

    // Build the base query
    var query = _supabase.from('kl_orders').select();

    // Apply status filter
    if (_selectedStatus != null) {
      query = query.eq('status', _selectedStatus!.databaseValue);
      print(
        'AdminOrdersProvider: Applied status filter: ${_selectedStatus!.databaseValue}',
      );
    }

    // Apply date filters
    final now = DateTime.now();
    if (_dateFilter == 'today') {
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      query = query
          .gte('created_at', today.toIso8601String())
          .lt('created_at', tomorrow.toIso8601String());
      print('AdminOrdersProvider: Applied today filter');
    } else if (_dateFilter == 'month') {
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfNextMonth = DateTime(now.year, now.month + 1, 1);
      query = query
          .gte('created_at', startOfMonth.toIso8601String())
          .lt('created_at', startOfNextMonth.toIso8601String());
      print('AdminOrdersProvider: Applied month filter');
    } else if (_dateRange != null) {
      query = query
          .gte('created_at', _dateRange!.start.toIso8601String())
          .lt(
            'created_at',
            _dateRange!.end.add(const Duration(days: 1)).toIso8601String(),
          );
      print('AdminOrdersProvider: Applied custom date range filter');
    }

    // Apply courier filter
    if (_courierFilter == 'resi_otomatis') {
      query = query.ilike('courier_info', '%resi otomatis%');
      print('AdminOrdersProvider: Applied resi otomatis filter');
    }

    // Apply payment filter - this requires checking kl_payments table
    if (_paymentFilter == 'pending_payment') {
      // For pending payment filter, we need to get order IDs that have pending payments
      // This is complex in the current architecture, so we'll handle it after loading orders
      print(
        'AdminOrdersProvider: Payment filter will be applied after loading orders',
      );
    }

    // Execute the filtered query
    final ordersResponse = await query.order('created_at', ascending: false);
    final ordersData = ordersResponse as List;

    print(
      'AdminOrdersProvider: Found ${ordersData.length} filtered orders in database',
    );

    // Load order items for each filtered order
    final orders = <Order>[];
    for (final orderData in ordersData) {
      final orderId = orderData['id'];

      try {
        final itemsResponse = await _supabase
            .from('kl_order_items')
            .select()
            .eq('order_id', orderId);

        final items = (itemsResponse as List)
            .map((item) => OrderItem.fromJson(item))
            .toList();

        orders.add(Order.fromJson(orderData, items));
      } catch (e) {
        print(
          'AdminOrdersProvider: Error loading items for order $orderId: $e',
        );
        // Still add the order even if items fail to load
        orders.add(Order.fromJson(orderData, []));
      }
    }

    _orders = orders;
    print(
      'AdminOrdersProvider: Successfully loaded ${orders.length} filtered orders',
    );

    // Apply client-side search filter if search query exists
    if (_searchQuery.isNotEmpty) {
      _orders = _orders.where((order) {
        return order.orderNumber.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            order.shippingAddress.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            (order.receiverName?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false);
      }).toList();
      print(
        'AdminOrdersProvider: Applied client-side search filter for: $_searchQuery',
      );
    }

    // Apply payment filter if active
    if (_paymentFilter == 'pending_payment') {
      _orders = await _applyPaymentFilter(_orders);
    }
  }

  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      await _supabase
          .from('kl_orders')
          .update({
            'status': newStatus.databaseValue,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      // Update local order
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(status: newStatus);
        notifyListeners();
      }

      print('AdminOrdersProvider: Order status updated successfully: $orderId');
      return true;
    } catch (e) {
      print('Error updating order status (continuing locally): $e');
      // Update locally even if database update fails
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(status: newStatus);
        notifyListeners();
      }
      return true;
    }
  }

  Future<bool> updatePaymentStatus(
    String orderId,
    PaymentStatus newStatus,
  ) async {
    try {
      await _supabase
          .from('kl_orders')
          .update({
            'payment_status': newStatus.toString().split('.').last,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      // Update local order
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          paymentStatus: newStatus,
        );
        notifyListeners();
      }

      print(
        'AdminOrdersProvider: Payment status updated successfully: $orderId',
      );
      return true;
    } catch (e) {
      print('Error updating payment status (continuing locally): $e');
      // Update locally even if database update fails
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          paymentStatus: newStatus,
        );
        notifyListeners();
      }
      return true;
    }
  }

  Future<bool> updateCourierInfo(String orderId, String courierInfo) async {
    try {
      await _supabase
          .from('kl_orders')
          .update({
            'courier_info': courierInfo,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      // Update local order
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          courierInfo: courierInfo,
        );
        notifyListeners();
      }

      print('AdminOrdersProvider: Courier info updated successfully: $orderId');
      return true;
    } catch (e) {
      print('Error updating courier info (continuing locally): $e');
      // Update locally even if database update fails
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          courierInfo: courierInfo,
        );
        notifyListeners();
      }
      return true;
    }
  }

  Future<bool> updateAdditionalCosts(
    String orderId,
    double additionalCosts,
    String? additionalCostsNotes,
  ) async {
    try {
      print(
        'AdminOrdersProvider: Starting additional costs update for order $orderId',
      );
      print(
        'AdminOrdersProvider: New additional costs: $additionalCosts, notes: $additionalCostsNotes',
      );

      // Get current order to check its status
      final currentOrder = _orders.firstWhere((order) => order.id == orderId);
      print(
        'AdminOrdersProvider: Current order status: ${currentOrder.status.displayName}',
      );
      OrderStatus? newStatus;

      // If additional costs are being added and current status is "Menunggu Ongkir",
      // automatically transition to "Menunggu Pembayaran"
      if (additionalCosts > 0 &&
          currentOrder.status == OrderStatus.menungguOngkir) {
        newStatus = OrderStatus.menungguPembayaran;
        print(
          'AdminOrdersProvider: Status will change to: ${newStatus.displayName}',
        );
      }

      final updateData = {
        'additional_costs': additionalCosts,
        'additional_costs_notes': additionalCostsNotes,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (newStatus != null) {
        updateData['status'] = newStatus.databaseValue;
      }

      print('AdminOrdersProvider: Update data: $updateData');

      final response = await _supabase
          .from('kl_orders')
          .update(updateData)
          .eq('id', orderId)
          .select();

      print('AdminOrdersProvider: Database response: $response');

      // Update local order
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          additionalCosts: additionalCosts,
          additionalCostsNotes: additionalCostsNotes,
          status: newStatus ?? currentOrder.status,
        );
        notifyListeners();
        print(
          'AdminOrdersProvider: Local order updated and listeners notified',
        );
      }

      print(
        'AdminOrdersProvider: Additional costs updated successfully: $orderId${newStatus != null ? ' (status changed to ${newStatus.displayName})' : ''}',
      );
      return true;
    } catch (e) {
      print('Error updating additional costs (continuing locally): $e');
      print('Stack trace: ${StackTrace.current}');
      // Update locally even if database update fails
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex >= 0) {
        final currentOrder = _orders[orderIndex];
        OrderStatus? newStatus;

        // If additional costs are being added and current status is "Menunggu Ongkir",
        // automatically transition to "Menunggu Pembayaran"
        if (additionalCosts > 0 &&
            currentOrder.status == OrderStatus.menungguOngkir) {
          newStatus = OrderStatus.menungguPembayaran;
        }

        _orders[orderIndex] = _orders[orderIndex].copyWith(
          additionalCosts: additionalCosts,
          additionalCostsNotes: additionalCostsNotes,
          status: newStatus ?? currentOrder.status,
        );
        notifyListeners();
        print('AdminOrdersProvider: Updated locally after database error');
      }
      return true;
    }
  }

  Future<bool> updateShippingAddress(String orderId, String newAddress) async {
    try {
      await _supabase
          .from('kl_orders')
          .update({
            'shipping_address': newAddress,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      // Update local order
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          shippingAddress: newAddress,
        );
        notifyListeners();
      }

      print(
        'AdminOrdersProvider: Shipping address updated successfully: $orderId',
      );
      return true;
    } catch (e) {
      print('Error updating shipping address (continuing locally): $e');
      // Update locally even if database update fails
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          shippingAddress: newAddress,
        );
        notifyListeners();
      }
      return true;
    }
  }

  Future<bool> deleteOrder(String orderId) async {
    try {
      // Delete order items first
      await _supabase.from('kl_order_items').delete().eq('order_id', orderId);

      // Delete order
      await _supabase.from('kl_orders').delete().eq('id', orderId);

      _orders.removeWhere((order) => order.id == orderId);
      notifyListeners();

      print('AdminOrdersProvider: Order deleted successfully: $orderId');
      return true;
    } catch (e) {
      print('Error deleting order (removing locally): $e');
      // Remove locally even if database deletion fails
      _orders.removeWhere((order) => order.id == orderId);
      notifyListeners();
      return true;
    }
  }

  Future<bool> cancelOrder(String orderId) async {
    try {
      // Get the order details first to restore quantities
      final order = await getOrderById(orderId);
      if (order == null) {
        print(
          'AdminOrdersProvider: Order not found for cancellation: $orderId',
        );
        return false;
      }

      // Check if order can be cancelled (not already shipped or cancelled)
      if (order.status == OrderStatus.barangDikirim) {
        print(
          'AdminOrdersProvider: Cannot cancel order that is already shipped',
        );
        return false;
      }

      if (order.status == OrderStatus.cancelled) {
        print('AdminOrdersProvider: Order is already cancelled');
        return false;
      }

      // Start a transaction-like operation
      // 1. Update order status to cancelled
      await _supabase
          .from('kl_orders')
          .update({
            'status': OrderStatus.cancelled.databaseValue,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      // 2. Restore product quantities for each order item
      for (final item in order.items) {
        if (item.productId.isNotEmpty) {
          // Get current product stock
          final productResponse = await _supabase
              .from('kl_products')
              .select('stock_quantity')
              .eq('id', item.productId)
              .maybeSingle();

          if (productResponse != null) {
            final currentStock = productResponse['stock_quantity'] as int? ?? 0;
            final newStock = currentStock + item.quantity;

            // Update product stock
            await _supabase
                .from('kl_products')
                .update({
                  'stock_quantity': newStock,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', item.productId);

            print(
              'AdminOrdersProvider: Restored ${item.quantity} units of product ${item.productId}. New stock: $newStock',
            );
          }
        }
      }

      // Update local order
      final orderIndex = _orders.indexWhere((o) => o.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          status: OrderStatus.cancelled,
        );
        notifyListeners();
      }

      print('AdminOrdersProvider: Order cancelled successfully: $orderId');
      return true;
    } catch (e) {
      print('Error cancelling order (updating locally): $e');
      // Update locally even if database update fails
      final orderIndex = _orders.indexWhere((o) => o.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          status: OrderStatus.cancelled,
        );
        notifyListeners();
      }
      return true;
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
    // Reload orders with the new search filter
    refreshOrders();
  }

  void setSelectedStatus(OrderStatus? status) {
    _selectedStatus = status;
    notifyListeners();
    // Reload orders with the new status filter
    refreshOrders();
  }

  void setCourierFilter(String? filter) {
    _courierFilter = filter;
    notifyListeners();
    // Reload orders with the new courier filter
    refreshOrders();
  }

  void setPaymentFilter(String? filter) {
    _paymentFilter = filter;
    notifyListeners();
    // Reload orders with the new payment filter
    refreshOrders();
  }

  void setDateRange(DateTimeRange? dateRange) {
    if (dateRange != null) {
      setCustomDateRangeFilter(dateRange);
    } else {
      _dateFilter = null;
      _dateRange = null;
      notifyListeners();
    }
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedStatus = null;
    _courierFilter = null;
    _dateFilter = null;
    _dateRange = null;
    _paymentFilter = null;
    notifyListeners();
    // Reload orders after clearing filters
    refreshOrders();
  }

  // Refresh orders based on current filters
  Future<void> refreshOrders() async {
    await loadAllOrders();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<Order?> getOrderById(String orderId) async {
    // First try to find in local orders
    try {
      return _orders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      print('Order not found in local list, fetching from database: $orderId');
      // If not found locally, try to fetch from database
      final order = await _fetchOrderFromDatabase(orderId);
      if (order != null) {
        // Add the fetched order to local list for future use
        _orders.add(order);
        notifyListeners();
      }
      return order;
    }
  }

  Future<Order?> _fetchOrderFromDatabase(String orderId) async {
    try {
      // Fetch order from database
      final orderResponse = await _supabase
          .from('kl_orders')
          .select()
          .eq('id', orderId)
          .maybeSingle();

      if (orderResponse == null) {
        print('Order not found in database: $orderId');
        return null;
      }

      // Fetch order items
      final itemsResponse = await _supabase
          .from('kl_order_items')
          .select()
          .eq('order_id', orderId);

      final items = (itemsResponse as List)
          .map((item) => OrderItem.fromJson(item))
          .toList();

      final order = Order.fromJson(orderResponse, items);
      print('Successfully fetched order from database: $orderId');
      return order;
    } catch (e) {
      print('Error fetching order from database: $e');
      return null;
    }
  }

  // Get orders with "Resi Otomatis" courier info
  List<Order> get ordersWithResiOtomatis {
    return _orders
        .where(
          (order) =>
              order.courierInfo?.toLowerCase().contains('resi otomatis') ==
              true,
        )
        .toList();
  }

  // Sales calculation variables
  double _monthlySales = 0.0;
  double _yearlySales = 0.0;
  bool _isCalculatingSales = false;

  // Getters for sales values
  double get monthlySales => _monthlySales;
  double get yearlySales => _yearlySales;
  bool get isCalculatingSales => _isCalculatingSales;

  // Calculate total sales for current month on demand (optimized - direct DB query)
  Future<void> calculateMonthlySales() async {
    if (_isCalculatingSales) return;

    _isCalculatingSales = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Query orders directly from database for monthly sales
      var query = _supabase
          .from('kl_orders')
          .select('total_amount, status, created_at')
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String());

      // Apply status filter using or conditions
      query = query.or(
        'status.eq.${OrderStatus.menungguPembayaran.databaseValue},status.eq.${OrderStatus.pembayaranPartial.databaseValue},status.eq.${OrderStatus.lunas.databaseValue},status.eq.${OrderStatus.barangDikirim.databaseValue}',
      );

      final ordersResponse = await query;

      final ordersData = ordersResponse as List;
      _monthlySales = ordersData.fold(0.0, (sum, order) {
        final totalAmount = order['total_amount'] as double? ?? 0.0;
        return sum + totalAmount;
      });

      print(
        'AdminOrdersProvider: Calculated monthly sales from DB: Rp ${_monthlySales.toStringAsFixed(0)} (${ordersData.length} orders)',
      );
    } catch (e) {
      print('AdminOrdersProvider: Error calculating monthly sales from DB: $e');
      _monthlySales = 0.0;
    } finally {
      _isCalculatingSales = false;
      notifyListeners();
    }
  }

  // Calculate total sales for current year on demand (optimized - direct DB query)
  Future<void> calculateYearlySales() async {
    if (_isCalculatingSales) return;

    _isCalculatingSales = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final endOfYear = DateTime(now.year, 12, 31, 23, 59, 59);

      // Query orders directly from database for yearly sales
      var query = _supabase
          .from('kl_orders')
          .select('total_amount, status, created_at')
          .gte('created_at', startOfYear.toIso8601String())
          .lte('created_at', endOfYear.toIso8601String());

      // Apply status filter using or conditions
      query = query.or(
        'status.eq.${OrderStatus.lunas.databaseValue},status.eq.${OrderStatus.barangDikirim.databaseValue}',
      );

      final ordersResponse = await query;

      final ordersData = ordersResponse as List;
      _yearlySales = ordersData.fold(0.0, (sum, order) {
        final totalAmount = order['total_amount'] as double? ?? 0.0;
        return sum + totalAmount;
      });

      print(
        'AdminOrdersProvider: Calculated yearly sales from DB: Rp ${_yearlySales.toStringAsFixed(0)} (${ordersData.length} orders)',
      );
    } catch (e) {
      print('AdminOrdersProvider: Error calculating yearly sales from DB: $e');
      _yearlySales = 0.0;
    } finally {
      _isCalculatingSales = false;
      notifyListeners();
    }
  }

  // Calculate total sales for all time
  double get totalSales {
    return _orders
        .where(
          (order) =>
              order.status == OrderStatus.lunas ||
              order.status == OrderStatus.barangDikirim,
        )
        .fold(0.0, (sum, order) => sum + order.totalAmount);
  }

  // Reset sales values
  void resetSalesValues() {
    _monthlySales = 0.0;
    _yearlySales = 0.0;
    notifyListeners();
  }

  // Apply payment filter by checking kl_payments table
  Future<List<Order>> _applyPaymentFilter(List<Order> orders) async {
    if (_paymentFilter != 'pending_payment') {
      return orders;
    }

    try {
      print(
        'AdminOrdersProvider: Applying payment filter for pending payments...',
      );

      // Get all order IDs that have pending payments in kl_payments table
      final paymentsResponse = await _supabase
          .from('kl_payments')
          .select('order_id')
          .eq('status', 'pending');

      final paymentsData = paymentsResponse as List;
      final pendingOrderIds = paymentsData
          .map((payment) => payment['order_id'] as String)
          .toSet();

      print(
        'AdminOrdersProvider: Found ${pendingOrderIds.length} orders with pending payments',
      );

      // Filter orders to only include those with pending payments
      final filteredOrders = orders
          .where((order) => pendingOrderIds.contains(order.id))
          .toList();

      print(
        'AdminOrdersProvider: Filtered to ${filteredOrders.length} orders with pending payments',
      );
      return filteredOrders;
    } catch (e) {
      print('AdminOrdersProvider: Error applying payment filter: $e');
      // Return original orders if there's an error
      return orders;
    }
  }
}

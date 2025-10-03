import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';

class AdminOrdersProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  OrderStatus? _selectedStatus;
  String? _courierFilter; // 'all', 'resi_otomatis', or null
  DateTimeRange? _dateRange;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  OrderStatus? get selectedStatus => _selectedStatus;
  String? get courierFilter => _courierFilter;
  DateTimeRange? get dateRange => _dateRange;

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

      final matchesDate =
          _dateRange == null ||
          (order.createdAt.isAfter(_dateRange!.start) &&
              order.createdAt.isBefore(
                _dateRange!.end.add(const Duration(days: 1)),
              ));

      return matchesSearch && matchesStatus && matchesCourier && matchesDate;
    }).toList();
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

      // Load orders
      final ordersResponse = await _supabase
          .from('kl_orders')
          .select()
          .order('created_at', ascending: false);

      final ordersData = ordersResponse as List;
      print(
        'AdminOrdersProvider: Found ${ordersData.length} orders in database',
      );

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
      print(
        'AdminOrdersProvider: Successfully loaded ${_orders.length} orders',
      );

      if (orders.isEmpty) {
        print('AdminOrdersProvider: No orders found in database');
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

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedStatus(OrderStatus? status) {
    _selectedStatus = status;
    notifyListeners();
  }

  void setCourierFilter(String? filter) {
    _courierFilter = filter;
    notifyListeners();
  }

  void setDateRange(DateTimeRange? dateRange) {
    _dateRange = dateRange;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedStatus = null;
    _courierFilter = null;
    _dateRange = null;
    notifyListeners();
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

  // Calculate total sales for current month
  double get monthlySales {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return _orders
        .where(
          (order) =>
              order.createdAt.isAfter(startOfMonth) &&
              order.createdAt.isBefore(endOfMonth) &&
              (order.status == OrderStatus.menungguPembayaran ||
                  order.status == OrderStatus.pembayaranPartial ||
                  order.status == OrderStatus.lunas ||
                  order.status == OrderStatus.barangDikirim),
        )
        .fold(0.0, (sum, order) => sum + order.totalAmount);
  }

  // Calculate total sales for current year
  double get yearlySales {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfYear = DateTime(now.year, 12, 31, 23, 59, 59);

    return _orders
        .where(
          (order) =>
              order.createdAt.isAfter(startOfYear) &&
              order.createdAt.isBefore(endOfYear) &&
              (order.status == OrderStatus.lunas ||
                  order.status == OrderStatus.barangDikirim),
        )
        .fold(0.0, (sum, order) => sum + order.totalAmount);
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
}

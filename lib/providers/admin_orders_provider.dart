import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import 'dart:async';
import 'dart:math';

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

  // Cache for search results to avoid redundant database queries
  final Duration _cacheExpiry = const Duration(seconds: 30);

  // Filtered orders based on search, status, courier filter, and date range
  List<Order> get filteredOrders {
    return _orders.where((order) {
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

      // For search, we rely on database-level search that's already applied
      // so we don't need to filter here anymore
      return matchesStatus && matchesCourier && matchesDate && matchesPayment;
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

      // Always use optimized filtered loading for better performance
      await _loadOptimizedOrders();
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

  // Optimized method that handles search, filtering, and pagination at database level
  Future<void> _loadOptimizedOrders() async {
    print('AdminOrdersProvider: Loading optimized orders...');

    // Clear cache when new filters are applied
    _clearExpiredCache();

    // Check if we have a cached result for this query
    final cacheKey = _generateCacheKey();
    final cachedResult = _cacheWithTimestamp[cacheKey]?.orders;
    if (cachedResult != null && _isCacheValid(cacheKey)) {
      print('AdminOrdersProvider: Using cached result for: $cacheKey');
      _orders = cachedResult;
      return;
    }

    // Handle search with comprehensive user data search
    if (_searchQuery.isNotEmpty) {
      await _searchWithUserData(_searchQuery);
      return;
    }

    // Build the base query with order items and user info
    var query = _supabase.from('kl_orders').select('''
      *,
      kl_order_items(*),
      kl_users!kl_orders_user_id_fkey(full_name, email)
    ''');

    // Apply filters for non-search queries
    if (_selectedStatus != null) {
      query = query.eq('status', _selectedStatus!.databaseValue);
    }

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

    // Add ordering and limit for better performance
    final orderedQuery = query.order('created_at', ascending: false);
    final finalQuery = orderedQuery.limit(1000);

    // Execute the optimized query
    final ordersResponse = await finalQuery;
    final ordersData = ordersResponse as List;

    print(
      'AdminOrdersProvider: Found ${ordersData.length} orders from database query',
    );

    // Convert to Order objects with order items
    final orders = <Order>[];
    for (final orderData in ordersData) {
      try {
        // Extract order items from the joined data
        final orderItemsData = orderData['kl_order_items'] as List? ?? [];
        final items = orderItemsData
            .map((item) => OrderItem.fromJson(item))
            .toList();

        // Add user info if available for search purposes
        final userData = orderData['kl_users'] as Map<String, dynamic>?;
        if (userData != null) {
          // Create enhanced order data with user information for search
          final enhancedOrderData = Map<String, dynamic>.from(orderData);
          enhancedOrderData['user_full_name'] = userData['full_name'];
          enhancedOrderData['user_email'] = userData['email'];

          orders.add(Order.fromJson(enhancedOrderData, items));
        } else {
          orders.add(Order.fromJson(orderData, items));
        }
      } catch (e) {
        print(
          'AdminOrdersProvider: Error processing order ${orderData['id']}: $e',
        );
        // Still add the order even if items fail to load
        orders.add(Order.fromJson(orderData, []));
      }
    }

    _orders = orders;
    print(
      'AdminOrdersProvider: Successfully loaded ${orders.length} optimized orders',
    );

    // Apply client-side search filter for additional fields (receiver name, address)
    if (_searchQuery.isNotEmpty) {
      final searchTerm = _searchQuery.toLowerCase();
      final clientSideFilteredOrders = orders.where((order) {
        return order.receiverName?.toLowerCase().contains(searchTerm) == true ||
            order.shippingAddress.toLowerCase().contains(searchTerm);
      }).toList();

      if (clientSideFilteredOrders.isNotEmpty) {
        _orders = clientSideFilteredOrders;
        print(
          'AdminOrdersProvider: Applied additional client-side search filter',
        );
      }
    }

    // Apply payment filter if active (this is done after loading due to complexity)
    if (_paymentFilter == 'pending_payment') {
      _orders = await _applyPaymentFilter(_orders);
    }

    // Cache the result
    _cacheSearchResult(cacheKey, List.from(_orders));
  }

  // Comprehensive search method including customer names and emails - FIXED VERSION
  Future<void> _searchWithUserData(String searchQuery) async {
    print(
      'AdminOrdersProvider: Starting comprehensive search for: $searchQuery',
    );
    final searchTerm = searchQuery.toLowerCase();

    try {
      List<Order> allMatchingOrders = [];

      // Strategy 1: Search by order number
      try {
        var orderNumberQuery = _supabase
            .from('kl_orders')
            .select('''
          *,
          kl_order_items(*),
          kl_users!kl_orders_user_id_fkey(full_name, email)
        ''')
            .ilike('order_number', '%$searchTerm%');

        // Apply basic filters
        if (_selectedStatus != null) {
          orderNumberQuery = orderNumberQuery.eq(
            'status',
            _selectedStatus!.databaseValue,
          );
        }

        final orderNumberResponse = await orderNumberQuery.limit(200);
        final orderNumberData = orderNumberResponse as List;

        for (final orderData in orderNumberData) {
          try {
            final orderItemsData = orderData['kl_order_items'] as List? ?? [];
            final items = orderItemsData
                .map((item) => OrderItem.fromJson(item))
                .toList();
            allMatchingOrders.add(Order.fromJson(orderData, items));
          } catch (e) {
            print(
              'AdminOrdersProvider: Error processing order number result: $e',
            );
          }
        }
        print(
          'AdminOrdersProvider: Found ${allMatchingOrders.length} orders by order number',
        );
      } catch (e) {
        print('AdminOrdersProvider: Error in order number search: $e');
      }

      // Strategy 2: Search by receiver name (DIRECT DATABASE SEARCH)
      try {
        var receiverNameQuery = _supabase
            .from('kl_orders')
            .select('''
          *,
          kl_order_items(*),
          kl_users!kl_orders_user_id_fkey(full_name, email)
        ''')
            .ilike('receiver_name', '%$searchTerm%');

        // Apply basic filters
        if (_selectedStatus != null) {
          receiverNameQuery = receiverNameQuery.eq(
            'status',
            _selectedStatus!.databaseValue,
          );
        }

        final receiverNameResponse = await receiverNameQuery.limit(200);
        final receiverNameData = receiverNameResponse as List;

        for (final orderData in receiverNameData) {
          try {
            final orderItemsData = orderData['kl_order_items'] as List? ?? [];
            final items = orderItemsData
                .map((item) => OrderItem.fromJson(item))
                .toList();
            allMatchingOrders.add(Order.fromJson(orderData, items));
          } catch (e) {
            print(
              'AdminOrdersProvider: Error processing receiver name result: $e',
            );
          }
        }
        print(
          'AdminOrdersProvider: Found ${receiverNameData.length} orders by receiver name',
        );
      } catch (e) {
        print('AdminOrdersProvider: Error in receiver name search: $e');
      }

      // Strategy 3: Search by shipping address (DIRECT DATABASE SEARCH)
      try {
        var addressQuery = _supabase
            .from('kl_orders')
            .select('''
          *,
          kl_order_items(*),
          kl_users!kl_orders_user_id_fkey(full_name, email)
        ''')
            .ilike('shipping_address', '%$searchTerm%');

        // Apply basic filters
        if (_selectedStatus != null) {
          addressQuery = addressQuery.eq(
            'status',
            _selectedStatus!.databaseValue,
          );
        }

        final addressResponse = await addressQuery.limit(200);
        final addressData = addressResponse as List;

        for (final orderData in addressData) {
          try {
            final orderItemsData = orderData['kl_order_items'] as List? ?? [];
            final items = orderItemsData
                .map((item) => OrderItem.fromJson(item))
                .toList();
            allMatchingOrders.add(Order.fromJson(orderData, items));
          } catch (e) {
            print('AdminOrdersProvider: Error processing address result: $e');
          }
        }
        print(
          'AdminOrdersProvider: Found ${addressData.length} orders by address',
        );
      } catch (e) {
        print('AdminOrdersProvider: Error in address search: $e');
      }

      // Strategy 4: Search by customer name
      try {
        final nameQuery = _supabase
            .from('kl_users')
            .select('id')
            .ilike('full_name', '%$searchTerm%');

        final nameResponse = await nameQuery;
        final nameData = nameResponse as List;
        final nameUserIds = nameData
            .map((user) => user['id'] as String)
            .toList();

        // Search orders for these users
        for (final userId in nameUserIds) {
          var userOrdersQuery = _supabase
              .from('kl_orders')
              .select('''
            *,
            kl_order_items(*),
            kl_users!kl_orders_user_id_fkey(full_name, email)
          ''')
              .eq('user_id', userId);

          // Apply filters
          if (_selectedStatus != null) {
            userOrdersQuery = userOrdersQuery.eq(
              'status',
              _selectedStatus!.databaseValue,
            );
          }

          final userOrdersResponse = await userOrdersQuery;
          final userOrdersData = userOrdersResponse as List;

          for (final orderData in userOrdersData) {
            try {
              final orderItemsData = orderData['kl_order_items'] as List? ?? [];
              final items = orderItemsData
                  .map((item) => OrderItem.fromJson(item))
                  .toList();
              allMatchingOrders.add(Order.fromJson(orderData, items));
            } catch (e) {
              print(
                'AdminOrdersProvider: Error processing user order result: $e',
              );
            }
          }
        }
        print('AdminOrdersProvider: Found ${nameUserIds.length} users by name');
      } catch (e) {
        print('AdminOrdersProvider: Error in name search: $e');
      }

      // Strategy 5: Search by email
      try {
        final emailQuery = _supabase
            .from('kl_users')
            .select('id')
            .ilike('email', '%$searchTerm%');

        final emailResponse = await emailQuery;
        final emailData = emailResponse as List;
        final emailUserIds = emailData
            .map((user) => user['id'] as String)
            .toList();

        // Search orders for these users
        for (final userId in emailUserIds) {
          var userOrdersQuery = _supabase
              .from('kl_orders')
              .select('''
            *,
            kl_order_items(*),
            kl_users!kl_orders_user_id_fkey(full_name, email)
          ''')
              .eq('user_id', userId);

          // Apply filters
          if (_selectedStatus != null) {
            userOrdersQuery = userOrdersQuery.eq(
              'status',
              _selectedStatus!.databaseValue,
            );
          }

          final userOrdersResponse = await userOrdersQuery;
          final userOrdersData = userOrdersResponse as List;

          for (final orderData in userOrdersData) {
            try {
              final orderItemsData = orderData['kl_order_items'] as List? ?? [];
              final items = orderItemsData
                  .map((item) => OrderItem.fromJson(item))
                  .toList();
              allMatchingOrders.add(Order.fromJson(orderData, items));
            } catch (e) {
              print(
                'AdminOrdersProvider: Error processing email user order result: $e',
              );
            }
          }
        }
        print(
          'AdminOrdersProvider: Found ${emailUserIds.length} users by email',
        );
      } catch (e) {
        print('AdminOrdersProvider: Error in email search: $e');
      }

      // Remove duplicates and apply additional client-side filtering
      final uniqueOrders = allMatchingOrders.toSet().toList();

      // Apply additional client-side filtering for any missed receiver names and addresses
      final clientSideFilteredOrders = uniqueOrders.where((order) {
        return order.receiverName?.toLowerCase().contains(searchTerm) == true ||
            order.shippingAddress.toLowerCase().contains(searchTerm);
      }).toList();

      // Combine results (database results + additional client-side results)
      final combinedResults = {
        ...uniqueOrders,
        ...clientSideFilteredOrders,
      }.toList();

      _orders = combinedResults;

      // Apply courier filter if active
      if (_courierFilter == 'resi_otomatis') {
        _orders = _orders.where((order) {
          return order.courierInfo?.toLowerCase().contains('resi otomatis') ==
              true;
        }).toList();
      }

      // Apply payment filter if active
      if (_paymentFilter == 'pending_payment') {
        _orders = await _applyPaymentFilter(_orders);
      }

      // Limit results
      _orders = _orders.take(1000).toList();

      // Cache the result
      final cacheKey = _generateCacheKey();
      _cacheSearchResult(cacheKey, List.from(_orders));

      print(
        'AdminOrdersProvider: Comprehensive search completed with ${_orders.length} results',
      );
    } catch (e) {
      print('AdminOrdersProvider: Error in comprehensive search: $e');
      // Fallback to empty result
      _orders = [];
    }
  }

  // Generate cache key based on current filters
  String _generateCacheKey() {
    return '${_searchQuery}_${_selectedStatus?.databaseValue ?? "null"}_${_courierFilter ?? "null"}_${_dateFilter ?? "null"}_${_dateRange?.start.toString() ?? "null"}_${_dateRange?.end.toString() ?? "null"}_${_paymentFilter ?? "null"}';
  }

  // Cache management
  final Map<String, ({List<Order> orders, DateTime timestamp})>
  _cacheWithTimestamp = {};

  void _cacheSearchResult(String key, List<Order> orders) {
    _cacheWithTimestamp[key] = (orders: orders, timestamp: DateTime.now());
  }

  bool _isCacheValid(String key) {
    final cached = _cacheWithTimestamp[key];
    if (cached == null) return false;
    return DateTime.now().difference(cached.timestamp) < _cacheExpiry;
  }

  void _clearExpiredCache() {
    final now = DateTime.now();
    _cacheWithTimestamp.removeWhere(
      (key, value) => now.difference(value.timestamp) >= _cacheExpiry,
    );
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
      // Get the order details first to check its status
      final order = await getOrderById(orderId);
      if (order == null) {
        print('AdminOrdersProvider: Order not found for deletion: $orderId');
        return false;
      }

      // For cancelled orders, delete the order record directly without deleting order items first
      // This prevents the trigger_increase_stock trigger from running and double-restoring quantities
      if (order.status == OrderStatus.cancelled) {
        print(
          'AdminOrdersProvider: Deleting cancelled order, skipping order items deletion to prevent double quantity restoration',
        );

        // Delete order directly (this will cascade delete order items via foreign key)
        await _supabase.from('kl_orders').delete().eq('id', orderId);
      } else {
        // For non-cancelled orders, delete order items first (normal process)
        // The trigger_increase_stock will run and restore quantities correctly
        print(
          'AdminOrdersProvider: Deleting non-cancelled order, order items will be deleted first',
        );

        // Delete order items first (this will trigger quantity restoration)
        await _supabase.from('kl_order_items').delete().eq('order_id', orderId);

        // Delete order
        await _supabase.from('kl_orders').delete().eq('id', orderId);
      }

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
      // Get the order details first
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

      // Update order status to cancelled
      // The database trigger "trigger_handle_order_cancellation" will handle quantity restoration
      await _supabase
          .from('kl_orders')
          .update({
            'status': OrderStatus.cancelled.databaseValue,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      // Update local order
      final orderIndex = _orders.indexWhere((o) => o.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          status: OrderStatus.cancelled,
        );
        notifyListeners();
      }

      print('AdminOrdersProvider: Order cancelled successfully: $orderId');
      print(
        'AdminOrdersProvider: Database trigger will handle quantity restoration',
      );
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

  // Quantity sales chart data
  List<Map<String, dynamic>> _monthlyQuantityData = [];
  List<Map<String, dynamic>> _yearlyQuantityData = [];
  bool _isCalculatingQuantitySales = false;

  // Getters for sales values
  double get monthlySales => _monthlySales;
  double get yearlySales => _yearlySales;
  bool get isCalculatingSales => _isCalculatingSales;

  // Getters for quantity sales data
  List<Map<String, dynamic>> get monthlyQuantityData => _monthlyQuantityData;
  List<Map<String, dynamic>> get yearlyQuantityData => _yearlyQuantityData;
  bool get isCalculatingQuantitySales => _isCalculatingQuantitySales;

  // Calculate total sales for current month on demand (optimized - direct DB query)
  Future<void> calculateMonthlySales() async {
    if (_isCalculatingSales) return;

    _isCalculatingSales = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Query orders directly from database for monthly sales - only completed payments
      var query = _supabase
          .from('kl_orders')
          .select('total_amount')
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String())
          .or(
            'status.eq.${OrderStatus.lunas.databaseValue},status.eq.${OrderStatus.barangDikirim.databaseValue}',
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

      // Query orders directly from database for yearly sales - only completed payments
      var query = _supabase
          .from('kl_orders')
          .select('total_amount')
          .gte('created_at', startOfYear.toIso8601String())
          .lte('created_at', endOfYear.toIso8601String())
          .or(
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

  // Calculate monthly quantity sales data for current month (daily breakdown)
  Future<void> calculateMonthlyQuantitySales() async {
    if (_isCalculatingQuantitySales) return;

    _isCalculatingQuantitySales = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Get all completed orders for the current month
      final ordersResponse = await _supabase
          .from('kl_orders')
          .select('''
            id,
            created_at,
            kl_order_items(quantity)
          ''')
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String())
          .or(
            'status.eq.${OrderStatus.lunas.databaseValue},status.eq.${OrderStatus.barangDikirim.databaseValue}',
          );

      final ordersData = ordersResponse as List;

      // Group by day and sum quantities
      final dailyData = <int, double>{};
      for (final order in ordersData) {
        final orderDate = DateTime.parse(order['created_at']);
        final day = orderDate.day;

        final orderItems = order['kl_order_items'] as List? ?? [];
        final totalQuantity = orderItems.fold<double>(
          0,
          (sum, item) => sum + (item['quantity'] as num).toDouble(),
        );

        dailyData[day] = (dailyData[day] ?? 0) + totalQuantity;
      }

      // Get number of days in current month
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

      // Create data for all days in the month
      _monthlyQuantityData = List.generate(daysInMonth, (index) {
        final day = index + 1;
        final quantity = dailyData[day] ?? 0.0;
        return {'day': day, 'quantity': quantity, 'label': day.toString()};
      });

      print(
        'AdminOrdersProvider: Calculated daily quantity sales data for ${now.year}-${now.month.toString().padLeft(2, '0')}',
      );
    } catch (e) {
      print(
        'AdminOrdersProvider: Error calculating monthly quantity sales: $e',
      );
      // Fallback to empty data for current month
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      _monthlyQuantityData = List.generate(
        daysInMonth,
        (index) => {
          'day': index + 1,
          'quantity': 0.0,
          'label': (index + 1).toString(),
        },
      );
    } finally {
      _isCalculatingQuantitySales = false;
      notifyListeners();
    }
  }

  // Calculate yearly quantity sales data for current year (monthly breakdown Jan-Dec)
  Future<void> calculateYearlyQuantitySales() async {
    if (_isCalculatingQuantitySales) return;

    _isCalculatingQuantitySales = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final endOfYear = DateTime(now.year, 12, 31, 23, 59, 59);

      // Get all completed orders for the current year
      final ordersResponse = await _supabase
          .from('kl_orders')
          .select('''
            id,
            created_at,
            kl_order_items(quantity)
          ''')
          .gte('created_at', startOfYear.toIso8601String())
          .lte('created_at', endOfYear.toIso8601String())
          .or(
            'status.eq.${OrderStatus.lunas.databaseValue},status.eq.${OrderStatus.barangDikirim.databaseValue}',
          );

      final ordersData = ordersResponse as List;

      // Group by month and sum quantities
      final monthlyData = <int, double>{};
      for (final order in ordersData) {
        final orderDate = DateTime.parse(order['created_at']);
        final month = orderDate.month;

        final orderItems = order['kl_order_items'] as List? ?? [];
        final totalQuantity = orderItems.fold<double>(
          0,
          (sum, item) => sum + (item['quantity'] as num).toDouble(),
        );

        monthlyData[month] = (monthlyData[month] ?? 0) + totalQuantity;
      }

      // Create data for all 12 months of the current year
      _yearlyQuantityData = List.generate(12, (index) {
        final month = index + 1;
        final quantity = monthlyData[month] ?? 0.0;
        return {
          'month': month,
          'quantity': quantity,
          'label': _getMonthName(month),
        };
      });

      print(
        'AdminOrdersProvider: Calculated monthly quantity sales data for ${now.year} (Jan-Dec)',
      );
    } catch (e) {
      print('AdminOrdersProvider: Error calculating yearly quantity sales: $e');
      // Fallback to empty data for all 12 months
      _yearlyQuantityData = List.generate(
        12,
        (index) => {
          'month': index + 1,
          'quantity': 0.0,
          'label': _getMonthName(index + 1),
        },
      );
    } finally {
      _isCalculatingQuantitySales = false;
      notifyListeners();
    }
  }

  // Helper method to get month name
  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
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

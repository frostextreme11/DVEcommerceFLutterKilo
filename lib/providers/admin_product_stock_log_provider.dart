import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_stock_log.dart';

class AdminProductStockLogProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ProductStockLog> _logs = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _startDate;
  DateTime? _endDate;

  List<ProductStockLog> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  // Filtered logs based on date range
  List<ProductStockLog> get filteredLogs {
    if (_startDate == null && _endDate == null) {
      return _logs;
    }

    return _logs.where((log) {
      final logDate = log.dateCreated;
      bool matchesStart =
          _startDate == null ||
          logDate.isAfter(_startDate!.subtract(const Duration(days: 1)));
      bool matchesEnd =
          _endDate == null ||
          logDate.isBefore(_endDate!.add(const Duration(days: 1)));
      return matchesStart && matchesEnd;
    }).toList();
  }

  Future<void> loadLogs({int limit = 100}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Use a single query with JOIN to avoid N+1 queries
      final response = await _supabase
          .from('kl_product_log')
          .select('''
            id,
            product_id,
            date_created,
            last_value,
            new_value,
            edited_by_email,
            edited_by_username,
            kl_products!inner(name)
          ''')
          .order('date_created', ascending: false)
          .limit(limit);

      final logsData = response as List;
      _logs = logsData.map((data) {
        // Flatten the joined data and ensure String keys
        final Map<String, dynamic> flattenedData = {
          'id': data['id'],
          'product_id': data['product_id'],
          'date_created': data['date_created'],
          'last_value': data['last_value'],
          'new_value': data['new_value'],
          'edited_by_email': data['edited_by_email'],
          'edited_by_username': data['edited_by_username'],
          'product_name': data['kl_products']['name'],
        };
        return ProductStockLog.fromJson(flattenedData);
      }).toList();

      print(
        'AdminProductStockLogProvider: Successfully loaded ${_logs.length} logs',
      );
    } catch (e) {
      _error = 'Failed to load product stock logs: ${e.toString()}';
      print('Error loading product stock logs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLogsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    int limit = 1000,
  }) async {
    _isLoading = true;
    _error = null;
    _startDate = startDate;
    _endDate = endDate;
    notifyListeners();

    try {
      // Use a single query with JOIN to avoid N+1 queries
      final response = await _supabase
          .from('kl_product_log')
          .select('''
            id,
            product_id,
            date_created,
            last_value,
            new_value,
            edited_by_email,
            edited_by_username,
            kl_products!inner(name)
          ''')
          .gte('date_created', startDate.toIso8601String())
          .lte(
            'date_created',
            endDate.add(const Duration(days: 1)).toIso8601String(),
          )
          .order('date_created', ascending: false)
          .limit(limit);

      final logsData = response as List;
      _logs = logsData.map((data) {
        // Flatten the joined data and ensure String keys
        final Map<String, dynamic> flattenedData = {
          'id': data['id'],
          'product_id': data['product_id'],
          'date_created': data['date_created'],
          'last_value': data['last_value'],
          'new_value': data['new_value'],
          'edited_by_email': data['edited_by_email'],
          'edited_by_username': data['edited_by_username'],
          'product_name': data['kl_products']['name'],
        };
        return ProductStockLog.fromJson(flattenedData);
      }).toList();

      print(
        'AdminProductStockLogProvider: Successfully loaded ${_logs.length} logs for date range',
      );
    } catch (e) {
      _error = 'Failed to load product stock logs: ${e.toString()}';
      print('Error loading product stock logs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  void clearDateRange() {
    _startDate = null;
    _endDate = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

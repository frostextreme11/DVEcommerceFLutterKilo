import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart' as app_user;
import '../../models/payment.dart';

class AllUsersOrderSummaryScreen extends StatefulWidget {
  const AllUsersOrderSummaryScreen({super.key});

  @override
  State<AllUsersOrderSummaryScreen> createState() =>
      _AllUsersOrderSummaryScreenState();
}

class _AllUsersOrderSummaryScreenState
    extends State<AllUsersOrderSummaryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  List<UserOrderSummary> _summaryData = [];
  String? _error;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _initializeDefaultDates();
  }

  void _initializeDefaultDates() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    setState(() {
      _startDate = firstDayOfMonth;
      _endDate = now;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Users Order Summary'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Date Selection Card
          _buildDateSelectionCard(),

          // Summary Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildErrorView()
                : _summaryData.isEmpty
                ? _buildEmptyView()
                : _buildSummaryTable(),
          ),
        ],
      ),
      floatingActionButton: _summaryData.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _exportToPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export PDF'),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildDateSelectionCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Date Range',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'Start Date',
                    date: _startDate,
                    onTap: () => _selectDate(isStartDate: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    label: 'End Date',
                    date: _endDate,
                    onTap: () => _selectDate(isStartDate: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _canSubmit() ? _generateReport : null,
                icon: const Icon(Icons.analytics),
                label: const Text('Generate Report'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  date != null ? _dateFormat.format(date) : 'Select date',
                  style: TextStyle(
                    fontSize: 14,
                    color: date != null ? Colors.black : Colors.grey,
                    fontWeight: date != null
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTable() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: Text(
                    'Customer',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'Qty',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    'Sales',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    'Ongkir',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    'Payment',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    'Debt',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // Table Body and Grand Total
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 56,
                  dataRowMinHeight: 64,
                  dataRowMaxHeight: 64,
                  columns: [
                    DataColumn(
                      label: SizedBox(
                        width: 200,
                        child: Text(
                          'Customer',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 80,
                        child: Text(
                          'Qty',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 120,
                        child: Text(
                          'Sales',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 120,
                        child: Text(
                          'Ongkir',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 120,
                        child: Text(
                          'Payment',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 120,
                        child: Text(
                          'Debt',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  ],
                  rows: [
                    // Customer data rows
                    ..._summaryData.map(
                      (summary) => DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 200,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    summary.customerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  Text(
                                    summary.customerEmail,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 80,
                              child: Text(
                                _formatNumber(summary.totalQuantity),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 120,
                              child: Text(
                                _formatCurrency(summary.totalSales),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: Colors.green,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 120,
                              child: Text(
                                _formatCurrency(summary.totalOngkir),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: Colors.orange,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 120,
                              child: Text(
                                _formatCurrency(summary.totalPayment),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: Colors.blue,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 120,
                              child: Text(
                                _formatCurrency(summary.totalDebt),
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: summary.totalDebt > 0
                                      ? Colors.red
                                      : Colors.green,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Grand Total row
                    DataRow(
                      cells: [
                        DataCell(
                          Container(
                            width: 200,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'GRAND TOTAL',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            width: 80,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _formatNumber(
                                _summaryData.fold<int>(
                                  0,
                                  (sum, item) => sum + item.totalQuantity,
                                ),
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).primaryColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            width: 120,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _formatCurrency(
                                _summaryData.fold<double>(
                                  0,
                                  (sum, item) => sum + item.totalSales,
                                ),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            width: 120,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _formatCurrency(
                                _summaryData.fold<double>(
                                  0,
                                  (sum, item) => sum + item.totalOngkir,
                                ),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.orange,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            width: 120,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _formatCurrency(
                                _summaryData.fold<double>(
                                  0,
                                  (sum, item) => sum + item.totalPayment,
                                ),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            width: 120,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _formatCurrency(
                                _summaryData.fold<double>(
                                  0,
                                  (sum, item) => sum + item.totalDebt,
                                ),
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color:
                                    _summaryData.fold<double>(
                                          0,
                                          (sum, item) => sum + item.totalDebt,
                                        ) >
                                        0
                                    ? Colors.red
                                    : Colors.green,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Error: $_error',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _generateReport,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No data available',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Select date range and generate report',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  bool _canSubmit() {
    return _startDate != null && _endDate != null && !_isLoading;
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    final initialDate = isStartDate
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());

    final firstDate = DateTime(2020);
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If end date is before start date, reset it
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _generateReport() async {
    if (!_canSubmit()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _summaryData = [];
    });

    try {
      final summaryData = await _fetchOrderSummaryData();

      setState(() {
        _summaryData = summaryData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<UserOrderSummary>> _fetchOrderSummaryData() async {
    final startDate = _startDate!.toIso8601String();
    final endDate = _endDate!.add(const Duration(days: 1)).toIso8601String();

    // OPTIMIZED: Use efficient batch queries instead of N+1 pattern
    final orderSummaries = await _getOrderSummaries(startDate, endDate);
    final paymentSummaries = await _getPaymentSummaries(startDate, endDate);

    return _combineSummaries(orderSummaries, paymentSummaries);
  }

  Future<Map<String, Map<String, dynamic>>> _getOrderSummaries(
    String startDate,
    String endDate,
  ) async {
    final response = await _supabase
        .from('kl_orders')
        .select('''
          user_id,
          status,
          additional_costs,
          order_items (
            quantity,
            total_price
          )
        ''')
        .neq('status', 'cancelled')
        .gte('created_at', startDate)
        .lte('created_at', endDate);

    final ordersData = response as List;
    final summaries = <String, Map<String, dynamic>>{};

    for (final order in ordersData) {
      final userId = order['user_id'] as String;
      final orderItems = (order['order_items'] as List?) ?? [];

      final summary =
          summaries[userId] ??
          {'totalQuantity': 0, 'totalSales': 0.0, 'totalOngkir': 0.0};

      // Aggregate order items
      for (final item in orderItems) {
        summary['totalQuantity'] =
            (summary['totalQuantity'] as int) +
            ((item['quantity'] as int?) ?? 0);
        summary['totalSales'] =
            (summary['totalSales'] as double) +
            ((item['total_price'] as num?)?.toDouble() ?? 0.0);
      }

      // Add additional costs (ongkir)
      summary['totalOngkir'] =
          (summary['totalOngkir'] as double) +
          ((order['additional_costs'] as num?)?.toDouble() ?? 0.0);

      summaries[userId] = summary;
    }

    return summaries;
  }

  Future<Map<String, double>> _getPaymentSummaries(
    String startDate,
    String endDate,
  ) async {
    final response = await _supabase
        .from('kl_payments')
        .select('user_id, amount')
        .eq('status', 'completed')
        .gte('created_at', startDate)
        .lte('created_at', endDate);

    final paymentsData = response as List;
    final summaries = <String, double>{};

    for (final payment in paymentsData) {
      final userId = payment['user_id'] as String;
      final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;

      summaries[userId] = (summaries[userId] ?? 0.0) + amount;
    }

    return summaries;
  }

  Future<List<UserOrderSummary>> _combineSummaries(
    Map<String, Map<String, dynamic>> orderSummaries,
    Map<String, double> paymentSummaries,
  ) async {
    // Get customer details
    final customersResponse = await _supabase
        .from('kl_users')
        .select('id, email, full_name')
        .eq('role', 'customer');

    final customers = customersResponse as List;
    final summaryData = <UserOrderSummary>[];

    for (final customer in customers) {
      final userId = customer['id'] as String;
      final orderSummary = orderSummaries[userId];
      final totalPayment = paymentSummaries[userId] ?? 0.0;

      // Only include customers with orders or payments
      if (orderSummary != null &&
          ((orderSummary['totalQuantity'] as int) > 0 || totalPayment > 0)) {
        final totalSales = orderSummary['totalSales'] as double;
        final totalOngkir = orderSummary['totalOngkir'] as double;
        final totalDebt = totalSales + totalOngkir - totalPayment;

        summaryData.add(
          UserOrderSummary(
            customerName: customer['full_name'] ?? 'No Name',
            customerEmail: customer['email'] ?? 'No Email',
            totalQuantity: orderSummary['totalQuantity'] as int,
            totalSales: totalSales,
            totalOngkir: totalOngkir,
            totalPayment: totalPayment,
            totalDebt: totalDebt,
          ),
        );
      }
    }

    // Sort by total sales descending
    summaryData.sort((a, b) => b.totalSales.compareTo(a.totalSales));

    return summaryData;
  }

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'All Users Order Summary Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
        ),
        build: (context) => [
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Text(
              'Date Range: ${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}',
              style: const pw.TextStyle(fontSize: 14),
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: [
              'Customer',
              'Quantity',
              'Total Sales',
              'Total Ongkir',
              'Total Payment',
              'Total Debt',
            ],
            data: [
              // Customer data rows
              ..._summaryData.map(
                (summary) => [
                  '${summary.customerName}\n${summary.customerEmail}',
                  _formatNumber(summary.totalQuantity),
                  _formatCurrency(summary.totalSales),
                  _formatCurrency(summary.totalOngkir),
                  _formatCurrency(summary.totalPayment),
                  _formatCurrency(summary.totalDebt),
                ],
              ),
              // Grand Total row
              [
                'GRAND TOTAL',
                _formatNumber(
                  _summaryData.fold<int>(
                    0,
                    (sum, item) => sum + item.totalQuantity,
                  ),
                ),
                _formatCurrency(
                  _summaryData.fold<double>(
                    0,
                    (sum, item) => sum + item.totalSales,
                  ),
                ),
                _formatCurrency(
                  _summaryData.fold<double>(
                    0,
                    (sum, item) => sum + item.totalOngkir,
                  ),
                ),
                _formatCurrency(
                  _summaryData.fold<double>(
                    0,
                    (sum, item) => sum + item.totalPayment,
                  ),
                ),
                _formatCurrency(
                  _summaryData.fold<double>(
                    0,
                    (sum, item) => sum + item.totalDebt,
                  ),
                ),
              ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.center,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  String _formatNumber(int number) {
    return NumberFormat('#,###').format(number);
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }
}

class UserOrderSummary {
  final String customerName;
  final String customerEmail;
  final int totalQuantity;
  final double totalSales;
  final double totalOngkir;
  final double totalPayment;
  final double totalDebt;

  UserOrderSummary({
    required this.customerName,
    required this.customerEmail,
    required this.totalQuantity,
    required this.totalSales,
    required this.totalOngkir,
    required this.totalPayment,
    required this.totalDebt,
  });
}

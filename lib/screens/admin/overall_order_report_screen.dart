import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/admin_orders_provider.dart';
import '../../providers/admin_users_provider.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../services/print_service.dart';

class OverallOrderReportScreen extends StatefulWidget {
  const OverallOrderReportScreen({Key? key}) : super(key: key);

  @override
  State<OverallOrderReportScreen> createState() =>
      _OverallOrderReportScreenState();
}

class _OverallOrderReportScreenState extends State<OverallOrderReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isGenerating = false;
  List<OverallOrderData> _orderData = [];
  int _totalQuantity = 0;
  double _totalAmount = 0.0;

  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _generateReport() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both start and end dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // Use optimized query to avoid N+1 problems
      final data = await _fetchOrdersWithDetails(_startDate!, _endDate!);

      setState(() {
        _orderData = data.orderData;
        _totalQuantity = data.totalQuantity;
        _totalAmount = data.totalAmount;
      });

      if (_orderData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No orders found in the selected date range'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<_ReportData> _fetchOrdersWithDetails(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final supabase = Supabase.instance.client;

    try {
      // Ensure proper date range handling
      // Start date: beginning of the day (00:00:00)
      final startDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        0,
        0,
        0,
      );

      // End date: end of the day (23:59:59)
      final endDateTime = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      );

      // Optimized query to avoid N+1 - single query with joins
      final query = supabase
          .from('kl_orders')
          .select('''
            *,
            kl_order_items(*),
            kl_users!kl_orders_user_id_fkey(id, email, full_name)
          ''')
          .gte('created_at', startDateTime.toIso8601String())
          .lte('created_at', endDateTime.toIso8601String())
          .order('created_at', ascending: true); // Show earliest orders first

      final ordersResponse = await query;
      final ordersData = ordersResponse as List;

      List<OverallOrderData> orderData = [];
      int totalQuantity = 0;
      double totalAmount = 0.0;
      int rowNumber = 1;

      // Process each order - group by order number
      for (final orderDataMap in ordersData) {
        try {
          // Extract user data from the joined query
          final userData = orderDataMap['kl_users'] as Map<String, dynamic>?;
          final userEmail = userData?['email'] ?? 'Unknown';
          final userName = userData?['full_name'] ?? 'N/A';

          // Extract order items
          final orderItemsData = orderDataMap['kl_order_items'] as List? ?? [];

          // Create Order object for processing
          final order = Order.fromJson(orderDataMap, []);

          // Process each order item - use same row number for all items in same order
          for (final itemData in orderItemsData) {
            final item = OrderItem.fromJson(itemData);

            orderData.add(
              OverallOrderData(
                rowNumber:
                    rowNumber, // Same row number for all items in same order
                orderDate: order.createdAt.add(
                  const Duration(hours: 7),
                ), // Convert to Jakarta time (UTC+7)
                userEmail: userEmail,
                userName: userName,
                receiverName: order.receiverName ?? 'N/A',
                status: order.status.displayName,
                orderNumber: order.orderNumber,
                productName: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                itemTotal: item.totalPrice,
              ),
            );

            totalQuantity += item.quantity;
            totalAmount += item.totalPrice;
          }

          // Move to next row number for the next order
          rowNumber++;
        } catch (e) {
          print('Error processing order ${orderDataMap['id']}: $e');
          // Continue processing other orders
          rowNumber++; // Still increment row number for next order
        }
      }

      return _ReportData(
        orderData: orderData,
        totalQuantity: totalQuantity,
        totalAmount: totalAmount,
      );
    } catch (e) {
      print('Error fetching orders with details: $e');
      return _ReportData(orderData: [], totalQuantity: 0, totalAmount: 0.0);
    }
  }

  Future<void> _exportToPDF() async {
    if (_orderData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await PrintService.generateOrderReportPDF(
        _orderData,
        _startDate!,
        _endDate!,
        _totalQuantity,
        _totalAmount,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF report generated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportToCSV() async {
    if (_orderData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await PrintService.generateOrderReportCSV(
        _orderData,
        _startDate!,
        _endDate!,
        _totalQuantity,
        _totalAmount,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV file generated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _endDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overall Order Report'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range Selection
            _buildDateRangeSection(),
            const SizedBox(height: 16),

            // Generate Button
            _buildGenerateButton(),
            const SizedBox(height: 16),

            // Export Buttons (only show if data exists)
            if (_orderData.isNotEmpty) ...[
              _buildExportButtons(),
              const SizedBox(height: 16),
            ],

            // Results Summary
            if (_orderData.isNotEmpty) _buildSummaryCard(),

            // Data Table
            if (_orderData.isNotEmpty) _buildDataTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Date Range Selection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    controller: _startDateController,
                    label: 'Start Date',
                    onTap: _selectStartDate,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    controller: _endDateController,
                    label: 'End Date',
                    onTap: _selectEndDate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : _generateReport,
        icon: _isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.analytics),
        label: Text(_isGenerating ? 'Generating...' : 'Generate Report'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildExportButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _exportToPDF,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Export PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _exportToCSV,
            icon: const Icon(Icons.table_chart),
            label: const Text('Export CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem('Total Orders', _orderData.length.toString()),
            _buildSummaryItem('Total Quantity', _totalQuantity.toString()),
            _buildSummaryItem(
              'Total Amount',
              'Rp ${NumberFormat('#,###').format(_totalAmount)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildDataTable() {
    // Track which orders we've processed for row numbering
    final processedOrders = <String>{};

    return Card(
      elevation: 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12,
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 60,
          columns: [
            const DataColumn(label: Text('Row\nNum')),
            const DataColumn(label: Text('Order Date')),
            const DataColumn(label: Text('User Email')),
            const DataColumn(label: Text('User Name')),
            const DataColumn(label: Text('Receiver\nName')),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('Order\nNumber')),
            const DataColumn(label: Text('Product\nName')),
            const DataColumn(label: Text('Qty')),
            const DataColumn(label: Text('Unit Price')),
            const DataColumn(label: Text('Item Total')),
          ],
          rows: [
            ..._orderData.map((data) {
              // Only show row number and order info for the first occurrence of each order number
              final shouldShowOrderInfo = !processedOrders.contains(
                data.orderNumber,
              );
              processedOrders.add(data.orderNumber);

              return DataRow(
                cells: [
                  DataCell(
                    Text(shouldShowOrderInfo ? data.rowNumber.toString() : ''),
                  ),
                  DataCell(
                    Text(
                      shouldShowOrderInfo
                          ? DateFormat(
                              'yyyy-MM-dd HH:mm:ss',
                            ).format(data.orderDate)
                          : '',
                    ),
                  ),
                  DataCell(Text(shouldShowOrderInfo ? data.userEmail : '')),
                  DataCell(Text(shouldShowOrderInfo ? data.userName : '')),
                  DataCell(Text(shouldShowOrderInfo ? data.receiverName : '')),
                  DataCell(Text(shouldShowOrderInfo ? data.status : '')),
                  DataCell(Text(data.orderNumber)),
                  DataCell(Text(data.productName)),
                  DataCell(Text(data.quantity.toString())),
                  DataCell(
                    Text('Rp ${NumberFormat('#,###').format(data.unitPrice)}'),
                  ),
                  DataCell(
                    Text('Rp ${NumberFormat('#,###').format(data.itemTotal)}'),
                  ),
                ],
              );
            }),
            // Total row
            DataRow(
              cells: [
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(
                  Text(
                    'TOTAL QUANTITY:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  Text(
                    _totalQuantity.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const DataCell(Text('')),
                DataCell(
                  Text(
                    'Rp ${NumberFormat('#,###').format(_totalAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportData {
  final List<OverallOrderData> orderData;
  final int totalQuantity;
  final double totalAmount;

  _ReportData({
    required this.orderData,
    required this.totalQuantity,
    required this.totalAmount,
  });
}

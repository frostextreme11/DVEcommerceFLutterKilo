import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/user.dart' as app_user;
import '../../widgets/custom_button.dart';

class UsersOrderSummaryScreen extends StatefulWidget {
  final app_user.User user;

  const UsersOrderSummaryScreen({super.key, required this.user});

  @override
  State<UsersOrderSummaryScreen> createState() =>
      _UsersOrderSummaryScreenState();
}

class _UsersOrderSummaryScreenState extends State<UsersOrderSummaryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  DateTime? _startDate;
  DateTime? _endDate;
  List<OrderSummaryData> _orderSummaryData = [];
  bool _isLoading = false;
  String? _error;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    // Set default date range to current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _loadOrderSummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Summary'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // User Information Header
          _buildUserInfoHeader(),

          // Date Selection Card
          _buildDateSelectionCard(),

          // Summary Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildErrorView()
                : _buildSummaryTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.2),
                child: Text(
                  widget.user.fullName?.isNotEmpty == true
                      ? widget.user.fullName![0].toUpperCase()
                      : widget.user.email[0].toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Summary Report',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.user.fullName ?? 'No name available',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.user.email,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    if (widget.user.phoneNumber != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.user.phoneNumber!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectionCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Date Range',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'Start Date',
                    date: _startDate,
                    onTap: () => _selectDate(true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    label: 'End Date',
                    date: _endDate,
                    onTap: () => _selectDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Submit',
                    onPressed: _loadOrderSummary,
                    isLoading: _isLoading,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: 'Preview PDF',
                    onPressed: _previewPDF,
                    isOutlined: true,
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
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              date != null ? _dateFormat.format(date) : 'Select date',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Error: $_error',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          CustomButton(text: 'Retry', onPressed: _loadOrderSummary),
        ],
      ),
    );
  }

  Widget _buildSummaryTable() {
    if (_orderSummaryData.isEmpty) {
      return const Center(
        child: Text('No orders found for the selected period'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Data Table
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Order Date')),
                  DataColumn(label: Text('Quantity')),
                  DataColumn(label: Text('Total Sales')),
                  DataColumn(label: Text('Total Ongkir')),
                  DataColumn(label: Text('Total Payment')),
                  DataColumn(label: Text('Total Debt')),
                ],
                rows: _orderSummaryData.map((data) {
                  return DataRow(
                    cells: [
                      DataCell(Text(_dateFormat.format(data.orderDate))),
                      DataCell(Text(data.totalQuantity.toString())),
                      DataCell(Text(_formatCurrency(data.totalSales))),
                      DataCell(Text(_formatCurrency(data.totalOngkir))),
                      DataCell(Text(_formatCurrency(data.totalPayment))),
                      DataCell(
                        Text(
                          _formatCurrency(data.totalDebt),
                          style: TextStyle(
                            color: data.totalDebt > 0
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Grand Total Card
          _buildGrandTotalCard(),
        ],
      ),
    );
  }

  Widget _buildGrandTotalCard() {
    final grandTotal = _calculateGrandTotals();

    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grand Total',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTotalItem(
                    'Total Quantity',
                    grandTotal.totalQuantity.toString(),
                  ),
                ),
                Expanded(
                  child: _buildTotalItem(
                    'Total Sales',
                    _formatCurrency(grandTotal.totalSales),
                  ),
                ),
                Expanded(
                  child: _buildTotalItem(
                    'Total Ongkir',
                    _formatCurrency(grandTotal.totalOngkir),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTotalItem(
                    'Total Payment',
                    _formatCurrency(grandTotal.totalPayment),
                  ),
                ),
                Expanded(
                  child: _buildTotalItem(
                    'Total Debt',
                    _formatCurrency(grandTotal.totalDebt),
                    valueColor: grandTotal.totalDebt > 0
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
                const Expanded(child: SizedBox()), // Empty space for alignment
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final initialDate = isStartDate
        ? _startDate ?? DateTime.now()
        : _endDate ?? DateTime.now();
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
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _loadOrderSummary() async {
    if (_startDate == null || _endDate == null) {
      setState(() {
        _error = 'Please select both start and end dates';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use optimized RPC function to avoid N+1 queries
      // This fetches all data in a single optimized query
      final response = await _supabase.rpc(
        'get_user_order_summary',
        params: {
          'p_user_id': widget.user.id,
          'p_start_date': _startDate!.toIso8601String(),
          'p_end_date': _endDate!
              .add(const Duration(days: 1))
              .toIso8601String(),
        },
      );

      final data = response as List;

      final summaryData = data.map((item) {
        return OrderSummaryData(
          orderDate: DateTime.parse(item['order_date']),
          totalQuantity: (item['total_quantity'] as num).toInt(),
          totalSales: (item['total_sales'] as num).toDouble(),
          totalOngkir: (item['total_ongkir'] as num).toDouble(),
          totalPayment: (item['total_payment'] as num).toDouble(),
          totalDebt: (item['total_debt'] as num).toDouble(),
        );
      }).toList();

      setState(() {
        _orderSummaryData = summaryData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load order summary: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _previewPDF() async {
    if (_orderSummaryData.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to preview. Please load order summary first.'),
        ),
      );
      return;
    }

    try {
      final pdf = await _generatePDF();

      // Show PDF preview options
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('PDF Options'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Share PDF'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (!mounted) return;
                    await Printing.sharePdf(
                      bytes: await pdf.save(),
                      filename:
                          'order_summary_${widget.user.fullName ?? widget.user.email}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.print),
                  title: const Text('Print PDF'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (!mounted) return;
                    await Printing.layoutPdf(
                      onLayout: (PdfPageFormat format) async => pdf.save(),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.preview),
                  title: const Text('Preview PDF'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (!mounted) return;
                    // For preview, we'll use the share functionality which opens the PDF
                    await Printing.sharePdf(
                      bytes: await pdf.save(),
                      filename:
                          'order_summary_${widget.user.fullName ?? widget.user.email}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to preview PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();

    // Create PDF content
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildPdfHeader(),
        build: (context) => [
          _buildPdfTitle(),
          pw.SizedBox(height: 20),
          _buildPdfTable(),
          pw.SizedBox(height: 20),
          _buildPdfGrandTotal(),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfHeader() {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Text(
        'Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
      ),
    );
  }

  pw.Widget _buildPdfTitle() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ORDER SUMMARY REPORT',
          style: pw.TextStyle(
            fontSize: 28,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue,
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey, width: 2),
            borderRadius: pw.BorderRadius.circular(8),
            color: PdfColors.grey100,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    'Customer Information',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Name: ${widget.user.fullName ?? 'No name available'}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Email: ${widget.user.email}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              if (widget.user.phoneNumber != null)
                pw.Text(
                  'Phone: ${widget.user.phoneNumber}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Text(
          'Report Period: ${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfTable() {
    return pw.TableHelper.fromTextArray(
      headers: [
        'Order Date',
        'Quantity',
        'Total Sales',
        'Total Ongkir',
        'Total Payment',
        'Total Debt',
      ],
      data: _orderSummaryData
          .map(
            (data) => [
              _dateFormat.format(data.orderDate),
              data.totalQuantity.toString(),
              _formatCurrency(data.totalSales),
              _formatCurrency(data.totalOngkir),
              _formatCurrency(data.totalPayment),
              _formatCurrency(data.totalDebt),
            ],
          )
          .toList(),
      border: pw.TableBorder.all(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget _buildPdfGrandTotal() {
    final grandTotal = _calculateGrandTotals();

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        color: PdfColors.grey100,
      ),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Grand Total',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Quantity: ${grandTotal.totalQuantity}'),
              pw.Text('Total Sales: ${_formatCurrency(grandTotal.totalSales)}'),
              pw.Text(
                'Total Ongkir: ${_formatCurrency(grandTotal.totalOngkir)}',
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Payment: ${_formatCurrency(grandTotal.totalPayment)}',
              ),
              pw.Text(
                'Total Debt: ${_formatCurrency(grandTotal.totalDebt)}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: grandTotal.totalDebt > 0
                      ? PdfColors.red
                      : PdfColors.green,
                ),
              ),
              pw.Container(), // Empty space for alignment
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return 'Rp ${NumberFormat('#,###').format(amount)}';
  }

  GrandTotalData _calculateGrandTotals() {
    final totalQuantity = _orderSummaryData.fold<int>(
      0,
      (sum, data) => sum + data.totalQuantity,
    );
    final totalSales = _orderSummaryData.fold<double>(
      0,
      (sum, data) => sum + data.totalSales,
    );
    final totalOngkir = _orderSummaryData.fold<double>(
      0,
      (sum, data) => sum + data.totalOngkir,
    );
    final totalPayment = _orderSummaryData.fold<double>(
      0,
      (sum, data) => sum + data.totalPayment,
    );
    final totalDebt = _orderSummaryData.fold<double>(
      0,
      (sum, data) => sum + data.totalDebt,
    );

    return GrandTotalData(
      totalQuantity: totalQuantity,
      totalSales: totalSales,
      totalOngkir: totalOngkir,
      totalPayment: totalPayment,
      totalDebt: totalDebt,
    );
  }
}

class OrderSummaryData {
  final DateTime orderDate;
  final int totalQuantity;
  final double totalSales;
  final double totalOngkir;
  final double totalPayment;
  final double totalDebt;

  OrderSummaryData({
    required this.orderDate,
    required this.totalQuantity,
    required this.totalSales,
    required this.totalOngkir,
    required this.totalPayment,
    required this.totalDebt,
  });
}

class GrandTotalData {
  final int totalQuantity;
  final double totalSales;
  final double totalOngkir;
  final double totalPayment;
  final double totalDebt;

  GrandTotalData({
    required this.totalQuantity,
    required this.totalSales,
    required this.totalOngkir,
    required this.totalPayment,
    required this.totalDebt,
  });
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../providers/admin_orders_provider.dart';

class ProductQuantityOrderedScreen extends StatefulWidget {
  const ProductQuantityOrderedScreen({Key? key}) : super(key: key);

  @override
  State<ProductQuantityOrderedScreen> createState() =>
      _ProductQuantityOrderedScreenState();
}

class _ProductQuantityOrderedScreenState
    extends State<ProductQuantityOrderedScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _productData = [];
  bool _isLoading = false;
  int _totalQuantity = 0;
  int _totalOrders = 0;

  // Pagination variables for large datasets
  int _currentOffset = 0;
  final int _pageSize = 500; // Smaller page size for better performance
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  List<Map<String, dynamic>> _allRawData =
      []; // Store all raw data for aggregation

  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeDates();
  }

  void _initializeDates() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1); // First day of current month
    _endDate = now;

    _startDateController.text = _formatDate(_startDate!);
    _endDateController.text = _formatDate(_endDate!);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
        _startDateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _endDateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _loadProductQuantityData() async {
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
      _isLoading = true;
      _currentOffset = 0;
      _hasMoreData = true;
      _allRawData.clear();
    });

    try {
      await _loadAllDataInPages();
      await _processAndDisplayData();
    } catch (e) {
      print('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllDataInPages() async {
    final supabase = Supabase.instance.client;
    _allRawData.clear();

    print('Starting pagination data load process...');
    print(
      'Date range: ${_formatDate(_startDate!)} to ${_formatDate(_endDate!)}',
    );

    while (_hasMoreData) {
      try {
        print(
          'Loading page starting at offset $_currentOffset (size: $_pageSize)',
        );

        final response = await supabase
            .from('kl_order_items')
            .select('''
              product_id,
              product_name,
              quantity,
              order_id,
              kl_orders!inner(
                created_at,
                status
              )
            ''')
            .neq('kl_orders.status', 'cancelled')
            .gte('kl_orders.created_at', _startDate!.toIso8601String())
            .lt(
              'kl_orders.created_at',
              _endDate!.add(const Duration(days: 1)).toIso8601String(),
            )
            .order('order_id', ascending: true)
            .range(_currentOffset, _currentOffset + _pageSize - 1);

        print('Received ${response.length} items in this page');

        if (response.isEmpty) {
          _hasMoreData = false;
          break;
        }

        _allRawData.addAll(response);
        _currentOffset += _pageSize;

        // If we got fewer items than page size, we've reached the end
        if (response.length < _pageSize) {
          _hasMoreData = false;
        }

        print('Total items loaded so far: ${_allRawData.length}');

        // Small delay to prevent overwhelming the database
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('Error loading page: $e');
        _hasMoreData = false;
        break;
      }
    }

    print('Completed loading all data. Total items: ${_allRawData.length}');
  }

  Future<void> _processAndDisplayData() async {
    if (_allRawData.isEmpty) {
      setState(() {
        _productData = [];
        _totalQuantity = 0;
        _totalOrders = 0;
      });
      return;
    }

    print('Processing ${_allRawData.length} items for aggregation...');

    // Aggregate data by product
    Map<String, Map<String, dynamic>> productMap = {};
    int totalQuantity = 0;
    Set<String> uniqueOrderIds = {};

    for (final item in _allRawData) {
      final productKey =
          item['product_id']?.toString() ?? item['product_name'] ?? 'unknown';
      final productName = item['product_name'] ?? 'Unknown Product';
      final quantity = (item['quantity'] ?? 0) as int;
      final orderId = item['order_id'].toString();

      uniqueOrderIds.add(orderId);

      if (productMap.containsKey(productKey)) {
        productMap[productKey]!['total_quantity'] += quantity;
        if (!productMap[productKey]!['order_ids'].contains(orderId)) {
          productMap[productKey]!['order_ids'].add(orderId);
        }
      } else {
        productMap[productKey] = {
          'product_name': productName,
          'total_quantity': quantity,
          'order_ids': {orderId},
        };
      }
      totalQuantity += quantity;
    }

    // Convert to list and sort by quantity descending
    List<Map<String, dynamic>> productData = [];

    for (final entry in productMap.entries) {
      final orderIdsList = entry.value['order_ids'] as Set<String>;
      productData.add({
        'product_name': entry.value['product_name'],
        'total_quantity': entry.value['total_quantity'],
        'total_orders': orderIdsList.length,
      });
    }

    productData.sort(
      (a, b) =>
          (b['total_quantity'] as int).compareTo(a['total_quantity'] as int),
    );

    print('Processed ${productData.length} unique products');
    print('Total quantity: $totalQuantity');
    print('Total orders: ${uniqueOrderIds.length}');

    setState(() {
      _productData = productData;
      _totalQuantity = totalQuantity;
      _totalOrders = uniqueOrderIds.length;
    });
  }

  Future<void> _exportToPDF() async {
    if (!mounted) return;
    print("STARTING EXPORTING PDF: $_productData.length");
    if (_productData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      print('Starting PDF export with ${_productData.length} items');

      for (final item in _productData) {
        print(
          'Product: ${item['product_name']}, Quantity: ${item['total_quantity']}, Orders: ${item['total_orders']}',
        );
      }
      print('Finished logging all items for PDF export.');

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Column(
              children: [
                pw.Text(
                  'Product Quantity Ordered Report',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 10),

                pw.Text(
                  'Date Range: ${_formatDate(_startDate!)} to ${_formatDate(_endDate!)}',
                  style: const pw.TextStyle(fontSize: 12),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 20),
              ] /*  */,
            ),
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: ['Product Name', 'Quantity', 'Total Orders'],
              data: [
                // Customer data rows
                ..._productData.map(
                  (product) => [
                    '${product['product_name']}',
                    product['total_quantity'],
                    product['total_orders'],
                  ],
                ),
                [
                  'GRAND TOTAL',
                  _productData.fold<int>(
                    0,
                    (sum, item) => sum + item['total_quantity'] as int,
                  ),
                  // _productData.fold<int>(
                  //   0,
                  //   (sum, item) => sum + item['total_orders'] as int,
                  // ),
                ],
              ],
            ),
          ],
        ),
      );

      print('PDF document created successfully');

      final pdfBytes = await pdf.save();
      final fileName =
          'Product_Quantity_Ordered_${_formatDate(_startDate!)}_${_formatDate(_endDate!)}';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: fileName,
        format: PdfPageFormat.a4,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      print('PDF exported successfully');
    } catch (e) {
      print('PDF Export Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToCSV() async {
    if (!mounted) return;

    if (_productData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      print('Starting CSV export with ${_productData.length} items');

      final csvContent = StringBuffer();

      csvContent.writeln('Product Name,Total Orders,Quantity Ordered');

      for (final item in _productData) {
        final productName = (item['product_name'] ?? '').toString().replaceAll(
          '"',
          '""',
        );
        final totalOrders = item['total_orders'] ?? 0;
        final quantity = item['total_quantity'] ?? 0;

        csvContent.writeln('"$productName",$quantity,$totalOrders');
      }

      csvContent.writeln('TOTALS,$_totalQuantity,$_totalOrders');
      csvContent.writeln(
        'Data Source: Processed ${_allRawData.length} total order items',
      );

      // Create temporary file for sharing
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'Product_Quantity_Ordered_${_formatDate(_startDate!)}_${_formatDate(_endDate!)}.csv';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(csvContent.toString());

      print('CSV file created: ${tempFile.path}');

      // Save to downloads directory for direct access
      final downloadsDir = await _getDownloadsDirectory();
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final downloadsFile = File('${downloadsDir.path}/$fileName');
      await tempFile.copy(downloadsFile.path);

      // Clean up temporary file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'CSV exported to Downloads folder: ${downloadsFile.path}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      print('CSV file saved to: ${downloadsFile.path}');
    } catch (e) {
      print('CSV Export Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Quantity Ordered'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by Date Range',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Start Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _selectStartDate,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _endDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'End Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _selectEndDate,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _loadProductQuantityData,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_isLoading ? 'Loading Data...' : 'Load Data'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            if (_isLoading) ...[
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      'Loading large dataset... This may take a moment.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (_allRawData.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Processed ${_allRawData.length} order items so far...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (_productData.isNotEmpty) ...[
              // Summary Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            'Total Products',
                            _productData.length.toString(),
                          ),
                          _buildSummaryItem(
                            'Total Quantity',
                            _totalQuantity.toString(),
                          ),
                          _buildSummaryItem(
                            'Total Orders',
                            _totalOrders.toString(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Processed ${_allRawData.length} order items from database',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _exportToPDF,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Export PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Card(
                elevation: 2,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Product Name',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Quantity Ordered',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Total Orders',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: [
                      ..._productData.map(
                        (item) => DataRow(
                          cells: [
                            DataCell(
                              Text(item['product_name']?.toString() ?? ''),
                            ),
                            DataCell(
                              Text(item['total_quantity']?.toString() ?? '0'),
                            ),
                            DataCell(
                              Text(item['total_orders']?.toString() ?? '0'),
                            ),
                          ],
                        ),
                      ),
                      DataRow(
                        cells: [
                          const DataCell(
                            Text(
                              'TOTAL',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataCell(
                            Text(
                              _totalQuantity.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              _totalOrders.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (!_isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No data available. Please select date range and click "Load Data".',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Future<Directory> _getDownloadsDirectory() async {
    // For Android: use Downloads directory
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final downloadsPath = '${directory.path}/Download';
        return Directory(downloadsPath);
      }
    }
    // For iOS and other platforms: use documents directory
    final directory = await getApplicationDocumentsDirectory();
    return directory;
  }
}

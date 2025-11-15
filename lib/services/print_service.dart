import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../models/order.dart';

// Define OverallOrderData class here since it's not imported
class OverallOrderData {
  final int rowNumber;
  final DateTime orderDate;
  final String userEmail;
  final String userName;
  final String receiverName;
  final String status;
  final String orderNumber;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double itemTotal;

  OverallOrderData({
    required this.rowNumber,
    required this.orderDate,
    required this.userEmail,
    required this.userName,
    required this.receiverName,
    required this.status,
    required this.orderNumber,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.itemTotal,
  });
}

class PrintService {
  static const String _separator =
      '===========================================================================';

  /// Generate PDF for delivery addresses
  static Future<Uint8List> generateDeliveryAddressPdf(
    List<Order> orders,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(
          15,
        ), // Reduced margin to fit more content
        header: (context) => _buildHeader(),
        build: (context) => [
          pw.SizedBox(height: 10),
          ...orders.map(
            (order) => pw.Container(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _buildOrderDeliveryLayout(order),
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Generate PDF for delivery addresses with new format
  static Future<Uint8List> generateDeliveryAddressPdfNew(
    List<Order> orders,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15),
        header: (context) => _buildHeader(),
        build: (context) => [
          pw.SizedBox(height: 10),
          ...orders.asMap().entries.map((entry) {
            final reverseOrderNumber = orders.length - entry.key;
            return pw.Container(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _buildOrderDeliveryLayoutNew(
                  entry.value,
                  reverseOrderNumber,
                ),
              ),
            );
          }),
        ],
      ),
    );

    return pdf.save();
  }

  /// Build header for each page
  static pw.Widget _buildHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 1, color: PdfColors.grey400),
        ),
      ),
      child: pw.Text(
        'Delivery Address List',
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  /// Generate print layout for delivery addresses
  static List<pw.Widget> _buildOrderDeliveryLayout(Order order) {
    final totalQuantity = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return [
      // Order container - keeps entire order together
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(width: 1, color: PdfColors.grey300),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Order header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Penerima: ${order.receiverName ?? 'No name'}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Text(
                  'Order ID: ${order.orderNumber}',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // Phone and courier info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'No HP: ${order.receiverPhone ?? 'No phone'}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.Text(
                  'Ekspedisi: ${order.courierInfo ?? 'No courier'}',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // Address
            pw.Container(
              width: double.infinity,
              child: pw.Text(
                'Alamat: ${order.shippingAddress}',
                style: pw.TextStyle(fontSize: 10),
              ),
            ),
            pw.SizedBox(height: 6),

            // Total items
            pw.Text(
              'Total Barang: $totalQuantity',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),

            // Order items list - compact format
            pw.Wrap(
              spacing: 4,
              runSpacing: 2,
              children: order.items
                  .map(
                    (item) => pw.Text(
                      '${item.productName}=(${item.quantity})',
                      style: pw.TextStyle(fontSize: 9),
                    ),
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 6),

            // Separator line
            pw.Container(
              width: double.infinity,
              height: 1,
              color: PdfColors.grey400,
            ),
          ],
        ),
      ),
    ];
  }

  /// Generate print layout for delivery addresses with new format
  static List<pw.Widget> _buildOrderDeliveryLayoutNew(
    Order order,
    int orderNumber,
  ) {
    final totalQuantity = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final senderName = order.isDropship
        ? (order.senderName ?? 'Dropship')
        : 'Dalanova';
    final senderPhone = order.isDropship
        ? (order.senderPhone ?? 'No phone')
        : '0823-1854-9875';

    return [
      // Order container - keeps entire order together
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(width: 1, color: PdfColors.grey300),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header line
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Order NO: $orderNumber',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Text(
                  'Order Date: ${order.createdAt != null ? '${order.createdAt!.add(const Duration(hours: 7))}' : 'No date'}',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 1),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Penerima: ${order.receiverName ?? 'No name'}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Text(
                  'Order ID: ${order.orderNumber}',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // Phone and courier info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'No HP: ${order.receiverPhone ?? 'No phone'}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.Text(
                  'Ekspedisi: ${order.courierInfo ?? 'No courier'}',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // Address
            pw.Container(
              width: double.infinity,
              child: pw.Text(
                'Alamat: ${order.shippingAddress}',
                style: pw.TextStyle(fontSize: 10),
              ),
            ),
            pw.SizedBox(height: 6),

            // Sender info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Note: ${order.notes ?? '-'}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.Text(
                  'Pengirim: $senderName',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text('', style: pw.TextStyle(fontSize: 10)),
                ),
                pw.Text(
                  'No Hp: $senderPhone',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // Total items
            pw.Text(
              'Total Barang: $totalQuantity',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),

            // Order items list - compact format
            pw.Wrap(
              spacing: 4,
              runSpacing: 2,
              children: order.items
                  .map(
                    (item) => pw.Text(
                      '${item.productName}=(${item.quantity})',
                      style: pw.TextStyle(fontSize: 9),
                    ),
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 6),

            // Separator line
            pw.Container(
              width: double.infinity,
              height: 1,
              color: PdfColors.grey400,
            ),
          ],
        ),
      ),
    ];
  }

  /// Print delivery addresses directly to printer
  static Future<void> printDeliveryAddresses(List<Order> orders) async {
    final pdfData = await generateDeliveryAddressPdf(orders);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      format: PdfPageFormat.a4,
    );
  }

  /// Print delivery addresses with new format directly to printer
  static Future<void> printDeliveryAddressesNew(List<Order> orders) async {
    final pdfData = await generateDeliveryAddressPdfNew(orders);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      format: PdfPageFormat.a4,
    );
  }

  /// Save delivery addresses as PDF file
  static Future<void> saveDeliveryAddressesAsPdf(
    List<Order> orders,
    String filename,
  ) async {
    final pdfData = await generateDeliveryAddressPdf(orders);

    await Printing.sharePdf(bytes: pdfData, filename: filename);
  }

  /// Save delivery addresses with new format as PDF file
  static Future<void> saveDeliveryAddressesAsPdfNew(
    List<Order> orders,
    String filename,
  ) async {
    final pdfData = await generateDeliveryAddressPdfNew(orders);

    await Printing.sharePdf(bytes: pdfData, filename: filename);
  }

  /// Show print preview dialog
  static Future<void> showPrintPreview(
    BuildContext context,
    List<Order> orders,
  ) async {
    final pdfData = await generateDeliveryAddressPdf(orders);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PrintPreviewScreen(pdfData: pdfData, orders: orders),
      ),
    );
  }

  /// Show print preview dialog with new format
  static Future<void> showPrintPreviewNew(
    BuildContext context,
    List<Order> orders,
  ) async {
    final pdfData = await generateDeliveryAddressPdfNew(orders);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PrintPreviewScreen(pdfData: pdfData, orders: orders),
      ),
    );
  }

  /// Generate PDF for overall order report
  static Future<void> generateOrderReportPDF(
    List<OverallOrderData> orderData,
    DateTime startDate,
    DateTime endDate,
    int totalQuantity,
    double totalAmount,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15),
        header: (context) => _buildOrderReportHeader(startDate, endDate),
        build: (context) => [
          pw.SizedBox(height: 10),
          _buildOrderReportSummary(totalQuantity, totalAmount),
          pw.SizedBox(height: 20),
          _buildOrderReportTable(orderData),
        ],
      ),
    );

    // Save and share the PDF
    final pdfData = await pdf.save();
    await Printing.sharePdf(
      bytes: pdfData,
      filename:
          'overall_order_report_${startDate.toIso8601String().substring(0, 10)}_${endDate.toIso8601String().substring(0, 10)}.pdf',
    );
  }

  /// Generate CSV for overall order report
  static Future<void> generateOrderReportCSV(
    List<OverallOrderData> orderData,
    DateTime startDate,
    DateTime endDate,
    int totalQuantity,
    double totalAmount,
  ) async {
    final csv = StringBuffer();

    // Add header
    csv.writeln('Overall Order Report');
    csv.writeln(
      'Period: ${startDate.toIso8601String().substring(0, 10)} to ${endDate.toIso8601String().substring(0, 10)}',
    );
    csv.writeln('');

    // Add summary
    csv.writeln('Total Orders,${orderData.length}');
    csv.writeln('Total Quantity,$totalQuantity');
    csv.writeln('Total Amount,Rp ${totalAmount.toStringAsFixed(0)}');
    csv.writeln('');

    // Add table headers
    csv.writeln(
      'Row Number,Order Date,User Email,User Name,Receiver Name,Status,Order Number,Product Name,Quantity,Unit Price,Item Total',
    );

    // Add data rows
    final processedOrders = <String>{}; // Track which orders we've processed

    for (final data in orderData) {
      // Only show row number and order info for the first occurrence of each order number
      final shouldShowOrderInfo = !processedOrders.contains(data.orderNumber);
      processedOrders.add(data.orderNumber);

      csv.writeln(
        '${shouldShowOrderInfo ? data.rowNumber : ''},'
        '${shouldShowOrderInfo ? DateFormat('yyyy-MM-dd HH:mm:ss').format(data.orderDate) : ''},'
        '${shouldShowOrderInfo ? data.userEmail : ''},'
        '${shouldShowOrderInfo ? data.userName : ''},'
        '${shouldShowOrderInfo ? data.receiverName : ''},'
        '${shouldShowOrderInfo ? data.status : ''},'
        '${data.orderNumber},'
        '${data.productName},'
        '${data.quantity},'
        '${data.unitPrice.toStringAsFixed(0)},'
        '${data.itemTotal.toStringAsFixed(0)}',
      );
    }

    // Add total row
    csv.writeln(
      'TOTAL,,,,,,,${totalQuantity},,${totalAmount.toStringAsFixed(0)}',
    );

    // Save to file using CSV sharing (using utf8 encoding)
    final csvData = utf8.encode(csv.toString());
    await Printing.sharePdf(
      bytes: csvData,
      filename:
          'overall_order_report_${startDate.toIso8601String().substring(0, 10)}_${endDate.toIso8601String().substring(0, 10)}.csv',
    );
  }

  /// Build header for order report
  static pw.Widget _buildOrderReportHeader(
    DateTime startDate,
    DateTime endDate,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 1, color: PdfColors.grey400),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'Overall Order Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Period: ${startDate.toIso8601String().substring(0, 10)} to ${endDate.toIso8601String().substring(0, 10)}',
            style: pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Build summary section for order report
  static pw.Widget _buildOrderReportSummary(
    int totalQuantity,
    double totalAmount,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: [
          pw.Column(
            children: [
              pw.Text(
                '$totalQuantity',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Total Quantity'),
            ],
          ),
          pw.Column(
            children: [
              pw.Text(
                'Rp ${totalAmount.toStringAsFixed(0)}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Total Amount'),
            ],
          ),
        ],
      ),
    );
  }

  /// Build data table for order report
  static pw.Widget _buildOrderReportTable(List<OverallOrderData> orderData) {
    final headers = [
      'Row #',
      'Order Date',
      'User Email',
      'User Name',
      'Receiver Name',
      'Status',
      'Order #',
      'Product Name',
      'Qty',
      'Unit Price',
      'Item Total',
    ];

    final tableRows = <pw.TableRow>[];

    // Header row
    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: headers
            .map(
              (header) => pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  header,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            )
            .toList(),
      ),
    );

    // Data rows
    final processedOrders =
        <String>{}; // Track which orders we've processed for row numbering

    for (final data in orderData) {
      // Only show row number and order info for the first occurrence of each order number
      final shouldShowOrderInfo = !processedOrders.contains(data.orderNumber);
      processedOrders.add(data.orderNumber);

      tableRows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                shouldShowOrderInfo ? data.rowNumber.toString() : '',
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                shouldShowOrderInfo
                    ? DateFormat('yyyy-MM-dd HH:mm:ss').format(data.orderDate)
                    : '',
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(shouldShowOrderInfo ? data.userEmail : ''),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(shouldShowOrderInfo ? data.userName : ''),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(shouldShowOrderInfo ? data.receiverName : ''),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(shouldShowOrderInfo ? data.status : ''),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(data.orderNumber),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(data.productName),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(data.quantity.toString()),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Rp ${data.unitPrice.toStringAsFixed(0)}'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Rp ${data.itemTotal.toStringAsFixed(0)}'),
            ),
          ],
        ),
      );
    }

    // Total row
    final totalQuantity = orderData.fold<int>(
      0,
      (sum, data) => sum + data.quantity,
    );
    final totalAmount = orderData.fold<double>(
      0.0,
      (sum, data) => sum + data.itemTotal,
    );

    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              'TOTAL QUANTITY:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              totalQuantity.toString(),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              '',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              'Rp ${totalAmount.toStringAsFixed(0)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return pw.Table(children: tableRows);
  }
}

class PrintPreviewScreen extends StatelessWidget {
  final Uint8List pdfData;
  final List<Order> orders;

  const PrintPreviewScreen({
    Key? key,
    required this.pdfData,
    required this.orders,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printPdf(),
            tooltip: 'Print',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePdf(),
            tooltip: 'Share/Save',
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => pdfData,
        allowSharing: false,
        allowPrinting: false,
        pdfFileName:
            'delivery_addresses_${DateTime.now().millisecondsSinceEpoch}.pdf',
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }

  void _printPdf() {
    Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfData);
  }

  void _sharePdf() {
    Printing.sharePdf(
      bytes: pdfData,
      filename:
          'delivery_addresses_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}

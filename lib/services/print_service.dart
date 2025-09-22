import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../models/order.dart';

class PrintService {
  static const String _separator = '===========================================================================';

  /// Generate PDF for delivery addresses
  static Future<Uint8List> generateDeliveryAddressPdf(List<Order> orders) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15), // Reduced margin to fit more content
        header: (context) => _buildHeader(),
        build: (context) => [
          pw.SizedBox(height: 10),
          ...orders.map((order) => pw.Container(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: _buildOrderDeliveryLayout(order),
            ),
          )),
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
    final totalQuantity = order.items.fold<int>(0, (sum, item) => sum + item.quantity);

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
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
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
                pw.Expanded(
                  child: pw.Text(
                    'Ekspedisi: ${order.courierInfo ?? 'No courier'}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
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
              children: order.items.map((item) => pw.Text(
                '${item.productName}=(${item.quantity})',
                style: pw.TextStyle(fontSize: 9),
              )).toList(),
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

  /// Save delivery addresses as PDF file
  static Future<void> saveDeliveryAddressesAsPdf(List<Order> orders, String filename) async {
    final pdfData = await generateDeliveryAddressPdf(orders);

    await Printing.sharePdf(
      bytes: pdfData,
      filename: filename,
    );
  }

  /// Show print preview dialog
  static Future<void> showPrintPreview(BuildContext context, List<Order> orders) async {
    final pdfData = await generateDeliveryAddressPdf(orders);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(
          pdfData: pdfData,
          orders: orders,
        ),
      ),
    );
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
        pdfFileName: 'delivery_addresses_${DateTime.now().millisecondsSinceEpoch}.pdf',
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }

  void _printPdf() {
    Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
    );
  }

  void _sharePdf() {
    Printing.sharePdf(
      bytes: pdfData,
      filename: 'delivery_addresses_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
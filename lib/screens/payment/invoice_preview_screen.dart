import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';

class InvoicePreviewScreen extends StatelessWidget {
  final Order order;

  const InvoicePreviewScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final totalAmount = order.totalAmount + (order.additionalCosts ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Preview'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printInvoice(context),
            tooltip: 'Print Invoice',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Invoice Header
            _buildInvoiceHeader(),

            const SizedBox(height: 24),

            // Customer Information
            _buildCustomerInfo(context, authProvider),

            const SizedBox(height: 24),

            // Order Items
            _buildOrderItems(),

            const SizedBox(height: 24),

            // Total Section
            _buildTotalSection(totalAmount),

            const SizedBox(height: 24),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'DALANOVA',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'INVOICE',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invoice #: ${order.orderNumber}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Date: ${_formatDate(order.createdAt)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(BuildContext context, AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Information',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Name', order.receiverName ?? 'N/A'),
          _buildInfoRow('Phone', order.receiverPhone ?? 'N/A'),
          _buildInfoRow('Address', order.shippingAddress),
        ],
      ),
    );
  }

  Widget _buildOrderItems() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...order.items.map((item) => _buildOrderItemRow(item)),
          const Divider(),
          _buildSummaryRow('Subtotal', order.totalAmount),
          if (order.additionalCosts != null && order.additionalCosts! > 0) ...[
            _buildSummaryRow(
              'Additional Costs${order.additionalCostsNotes != null ? ' (${order.additionalCostsNotes})' : ''}',
              order.additionalCosts!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'Qty: ${item.quantity} × Rp ${item.unitPrice.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            'Rp ${item.totalPrice.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(
          'Rp ${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTotalSection(double totalAmount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'TOTAL AMOUNT',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            'Rp ${totalAmount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        children: [
          Text(
            'Thank you for your business!',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'For any inquiries, please contact our customer service.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _printInvoice(BuildContext context) async {
    try {
      // Create a simple invoice data structure for printing
      final invoiceData = {
        'invoiceNumber': order.orderNumber,
        'date': _formatDate(order.createdAt),
        'customerName': order.receiverName ?? 'N/A',
        'customerPhone': order.receiverPhone ?? 'N/A',
        'customerAddress': order.shippingAddress,
        'items': order.items
            .map(
              (item) => {
                'name': item.productName,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'totalPrice': item.totalPrice,
              },
            )
            .toList(),
        'subtotal': order.totalAmount,
        'additionalCosts': order.additionalCosts ?? 0,
        'additionalCostsNotes': order.additionalCostsNotes,
        'total': order.totalAmount + (order.additionalCosts ?? 0),
      };

      // For now, we'll use the existing print functionality
      // You can extend this to create a proper invoice PDF
      await Printing.sharePdf(
        bytes: await _generateInvoicePdf(),
        filename: 'invoice_${order.orderNumber}.pdf',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice sent to printer'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Uint8List> _generateInvoicePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'DALANOVA',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Invoice details
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Invoice #: ${order.orderNumber}'),
                    pw.Text('Date: ${_formatDate(order.createdAt)}'),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 30),

            // Customer info
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Customer Information',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('Name: ${order.receiverName ?? 'N/A'}'),
                  pw.Text('Phone: ${order.receiverPhone ?? 'N/A'}'),
                  pw.Text('Address: ${order.shippingAddress}'),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Items table
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                // Header
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Item',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Qty',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Price',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Total',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                // Items
                ...order.items.map(
                  (item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(item.productName),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(item.quantity.toString()),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rp ${item.unitPrice.toStringAsFixed(0)}',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rp ${item.totalPrice.toStringAsFixed(0)}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // Total
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Subtotal: Rp ${order.totalAmount.toStringAsFixed(0)}',
                  ),
                  if (order.additionalCosts != null &&
                      order.additionalCosts! > 0) ...[
                    pw.Text(
                      'Additional Costs: Rp ${order.additionalCosts!.toStringAsFixed(0)}',
                    ),
                  ],
                  pw.Divider(),
                  pw.Text(
                    'TOTAL: Rp ${(order.totalAmount + (order.additionalCosts ?? 0)).toStringAsFixed(0)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Footer
            pw.Center(
              child: pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }
}

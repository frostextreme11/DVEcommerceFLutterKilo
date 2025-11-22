import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/order.dart';
import '../../models/payment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/customer_notification_provider.dart';
import '../../widgets/custom_button.dart';
import '../../services/notification_service.dart';
import 'invoice_preview_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Order order;

  const PaymentScreen({super.key, required this.order});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  File? _paymentProofImage;
  bool _isUploading = false;
  bool _isSubmitting = false;
  String? _uploadedImageUrl;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _amountController = TextEditingController();

  // Payment data state
  List<Payment> _payments = [];
  bool _isLoadingPayments = false;
  PaymentProgress? _paymentProgress;

  // Bank information
  final Map<String, String> _bankInfo = {
    'BCA': '1392992019',
    'Muamalat': '1050016787',
  };

  final String _accountHolder = 'Nova Sugiar Pertiwi';

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final totalAmount =
        widget.order.totalAmount + (widget.order.additionalCosts ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () => _showInvoicePreview(context),
            tooltip: 'Invoice Preview',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingPayments ? null : _refreshPaymentData,
            tooltip: 'Refresh Payment Data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Amount Card
            Card(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Bayar:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Rp ${totalAmount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Payment Status Card (only show if there are payments)
            if (_payments.isNotEmpty ||
                (_paymentProgress != null &&
                    _paymentProgress!.totalPaid > 0)) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.payment,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Payment Status',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Payment Progress
                      if (_paymentProgress != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Payment Progress:',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${_paymentProgress!.progress.toStringAsFixed(1)}%',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _paymentProgress!.isFullyPaid
                                        ? Colors.green
                                        : _paymentProgress!.hasPartialPayment
                                        ? Colors.orange
                                        : Colors.grey,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _paymentProgress!.progress / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _paymentProgress!.isFullyPaid
                                ? Colors.green
                                : _paymentProgress!.hasPartialPayment
                                ? Colors.orange
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Paid: Rp ${_paymentProgress!.totalPaid.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                              style: TextStyle(
                                color: _paymentProgress!.totalPaid > 0
                                    ? Colors.green
                                    : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Total: Rp ${_paymentProgress!.orderTotal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (_paymentProgress!.remainingAmount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Remaining: Rp ${_paymentProgress!.remainingAmount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],

                      const SizedBox(height: 16),

                      // Recent Payments
                      if (_payments.isNotEmpty) ...[
                        Text(
                          'Recent Payments:',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        ..._payments
                            .take(3)
                            .map(
                              (payment) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Rp ${payment.amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                            ),
                                          ),
                                          Text(
                                            payment.createdAt.toString().split(
                                              ' ',
                                            )[0],
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: payment.status.color.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        payment.status.displayName,
                                        style: TextStyle(
                                          color: payment.status.color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],

            // Bank Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Informasi Nomor Rekening',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Transfer Ke Rekening:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bank Details
                    ..._bankInfo.entries.map(
                      (entry) => _buildBankDetailRow(entry.key, entry.value),
                    ),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Atas Nama: $_accountHolder',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Text(
                      'Mohon transfer sesuai dengan jumlah tagihan.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Payment Amount Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pembayaran',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Masukan jumlah pembayaran (minimum Rp 10,000)',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Jumlah Pembayaran (Rp)',
                        hintText: 'Masukkan jumlah yang ingin dibayar',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Masukan jumlah pembayaran';
                        }
                        final amount = double.tryParse(value.trim());
                        if (amount == null || amount < 10000) {
                          return 'Minimum pembayaran adalah Rp 10,000';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Tagihan: Rp ${totalAmount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _amountController.text = totalAmount
                              .toStringAsFixed(0),
                          child: const Text(
                            'Bayar Penuh',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Payment Proof Upload
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Bukti Transfer',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Image Preview or Upload Area
                    if (_paymentProofImage != null ||
                        _uploadedImageUrl != null) ...[
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _paymentProofImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _paymentProofImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : _uploadedImageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _uploadedImageUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) {
                                    print(
                                      'Error loading payment proof preview: $error',
                                    );
                                    return const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.error, color: Colors.red),
                                          SizedBox(height: 4),
                                          Text(
                                            'Failed to load',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              )
                            : const SizedBox(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isUploading ? null : _pickImage,
                              icon: const Icon(Icons.photo_camera),
                              label: const Text('Ganti Gambar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isUploading ? null : _removeImage,
                              icon: const Icon(Icons.delete),
                              label: const Text('Hapus Gambar'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Upload Area
                      InkWell(
                        onTap: _isUploading ? null : _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).primaryColor,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: 48,
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Click untuk upload bukti transfer',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'JPG, PNG up to 5MB',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (_isUploading) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text(
                        'Uploading image...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Submit Payment Button
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: _isSubmitting
                    ? 'Pembayaran Disubmit...'
                    : 'Submit Pembayaran',
                onPressed:
                    (_paymentProofImage == null && _uploadedImageUrl == null) ||
                        _isSubmitting
                    ? null
                    : () => _submitPayment(context, authProvider),
                backgroundColor: Theme.of(context).primaryColor,
                isLoading: _isSubmitting,
              ),
            ),

            const SizedBox(height: 16),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[400]!),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankDetailRow(String bankName, String accountNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$bankName:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Row(
            children: [
              Text(
                accountNumber,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _copyToClipboard(accountNumber),
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy account number',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _paymentProofImage = File(pickedFile.path);
          _uploadedImageUrl =
              null; // Reset uploaded URL when new image is selected
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _paymentProofImage = null;
      _uploadedImageUrl = null;
    });
  }

  Future<void> _copyToClipboard(String text) async {
    // Note: In a real app, you'd use a clipboard package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Account number copied: $text'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _uploadPaymentProof() async {
    if (_paymentProofImage == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final fileName =
          'payment_proof_${widget.order.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      try {
        // Upload to Supabase storage
        final response = await supabase.storage
            .from('payment-proofs')
            .upload(fileName, _paymentProofImage!);

        if (response.isNotEmpty) {
          // Get public URL
          final imageUrl = supabase.storage
              .from('payment-proofs')
              .getPublicUrl(fileName);

          print('Bukti Pembayaran Berhasil diupload: $imageUrl');
          setState(() {
            _uploadedImageUrl = imageUrl;
            _paymentProofImage = null; // Clear the file reference
          });
        }
      } catch (e) {
        print('Storage upload error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload bukti pembayaran gagal. Silakan periksa koneksi Anda dan coba lagi. Error: $e',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        // Don't continue with payment submission if image upload fails
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error Upload Gambar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _submitPayment(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    // Upload image first if not already uploaded
    if (_paymentProofImage != null && _uploadedImageUrl == null) {
      await _uploadPaymentProof();
      if (_uploadedImageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan unggah bukti pembayaran terlebih dahulu'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    if (_uploadedImageUrl == null && _paymentProofImage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Silakan tunggu hingga bukti pembayaran diunggah atau coba lagi',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // Get the entered payment amount
      final enteredAmountText = _amountController.text.trim();
      if (enteredAmountText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan masukkan jumlah pembayaran'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final paymentAmount = double.tryParse(enteredAmountText);
      if (paymentAmount == null || paymentAmount < 10000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Silakan masukkan jumlah pembayaran yang valid (minimum Rp 10.000)',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Create payment record
      final paymentData = {
        'order_id': widget.order.id,
        'user_id': authProvider.user!.id,
        'amount': paymentAmount,
        'status': 'pending',
        'payment_proof_url': _uploadedImageUrl ?? 'No image uploaded',
        'payment_method': 'Bank Transfer',
        'notes':
            'Payment submitted via app - Amount: Rp ${paymentAmount.toStringAsFixed(0)}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await supabase
          .from('kl_payments')
          .insert(paymentData)
          .select()
          .single();

      if (response != null) {
        // Send notification to admin
        await _sendNotificationToAdmin(context, widget.order, paymentAmount);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pembayaran berhasil disubmit! Admin akan memverifikasi pembayaran Anda.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back with success result after successful payment with delay to avoid conflicts
        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            if (context.mounted) {
              print(
                "PaymentScreen: Navigating back with payment success result",
              );
              Navigator.of(
                context,
              ).pop({'payment_success': true, 'order_id': widget.order.id});
            }
          } catch (e) {
            print('Navigation error: $e');
          }
        });

        // Also trigger refresh of order tracking screen if it's open
        // by refreshing the order data in OrdersProvider
        final ordersProvider = Provider.of<OrdersProvider>(
          context,
          listen: false,
        );
        await ordersProvider.refreshOrderById(widget.order.id);

        print(
          'PaymentScreen: Order data refreshed for order: ${widget.order.orderNumber}',
        );

        // Clear form after successful submission
        setState(() {
          _amountController.clear();
          _paymentProofImage = null;
          _uploadedImageUrl = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submit pembayaran: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _sendNotificationToAdmin(
    BuildContext context,
    Order order,
    double paymentAmount,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Find admin user
      final adminResponse = await supabase
          .from('kl_users')
          .select('id')
          .eq('role', 'admin')
          .limit(1)
          .maybeSingle();

      if (adminResponse != null) {
        final adminId = adminResponse['id'];

        // Calculate total quantity from order items
        final totalQuantity = order.items.fold<int>(
          0,
          (sum, item) => sum + item.quantity,
        );

        // Insert admin notification with requested format
        await supabase.from('kl_admin_notifications').insert({
          'user_id': adminId,
          'order_id': order.id,
          'quantity': totalQuantity,
          'customer_name': order.isDropship
              ? order.senderName
              : order.receiverName,
          'title':
              'Payment from: ${order.isDropship ? order.senderName : order.receiverName} - ${order.orderNumber} - Rp ${paymentAmount.toStringAsFixed(0)}',
          'message':
              'Payment of Rp ${paymentAmount.toStringAsFixed(0)} received for order ${order.orderNumber}. Please verify the payment proof.',
          'type': 'payment',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Also send push notification if admin has FCM token
        final tokenResponse = await supabase
            .from('kl_admin_fcm_tokens')
            .select('fcm_token')
            .eq('user_id', adminId)
            .maybeSingle();

        if (tokenResponse != null && tokenResponse['fcm_token'] != null) {
          final notificationService = NotificationService();
          final totalItems = order.items.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          );

          await notificationService.sendOrderNotificationToAdmin(
            adminToken: tokenResponse['fcm_token'],
            title:
                'Payment from: ${order.isDropship ? order.senderName : order.receiverName} - ${order.orderNumber} - Rp ${paymentAmount.toStringAsFixed(0)}',
            customerName: order.receiverName ?? 'Customer',
            quantity: totalItems,
            totalPrice: paymentAmount,
            orderId: order.id,
            orderDate: order.createdAt,
          );
        }
      }
    } catch (e) {
      print('Error sending admin notification: $e');
      // Continue even if notification fails
    }
  }

  void _showInvoicePreview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InvoicePreviewScreen(order: widget.order),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPaymentData();
  }

  Future<void> _loadPaymentData() async {
    setState(() {
      _isLoadingPayments = true;
    });

    try {
      final paymentProvider = Provider.of<PaymentProvider>(
        context,
        listen: false,
      );

      // Load payments for this order
      final payments = await paymentProvider.getPaymentsForOrder(
        widget.order.id,
      );
      final paymentProgress = paymentProvider.calculatePaymentProgress(
        widget.order.id,
        widget.order.totalAmount + (widget.order.additionalCosts ?? 0),
      );

      setState(() {
        _payments = payments;
        _paymentProgress = paymentProgress;
      });

      print(
        'PaymentScreen: Loaded ${payments.length} payments for order ${widget.order.orderNumber}',
      );
    } catch (e) {
      print('Error loading payment data: $e');
    } finally {
      setState(() {
        _isLoadingPayments = false;
      });
    }
  }

  Future<void> _refreshPaymentData() async {
    await _loadPaymentData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}

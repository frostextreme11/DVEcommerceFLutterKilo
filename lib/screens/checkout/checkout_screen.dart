import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../providers/cart_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../models/order.dart';
import '../../services/rajaongkir_service.dart';
import '../payment/payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _receiverAddressController = TextEditingController();
  final _courierController = TextEditingController();
  final _notesController = TextEditingController();
  final _senderNameController = TextEditingController();
  final _senderPhoneController = TextEditingController();

  // RajaOngkir integration fields
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _courierSearchController = TextEditingController();
  Timer? _originDebounceTimer;
  Timer? _destinationDebounceTimer;
  List<Destination> _originResults = [];
  List<Destination> _destinationResults = [];
  List<ShippingCost> _shippingCosts = [];
  List<ShippingCost> _filteredShippingCosts = [];
  bool _isLoadingOrigin = false;
  bool _isLoadingDestination = false;
  bool _isLoadingShippingCost = false;
  Destination? _selectedOrigin;
  Destination? _selectedDestination;
  ShippingCost? _selectedShippingCost;
  double _shippingCost = 0.0;

  String _selectedPaymentMethod = 'Bank Transfer';
  String? _selectedCourier;
  bool _isProcessing = false;
  bool _isDropship = true;

  final List<String> _courierOptions = [
    'Jne REG',
    'JNT REG',
    'Indah Cargo',
    'SPX',
    'Lion REG',
    'Lion Jago',
    'JTR',
    'Sentral Cargo',
    'Baraka',
    'SPX Resi Otomatis',
    'JNT Resi Otomatis',
  ];

  final List<String> _paymentMethods = [
    'Bank Transfer',
    'Credit Card',
    'E-Wallet',
    'Cash on Delivery',
  ];

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _receiverNameController.text = authProvider.userProfile?['full_name'] ?? '';
    _receiverPhoneController.text =
        authProvider.userProfile?['phone_number'] ?? '';
    _receiverAddressController.text =
        authProvider.userProfile?['full_address'] ?? '';

    // Set default origin to Cimahi, Jawa Barat
    _setDefaultOrigin();
  }

  Future<void> _setDefaultOrigin() async {
    try {
      // Set the default origin from Cimahi, Jawa Barat
      final defaultOrigin = Destination(
        id: 5250,
        label: "CIBEUREUM, CIMAHI SELATAN, CIMAHI, JAWA BARAT, 40535",
        provinceName: "JAWA BARAT",
        cityName: "CIMAHI",
        districtName: "CIMAHI SELATAN",
        subdistrictName: "CIBEUREUM",
        zipCode: "40535",
      );

      setState(() {
        _selectedOrigin = defaultOrigin;
        _originController.text = defaultOrigin.label;
      });
    } catch (e) {
      print('Error setting default origin: $e');
    }
  }

  @override
  void dispose() {
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _receiverAddressController.dispose();
    _courierController.dispose();
    _notesController.dispose();
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _courierSearchController.dispose();
    _originDebounceTimer?.cancel();
    _destinationDebounceTimer?.cancel();
    super.dispose();
  }

  // RajaOngkir integration methods
  void _onOriginSearchChanged(String query) {
    _originDebounceTimer?.cancel();
    _originDebounceTimer = Timer(const Duration(seconds: 1), () {
      _searchOrigins(query);
    });
  }

  void _onDestinationSearchChanged(String query) {
    _destinationDebounceTimer?.cancel();
    _destinationDebounceTimer = Timer(const Duration(seconds: 1), () {
      _searchDestinations(query);
    });
  }

  Future<void> _searchOrigins(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _originResults = [];
        _isLoadingOrigin = false;
      });
      return;
    }

    setState(() {
      _isLoadingOrigin = true;
    });

    try {
      print('Searching origins for query: $query');
      final results = await RajaOngkirService.searchDestinations(query);
      print('Found ${results.length} origins');
      if (mounted) {
        setState(() {
          _originResults = results;
          _isLoadingOrigin = false;
        });
      }
    } catch (e) {
      print('Error searching origins: $e');
      if (mounted) {
        setState(() {
          _originResults = [];
          _isLoadingOrigin = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching origins: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _searchDestinations(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _destinationResults = [];
        _isLoadingDestination = false;
      });
      return;
    }

    setState(() {
      _isLoadingDestination = true;
    });

    try {
      print('Searching destinations for query: $query');
      final results = await RajaOngkirService.searchDestinations(query);
      print('Found ${results.length} destinations');
      if (mounted) {
        setState(() {
          _destinationResults = results;
          _isLoadingDestination = false;
        });
      }
    } catch (e) {
      print('Error searching destinations: $e');
      if (mounted) {
        setState(() {
          _destinationResults = [];
          _isLoadingDestination = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching destinations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterShippingCosts(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredShippingCosts = _shippingCosts;
      } else {
        _filteredShippingCosts = _shippingCosts.where((shippingCost) {
          final courierName = shippingCost.name.toLowerCase();
          final serviceName = shippingCost.service.toLowerCase();
          final searchQuery = query.toLowerCase();
          return courierName.contains(searchQuery) ||
              serviceName.contains(searchQuery);
        }).toList();
      }
    });
  }

  void _clearOriginSelection() {
    setState(() {
      _selectedOrigin = null;
      _originController.clear();
      _originResults = [];
      _shippingCosts = [];
      _filteredShippingCosts = [];
      _selectedShippingCost = null;
      _shippingCost = 0.0;
    });
  }

  void _clearDestinationSelection() {
    setState(() {
      _selectedDestination = null;
      _destinationController.clear();
      _destinationResults = [];
      _shippingCosts = [];
      _filteredShippingCosts = [];
      _selectedShippingCost = null;
      _shippingCost = 0.0;
    });
  }

  void _updateAddressWithDestination() {
    if (_selectedDestination != null) {
      final currentAddress = _receiverAddressController.text.trim();
      final destinationInfo =
          '\n📍 Tujuan: ${_selectedDestination!.cityName}, ${_selectedDestination!.provinceName}';

      // Only add destination info if it's not already in the address
      if (!currentAddress.contains(destinationInfo)) {
        _receiverAddressController.text = currentAddress + destinationInfo;
      }
    }
  }

  Future<void> _calculateShippingCost() async {
    if (_selectedOrigin == null || _selectedDestination == null) {
      setState(() {
        _shippingCosts = [];
        _selectedShippingCost = null;
        _shippingCost = 0.0;
      });
      return;
    }

    setState(() {
      _isLoadingShippingCost = true;
      _shippingCosts = [];
      _selectedShippingCost = null;
      _shippingCost = 0.0;
    });

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      // Calculate total weight by fetching from kl_products, default to 800g if empty
      int totalWeight = 0;
      for (final item in cartProvider.items) {
        try {
          final productResponse = await Supabase.instance.client
              .from('kl_products')
              .select('weight')
              .eq('id', item.productId)
              .single();

          int weight = 800; // default
          final weightValue = productResponse['weight'];
          if (weightValue != null && weightValue.toString().trim().isNotEmpty) {
            weight = int.tryParse(weightValue.toString()) ?? 800;
          }
          totalWeight += weight * item.quantity;
        } catch (e) {
          print('Error fetching weight for product ${item.productId}: $e');
          // Use default 800 grams on error
          totalWeight += 800 * item.quantity;
        }
      }

      // Only request allowed courier codes: jne, sicepat, ide, jnt, sentral, lion (baraka is not valid)
      final courierCodes = 'jne:sicepat:ide:jnt:sentral:lion';

      print('Calculating shipping cost:');
      print('Origin: ${_selectedOrigin!.id} (${_selectedOrigin!.cityName})');
      print(
        'Destination: ${_selectedDestination!.id} (${_selectedDestination!.cityName})',
      );
      print('Weight: $totalWeight grams');
      print('Couriers: $courierCodes');

      final results = await RajaOngkirService.calculateShippingCost(
        origin: _selectedOrigin!.id.toString(),
        destination: _selectedDestination!.id.toString(),
        weight: totalWeight,
        couriers: courierCodes,
      );

      print('Shipping cost calculation returned ${results.length} results');

      if (mounted) {
        // Add hardcoded zero-cost couriers to the results
        final allShippingCosts = [
          ...results,
          ...RajaOngkirService.getHardcodedZeroCostCouriers(),
        ];

        setState(() {
          _shippingCosts = allShippingCosts;
          _filteredShippingCosts = allShippingCosts;
          _isLoadingShippingCost = false;
        });
      }
    } catch (e) {
      print('Error calculating shipping cost: $e');
      if (mounted) {
        // Fallback to zero-cost couriers if API fails
        final fallbackCouriers =
            RajaOngkirService.getHardcodedZeroCostCouriers();
        setState(() {
          _shippingCosts = fallbackCouriers;
          _filteredShippingCosts = fallbackCouriers;
          _isLoadingShippingCost = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using free shipping options due to API error'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final ordersProvider = Provider.of<OrdersProvider>(context);

    if (cartProvider.items.isEmpty) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (!didPop) {
            // Navigate back to cart screen when cart is empty
            context.go('/cart');
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Checkout'),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/cart'),
            ),
          ),
          body: const Center(child: Text('Your cart is empty')),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // Show confirmation dialog before leaving checkout
          context.go('/cart');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Checkout'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBackPress(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Summary
                _buildSectionTitle('Ringkasan Daftar Pesanan'),
                _buildOrderSummary(cartProvider),

                const SizedBox(height: 24),

                // Shipping Information
                _buildSectionTitle('Informasi Pengiriman'),
                _buildShippingForm(),

                const SizedBox(height: 10),

                // Payment Method
                //_buildSectionTitle('Payment Method'),
                //_buildPaymentMethodSelector(),

                // Order Total
                _buildOrderTotal(cartProvider),

                const SizedBox(height: 32),

                // Place Order Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _placeOrder(
                            context,
                            cartProvider,
                            ordersProvider,
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Checkout Sekarang - Rp ${(cartProvider.total.toInt() + _shippingCost).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildOrderSummary(CartProvider cartProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cartProvider.items.length,
              itemBuilder: (context, index) {
                final item = cartProvider.items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).cardColor,
                        ),
                        child: item.imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.inventory_2,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.inventory_2,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${item.quantity}x Rp ${item.currentPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rp ${item.totalPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Items (${cartProvider.itemCount}):',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  'Rp ${cartProvider.subtotal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Receiver Information Section
            Text(
              'Informasi Penerima',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Receiver Name
            TextFormField(
              controller: _receiverNameController,
              decoration: InputDecoration(
                labelText: 'Nama Lengkap Penerima',
                hintText: 'Masukkan Nama Penerima',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Tolong masukkan nama penerima';
                }
                if (value.trim().length < 2) {
                  return 'Nama harus terdiri dari minimal 2 karakter';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Receiver Phone Number
            TextFormField(
              controller: _receiverPhoneController,
              decoration: InputDecoration(
                labelText: 'Nomor Telepon Penerima',
                hintText: '+62xxxxxxxxxx',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Tolong masukkan nomor telepon penerima';
                }
                if (value.trim().length < 10) {
                  return 'Tolong masukkan nomor telepon yang valid';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Shipping Address Section
            Text(
              'Alamat Pengiriman',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Receiver Address
            TextFormField(
              controller: _receiverAddressController,
              decoration: InputDecoration(
                labelText: 'Alamat Lengkap Pengiriman',
                hintText: _selectedDestination != null
                    ? 'Alamat jalan, kecamatan, kota, provinsi, kode pos\n📍 Tujuan: ${_selectedDestination!.cityName}, ${_selectedDestination!.provinceName}'
                    : 'Alamat jalan, kecamatan, kota, provinsi, kode pos',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Tolong masukkan alamat pengiriman yang lengkap';
                }
                if (value.trim().length < 20) {
                  return 'Tolong masukkan alamat yang lengkap dengan semua detail';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Origin and Destination Section
            Text(
              'Lokasi Pengiriman',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Origin Selection with Search
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _originController,
                  decoration: InputDecoration(
                    labelText: 'Kota Asal',
                    hintText: 'Cari kota asal pengiriman...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isLoadingOrigin
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.location_city),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      _clearOriginSelection();
                    } else {
                      _onOriginSearchChanged(value);
                    }
                  },
                ),
                if (_originResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _originResults.length,
                      itemBuilder: (context, index) {
                        final origin = _originResults[index];
                        return ListTile(
                          title: Text(origin.label),
                          subtitle: Text(
                            '${origin.cityName}, ${origin.provinceName}',
                          ),
                          onTap: () {
                            setState(() {
                              _selectedOrigin = origin;
                              _originController.text = origin.label;
                              _originResults = [];
                              _calculateShippingCost();
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Destination Selection with Search
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _destinationController,
                  decoration: InputDecoration(
                    labelText: 'Kota Tujuan',
                    hintText: 'Cari kota tujuan pengiriman...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isLoadingDestination
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      _clearDestinationSelection();
                    } else {
                      _onDestinationSearchChanged(value);
                    }
                  },
                ),
                if (_destinationResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _destinationResults.length,
                      itemBuilder: (context, index) {
                        final destination = _destinationResults[index];
                        return ListTile(
                          title: Text(destination.label),
                          subtitle: Text(
                            '${destination.cityName}, ${destination.provinceName}',
                          ),
                          onTap: () {
                            setState(() {
                              _selectedDestination = destination;
                              _destinationController.text = destination.label;
                              _destinationResults = [];
                              _calculateShippingCost();
                              _updateAddressWithDestination();
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Courier Selection
            if (_shippingCosts.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Courier Search Field
                  // TextFormField(
                  //   controller: _courierSearchController,
                  //   decoration: InputDecoration(
                  //     labelText: 'Cari Kurir',
                  //     hintText: 'Cari kurir lalu pilih di bawah...',
                  //     prefixIcon: const Icon(Icons.search),
                  //     suffixIcon: _courierSearchController.text.isNotEmpty
                  //         ? IconButton(
                  //             icon: const Icon(Icons.clear),
                  //             onPressed: () {
                  //               _courierSearchController.clear();
                  //               _filterShippingCosts('');
                  //             },
                  //           )
                  //         : null,
                  //     border: OutlineInputBorder(
                  //       borderRadius: BorderRadius.circular(8),
                  //     ),
                  //     filled: true,
                  //     fillColor: Theme.of(context).cardColor,
                  //   ),
                  //   onChanged: _filterShippingCosts,
                  // ),
                  const SizedBox(height: 8),
                  // Courier Selection Dropdown
                  DropdownButtonFormField<ShippingCost>(
                    value: _selectedShippingCost,
                    decoration: InputDecoration(
                      labelText: 'Kurir Pengiriman',
                      hintText:
                          _filteredShippingCosts.isEmpty &&
                              _courierSearchController.text.isNotEmpty
                          ? 'Tidak ada kurir ditemukan'
                          : 'Pilih layanan kurir',
                      prefixIcon: const Icon(Icons.local_shipping),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 30,
                        horizontal: 16,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<ShippingCost>(
                        value: null,
                        child: Text('Pilih layanan kurir...'),
                      ),
                      ..._filteredShippingCosts.map((shippingCost) {
                        return DropdownMenuItem<ShippingCost>(
                          value: shippingCost,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${shippingCost.name} ${shippingCost.service}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rp ${shippingCost.cost.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} - ${shippingCost.etd}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedShippingCost = value;
                        _shippingCost = value?.cost.toDouble() ?? 0.0;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Tolong pilih layanan kurir';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ] else if (_isLoadingShippingCost) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Menghitung biaya pengiriman...'),
                  ],
                ),
              ),
            ] else if (_selectedOrigin != null &&
                _selectedDestination != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: const Text(
                  'Pilih asal dan tujuan pengiriman untuk melihat opsi kurir',
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: const Text(
                  'Pilih kota asal dan tujuan untuk melihat opsi kurir',
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Order Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Catatan Pesanan (Opsional)',
                hintText: 'Instruksi orderan atau pengiriman',
                prefixIcon: const Icon(Icons.note),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 16),

            // Dropship Checkbox
            // Container(
            //   padding: const EdgeInsets.all(12),
            //   decoration: BoxDecoration(
            //     color: Theme.of(context).cardColor,
            //     borderRadius: BorderRadius.circular(8),
            //     border: Border.all(color: Theme.of(context).dividerColor),
            //   ),
            //   child: Row(
            //     children: [
            //       Checkbox(
            //         value: _isDropship,
            //         onChanged: (value) {
            //           setState(() {
            //             _isDropship = value ?? false;
            //             if (!_isDropship) {
            //               // Clear sender fields when dropship is unchecked
            //               _senderNameController.clear();
            //               _senderPhoneController.clear();
            //             }
            //           });
            //         },
            //         activeColor: Theme.of(context).primaryColor,
            //       ),
            //       const SizedBox(width: 8),
            //       Expanded(
            //         child: Text(
            //           'Dropship Order',
            //           style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            //             fontWeight: FontWeight.w500,
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            const SizedBox(height: 16),

            // Sender Information (only show if dropship is checked)
            if (_isDropship) ...[
              Text(
                'Informasi Pengirim',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              // Sender Name
              TextFormField(
                controller: _senderNameController,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap Pengirim',
                  hintText: 'Masukkan Nama Pengirim',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
                validator: (value) {
                  if (_isDropship && (value == null || value.trim().isEmpty)) {
                    return 'Tolong masukkan nama pengirim';
                  }
                  if (_isDropship && value != null && value.trim().length < 2) {
                    return 'Nama harus terdiri dari minimal 2 karakter';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Sender Phone Number
              TextFormField(
                controller: _senderPhoneController,
                decoration: InputDecoration(
                  labelText: 'Nomor Telepon Pengirim',
                  hintText: '+62xxxxxxxxxx',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (_isDropship && (value == null || value.trim().isEmpty)) {
                    return 'Tolong masukkan nomor telepon pengirim';
                  }
                  if (_isDropship &&
                      value != null &&
                      value.trim().length < 10) {
                    return 'Tolong masukkan nomor telepon yang valid';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),
            ],

            // Address Preview
            // Container(
            //   padding: const EdgeInsets.all(12),
            //   decoration: BoxDecoration(
            //     color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            //     borderRadius: BorderRadius.circular(8),
            //     border: Border.all(
            //       color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            //     ),
            //   ),
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       Row(
            //         children: [
            //           Icon(
            //             Icons.location_on,
            //             size: 16,
            //             color: Theme.of(context).primaryColor,
            //           ),
            //           const SizedBox(width: 8),
            //           Text(
            //             'Alamat Pengiriman Tercatat',
            //             style: Theme.of(context).textTheme.bodySmall?.copyWith(
            //               fontWeight: FontWeight.bold,
            //               color: Theme.of(context).primaryColor,
            //             ),
            //           ),
            //         ],
            //       ),
            //       const SizedBox(height: 8),
            //       Text(
            //         _receiverAddressController.text.isNotEmpty
            //             ? _receiverAddressController.text
            //             : 'Alamat lengkap akan muncul di sini...',
            //         style: Theme.of(context).textTheme.bodySmall?.copyWith(
            //           color: Theme.of(
            //             context,
            //           ).colorScheme.onSurface.withValues(alpha: 0.8),
            //           height: 1.4,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _paymentMethods.map((method) {
            return RadioListTile<String>(
              title: Text(method),
              value: method,
              groupValue: _selectedPaymentMethod,
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value!;
                });
              },
              activeColor: Theme.of(context).primaryColor,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOrderTotal(CartProvider cartProvider) {
    final subtotal = cartProvider.subtotal;
    final discount = cartProvider.totalDiscount;
    final total = subtotal + _shippingCost;

    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal:', style: Theme.of(context).textTheme.bodyLarge),
                Text(
                  'Rp ${subtotal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            if (discount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Discount:',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.green),
                  ),
                  Text(
                    '-Rp ${discount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if (_shippingCost > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ongkos Kirim:',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    'Rp ${_shippingCost.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total:',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Rp ${total.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Tinggalkan Checkout?'),
              content: const Text(
                'Apakah Anda yakin ingin meninggalkan checkout? Semua perubahan yang belum disimpan akan hilang.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Leave'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _handleBackPress(BuildContext context) async {
    final shouldPop = await _showExitConfirmationDialog(context);
    if (shouldPop) {
      context.go('/cart');
    }
  }

  Future<void> _placeOrder(
    BuildContext context,
    CartProvider cartProvider,
    OrdersProvider ordersProvider,
  ) async {
    // Check authentication first
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masuk untuk melakukan pemesanan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon isi semua field yang diperlukan dengan benar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Additional validation for dropship
    if (_isDropship) {
      if (_senderNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mohon masukkan nama pengirim'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_senderPhoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mohon masukkan nomor telepon pengirim'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      print('CheckoutScreen: Placing order...');
      print('CheckoutScreen: Cart items: ${cartProvider.items.length}');
      print('CheckoutScreen: Total amount: ${cartProvider.total}');
      print(
        'CheckoutScreen: User authenticated: ${authProvider.isAuthenticated}',
      );

      // Validate stock availability for all cart items
      final outOfStockItems = <String>[];
      for (final cartItem in cartProvider.items) {
        try {
          final productResponse = await Supabase.instance.client
              .from('kl_products')
              .select('stock_quantity, name')
              .eq('id', cartItem.productId)
              .single();

          final stockQuantity = productResponse['stock_quantity'] ?? 0;
          if (stockQuantity < cartItem.quantity) {
            outOfStockItems.add(productResponse['name'] ?? cartItem.name);
          }
        } catch (e) {
          print('Error checking stock for product ${cartItem.productId}: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error checking stock for ${cartItem.name}. Please try again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // If any items are out of stock, show error and prevent order creation
      if (outOfStockItems.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Produk ini tidak tersedia: ${outOfStockItems.join(', ')}. Silakan hapus dari keranjang belanja atau kurangi jumlahnya.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      final order = await ordersProvider.createOrder(
        cartItems: cartProvider.items,
        shippingAddress: _receiverAddressController.text.trim(),
        paymentMethod: _selectedPaymentMethod,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        receiverName: _receiverNameController.text.trim(),
        receiverPhone: _receiverPhoneController.text.trim(),
        courierInfo: _selectedShippingCost != null
            ? '${_selectedShippingCost!.name} ${_selectedShippingCost!.service}'
            : '',
        isDropship: _isDropship,
        senderName: _isDropship ? _senderNameController.text.trim() : null,
        senderPhone: _isDropship ? _senderPhoneController.text.trim() : null,
        additionalCosts: _shippingCost,
        originCity: _selectedOrigin?.cityName ?? '',
        destinationCity: _selectedDestination?.cityName ?? '',
      );

      if (order != null && mounted) {
        print(
          'CheckoutScreen: Order created successfully: ${order.orderNumber}',
        );

        // Clear cart
        await cartProvider.clearCart();

        // Show success message and navigate
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order berhasil dibuat dengan nomor order #${order.orderNumber}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        context.go('/home');
        // Show Pay Now option for payment
        // _showPaymentOptions(context, order);
      } else {
        print('CheckoutScreen: Order creation failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ordersProvider.error ??
                    'Gagal melakukan pemesanan. Silakan coba lagi.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('CheckoutScreen: Error placing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mencheckout order: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showPaymentOptions(BuildContext context, Order order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Order Placed Successfully!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order #${order.orderNumber}'),
              const SizedBox(height: 8),
              Text(
                'Total: Rp ${(order.totalAmount + (order.additionalCosts ?? 0)).toStringAsFixed(0)}',
              ),
              const SizedBox(height: 16),
              const Text('What would you like to do next?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                context.go('/home'); // Go to home
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Navigate to payment screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PaymentScreen(order: order),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Pay Now'),
            ),
          ],
        );
      },
    );
  }
}

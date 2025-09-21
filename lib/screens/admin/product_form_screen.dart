import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_products_provider.dart';
import '../../providers/admin_categories_provider.dart';
import '../../models/product.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({Key? key, this.product}) : super(key: key);

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String? _selectedCategory;
  bool _isActive = true;
  bool _isFeatured = false;
  bool _isBestSeller = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _loadProductData();
    }

    // Add listener to re-validate discount price when regular price changes
    _priceController.addListener(() {
      if (_discountPriceController.text.isNotEmpty) {
        _formKey.currentState?.validate();
      }
    });
  }

  void _loadProductData() {
    final product = widget.product!;
    _nameController.text = product.name;
    _descriptionController.text = product.description;
    _priceController.text = product.price.toString();
    _discountPriceController.text = product.discountPrice?.toString() ?? '';
    _stockController.text = product.stockQuantity.toString();
    _imageUrlController.text = product.imageUrl ?? '';
    _selectedCategory = product.category;
    _isActive = product.isActive;
    _isFeatured = product.isFeatured;
    _isBestSeller = product.isBestSeller;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _discountPriceController.dispose();
    _stockController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final product = Product(
        id: widget.product?.id ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        discountPrice: _discountPriceController.text.isNotEmpty
            ? double.parse(_discountPriceController.text)
            : null,
        imageUrl: _imageUrlController.text.trim().isNotEmpty
            ? _imageUrlController.text.trim()
            : null,
        category: _selectedCategory,
        stockQuantity: int.parse(_stockController.text),
        isActive: _isActive,
        isFeatured: _isFeatured,
        isBestSeller: _isBestSeller,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final provider = context.read<AdminProductsProvider>();
      bool success;

      if (widget.product == null) {
        success = await provider.createProduct(product);
      } else {
        success = await provider.updateProduct(product);
      }

      if (success && mounted) {
        context.go('/admin');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.product == null
                  ? 'Product created successfully'
                  : 'Product updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
          tooltip: 'Back',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information
              const Text(
                'Basic Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _nameController,
                labelText: 'Product Name',
                hintText: 'Enter product name',
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Product name is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              CustomTextField(
                controller: _descriptionController,
                labelText: 'Description',
                hintText: 'Enter product description',
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              // Category Selection
              Consumer<AdminCategoriesProvider>(
                builder: (context, categoriesProvider, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonFormField<String?>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: InputBorder.none,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Select Category'),
                        ),
                        ...categoriesProvider.categories.map((category) {
                          return DropdownMenuItem<String?>(
                            value: category.name,
                            child: Text(category.name),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Pricing
              const Text(
                'Pricing',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _priceController,
                      labelText: 'Price',
                      hintText: '0',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Price is required';
                        }
                        final price = double.tryParse(value!);
                        if (price == null || price <= 0) {
                          return 'Price must be greater than 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: _discountPriceController,
                      labelText: 'Discount Price (Optional)',
                      hintText: '0',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isNotEmpty ?? false) {
                          final discountPrice = double.tryParse(value!);
                          if (discountPrice == null || discountPrice < 0) {
                            return 'Discount price must be a positive number';
                          }

                          final regularPrice = double.tryParse(_priceController.text);
                          if (regularPrice != null && discountPrice > regularPrice) {
                            return 'Discount price cannot be higher than regular price';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Stock
              const Text(
                'Stock & Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _stockController,
                labelText: 'Stock Quantity',
                hintText: '0',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Stock quantity is required';
                  }
                  final stock = int.tryParse(value!);
                  if (stock == null || stock < 0) {
                    return 'Invalid stock quantity';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              CustomTextField(
                controller: _imageUrlController,
                labelText: 'Image URL (Optional)',
                hintText: 'https://example.com/image.jpg',
              ),

              const SizedBox(height: 16),

              // Status Switches
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text('Product is available for purchase'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),

              SwitchListTile(
                title: const Text('Featured'),
                subtitle: const Text('Show in featured products'),
                value: _isFeatured,
                onChanged: (value) {
                  setState(() {
                    _isFeatured = value;
                  });
                },
              ),

              SwitchListTile(
                title: const Text('Best Seller'),
                subtitle: const Text('Mark as best seller product'),
                value: _isBestSeller,
                onChanged: (value) {
                  setState(() {
                    _isBestSeller = value;
                  });
                },
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: _isLoading
                      ? 'Saving...'
                      : (widget.product == null ? 'Create Product' : 'Update Product'),
                  onPressed: _isLoading ? null : _saveProduct,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
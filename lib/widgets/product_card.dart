import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/theme_provider.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final bool showAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.showAddToCart = true,
  });

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isInCart = cartProvider.isInCart(product.id);
    final cartItem = cartProvider.getCartItem(product.id);

    return Card(
      elevation: 2,
      shadowColor: themeProvider.currentTheme.shadowColor?.withValues(
        alpha: 0.1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 300, // Increased height to accommodate content
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: product.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Theme.of(context).cardColor,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Theme.of(context).cardColor,
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                  size: 24,
                                ),
                              ),
                            )
                          : Container(
                              color: Theme.of(context).cardColor,
                              child: Icon(
                                Icons.inventory_2,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                                size: 24,
                              ),
                            ),
                    ),
                  ),

                  // Badges
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: [
                        if (product.isBestSeller)
                          _buildBadge('Best', Colors.orange),
                        if (product.isFeatured) _buildBadge('New', Colors.blue),
                        if (product.hasDiscount)
                          _buildBadge(
                            '${product.discountPercentage?.toInt() ?? ((product.price - product.discountPrice!) / product.price * 100).round()}%',
                            Colors.red,
                          ),
                      ],
                    ),
                  ),

                  // Stock status
                  if (product.stockQuantity <= 5)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: product.stockQuantity == 0
                              ? Colors.red
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.stockQuantity == 0 ? 'Out' : 'Low',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Product Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      if (product.category != null)
                        Text(
                          product.category!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                      const SizedBox(height: 2),

                      // Product Name
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // Price
                      Row(
                        children: [
                          Text(
                            'Rp ${product.currentPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),

                          if (product.hasDiscount) ...[
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Rp ${product.price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Add to Cart Button
                      if (showAddToCart)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: product.stockQuantity == 0
                                ? null
                                : () async {
                                    if (isInCart) {
                                      // Show quantity selector
                                      _showQuantityDialog(
                                        context,
                                        product,
                                        cartProvider,
                                      );
                                    } else {
                                      await cartProvider.addItem(
                                        productId: product.id,
                                        name: product.name,
                                        imageUrl: product.imageUrl ?? '',
                                        price: product.price,
                                        discountPrice: product.discountPrice,
                                      );

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${product.name} added to cart',
                                            ),
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                            action: SnackBarAction(
                                              label: 'View Cart',
                                              onPressed: () {
                                                // Navigate to cart screen
                                                GoRouter.of(
                                                  context,
                                                ).push('/cart');
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isInCart
                                  ? Theme.of(context).colorScheme.secondary
                                  : Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              minimumSize: const Size(double.infinity, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: Text(
                              isInCart
                                  ? 'In Cart (${cartItem?.quantity ?? 0})'
                                  : 'Add to Cart',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showQuantityDialog(
    BuildContext context,
    Product product,
    CartProvider cartProvider,
  ) {
    final cartItem = cartProvider.getCartItem(product.id);
    int quantity = cartItem?.quantity ?? 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(product.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: quantity > 1
                        ? () => setState(() => quantity--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      quantity.toString(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: quantity < product.stockQuantity
                        ? () => setState(() => quantity++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Total: Rp ${(product.currentPrice * quantity).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await cartProvider.updateQuantity(product.id, quantity);
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cart updated: ${product.name} x$quantity'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Update Cart'),
            ),
          ],
        ),
      ),
    );
  }
}

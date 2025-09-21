import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/products_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/search_filter_widget.dart';
import 'product_detail_screen.dart';

class ProductByCategoryScreen extends StatefulWidget {
  final String category;

  const ProductByCategoryScreen({super.key, required this.category});

  @override
  State<ProductByCategoryScreen> createState() => _ProductByCategoryScreenState();
}

class _ProductByCategoryScreenState extends State<ProductByCategoryScreen> {
  late ProductsProvider _productsProvider;

  @override
  void initState() {
    super.initState();
    // Get provider reference
    _productsProvider = Provider.of<ProductsProvider>(context, listen: false);
    // Set the selected category in the provider when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _productsProvider.setSelectedCategory(widget.category);
    });
  }

  @override
  void dispose() {
    // Clear category filter when leaving screen
    _productsProvider.setSelectedCategory(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsProvider = Provider.of<ProductsProvider>(context);
    final categoryProducts = productsProvider.products;

    return Scaffold(
      appBar: AppBar(
        title: Text('Products in ${widget.category}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await productsProvider.refreshProducts();
        },
        child: CustomScrollView(
          slivers: [
            // Search and Filter Widget
            const SliverToBoxAdapter(
              child: SearchFilterWidget(),
            ),

            // Products Grid
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.65,
                  mainAxisExtent: 320,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= categoryProducts.length) {
                      return null;
                    }

                    final product = categoryProducts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ProductCard(
                        product: product,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ProductDetailScreen(product: product),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: categoryProducts.length,
                ),
              ),
            ),

            // Loading indicator or empty state
            if (productsProvider.isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (categoryProducts.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products found in ${widget.category}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filters',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
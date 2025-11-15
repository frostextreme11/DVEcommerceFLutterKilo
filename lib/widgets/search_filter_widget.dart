import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/products_provider.dart';

class SearchFilterWidget extends StatefulWidget {
  const SearchFilterWidget({super.key});

  @override
  State<SearchFilterWidget> createState() => _SearchFilterWidgetState();
}

class _SearchFilterWidgetState extends State<SearchFilterWidget> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsProvider = Provider.of<ProductsProvider>(context);

    return Column(
      children: [
        // Search Bar
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              // Cancel previous timer
              _debounceTimer?.cancel();

              // Create new timer for 1 second delay
              _debounceTimer = Timer(const Duration(seconds: 1), () {
                // Only execute search after 1 second of no typing
                productsProvider.setSearchQuery(value);
              });
            },
            decoration: InputDecoration(
              hintText: 'Cari Produk...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        productsProvider.setSearchQuery('');
                        // Cancel debounce timer when clearing
                        _debounceTimer?.cancel();
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      _showFilters ? Icons.filter_list_off : Icons.filter_list,
                    ),
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                  ),
                ],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),

        // Filters Panel
        if (_showFilters)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sort Options
                Text(
                  'Urutkan Berdasarkan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: SortOption.values.map((option) {
                    final isSelected = productsProvider.sortOption == option;
                    return FilterChip(
                      label: Text(_getSortOptionLabel(option)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          productsProvider.setSortOption(option);
                        }
                      },
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Category Filter
                Text(
                  'Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: productsProvider.selectedCategory == null,
                      onSelected: (selected) {
                        if (selected) {
                          productsProvider.setSelectedCategory(null);
                        }
                      },
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                    ),
                    ...productsProvider.categories.map((category) {
                      final isSelected =
                          productsProvider.selectedCategory == category;
                      return FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          productsProvider.setSelectedCategory(
                            selected ? category : null,
                          );
                        },
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 16),

                // Price Range
                Text(
                  'Rentang Harga',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                RangeSlider(
                  values: productsProvider.priceRange,
                  min: 0,
                  max: 1000000,
                  divisions: 100,
                  labels: RangeLabels(
                    'Rp ${productsProvider.priceRange.start.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                    'Rp ${productsProvider.priceRange.end.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                  ),
                  onChanged: (values) {
                    productsProvider.setPriceRange(values);
                  },
                  activeColor: Theme.of(context).colorScheme.primary,
                ),

                const SizedBox(height: 16),

                // Clear Filters Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      productsProvider.clearFilters();
                      _searchController.clear();
                      // Cancel debounce timer when clearing all filters
                      _debounceTimer?.cancel();
                      setState(() {
                        _showFilters = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Clear All Filters'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _getSortOptionLabel(SortOption option) {
    switch (option) {
      case SortOption.newest:
        return 'Terbaru';
      case SortOption.priceLowToHigh:
        return 'Harga: Terendah ke Tertinggi';
      case SortOption.priceHighToLow:
        return 'Harga: Tertinggi ke Terendah';
      case SortOption.nameAZ:
        return 'Nama: A ke Z';
      case SortOption.nameZA:
        return 'Nama: Z ke A';
      case SortOption.popularity:
        return 'Popularitas';
    }
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final double? discountPrice;
  final double? discountPercentage;
  final String? imageUrl;
  final String? category;
  final int stockQuantity;
  final bool isActive;
  final bool isFeatured;
  final bool isBestSeller;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.discountPrice,
    this.discountPercentage,
    this.imageUrl,
    this.category,
    required this.stockQuantity,
    required this.isActive,
    required this.isFeatured,
    required this.isBestSeller,
    required this.createdAt,
    required this.updatedAt,
  });

  double get currentPrice => discountPrice ?? price;
  bool get hasDiscount => discountPrice != null && discountPrice! < price;
  double get discountAmount => hasDiscount ? price - discountPrice! : 0;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      price: (json['price'] as num).toDouble(),
      discountPrice: json['discount_price'] != null ? (json['discount_price'] as num).toDouble() : null,
      discountPercentage: json['discount_percentage'] != null ? (json['discount_percentage'] as num).toDouble() : null,
      imageUrl: json['image_url'],
      category: json['category'],
      stockQuantity: json['stock_quantity'] ?? 0,
      isActive: json['is_active'] ?? true,
      isFeatured: json['is_featured'] ?? false,
      isBestSeller: json['is_best_seller'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'discount_price': discountPrice,
      'discount_percentage': discountPercentage,
      'image_url': imageUrl,
      'category': category,
      'stock_quantity': stockQuantity,
      'is_active': isActive,
      'is_featured': isFeatured,
      'is_best_seller': isBestSeller,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    double? discountPrice,
    double? discountPercentage,
    String? imageUrl,
    String? category,
    int? stockQuantity,
    bool? isActive,
    bool? isFeatured,
    bool? isBestSeller,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      discountPrice: discountPrice ?? this.discountPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      isBestSeller: isBestSeller ?? this.isBestSeller,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
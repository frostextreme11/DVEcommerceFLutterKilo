class ProductStockLog {
  final String id;
  final String productId;
  final String productName;
  final DateTime dateCreated;
  final int? lastValue;
  final int newValue;
  final String editedByEmail;
  final String editedByUsername;

  ProductStockLog({
    required this.id,
    required this.productId,
    required this.productName,
    required this.dateCreated,
    this.lastValue,
    required this.newValue,
    required this.editedByEmail,
    required this.editedByUsername,
  });

  factory ProductStockLog.fromJson(Map<String, dynamic> json) {
    return ProductStockLog(
      id: json['id'],
      productId: json['product_id'],
      productName: json['product_name'] ?? '',
      dateCreated: DateTime.parse(json['date_created']),
      lastValue: json['last_value'] as int?,
      newValue: json['new_value'],
      editedByEmail: json['edited_by_email'],
      editedByUsername: json['edited_by_username'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'date_created': dateCreated.toIso8601String(),
      'last_value': lastValue,
      'new_value': newValue,
      'edited_by_email': editedByEmail,
      'edited_by_username': editedByUsername,
    };
  }
}

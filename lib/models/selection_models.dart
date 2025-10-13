// lib/models/selection_models.dart

class SelectableItem {
  final String id;
  final String name;
  final String? subtitle;
  final Map<String, dynamic>? data; // ✅ ADDED: To store extra data like addresses

  SelectableItem({
    required this.id,
    required this.name,
    this.subtitle,
    this.data, // ✅ ADDED
  });

  @override
  bool operator ==(Object other) => other is SelectableItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class ProductSelection {
  final String productId;
  final String productName;
  final int quantity;

  ProductSelection({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  // ✅ ADDED: toJson method for Firestore compatibility
  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
    };
  }
}
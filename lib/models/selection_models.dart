// lib/models/selection_models.dart

class SelectableItem {
  final String id;
  final String name;
  final String? subtitle;
  final Map<String, dynamic>? data;

  SelectableItem({
    required this.id,
    required this.name,
    this.subtitle,
    this.data,
  });

  @override
  bool operator ==(Object other) => other is SelectableItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class ProductSelection {
  final String productId;
  final String productName;
  // ✅ 1. ADDED the 'marque' field
  final String marque;
  // ✅ 2. REMOVED 'final' so the quantity can be changed
  int quantity;

  ProductSelection({
    required this.productId,
    required this.productName,
    // ✅ 3. ADDED 'marque' to the constructor
    required this.marque,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      // ✅ 4. ADDED 'marque' to the JSON output
      'marque': marque,
      'quantity': quantity,
    };
  }
}
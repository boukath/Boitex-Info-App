// lib/models/selection_models.dart

class SelectableItem {
  final String id;
  final String name;
  final String? subtitle;
  SelectableItem({required this.id, required this.name, this.subtitle});

  @override
  bool operator ==(Object other) => other is SelectableItem && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class ProductSelection {
  final String productId;
  final String productName;
  final int quantity;
  ProductSelection({required this.productId, required this.productName, required this.quantity});
}
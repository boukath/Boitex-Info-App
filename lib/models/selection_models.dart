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
  final String marque;
  // ✅ ADDED: A field to hold the part number (reference).
  final String partNumber;
  int quantity;
  List<String> serialNumbers;

  ProductSelection({
    required this.productId,
    required this.productName,
    required this.marque,
    // ✅ ADDED: partNumber is now required.
    required this.partNumber,
    required this.quantity,
    List<String>? serialNumbers,
  }) : serialNumbers = serialNumbers ?? [];

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'marque': marque,
      // ✅ ADDED: Include partNumber when saving to Firestore.
      'partNumber': partNumber,
      'quantity': quantity,
      'serialNumbers': serialNumbers,
    };
  }
}
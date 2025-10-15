// lib/models/selection_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Universal model for items in dropdowns and lists.
class SelectableItem {
  final String id;
  final String name;
  final String? subtitle;
  final String? partNumber; // Added for products
  final Map<String, dynamic>? data;

  SelectableItem({
    required this.id,
    required this.name,
    this.subtitle,
    this.partNumber, // Now an optional parameter
    this.data,
  });

  // Factory to create an item from a Firestore product document
  factory SelectableItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SelectableItem(
      id: doc.id,
      name: data['productName'] ?? 'Nom inconnu',
      partNumber: data['partNumber'] ?? 'Référence inconnue',
      data: data, // Store the full document data if needed elsewhere
    );
  }

  @override
  bool operator ==(Object other) => other is SelectableItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Model for a product that has been selected for a delivery or project.
class ProductSelection {
  final String productId;
  final String productName;
  final String partNumber;
  final String marque;
  int quantity;
  List<String> serialNumbers;

  ProductSelection({
    required this.productId,
    required this.productName,
    required this.partNumber,
    required this.marque,
    required this.quantity,
    List<String>? serialNumbers,
  }) : serialNumbers = serialNumbers ?? [];

  // Creates a deep copy of the object
  ProductSelection copy() {
    return ProductSelection(
      productId: productId,
      productName: productName,
      partNumber: partNumber,
      marque: marque,
      quantity: quantity,
      serialNumbers: List.from(serialNumbers),
    );
  }

  // Converts the object to a Map for saving to Firestore
  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'partNumber': partNumber,
      'marque': marque,
      'quantity': quantity,
      'serialNumbers': serialNumbers,
    };
  }
}
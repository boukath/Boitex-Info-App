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
      name: data['nom'] ?? 'Nom inconnu',
      partNumber: data['reference'] ?? 'Référence inconnue',  // ✅ FIXED: Changed from 'partNumber' to 'reference'
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

  // ✅ ADDED: Fields to preserve logistics progress
  int pickedQuantity;
  String status; // e.g., 'pending', 'picked'

  ProductSelection({
    required this.productId,
    required this.productName,
    required this.partNumber,
    required this.marque,
    required this.quantity,
    List<String>? serialNumbers,
    this.pickedQuantity = 0, // Default to 0
    this.status = 'pending', // Default to pending
  }) : serialNumbers = serialNumbers ?? [];

  // Creates a deep copy of the object
  ProductSelection copy() {
    return ProductSelection(
      productId: productId,
      productName: productName,
      partNumber: partNumber,
      marque: marque,
      quantity: quantity,
      serialNumbers: List<String>.from(serialNumbers),
      pickedQuantity: pickedQuantity, // ✅ Copy this
      status: status, // ✅ Copy this
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
      // ✅ Save these back so we don't wipe progress
      'pickedQuantity': pickedQuantity,
      'status': status,
    };
  }

  // ✅ Factory to create an instance from a Firestore map
  factory ProductSelection.fromJson(Map<String, dynamic> json) {
    return ProductSelection(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? 'N/A',
      partNumber: json['partNumber'] ?? 'N/A',
      marque: json['marque'] ?? 'N/A',
      quantity: json['quantity'] ?? 0,
      // Ensure serialNumbers is always a List<String>
      serialNumbers: List<String>.from(json['serialNumbers'] ?? []),
      // ✅ Load existing progress (default to 0 if missing)
      pickedQuantity: json['pickedQuantity'] ?? 0,
      status: json['status'] ?? 'pending',
    );
  }
}
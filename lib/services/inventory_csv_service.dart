// lib/services/inventory_csv_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryCsvService {
  /// Generates a CSV string from the product list.
  /// Uses a semicolon (;) as a separator for better compatibility
  /// with French/European versions of Excel.
  static String generateInventoryCsv(List<DocumentSnapshot> products) {
    final buffer = StringBuffer();

    // 1. Add Header Row
    buffer.writeln('Référence;Nom;Quantité en Stock;Catégorie;Sous-Catégorie');

    // 2. Add Data Rows
    for (final doc in products) {
      final data = doc.data() as Map<String, dynamic>;

      // Helper to clean data for CSV (removes internal quotes)
      String clean(dynamic data) {
        return data.toString().replaceAll('"', "'");
      }

      final ref = clean(data['reference'] ?? 'N/A');
      final name = clean(data['nom'] ?? 'Nom inconnu');
      final stock = (data['quantiteEnStock'] ?? 0).toString();
      final mainCategory = clean(data['mainCategory'] ?? 'N/A');
      final subCategory = clean(data['categorie'] ?? 'N/A');

      // Enclose in quotes to handle any stray semicolons
      buffer.writeln('"$ref";"$name";$stock;"$mainCategory";"$subCategory"');
    }

    return buffer.toString();
  }
}
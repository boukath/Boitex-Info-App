// lib/services/stock_audit_csv_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

class StockAuditCsvService {
  /// Generates a CSV string from the list of stock movements.
  Future<String> generateAuditCsv(
      List<QueryDocumentSnapshot> movements,
      Map<String, String> userNamesMap, // ✅ --- ADDED: Pass the map ---
      ) async {
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm:ss');

    final List<String> header = [
      'Date',
      'Produit',
      'Référence',
      'Changement',
      'Quantité Avant',
      'Quantité Après',
      'Utilisateur',
      'Notes'
    ];

    final List<List<dynamic>> rows = [header];

    for (final doc in movements) {
      final movementData = doc.data() as Map<String, dynamic>;
      final Timestamp? ts = movementData['timestamp'];
      final String formattedDate =
      ts != null ? dateFormatter.format(ts.toDate()) : 'N/A';

      final List<dynamic> row = [
        formattedDate,
        movementData['productName'] ?? 'N/A',
        movementData['productRef'] ?? 'N/A',
        movementData['quantityChange'] ?? 0,
        movementData['oldQuantity'] ?? 0,
        movementData['newQuantity'] ?? 0,
        // ✅ --- UPDATED: Use the map ---
        userNamesMap[movementData['userId']] ?? 'Inconnu',
        // ✅ --- END UPDATED ---
        movementData['notes'] ?? '',
      ];
      rows.add(row);
    }

    String csv = const ListToCsvConverter().convert(rows);
    return csv;
  }
}
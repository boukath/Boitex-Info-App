// lib/services/stock_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Handles the logic for a Client Return (Triage System)
  /// Returns [true] if the operation was successful.
  Future<void> processClientReturn({
    required String productId,
    required String productName,
    required String productReference,
    required int quantityReturned,
    required bool isResellable, // ✅ The Triage Decision
    required String reason,     // e.g., "Change of mind", "Broken"
    String? clientId,           // Optional: Link to a client
    String? clientName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final String userName = user?.displayName ?? "Technicien";
    final String userId = user?.uid ?? "unknown";

    await _db.runTransaction((transaction) async {
      // 1. Reference to the product
      final productRef = _db.collection('produits').doc(productId);

      // 2. Reference to the history log
      final movementRef = _db.collection('stock_movements').doc();

      // 3. LOGIC FORK:
      if (isResellable) {
        // ✅ CASE A: RESELLABLE (Back to Stock)
        // We read the product first to ensure safety
        final snapshot = await transaction.get(productRef);
        if (!snapshot.exists) throw Exception("Produit introuvable!");

        final int currentStock = snapshot.data()?['quantiteEnStock'] ?? 0;
        final int newStock = currentStock + quantityReturned;

        // Update Stock
        transaction.update(productRef, {
          'quantiteEnStock': newStock,
          'lastModifiedBy': userName,
          'lastModifiedAt': FieldValue.serverTimestamp(),
        });

        // Log Movement (Type: RETURN_OK)
        transaction.set(movementRef, {
          'productId': productId,
          'productName': productName,
          'productRef': productReference,
          'quantityChange': quantityReturned, // Positive because it enters stock
          'oldQuantity': currentStock,
          'newQuantity': newStock,
          'type': 'CLIENT_RETURN_OK',
          'condition': 'Resellable', // ✨ Metadata
          'reason': reason,
          'clientId': clientId,
          'clientName': clientName,
          'user': userName,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });

      } else {
        // ⚠️ CASE B: DEFECTIVE (Quarantine / SAV)
        // We do NOT update 'quantiteEnStock' because it's broken.

        // Log Movement (Type: RETURN_DEFECTIVE)
        // quantityChange is 0 regarding "Sellable Stock", but we record the event.
        transaction.set(movementRef, {
          'productId': productId,
          'productName': productName,
          'productRef': productReference,
          'quantityChange': 0, // Stock didn't change
          'affectedQuantity': quantityReturned, // But 1 item came back
          'type': 'CLIENT_RETURN_DEFECTIVE',
          'condition': 'Defective', // ✨ Metadata
          'reason': reason,
          'clientId': clientId,
          'clientName': clientName,
          'user': userName,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
          'notes': 'Article défectueux - Ne pas remettre en rayon',
        });
      }
    });
  }
}
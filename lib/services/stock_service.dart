// lib/services/stock_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Handles the logic for a Client Return (Triage System)
  Future<void> processClientReturn({
    required String productId,
    required String productName,
    required String productReference,
    required int quantityReturned,
    required bool isResellable,
    required String reason,
    String? clientId,
    String? clientName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final String userName = user?.displayName ?? "Technicien";
    final String userId = user?.uid ?? "unknown";

    await _db.runTransaction((transaction) async {
      final productRef = _db.collection('produits').doc(productId);
      final movementRef = _db.collection('stock_movements').doc();

      if (isResellable) {
        // CASE A: RESELLABLE (Back to Stock)
        final snapshot = await transaction.get(productRef);
        if (!snapshot.exists) throw Exception("Produit introuvable!");

        final int currentStock = snapshot.data()?['quantiteEnStock'] ?? 0;
        final int newStock = currentStock + quantityReturned;

        transaction.update(productRef, {
          'quantiteEnStock': newStock,
          'lastModifiedBy': userName,
          'lastModifiedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(movementRef, {
          'productId': productId,
          'productName': productName,
          'productRef': productReference,
          'quantityChange': quantityReturned,
          'oldQuantity': currentStock,
          'newQuantity': newStock,
          'type': 'CLIENT_RETURN_OK',
          'condition': 'Resellable',
          'reason': reason,
          'clientId': clientId,
          'clientName': clientName,
          'user': userName,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });

      } else {
        // CASE B: DEFECTIVE RETURN
        final snapshot = await transaction.get(productRef);
        if (!snapshot.exists) throw Exception("Produit introuvable!");

        final int currentBrokenStock = snapshot.data()?['quantiteDefectueuse'] ?? 0;
        final int newBrokenStock = currentBrokenStock + quantityReturned;

        transaction.update(productRef, {
          'quantiteDefectueuse': newBrokenStock,
          'lastModifiedBy': userName,
          'lastModifiedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(movementRef, {
          'productId': productId,
          'productName': productName,
          'productRef': productReference,
          'quantityChange': 0,
          'brokenStockChange': quantityReturned,
          'type': 'CLIENT_RETURN_BROKEN',
          'condition': 'Defective',
          'reason': reason,
          'clientId': clientId,
          'clientName': clientName,
          'user': userName,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
          'notes': 'Retour client (Non Vendable) -> Stock Défectueux',
        });
      }
    });
  }

  // ✅ NEW FUNCTION: Internal Breakage Report
  // Moves stock from "Good" -> "Defective" and saves the B2 Photo URL
  Future<void> reportInternalBreakage({
    required String productId,
    required String productName,
    required String productReference,
    required int quantityBroken,
    required String reason, // The description of how it broke
    required String? photoUrl, // 📸 The B2 Image Link
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final String userName = user?.displayName ?? "Technicien";
    final String userId = user?.uid ?? "unknown";

    await _db.runTransaction((transaction) async {
      final productRef = _db.collection('produits').doc(productId);
      final movementRef = _db.collection('stock_movements').doc();

      // 1. Read Product State
      final snapshot = await transaction.get(productRef);
      if (!snapshot.exists) throw Exception("Produit introuvable !");

      final int currentStock = snapshot.data()?['quantiteEnStock'] ?? 0;
      final int currentBroken = snapshot.data()?['quantiteDefectueuse'] ?? 0;

      // 2. Validate Inventory
      if (currentStock < quantityBroken) {
        throw Exception("Stock insuffisant ! (Dispo: $currentStock, Demandé: $quantityBroken)");
      }

      // 3. Calculate New Values
      final int newStock = currentStock - quantityBroken; // Decrease Good
      final int newBroken = currentBroken + quantityBroken; // Increase Bad

      // 4. Update Product
      transaction.update(productRef, {
        'quantiteEnStock': newStock,
        'quantiteDefectueuse': newBroken,
        'lastModifiedBy': userName,
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      // 5. Log Movement
      transaction.set(movementRef, {
        'productId': productId,
        'productName': productName,
        'productRef': productReference,
        'quantityChange': -quantityBroken, // Negative because it left sellable stock
        'brokenStockChange': quantityBroken, // Positive because it entered broken stock
        'oldQuantity': currentStock,
        'newQuantity': newStock,
        'type': 'INTERNAL_BREAKAGE', // ⚠️ Specific Type
        'condition': 'Damaged',
        'reason': reason,
        'photoUrl': photoUrl, // 📸 Save the B2 Link here
        'user': userName,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'notes': 'Casse interne déclarée',
      });
    });
  }

  // ✅ EDIT: Manually adjust the broken quantity
  Future<void> updateBrokenQuantity({
    required String productId,
    required int newQuantity,
    required String reason,
    required String userName,
  }) async {
    final productRef = _db.collection('produits').doc(productId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(productRef);
      if (!snapshot.exists) throw Exception("Produit introuvable");

      final int currentBroken = snapshot.data()?['quantiteDefectueuse'] ?? 0;
      final int diff = newQuantity - currentBroken;

      if (diff == 0) return; // No change

      transaction.update(productRef, {
        'quantiteDefectueuse': newQuantity,
        'lastModifiedBy': userName,
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      // Log the correction
      final movementRef = _db.collection('stock_movements').doc();
      transaction.set(movementRef, {
        'productId': productId,
        'quantityChange': 0,
        'brokenStockChange': diff,
        'type': 'BROKEN_STOCK_CORRECTION',
        'reason': reason,
        'user': userName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  // ✅ DELETE: Resolve the broken item (Restock or Destroy)
  Future<void> resolveBrokenItem({
    required String productId,
    required int quantityToRemove, // Usually the total broken count
    required bool restoreToHealthyStock, // TRUE = Fix/Mistake, FALSE = Trash
    required String userName,
  }) async {
    final productRef = _db.collection('produits').doc(productId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(productRef);
      if (!snapshot.exists) throw Exception("Produit introuvable");

      final int currentStock = snapshot.data()?['quantiteEnStock'] ?? 0;
      final int currentBroken = snapshot.data()?['quantiteDefectueuse'] ?? 0;

      // Calculate new values
      final int newBroken = currentBroken - quantityToRemove;
      // If restoring, we add back to healthy stock. If destroying, healthy stock stays same.
      final int newStock = restoreToHealthyStock
          ? currentStock + quantityToRemove
          : currentStock;

      if (newBroken < 0) throw Exception("Impossible de retirer plus que le stock actuel");

      transaction.update(productRef, {
        'quantiteEnStock': newStock,
        'quantiteDefectueuse': newBroken,
        'lastModifiedBy': userName,
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      // Log the resolution
      final movementRef = _db.collection('stock_movements').doc();
      transaction.set(movementRef, {
        'productId': productId,
        'quantityChange': restoreToHealthyStock ? quantityToRemove : 0,
        'brokenStockChange': -quantityToRemove,
        'type': restoreToHealthyStock ? 'BROKEN_RESTORED' : 'BROKEN_DESTROYED',
        'reason': restoreToHealthyStock ? 'Remise en stock (Réparé/Erreur)' : 'Mise au rebut (Destruction)',
        'user': userName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }
}
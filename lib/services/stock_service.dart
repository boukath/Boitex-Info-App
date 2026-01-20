// lib/services/stock_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ✅ IMPORT YOUR NEW MODEL
import 'package:boitex_info_app/models/quarantine_item.dart';

class StockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===========================================================================
  // 👤 HELPER: GET REAL USER NAME FROM FIRESTORE
  // ===========================================================================
  Future<String> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "Inconnu";

    // 1. Default to Auth display name or "Technicien"
    String finalName = user.displayName ?? "Technicien";

    try {
      // 2. Try to fetch from 'users' collection for accurate name
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        // Check 'displayName' first, then 'fullName' as requested
        if (data['displayName'] != null && data['displayName'].toString().isNotEmpty) {
          finalName = data['displayName'];
        } else if (data['fullName'] != null && data['fullName'].toString().isNotEmpty) {
          finalName = data['fullName'];
        }
      }
    } catch (e) {
      print("⚠️ Error fetching user name from Firestore: $e");
    }
    return finalName;
  }

  // ===========================================================================
  // 1. CONFIRM DELIVERY (NEW LOGIC: EXIT STOCK AT END)
  // ===========================================================================

  // ✅ NEW: Called when status becomes "Livré"
  // Only deducts what the client actually ACCEPTED.
  Future<void> confirmDeliveryStockOut({
    required String deliveryId,
    required List<Map<String, dynamic>> products,
  }) async {
    final String userName = await _fetchUserName();

    await _db.runTransaction((transaction) async {
      for (var item in products) {
        // We only care about items with a valid Product ID
        if (item['productId'] == null) continue;

        final String productId = item['productId'];
        final String productName = item['productName'] ?? 'Produit Inconnu';

        // Use the 'deliveredQuantity' (what client accepted) or fallback to 'quantity'
        final int qtyToDeduct = item['deliveredQuantity'] ?? item['quantity'] ?? 0;

        if (qtyToDeduct <= 0) continue; // Skip if 0 accepted

        final productRef = _db.collection('produits').doc(productId);

        // 1. Deduct from Physical Stock
        transaction.update(productRef, {
          'quantiteEnStock': FieldValue.increment(-qtyToDeduct),
          'lastModifiedBy': userName,
          'lastModifiedAt': FieldValue.serverTimestamp(),
        });

        // 2. Log the Sale Movement
        final movementRef = _db.collection('stock_movements').doc();
        transaction.set(movementRef, {
          'productId': productId,
          'productName': productName,
          'quantityChange': -qtyToDeduct,
          'type': 'LIVRAISON_CLIENT',
          'livraisonId': deliveryId,
          'notes': 'Sortie de stock confirmée (Livré)',
          'user': userName,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ===========================================================================
  // 2. CLIENT RETURN (EXISTING LOGIC)
  // ===========================================================================

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
    final String userId = user?.uid ?? "unknown";
    final String userName = await _fetchUserName();
    final DateTime now = DateTime.now();

    await _db.runTransaction((transaction) async {
      final productRef = _db.collection('produits').doc(productId);
      final movementRef = _db.collection('stock_movements').doc();

      if (isResellable) {
        // CASE A: RESELLABLE (Back to Healthy Stock)
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
        // CASE B: DEFECTIVE RETURN (Quarantine)
        final snapshot = await transaction.get(productRef);
        if (!snapshot.exists) throw Exception("Produit introuvable!");

        final int currentBrokenStock = snapshot.data()?['quantiteDefectueuse'] ?? 0;
        final int newBrokenStock = currentBrokenStock + quantityReturned;

        // 1. Update Product Counter
        transaction.update(productRef, {
          'quantiteDefectueuse': newBrokenStock,
          'lastModifiedBy': userName,
          'lastModifiedAt': FieldValue.serverTimestamp(),
        });

        // 2. CREATE QUARANTINE CASE FILE
        final quarantineRef = _db.collection('quarantine_items').doc();

        final newItem = QuarantineItem(
          id: quarantineRef.id,
          productId: productId,
          productName: productName,
          productReference: productReference,
          quantity: quantityReturned,
          reason: "Retour Client (${clientName ?? 'Inconnu'}) - $reason",
          photoUrl: null,
          reportedBy: userName,
          reportedByUid: userId,
          reportedAt: now,
          status: 'PENDING',
          history: [
            {
              'action': 'CLIENT_RETURN',
              'by': userName,
              'date': Timestamp.fromDate(now),
              'note': "Retour SAV Client: $reason"
            }
          ],
        );

        transaction.set(quarantineRef, newItem.toMap());

        // 3. Log Movement
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
          'quarantineId': quarantineRef.id,
        });
      }
    });
  }

  // ===========================================================================
  // 3. INTERNAL BREAKAGE (CASE MANAGEMENT)
  // ===========================================================================

  Future<void> reportInternalBreakage({
    required String productId,
    required String productName,
    required String productReference,
    required int quantityBroken,
    required String reason,
    required String? photoUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final String userId = user?.uid ?? "unknown";
    final DateTime now = DateTime.now();
    final String userName = await _fetchUserName();

    await _db.runTransaction((transaction) async {
      final productRef = _db.collection('produits').doc(productId);

      // A. Read Product State
      final snapshot = await transaction.get(productRef);
      if (!snapshot.exists) throw Exception("Produit introuvable !");

      final int currentStock = snapshot.data()?['quantiteEnStock'] ?? 0;
      final int currentBroken = snapshot.data()?['quantiteDefectueuse'] ?? 0;

      // B. Validate
      if (currentStock < quantityBroken) {
        throw Exception("Stock insuffisant ! (Dispo: $currentStock)");
      }

      // C. Update Main Inventory Counters
      final int newStock = currentStock - quantityBroken;
      final int newBroken = currentBroken + quantityBroken;

      transaction.update(productRef, {
        'quantiteEnStock': newStock,
        'quantiteDefectueuse': newBroken,
        'lastModifiedBy': userName,
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      // D. Create the "Quarantine Case"
      final quarantineRef = _db.collection('quarantine_items').doc();

      final newItem = QuarantineItem(
        id: quarantineRef.id,
        productId: productId,
        productName: productName,
        productReference: productReference,
        quantity: quantityBroken,
        reason: reason,
        photoUrl: photoUrl,
        reportedBy: userName,
        reportedByUid: userId,
        reportedAt: now,
        status: 'PENDING',
        history: [
          {
            'action': 'CREATED',
            'by': userName,
            'date': Timestamp.fromDate(now),
            'note': 'Déclaration initiale: $reason'
          }
        ],
      );

      transaction.set(quarantineRef, newItem.toMap());

      // E. Audit Log
      final movementRef = _db.collection('stock_movements').doc();
      transaction.set(movementRef, {
        'productId': productId,
        'productName': productName,
        'productRef': productReference,
        'quantityChange': -quantityBroken,
        'brokenStockChange': quantityBroken,
        'type': 'INTERNAL_BREAKAGE',
        'reason': reason,
        'quarantineId': quarantineRef.id,
        'user': userName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  // ===========================================================================
  // 4. MANAGEMENT (UPDATE STATUS)
  // ===========================================================================

  Future<void> updateQuarantineStatus({
    required String quarantineId,
    required String newStatus,
    required String note,
  }) async {
    final String userName = await _fetchUserName();
    final docRef = _db.collection('quarantine_items').doc(quarantineId);

    await docRef.update({
      'status': newStatus,
      'history': FieldValue.arrayUnion([
        {
          'action': 'STATUS_CHANGE',
          'newStatus': newStatus,
          'by': userName,
          'date': Timestamp.now(),
          'note': note
        }
      ])
    });
  }

  // ===========================================================================
  // 5. RESOLUTION & SALVAGE (FINALIZE)
  // ===========================================================================

  Future<void> resolveQuarantineItem({
    required QuarantineItem item,
    required String resolutionType, // 'RESTORE', 'DESTROY'
    required String note,
  }) async {
    final String userName = await _fetchUserName();

    await _db.runTransaction((transaction) async {
      final productRef = _db.collection('produits').doc(item.productId);
      final quarantineRef = _db.collection('quarantine_items').doc(item.id);

      final productSnap = await transaction.get(productRef);
      if (!productSnap.exists) throw Exception("Produit original introuvable");

      final int currentBroken = productSnap.data()?['quantiteDefectueuse'] ?? 0;
      final int currentStock = productSnap.data()?['quantiteEnStock'] ?? 0;

      if (resolutionType == 'RESTORE') {
        transaction.update(productRef, {
          'quantiteDefectueuse': currentBroken - item.quantity,
          'quantiteEnStock': currentStock + item.quantity,
        });
      } else {
        transaction.update(productRef, {
          'quantiteDefectueuse': currentBroken - item.quantity,
        });
      }

      transaction.update(quarantineRef, {
        'status': 'RESOLVED',
        'resolutionType': resolutionType,
        'history': FieldValue.arrayUnion([
          {
            'action': 'RESOLVED',
            'type': resolutionType,
            'by': userName,
            'date': Timestamp.now(),
            'note': note
          }
        ])
      });

      final movementRef = _db.collection('stock_movements').doc();
      transaction.set(movementRef, {
        'productId': item.productId,
        'productName': item.productName,
        'brokenStockChange': -item.quantity,
        'quantityChange': resolutionType == 'RESTORE' ? item.quantity : 0,
        'type': 'QUARANTINE_RESOLVED',
        'resolution': resolutionType,
        'quarantineId': item.id,
        'user': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'note': note,
      });
    });
  }

  // ✅ SALVAGE PROCESS
  Future<void> processSalvage({
    required QuarantineItem item,
    required List<Map<String, dynamic>> recoveredParts,
    required String note,
  }) async {
    final String userName = await _fetchUserName();

    await _db.runTransaction((transaction) async {
      final mainProductRef = _db.collection('produits').doc(item.productId);
      final quarantineRef = _db.collection('quarantine_items').doc(item.id);

      final mainSnap = await transaction.get(mainProductRef);
      if (!mainSnap.exists) throw Exception("Produit original introuvable");

      final int currentBroken = mainSnap.data()?['quantiteDefectueuse'] ?? 0;
      if (currentBroken < item.quantity) throw Exception("Erreur stock (Déjà traité ?)");

      for (var part in recoveredParts) {
        final partRef = _db.collection('produits').doc(part['productId']);
        final partSnap = await transaction.get(partRef);
        if (!partSnap.exists) throw Exception("Pièce détachée introuvable: ${part['productName']}");
      }

      // WRITES
      transaction.update(mainProductRef, {
        'quantiteDefectueuse': currentBroken - item.quantity,
      });

      for (var part in recoveredParts) {
        final partRef = _db.collection('produits').doc(part['productId']);
        transaction.update(partRef, {
          'quantiteMaintenance': FieldValue.increment(part['quantity']),
        });

        final partLogRef = _db.collection('stock_movements').doc();
        transaction.set(partLogRef, {
          'productId': part['productId'],
          'productName': part['productName'],
          'quantityChange': 0,
          'maintenanceStockChange': part['quantity'],
          'type': 'SALVAGE_RECOVERY',
          'sourceItemId': item.productId,
          'sourceItemName': item.productName,
          'user': userName,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      transaction.update(quarantineRef, {
        'status': 'RESOLVED',
        'resolutionType': 'SALVAGE',
        'salvagedParts': recoveredParts,
        'history': FieldValue.arrayUnion([
          {
            'action': 'SALVAGE_COMPLETED',
            'type': 'SALVAGE',
            'by': userName,
            'date': Timestamp.now(),
            'note': "Récupération pièces: $note"
          }
        ])
      });

      final mainLogRef = _db.collection('stock_movements').doc();
      transaction.set(mainLogRef, {
        'productId': item.productId,
        'productName': item.productName,
        'brokenStockChange': -item.quantity,
        'type': 'QUARANTINE_SALVAGED',
        'resolution': 'SALVAGE',
        'quarantineId': item.id,
        'user': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'note': "Démantelé pour pièces. $note",
      });
    });
  }

  // ✅ UPDATED: MOVE TO BROKEN STOCK (Traffic Cop for "Produit Endommagé")
  Future<void> moveToBrokenStock(
      String productId,
      int quantity, {
        String? productName,
        String? deliveryId,
        String? reason,
      }) async {
    final String userName = await _fetchUserName();
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? "unknown";
    final DateTime now = DateTime.now();

    await _db.runTransaction((transaction) async {
      // 1. Update Physical Product Counter
      final productRef = _db.collection('produits').doc(productId);

      final snapshot = await transaction.get(productRef);
      if (!snapshot.exists) throw Exception("Produit introuvable pour mise en rebut");

      final String finalName = productName ?? snapshot.data()?['nom'] ?? 'Produit Inconnu';
      final String productRefCode = snapshot.data()?['reference'] ?? 'N/A';

      // ⚠️ UPDATED LOGIC FOR "DEDUCT AT END":
      // Since stock was NOT deducted during preparation, when an item is broken during delivery,
      // it effectively leaves "QuantiteEnStock" and enters "QuantiteDefectueuse".
      transaction.update(productRef, {
        'quantiteEnStock': FieldValue.increment(-quantity), // Remove from Healthy
        'quantiteDefectueuse': FieldValue.increment(quantity), // Add to Broken
        'lastModifiedBy': userName,
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      // 2. CREATE QUARANTINE CASE FILE
      final quarantineRef = _db.collection('quarantine_items').doc();

      final newItem = QuarantineItem(
        id: quarantineRef.id,
        productId: productId,
        productName: finalName,
        productReference: productRefCode,
        quantity: quantity,
        reason: "Retour Livraison (${deliveryId ?? 'N/A'}) - ${reason ?? 'HS'}",
        photoUrl: null,
        reportedBy: userName,
        reportedByUid: userId,
        reportedAt: now,
        status: 'PENDING',
        history: [
          {
            'action': 'DELIVERY_RETURN',
            'by': userName,
            'date': Timestamp.fromDate(now),
            'note': "Retour Livraison: $reason"
          }
        ],
      );

      transaction.set(quarantineRef, newItem.toMap());

      // 3. Log Movement (Audit Trail)
      final movementRef = _db.collection('stock_movements').doc();
      transaction.set(movementRef, {
        'productId': productId,
        'productName': finalName,
        'quantityChange': -quantity, // It left commercial stock
        'brokenStockChange': quantity,
        'type': 'CLIENT_RETURN_BROKEN',
        'source': 'Retour Livraison',
        'livraisonId': deliveryId,
        'reason': reason ?? 'Non spécifié',
        'user': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'quarantineId': quarantineRef.id,
      });
    });
  }

  // ⚠️ DEPRECATED/UNUSED in new flow: Kept for safety or manual corrections
  Future<void> restockFromPartialDelivery(String productId, int quantity, {String? productName, String? deliveryId}) async {
    final String userName = await _fetchUserName();
    final productRef = _db.collection('produits').doc(productId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(productRef);
      if (!snapshot.exists) throw Exception("Produit introuvable lors du retour stock");

      final String finalName = productName ?? snapshot.data()?['nom'] ?? 'Produit Inconnu';

      transaction.update(productRef, {
        'quantiteEnStock': FieldValue.increment(quantity),
        'lastModifiedBy': userName,
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      final movementRef = _db.collection('stock_movements').doc();
      transaction.set(movementRef, {
        'productId': productId,
        'productName': finalName,
        'quantityChange': quantity,
        'type': 'RETOUR_LIVRAISON',
        'notes': 'Retour immédiat (Livraison Partielle)${deliveryId != null ? " - BL: $deliveryId" : ""}',
        'user': userName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }
}
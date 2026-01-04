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
  // 1. CLIENT RETURN (EXISTING LOGIC)
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
  // 2. INTERNAL BREAKAGE (CASE MANAGEMENT)
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
  // 3. MANAGEMENT (UPDATE STATUS)
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
  // 4. RESOLUTION & SALVAGE (FINALIZE)
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

  // ✅ NEW: SALVAGE PROCESS (Transform Broken -> Maintenance Stock)
  // Creates new "Spare Parts" from the dead item
  Future<void> processSalvage({
    required QuarantineItem item,
    required List<Map<String, dynamic>> recoveredParts, // List of {productId, quantity, productName}
    required String note,
  }) async {
    final String userName = await _fetchUserName();

    await _db.runTransaction((transaction) async {
      // 1. Get Refs
      final mainProductRef = _db.collection('produits').doc(item.productId);
      final quarantineRef = _db.collection('quarantine_items').doc(item.id);

      // 2. Read Main Product (The broken one)
      final mainSnap = await transaction.get(mainProductRef);
      if (!mainSnap.exists) throw Exception("Produit original introuvable");

      final int currentBroken = mainSnap.data()?['quantiteDefectueuse'] ?? 0;
      if (currentBroken < item.quantity) throw Exception("Erreur stock (Déjà traité ?)");

      // 3. Read All Spare Parts (To ensure they exist and get current stock)
      // NOTE: We do this inside transaction to be safe
      for (var part in recoveredParts) {
        final partRef = _db.collection('produits').doc(part['productId']);
        final partSnap = await transaction.get(partRef);
        if (!partSnap.exists) throw Exception("Pièce détachée introuvable: ${part['productName']}");
      }

      // --- WRITES START HERE ---

      // 4. Decrease Broken Stock (Main Item is destroyed/consumed)
      transaction.update(mainProductRef, {
        'quantiteDefectueuse': currentBroken - item.quantity,
      });

      // 5. Increase Maintenance Stock for each Part
      for (var part in recoveredParts) {
        final partRef = _db.collection('produits').doc(part['productId']);
        // We use FieldValue.increment because we already validated existence
        transaction.update(partRef, {
          'quantiteMaintenance': FieldValue.increment(part['quantity']), // ✅ ADDS TO NEW STOCK
        });

        // Log movement for the PART
        final partLogRef = _db.collection('stock_movements').doc();
        transaction.set(partLogRef, {
          'productId': part['productId'],
          'productName': part['productName'],
          'quantityChange': 0, // Not commercial stock
          'maintenanceStockChange': part['quantity'], // ✅ Track this new flow
          'type': 'SALVAGE_RECOVERY',
          'sourceItemId': item.productId,
          'sourceItemName': item.productName,
          'user': userName,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // 6. Close the Quarantine Case
      transaction.update(quarantineRef, {
        'status': 'RESOLVED',
        'resolutionType': 'SALVAGE',
        'salvagedParts': recoveredParts, // Save what we got
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

      // 7. Log movement for the Main Item (Destroyed)
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
}
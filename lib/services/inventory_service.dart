// lib/services/inventory_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/inventory_session.dart';

class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'inventory_sessions';

  // ===========================================================================
  // 🟢 SESSION MANAGEMENT (TECHNICIAN)
  // ===========================================================================

  /// 1. Start a new Inventory Session
  Future<String> startSession({required String scope, required String userName}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    final docRef = _db.collection(_collection).doc();

    final session = InventorySession(
      id: docRef.id,
      createdByUid: user.uid,
      createdByName: userName,
      createdAt: DateTime.now(),
      status: InventoryStatus.inProgress,
      scope: scope,
      totalItemsScanned: 0,
    );

    await docRef.set(session.toMap());
    return docRef.id;
  }

  /// 2. Get Active Session (if any)
  Stream<InventorySession?> getActiveSession() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);

    return _db
        .collection(_collection)
        .where('status', isEqualTo: 'inProgress')
        .where('createdByUid', isEqualTo: user.uid)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return InventorySession.fromFirestore(snapshot.docs.first);
    });
  }

  /// 3. Finish Session (Move to 'Reviewing')
  Future<void> finishSession(String sessionId) async {
    await _db.collection(_collection).doc(sessionId).update({
      'status': InventoryStatus.reviewing.name,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===========================================================================
  // 📦 ITEM MANAGEMENT (ADD / EDIT / DELETE)
  // ===========================================================================

  /// 4. Add (or Update) a Scanned Item to the Session
  Future<void> addItemToSession({
    required String sessionId,
    required InventoryItem item,
  }) async {
    final sessionRef = _db.collection(_collection).doc(sessionId);
    final itemRef = sessionRef.collection('items').doc(item.productId);

    await _db.runTransaction((transaction) async {
      // Get current item if exists (to handle re-scans)
      final itemDoc = await transaction.get(itemRef);

      if (itemDoc.exists) {
        // Option A: Overwrite existing scan
        transaction.update(itemRef, item.toMap());
      } else {
        // Option B: New Entry
        transaction.set(itemRef, item.toMap());

        // Increment total count on parent session
        transaction.update(sessionRef, {
          'totalItemsScanned': FieldValue.increment(1),
        });
      }
    });
  }

  /// 5. Get Stream of Items in a Session (For the Review Page)
  Stream<List<InventoryItem>> getSessionItems(String sessionId) {
    return _db
        .collection(_collection)
        .doc(sessionId)
        .collection('items')
        .orderBy('scannedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => InventoryItem.fromMap(doc.data())).toList();
    });
  }

  /// 6. Update Item Count (Fix a mistake from the Review Page)
  Future<void> updateItemCount(String sessionId, String productId, int newCount) async {
    final itemRef = _db
        .collection(_collection)
        .doc(sessionId)
        .collection('items')
        .doc(productId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(itemRef);
      if (!snapshot.exists) throw Exception("Item not found");

      final data = snapshot.data()!;
      final int systemQty = data['systemQuantity'] ?? 0;

      transaction.update(itemRef, {
        'countedQuantity': newCount,
        'difference': newCount - systemQty,
      });
    });
  }

  /// 7. Delete Item (Remove from draft)
  Future<void> deleteItem(String sessionId, String productId) async {
    final sessionRef = _db.collection(_collection).doc(sessionId);
    final itemRef = sessionRef.collection('items').doc(productId);

    await _db.runTransaction((transaction) async {
      transaction.delete(itemRef);

      // Decrement total count on parent session
      transaction.update(sessionRef, {
        'totalItemsScanned': FieldValue.increment(-1),
      });
    });
  }

  // ===========================================================================
  // 👮 MANAGER ACTIONS (APPROVE / REJECT)
  // ===========================================================================

  /// 8. Get all sessions waiting for review
  Stream<List<InventorySession>> getPendingSessions() {
    return _db
        .collection(_collection)
        .where('status', isEqualTo: 'reviewing')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => InventorySession.fromFirestore(doc)).toList();
    });
  }

  /// 9. Reject a session (Just mark as rejected, no stock changes)
  Future<void> rejectSession(String sessionId) async {
    await _db.collection(_collection).doc(sessionId).update({
      'status': InventoryStatus.rejected.name,
    });
  }

  /// 10. APPROVE SESSION (The Critical Operation)
  /// This updates actual stock and writes history logs in batches.
  Future<void> approveSession(String sessionId) async {
    final user = FirebaseAuth.instance.currentUser;
    final String managerName = user?.displayName ?? "Manager";
    final String managerId = user?.uid ?? "unknown";

    // 1. Get all items in this session
    final itemsSnapshot = await _db
        .collection(_collection)
        .doc(sessionId)
        .collection('items')
        .get();

    final List<InventoryItem> items = itemsSnapshot.docs
        .map((doc) => InventoryItem.fromMap(doc.data()))
        .toList();

    // 2. Prepare Batches (Firestore limit is 500 writes per batch)
    // We do ~2 writes per item (Update Product + Write History)
    // So we can handle ~200 items per batch safely to stay under the 500 limit.
    int batchSize = 200;
    List<List<InventoryItem>> chunks = [];
    for (var i = 0; i < items.length; i += batchSize) {
      chunks.add(items.sublist(i, i + batchSize > items.length ? items.length : i + batchSize));
    }

    // 3. Process each chunk sequentially
    for (var chunk in chunks) {
      final WriteBatch batch = _db.batch();

      for (var item in chunk) {
        // A. Update Product Stock (The Live Data)
        final productRef = _db.collection('produits').doc(item.productId);
        batch.update(productRef, {
          'quantiteEnStock': item.countedQuantity,
          'lastModifiedBy': managerName,
          'lastModifiedAt': FieldValue.serverTimestamp(),
        });

        // B. Add to History Log (Audit Trail)
        final historyRef = _db.collection('stock_movements').doc();
        batch.set(historyRef, {
          'productId': item.productId,
          'productName': item.productName,
          'productRef': item.productReference,
          'oldQuantity': item.systemQuantity,
          'newQuantity': item.countedQuantity,
          'quantityChange': item.difference,
          'type': 'INVENTORY_VALIDATION',
          'notes': 'Inventaire validé par $managerName',
          'userId': managerId,
          'user': managerName,
          'timestamp': FieldValue.serverTimestamp(),
          'sessionId': sessionId,
        });
      }
      // Commit this chunk
      await batch.commit();
    }

    // 4. Mark Session as Approved (Close the session)
    await _db.collection(_collection).doc(sessionId).update({
      'status': InventoryStatus.approved.name,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': managerName,
    });
  }
}
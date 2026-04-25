// lib/services/store_transfer_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class StoreTransferService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> transferStore({
    required String oldClientId,
    required String newClientId,
    required String storeId,
  }) async {
    try {
      debugPrint("🚀 Starting transfer for Store: $storeId");

      final oldStoreRef = _db.collection('clients').doc(oldClientId).collection('stores').doc(storeId);
      final newStoreRef = _db.collection('clients').doc(newClientId).collection('stores').doc(storeId);

      // 1. Fetch the main store document
      final storeSnapshot = await oldStoreRef.get();
      if (!storeSnapshot.exists) {
        throw Exception("Le magasin source n'existe pas.");
      }

      int operationCount = 0;
      WriteBatch batch = _db.batch();

      Future<void> commitBatchIfNeeded() async {
        if (operationCount >= 450) {
          await batch.commit();
          batch = _db.batch();
          operationCount = 0;
        }
      }

      // --- 1. COPY MAIN STORE ---
      Map<String, dynamic> storeData = storeSnapshot.data()!;
      storeData['clientId'] = newClientId; // Ensure clientId is updated internally
      batch.set(newStoreRef, storeData);
      operationCount++;

      // --- 2. COPY 'materiel_installe' SUB-COLLECTION ---
      final equipmentSnapshot = await oldStoreRef.collection('materiel_installe').get();
      for (var doc in equipmentSnapshot.docs) {
        final newSubDocRef = newStoreRef.collection('materiel_installe').doc(doc.id);
        batch.set(newSubDocRef, doc.data());
        operationCount++;
        await commitBatchIfNeeded();
      }

      // --- 3. UPDATE ROOT COLLECTIONS (Change clientId where storeId matches) ---
      // These are your main collections that hold history related to this store
      final List<String> rootCollectionsToUpdate = [
        'interventions',
        'installations',
        'livraisons',
        'sav_tickets',
        'projects'
      ];

      for (String collectionName in rootCollectionsToUpdate) {
        final querySnapshot = await _db.collection(collectionName).where('storeId', isEqualTo: storeId).get();
        for (var doc in querySnapshot.docs) {
          batch.update(doc.reference, {'clientId': newClientId});
          operationCount++;
          await commitBatchIfNeeded();
        }
      }

      // Commit all copy/update writes
      if (operationCount > 0) {
        await batch.commit();
        batch = _db.batch();
        operationCount = 0;
      }

      // --- 4. DELETION PHASE ---
      // Delete old equipment
      for (var doc in equipmentSnapshot.docs) {
        batch.delete(doc.reference);
        operationCount++;
        await commitBatchIfNeeded();
      }

      // Delete old store
      batch.delete(oldStoreRef);
      operationCount++;

      if (operationCount > 0) {
        await batch.commit();
      }

      debugPrint("🎉 Transfer complete! Store $storeId successfully moved to Client $newClientId.");

    } catch (e) {
      debugPrint("❌ Error during store transfer: $e");
      rethrow;
    }
  }
}
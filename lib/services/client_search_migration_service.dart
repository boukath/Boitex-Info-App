// lib/services/client_search_migration_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/utils/search_utils.dart'; // ✅ Uses your new keyword generator
import 'package:boitex_info_app/utils/user_roles.dart';   // ✅ Import roles for security check

class ClientSearchMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🚀 AUTO-DISCOVERY: Scans all stores and fixes Client keywords
  /// 🔒 SECURITY: Requires 'Admin' role to execute
  // ✅ FIX: Added 'userRole' parameter here so it matches the call in Settings Page
  Future<Map<String, int>> runAutoDiscoveryMigration(String userRole) async {

    // 🔥 SECURITY CHECK
    if (userRole != UserRoles.admin) {
      print("⛔ ACCESS DENIED: Attempted migration with role $userRole");
      throw "Accès refusé. Cette opération est réservée aux Administrateurs.";
    }

    int clientsUpdated = 0;
    int brandsFound = 0;

    try {
      // 1️⃣ SCAN: Fetch ALL stores from the entire database
      final QuerySnapshot storesSnapshot = await _firestore.collectionGroup('stores').get();

      // Map: ClientID -> Set of Unique Store Names
      Map<String, Set<String>> clientBrandsMap = {};

      print("🔍 Found ${storesSnapshot.docs.length} stores. Analyzing relationships...");

      for (var doc in storesSnapshot.docs) {
        final storeData = doc.data() as Map<String, dynamic>;
        final String storeName = (storeData['name'] ?? '').toString().trim();

        if (storeName.isEmpty) continue;

        // 🧠 LOGIC: The parent of a store doc is the 'stores' collection.
        // The parent of the 'stores' collection is the 'client' document.
        final DocumentReference? clientRef = doc.reference.parent.parent;

        if (clientRef != null) {
          final String clientId = clientRef.id;

          if (!clientBrandsMap.containsKey(clientId)) {
            clientBrandsMap[clientId] = {};
          }
          // Add store name as a brand (e.g. "Zara")
          clientBrandsMap[clientId]!.add(storeName);
        }
      }

      // 2️⃣ UPDATE: Inject data into Clients
      for (String clientId in clientBrandsMap.keys) {
        final Set<String> foundBrands = clientBrandsMap[clientId]!;
        if (foundBrands.isEmpty) continue;

        final DocumentReference clientRef = _firestore.collection('clients').doc(clientId);

        // We use a transaction to ensure we don't overwrite other updates
        await _firestore.runTransaction((transaction) async {
          final clientDoc = await transaction.get(clientRef);
          if (!clientDoc.exists) return;

          final clientData = clientDoc.data() as Map<String, dynamic>;
          final String clientName = clientData['name'] ?? '';

          // Merge with existing brands (don't lose what you manually added)
          List<dynamic> existingBrandsRaw = clientData['brands'] ?? [];
          Set<String> allBrands = existingBrandsRaw.map((e) => e.toString()).toSet();
          allBrands.addAll(foundBrands); // Add the discovered ones

          // 🧠 GENERATE KEYWORDS: Client Name + All Brands
          List<String> searchKeywords = generateSearchKeywords([
            clientName,
            ...allBrands
          ]);

          // Update the Client Document
          transaction.update(clientRef, {
            'brands': allBrands.toList(),
            'search_keywords': searchKeywords,
            'lastMigration': FieldValue.serverTimestamp(), // Audit trail
          });
        });

        clientsUpdated++;
        brandsFound += foundBrands.length;
        print("✅ Updated Client: $clientId with brands: $foundBrands");
      }

    } catch (e) {
      print("❌ Migration Error: $e");
      rethrow;
    }

    return {'clients': clientsUpdated, 'brands': brandsFound};
  }
}
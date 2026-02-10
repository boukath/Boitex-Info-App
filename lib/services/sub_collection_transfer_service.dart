import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubCollectionTransferService {
  // 🟢 CONFIGURATION FOR NEW PROJECT (boitexinfo-63060)
  static const String _newApiKey = "AIzaSyApz5fasLqpYhVvbahaHOST6gAOx1ghicE";
  static const String _newAppId = "1:177944311253:web:07e69da9b69227561a795c";
  static const String _newMessagingSenderId = "177944311253";
  static const String _newProjectId = "boitexinfo-63060";

  Future<void> startSubCollectionTransfer() async {
    print("🚀 STARTING SUB-COLLECTION TRANSFER...");

    try {
      // 1. Initialize Target App
      FirebaseApp targetApp;
      try {
        targetApp = Firebase.app('subColTarget');
      } catch (e) {
        targetApp = await Firebase.initializeApp(
          name: 'subColTarget',
          options: const FirebaseOptions(
            apiKey: _newApiKey,
            appId: _newAppId,
            messagingSenderId: _newMessagingSenderId,
            projectId: _newProjectId,
            storageBucket: "$_newProjectId.firebasestorage.app",
          ),
        );
      }

      final sourceDb = FirebaseFirestore.instance;
      final targetDb = FirebaseFirestore.instanceFor(app: targetApp);

      // ====================================================
      // 1. MIGRATE CLIENT SUB-STRUCTURE
      // ====================================================
      print("🔹 Processing Clients & Stores...");
      var clients = await sourceDb.collection('clients').get();
      for (var client in clients.docs) {
        // A. Copy Stores
        await _copySubCol(sourceDb, targetDb, 'clients/${client.id}/stores');

        // B. Copy Store Sub-collections (Equipment, Systems)
        var stores = await sourceDb.collection('clients/${client.id}/stores').get();
        for (var store in stores.docs) {
          String storePath = 'clients/${client.id}/stores/${store.id}';

          await _copySubCol(sourceDb, targetDb, '$storePath/materiel_installe');

          // C. Systems & Antennas
          await _copySubCol(sourceDb, targetDb, '$storePath/systems');
          var systems = await sourceDb.collection('$storePath/systems').get();
          for (var system in systems.docs) {
            await _copySubCol(sourceDb, targetDb, '$storePath/systems/${system.id}/antennas');
          }
        }
      }

      // ====================================================
      // 2. MIGRATE INVENTORY ITEMS
      // ====================================================
      print("🔹 Processing Inventory Items...");
      var sessions = await sourceDb.collection('inventory_sessions').get();
      for (var session in sessions.docs) {
        await _copySubCol(sourceDb, targetDb, 'inventory_sessions/${session.id}/items');
      }

      // ====================================================
      // 3. MIGRATE VEHICLE LOGS
      // ====================================================
      print("🔹 Processing Vehicle Logs...");
      var vehicles = await sourceDb.collection('vehicles').get();
      for (var vehicle in vehicles.docs) {
        await _copySubCol(sourceDb, targetDb, 'vehicles/${vehicle.id}/maintenance_logs');
        await _copySubCol(sourceDb, targetDb, 'vehicles/${vehicle.id}/inspections');
      }

      // ====================================================
      // 4. MIGRATE INSTALLATION LOGS
      // ====================================================
      print("🔹 Processing Installation Logs...");
      var installations = await sourceDb.collection('installations').get();
      for (var install in installations.docs) {
        await _copySubCol(sourceDb, targetDb, 'installations/${install.id}/daily_logs');
      }

      // ====================================================
      // 5. MIGRATE REQUISITION RECEPTIONS
      // ====================================================
      print("🔹 Processing Requisitions...");
      var reqs = await sourceDb.collection('requisitions').get();
      for (var req in reqs.docs) {
        await _copySubCol(sourceDb, targetDb, 'requisitions/${req.id}/receptions');
      }

      // ====================================================
      // 6. MIGRATE PRODUCT HISTORY
      // ====================================================
      print("🔹 Processing Product History...");
      var products = await sourceDb.collection('produits').get();
      for (var prod in products.docs) {
        await _copySubCol(sourceDb, targetDb, 'produits/${prod.id}/stock_history');
      }

      // ====================================================
      // 7. MIGRATE TRAINING HUB (Deep Nested)
      // ====================================================
      print("🔹 Processing Training Hub...");
      var categories = await sourceDb.collection('training_categories').get();
      for (var cat in categories.docs) {
        // Level 1: Systems
        String catPath = 'training_categories/${cat.id}';
        await _copySubCol(sourceDb, targetDb, '$catPath/training_systems');

        var systems = await sourceDb.collection('$catPath/training_systems').get();
        for (var sys in systems.docs) {
          // Level 2: Sub-Systems
          String sysPath = '$catPath/training_systems/${sys.id}';
          await _copySubCol(sourceDb, targetDb, '$sysPath/training_sub_systems');

          var subSystems = await sourceDb.collection('$sysPath/training_sub_systems').get();
          for (var sub in subSystems.docs) {
            // Level 3: Documents
            String subPath = '$sysPath/training_sub_systems/${sub.id}';
            await _copySubCol(sourceDb, targetDb, '$subPath/training_documents');
          }
        }
      }

      print("🎉 ✅ ALL SUB-COLLECTIONS TRANSFERRED SUCCESSFULLY!");

    } catch (e) {
      print("❌ ERROR: $e");
    }
  }

  // Generic Helper to Copy a Collection Path
  Future<void> _copySubCol(FirebaseFirestore source, FirebaseFirestore target, String path) async {
    var snapshot = await source.collection(path).get();
    if (snapshot.docs.isEmpty) return;

    print("   -> Copying $path (${snapshot.docs.length} docs)");
    WriteBatch batch = target.batch();
    int count = 0;

    for (var doc in snapshot.docs) {
      batch.set(target.collection(path).doc(doc.id), doc.data());
      count++;
      if (count % 400 == 0) {
        await batch.commit();
        batch = target.batch();
      }
    }
    await batch.commit();
  }
}
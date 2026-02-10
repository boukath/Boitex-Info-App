import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DatabaseTransferService {
  // =========================================================
  // 🟢 CONFIGURATION FOR NEW PROJECT (boitexinfo-63060)
  // =========================================================
  static const String _newApiKey = "AIzaSyApz5fasLqpYhVvbahaHOST6gAOx1ghicE";
  static const String _newAppId = "1:177944311253:web:07e69da9b69227561a795c";
  static const String _newMessagingSenderId = "177944311253";
  static const String _newProjectId = "boitexinfo-63060";

  // =========================================================
  // 🟡 YOUR EXACT COLLECTION LIST
  // =========================================================
  final List<String> _collectionsToMigrate = [
    'activity_log',
    'analytics',
    'analytics_dashboard',
    'antivolSystems',
    'channels',
    'clients',
    'counters',
    'global_activity_log',
    'installations',
    'interventions',
    'inventory_sessions',
    'livraisons',
    'missions',
    'produits',
    'projects',
    'prospects',
    'quarantine_items',
    'requisitions',
    'sav_tickets',
    'settings',
    'stock_movements',
    'training_categories',
    'user_notifications',
    'users',
    'vehicles',
  ];

  // =========================================================
  // ⚙️ SYSTEM CODE
  // =========================================================

  Future<void> startTransfer() async {
    print("🚀 TRANSFER SERVICE: Starting...");

    try {
      // 1. Initialize the Target App (New Project)
      FirebaseApp targetApp;
      try {
        targetApp = Firebase.app('transferTarget');
      } catch (e) {
        targetApp = await Firebase.initializeApp(
          name: 'transferTarget',
          options: const FirebaseOptions(
            apiKey: _newApiKey,
            appId: _newAppId,
            messagingSenderId: _newMessagingSenderId,
            projectId: _newProjectId,
            storageBucket: "$_newProjectId.firebasestorage.app",
          ),
        );
      }

      // 2. Get Database Instances
      final sourceDb = FirebaseFirestore.instance; // Old Project
      final targetDb = FirebaseFirestore.instanceFor(app: targetApp); // New Project

      print("✅ Connected to Source (Old): ${sourceDb.app.options.projectId}");
      print("✅ Connected to Target (New): ${targetDb.app.options.projectId}");

      // 3. Start Copying
      for (String collectionName in _collectionsToMigrate) {
        await _transferCollection(sourceDb, targetDb, collectionName);
      }

      print("🎉 --------------------------------------");
      print("🎉 TRANSFER COMPLETED SUCCESSFULLY!");
      print("🎉 --------------------------------------");

    } catch (e) {
      print("❌ CRITICAL ERROR DURING TRANSFER: $e");
    }
  }

  Future<void> _transferCollection(
      FirebaseFirestore source, FirebaseFirestore target, String colName) async {
    print("📂 Processing collection: $colName...");

    // Get all documents from source
    final snapshot = await source.collection(colName).get();

    if (snapshot.docs.isEmpty) {
      print("   ↳ Skipped (Empty)");
      return;
    }

    int count = 0;
    WriteBatch batch = target.batch();

    for (var doc in snapshot.docs) {
      try {
        // Add to batch
        batch.set(target.collection(colName).doc(doc.id), doc.data());
        count++;

        // Commit batch every 400 documents
        if (count % 400 == 0) {
          await batch.commit();
          batch = target.batch();
          print("   ↳ Committed batch of 400 documents...");
        }

        // ⚠️ SPECIAL HANDLING FOR CHAT MESSAGES
        if (colName == 'channels') {
          await _transferSubCollection(source, target, '$colName/${doc.id}/messages');
        }

      } catch (e) {
        print("⚠️ Error copying doc ${doc.id}: $e");
      }
    }

    // Commit remaining documents
    if (count % 400 != 0) {
      await batch.commit();
    }

    print("✅ Finished $colName: $count documents.");
  }

  Future<void> _transferSubCollection(
      FirebaseFirestore source, FirebaseFirestore target, String path) async {
    final snapshot = await source.collection(path).get();
    if (snapshot.docs.isEmpty) return;

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
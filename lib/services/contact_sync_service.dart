import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ContactSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🚀 MAIN FUNCTION: Syncs Intervention Contacts to Store Contact Lists
  /// Run this ONCE to backfill all your old interventions into the store profiles.
  Future<String> runContactSync() async {
    int processedInterventions = 0;
    int updatedStores = 0;

    try {
      debugPrint("🚀 STARTING CONTACT SYNC SERVICE...");

      // 1. Fetch ALL Interventions
      // You might want to limit this if you have thousands (e.g., .limit(500))
      final interventionsSnapshot = await _firestore.collection('interventions').get();
      debugPrint("📂 Found ${interventionsSnapshot.docs.length} interventions to scan.");

      for (var doc in interventionsSnapshot.docs) {
        processedInterventions++;
        final data = doc.data();

        final String? clientId = data['clientId'];
        final String? storeId = data['storeId'];

        // Skip if not linked to a store
        if (clientId == null || storeId == null) continue;

        // 2. Extract Contact Info from Intervention
        // We look for both new 'manager' keys and legacy 'contact' keys
        final String? name = data['managerName'] ?? data['contactName'];
        final String? phone = data['managerPhone'] ?? data['contactPhone'];
        final String? email = data['managerEmail'] ?? data['contactEmail'];

        // If no meaningful contact info exists, skip
        if ((phone == null || phone.isEmpty) && (email == null || email.isEmpty)) {
          continue;
        }

        final storeRef = _firestore
            .collection('clients')
            .doc(clientId)
            .collection('stores')
            .doc(storeId);

        // 3. Fetch Store to check existing contacts
        final storeDoc = await storeRef.get();
        if (!storeDoc.exists) continue;

        final storeData = storeDoc.data() ?? {};
        List<dynamic> currentContacts = [];

        if (storeData['storeContacts'] is List) {
          currentContacts = List.from(storeData['storeContacts']);
        }

        bool modified = false;

        // --- HELPER: Add Unique Contact ---
        void addContactIfMissing(String type, String value, String label) {
          if (value.isEmpty) return;

          // Check if this specific value (phone/email) already exists
          final exists = currentContacts.any((c) {
            final cVal = c['value']?.toString().toLowerCase().trim() ?? '';
            final newVal = value.toLowerCase().trim();
            return cVal == newVal;
          });

          if (!exists) {
            currentContacts.add({
              'id': DateTime.now().millisecondsSinceEpoch.toString() + type, // Simple ID
              'type': type,
              'label': label,
              'value': value.trim(),
            });
            modified = true;
          }
        }

        // 4. Perform Updates
        String label = "Manager";
        if (name != null && name.isNotEmpty) {
          label = "Manager ($name)";
        }

        if (phone != null) addContactIfMissing('Téléphone', phone, label);
        if (email != null) addContactIfMissing('E-mail', email, label);

        // 5. Save back to Firestore if we made changes
        if (modified) {
          final Map<String, dynamic> updates = {
            'storeContacts': currentContacts,
          };

          // Optional: Ensure flat fields are populated for backward compatibility
          if (storeData['managerName'] == null && name != null) updates['managerName'] = name;
          if (storeData['managerPhone'] == null && phone != null) updates['managerPhone'] = phone;
          if (storeData['managerEmail'] == null && email != null) updates['managerEmail'] = email;

          await storeRef.update(updates);
          updatedStores++;
          debugPrint("✅ Updated Store: $storeId with new contacts.");
        }
      }

      final result = "✅ SYNC COMPLETE!\nScanned: $processedInterventions interventions\nStores Updated: $updatedStores";
      debugPrint(result);
      return result;

    } catch (e) {
      final error = "❌ SYNC FAILED: $e";
      debugPrint(error);
      return error;
    }
  }
}
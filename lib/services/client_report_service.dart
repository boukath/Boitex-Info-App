// lib/services/client_report_service.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// -----------------------------------------------------------------------------
// 📝 HELPER MODELS (DTOs)
// -----------------------------------------------------------------------------

class ClientReportData {
  final String clientName;
  final DateTime startDate;
  final DateTime endDate;
  final List<StoreReportData> stores;
  final List<StoreReportData> topProblematicStores;
  final int totalInterventions;
  final int totalEquipment;

  ClientReportData({
    required this.clientName,
    required this.startDate,
    required this.endDate,
    required this.stores,
    required this.topProblematicStores,
    required this.totalInterventions,
    required this.totalEquipment,
  });
}

class StoreReportData {
  final String id;
  final String name;
  final String location;
  final List<EquipmentReportItem> equipment;
  final List<InterventionReportItem> interventions;

  StoreReportData({
    required this.id,
    required this.name,
    required this.location,
    required this.equipment,
    required this.interventions,
  });

  bool get hasActivity => equipment.isNotEmpty || interventions.isNotEmpty;
}

class EquipmentReportItem {
  final String name;
  final String marque;
  final String serial;
  final DateTime? installDate;

  EquipmentReportItem({
    required this.name,
    required this.marque,
    required this.serial,
    this.installDate,
  });
}

class InterventionReportItem {
  final DateTime date;
  final String technician;
  final String managerName; // ✅ ADDED: Manager who signed
  final String type;
  final String summary; // Request
  final String status;
  final String diagnostic;
  final String workDone;

  InterventionReportItem({
    required this.date,
    required this.technician,
    required this.managerName,
    required this.type,
    required this.summary,
    required this.status,
    required this.diagnostic,
    required this.workDone,
  });
}

// -----------------------------------------------------------------------------
// 🚀 SERVICE CLASS
// -----------------------------------------------------------------------------

class ClientReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<ClientReportData> fetchReportData({
    required String clientId,
    required String clientName,
    required DateTimeRange dateRange,
  }) async {
    try {
      print("🚀 STARTING REPORT GENERATION for $clientName");

      // 1. Fetch All Stores
      final storesSnapshot = await _firestore
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .get();

      // 2. Fetch Interventions
      final interventionsSnapshot = await _firestore
          .collection('interventions')
          .where('clientId', isEqualTo: clientId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))
          .orderBy('createdAt', descending: true)
          .get();

      print("🛠️ Found ${interventionsSnapshot.docs.length} interventions.");

      final Map<String, List<InterventionReportItem>> interventionsByStore = {};

      for (var doc in interventionsSnapshot.docs) {
        final data = doc.data();
        final String? sId = data['storeId'];

        if (sId == null) continue;

        if (!interventionsByStore.containsKey(sId)) {
          interventionsByStore[sId] = [];
        }

        DateTime date = DateTime.now();
        if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
          date = (data['createdAt'] as Timestamp).toDate();
        }

        interventionsByStore[sId]!.add(
          InterventionReportItem(
            date: date,
            technician: data['createdByName'] ?? 'Technicien',
            managerName: data['managerName'] ?? 'Non signé', // ✅ FETCH MANAGER
            type: data['interventionType'] ?? 'Intervention',
            summary: data['requestDescription'] ?? '',
            status: data['status'] ?? 'Terminé',
            diagnostic: data['diagnostic'] ?? '',
            workDone: data['workDone'] ?? '',
          ),
        );
      }

      // 3. Parallel Fetch of Equipment
      List<Future<StoreReportData>> storeFutures = storesSnapshot.docs.map((doc) async {
        final data = doc.data();
        final String storeId = doc.id;
        final String name = data['name'] ?? 'Magasin Inconnu';
        final String location = data['location'] ?? '';

        final equipmentSnapshot = await doc.reference
            .collection('materiel_installe')
            .get();

        final equipmentList = equipmentSnapshot.docs.map((eDoc) {
          final eData = eDoc.data();
          return EquipmentReportItem(
            name: eData['name'] ?? eData['nom'] ?? 'Équipement',
            marque: eData['marque'] ?? '-',
            serial: eData['serialNumber'] ?? '-',
            installDate: (eData['installDate'] as Timestamp?)?.toDate(),
          );
        }).toList();

        final storeInterventions = interventionsByStore[storeId] ?? [];

        return StoreReportData(
          id: storeId,
          name: name,
          location: location,
          equipment: equipmentList,
          interventions: storeInterventions,
        );
      }).toList();

      final List<StoreReportData> allStoresData = await Future.wait(storeFutures);

      // 4. Calculate Stats
      final List<StoreReportData> sortedByIssues = List.from(allStoresData);
      sortedByIssues.sort((a, b) => b.interventions.length.compareTo(a.interventions.length));

      final top3 = sortedByIssues.take(3).where((s) => s.interventions.isNotEmpty).toList();

      allStoresData.sort((a, b) => a.name.compareTo(b.name));

      int totalInterventions = interventionsSnapshot.docs.length;
      int totalEquipment = allStoresData.fold(0, (sum, store) => sum + store.equipment.length);

      return ClientReportData(
        clientName: clientName,
        startDate: dateRange.start,
        endDate: dateRange.end,
        stores: allStoresData,
        topProblematicStores: top3,
        totalInterventions: totalInterventions,
        totalEquipment: totalEquipment,
      );

    } catch (e) {
      print("❌ Error generating Client Report Data: $e");
      rethrow;
    }
  }
}
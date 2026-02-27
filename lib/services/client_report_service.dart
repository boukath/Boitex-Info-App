// lib/services/client_report_service.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// -----------------------------------------------------------------------------
// 📝 HELPER MODELS (DTOs)
// -----------------------------------------------------------------------------

class ClientReportData {
  final String clientName;
  final DateTime startDate;
  final DateTime endDate;
  final List<StoreReportData> stores;
  final List<StoreReportData> topProblematicStores;

  // Global KPIs
  final int totalInterventions;
  final int totalInstallations;
  final int totalLivraisons;
  final int totalEquipment;

  final Map<String, int> activityByMonth;
  final Map<String, int> activityByType;

  ClientReportData({
    required this.clientName,
    required this.startDate,
    required this.endDate,
    required this.stores,
    required this.topProblematicStores,
    required this.totalInterventions,
    required this.totalInstallations,
    required this.totalLivraisons,
    required this.totalEquipment,
    required this.activityByMonth,
    required this.activityByType,
  });
}

class StoreReportData {
  final String id;
  final String name;
  final String location;
  final String? logoUrl;
  final List<EquipmentReportItem> equipment;
  final List<InterventionReportItem> interventions;
  final List<InstallationReportItem> installations;
  final List<LivraisonReportItem> livraisons;

  StoreReportData({
    required this.id,
    required this.name,
    required this.location,
    this.logoUrl,
    required this.equipment,
    required this.interventions,
    required this.installations,
    required this.livraisons,
  });

  bool get hasActivity => equipment.isNotEmpty || interventions.isNotEmpty || installations.isNotEmpty || livraisons.isNotEmpty;
}

class EquipmentReportItem {
  final String name;
  final String marque;
  final String serial;
  final DateTime? installDate;

  EquipmentReportItem({required this.name, required this.marque, required this.serial, this.installDate});
}

class InterventionReportItem {
  final DateTime date;
  final String technician;
  final String type;
  final String status;
  final String diagnostic;

  InterventionReportItem({required this.date, required this.technician, required this.type, required this.status, required this.diagnostic});
}

// ✅ NEW: Model to hold specific product details inside an installation
class InstallationProductItem {
  final String name;
  final String marque;
  final String reference;
  final int quantity;
  final List<String> serialNumbers;

  InstallationProductItem({
    required this.name,
    required this.marque,
    required this.reference,
    required this.quantity,
    required this.serialNumbers,
  });
}

// ✅ UPDATED: Added products list to the installation report item
class InstallationReportItem {
  final DateTime date;
  final String code;
  final String status;
  final String technicians;
  final List<InstallationProductItem> products; // Added this

  InstallationReportItem({
    required this.date,
    required this.code,
    required this.status,
    required this.technicians,
    required this.products, // Added this
  });
}

class LivraisonProductItem {
  final String name;
  final String marque;
  final String partNumber;
  final int quantity;
  final List<String> serialNumbers;

  LivraisonProductItem({
    required this.name,
    required this.marque,
    required this.partNumber,
    required this.quantity,
    required this.serialNumbers,
  });
}

class LivraisonReportItem {
  final DateTime date;
  final String code;
  final String status;
  final String recipient;
  final List<LivraisonProductItem> products;

  LivraisonReportItem({
    required this.date,
    required this.code,
    required this.status,
    required this.recipient,
    required this.products,
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
      print("🚀 STARTING PREMIUM REPORT GENERATION for $clientName");

      // 1. Fetch All Stores
      final storesSnapshot = await _firestore.collection('clients').doc(clientId).collection('stores').get();

      // 2. Fetch Interventions, Installations, Livraisons concurrently
      final startTimestamp = Timestamp.fromDate(dateRange.start);
      final endTimestamp = Timestamp.fromDate(dateRange.end);

      final futures = await Future.wait([
        _firestore.collection('interventions')
            .where('clientId', isEqualTo: clientId)
            .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
            .where('createdAt', isLessThanOrEqualTo: endTimestamp).get(),

        _firestore.collection('installations')
            .where('clientId', isEqualTo: clientId)
            .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
            .where('createdAt', isLessThanOrEqualTo: endTimestamp).get(),

        _firestore.collection('livraisons')
            .where('clientId', isEqualTo: clientId)
            .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
            .where('createdAt', isLessThanOrEqualTo: endTimestamp).get(),
      ]);

      final interventionsDocs = futures[0].docs;
      final installationsDocs = futures[1].docs;
      final livraisonsDocs = futures[2].docs;

      // Grouping Maps
      final Map<String, List<InterventionReportItem>> interventionsByStore = {};
      final Map<String, List<InstallationReportItem>> installationsByStore = {};
      final Map<String, List<LivraisonReportItem>> livraisonsByStore = {};

      final Map<String, int> statsByMonth = {};
      final Map<String, int> statsByType = {}; // Tracks all activity types

      // Process Interventions
      for (var doc in interventionsDocs) {
        final data = doc.data();
        final sId = data['storeId'];
        if (sId == null) continue;

        DateTime date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        statsByMonth[DateFormat('MMM yyyy', 'fr_FR').format(date)] = (statsByMonth[DateFormat('MMM yyyy', 'fr_FR').format(date)] ?? 0) + 1;
        statsByType['Interventions'] = (statsByType['Interventions'] ?? 0) + 1;

        interventionsByStore.putIfAbsent(sId, () => []).add(InterventionReportItem(
          date: date,
          technician: data['createdByName'] ?? 'Inconnu',
          type: data['interventionType'] ?? 'Autre',
          status: data['status'] ?? 'Terminé',
          diagnostic: data['diagnostic'] ?? '-',
        ));
      }

      // Process Installations
      for (var doc in installationsDocs) {
        final data = doc.data();
        final sId = data['storeId'];
        if (sId == null) continue;

        DateTime date = (data['installationDate'] as Timestamp?)?.toDate() ?? (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        statsByMonth[DateFormat('MMM yyyy', 'fr_FR').format(date)] = (statsByMonth[DateFormat('MMM yyyy', 'fr_FR').format(date)] ?? 0) + 1;
        statsByType['Installations'] = (statsByType['Installations'] ?? 0) + 1;

        String techs = 'Non assigné';

        if (data['effectiveTechnicians'] is List && (data['effectiveTechnicians'] as List).isNotEmpty) {
          techs = (data['effectiveTechnicians'] as List).join(', ');
        } else if (data['assignedTechnicianNames'] is List && (data['assignedTechnicianNames'] as List).isNotEmpty) {
          techs = (data['assignedTechnicianNames'] as List).join(', ');
        }
        else if (data['assignedTechnicians'] is List) {
          List techList = data['assignedTechnicians'];
          if (techList.isNotEmpty) {
            techs = techList.map((t) {
              if (t is Map) return t['displayName'] ?? 'Inconnu';
              if (t is String) return 'Tech (Assigné)';
              return '';
            }).where((s) => s.isNotEmpty).join(', ');
          }
        }

        // ✅ NEW: Parse the systems/products array for full installation details
        List<InstallationProductItem> parsedProducts = [];
        if (data['systems'] is List) {
          for (var p in (data['systems'] as List)) {
            if (p is Map) {
              List<String> serials = [];
              if (p['serialNumbers'] is List) {
                // Filter out empty strings in case a serial number wasn't fully entered
                serials = (p['serialNumbers'] as List)
                    .map((s) => s.toString())
                    .where((s) => s.trim().isNotEmpty)
                    .toList();
              }

              parsedProducts.add(InstallationProductItem(
                name: p['name'] ?? p['productName'] ?? 'Produit',
                marque: p['marque'] ?? '-',
                reference: p['reference'] ?? '-',
                quantity: (p['quantity'] ?? 0).toInt(),
                serialNumbers: serials,
              ));
            }
          }
        }

        installationsByStore.putIfAbsent(sId, () => []).add(InstallationReportItem(
          date: date,
          code: data['installationCode'] ?? 'INST-XXX',
          status: data['status'] ?? 'À Planifier',
          technicians: techs,
          products: parsedProducts, // ✅ Pass detailed products
        ));
      }

      // Process Livraisons
      for (var doc in livraisonsDocs) {
        final data = doc.data();
        final sId = data['storeId'];
        if (sId == null) continue;

        DateTime date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        statsByMonth[DateFormat('MMM yyyy', 'fr_FR').format(date)] = (statsByMonth[DateFormat('MMM yyyy', 'fr_FR').format(date)] ?? 0) + 1;
        statsByType['Livraisons'] = (statsByType['Livraisons'] ?? 0) + 1;

        List<LivraisonProductItem> parsedProducts = [];
        if (data['products'] is List) {
          for (var p in (data['products'] as List)) {
            if (p is Map) {
              List<String> serials = [];
              if (p['serialNumbers'] is List) {
                serials = (p['serialNumbers'] as List).map((s) => s.toString()).toList();
              } else if (p['deliveredSerials'] is List) {
                serials = (p['deliveredSerials'] as List).map((s) => s.toString()).toList();
              }

              parsedProducts.add(LivraisonProductItem(
                name: p['productName'] ?? 'Produit',
                marque: p['marque'] ?? '-',
                partNumber: p['partNumber'] ?? p['reference'] ?? '-',
                quantity: (p['quantity'] ?? p['deliveredQuantity'] ?? 0).toInt(),
                serialNumbers: serials,
              ));
            }
          }
        }

        livraisonsByStore.putIfAbsent(sId, () => []).add(LivraisonReportItem(
          date: date,
          code: data['bonLivraisonCode'] ?? 'BL-XXX',
          status: data['status'] ?? 'En Cours',
          recipient: data['recipientName'] ?? 'Non spécifié',
          products: parsedProducts,
        ));
      }

      // 3. Parallel Fetch of Equipment for Stores
      List<Future<StoreReportData>> storeFutures = storesSnapshot.docs.map((doc) async {
        final data = doc.data();
        final String storeId = doc.id;

        final equipmentSnapshot = await doc.reference.collection('materiel_installe').get();
        final equipmentList = equipmentSnapshot.docs.map((eDoc) {
          final eData = eDoc.data();
          return EquipmentReportItem(
            name: eData['name'] ?? eData['nom'] ?? 'Équipement',
            marque: eData['marque'] ?? '-',
            serial: eData['serialNumber'] ?? '-',
            installDate: (eData['installDate'] as Timestamp?)?.toDate(),
          );
        }).toList();

        return StoreReportData(
          id: storeId,
          name: data['name'] ?? 'Magasin Inconnu',
          location: data['location'] ?? '',
          logoUrl: data['logoUrl'],
          equipment: equipmentList,
          interventions: interventionsByStore[storeId] ?? [],
          installations: installationsByStore[storeId] ?? [],
          livraisons: livraisonsByStore[storeId] ?? [],
        );
      }).toList();

      final List<StoreReportData> allStoresData = await Future.wait(storeFutures);

      allStoresData.sort((a, b) {
        int aVol = a.interventions.length + a.installations.length + a.livraisons.length;
        int bVol = b.interventions.length + b.installations.length + b.livraisons.length;
        return bVol.compareTo(aVol);
      });

      final top3 = allStoresData.take(3).where((s) => s.hasActivity).toList();

      allStoresData.sort((a, b) => a.name.compareTo(b.name));

      return ClientReportData(
        clientName: clientName,
        startDate: dateRange.start,
        endDate: dateRange.end,
        stores: allStoresData,
        topProblematicStores: top3,
        totalInterventions: interventionsDocs.length,
        totalInstallations: installationsDocs.length,
        totalLivraisons: livraisonsDocs.length,
        totalEquipment: allStoresData.fold(0, (sum, store) => sum + store.equipment.length),
        activityByMonth: statsByMonth,
        activityByType: statsByType,
      );

    } catch (e) {
      print("❌ Error generating Premium Report Data: $e");
      rethrow;
    }
  }
}
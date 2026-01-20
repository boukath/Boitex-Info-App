// lib/models/maintenance_log.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenanceLog {
  final String id;
  final String vehicleId;
  final DateTime date;
  final int mileage;
  final List<String> performedItems; // Standard tags (e.g. "OIL_CHANGE")
  final List<String> customParts;    // ✅ NEW: Free text parts (e.g. "Alternateur")
  final String? invoiceUrl;
  final String? notes;
  final double? cost;
  final String? technicianId;

  MaintenanceLog({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.mileage,
    required this.performedItems,
    this.customParts = const [], // ✅ Default to empty
    this.invoiceUrl,
    this.notes,
    this.cost,
    this.technicianId,
  });

  // 🔹 Create an empty log
  factory MaintenanceLog.empty(String vehicleId) {
    return MaintenanceLog(
      id: '',
      vehicleId: vehicleId,
      date: DateTime.now(),
      mileage: 0,
      performedItems: [],
      customParts: [],
    );
  }

  // 🔹 Firestore Serialization
  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'date': Timestamp.fromDate(date),
      'mileage': mileage,
      'performedItems': performedItems,
      'customParts': customParts, // ✅ Save custom parts
      'invoiceUrl': invoiceUrl,
      'notes': notes,
      'cost': cost,
      'technicianId': technicianId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // 🔹 Firestore Deserialization
  factory MaintenanceLog.fromMap(Map<String, dynamic> map, String docId) {
    return MaintenanceLog(
      id: docId,
      vehicleId: map['vehicleId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      mileage: map['mileage']?.toInt() ?? 0,
      performedItems: List<String>.from(map['performedItems'] ?? []),
      customParts: List<String>.from(map['customParts'] ?? []), // ✅ Load custom parts
      invoiceUrl: map['invoiceUrl'],
      notes: map['notes'],
      cost: map['cost']?.toDouble(),
      technicianId: map['technicianId'],
    );
  }

  // 🔹 Clone for immutability
  MaintenanceLog copyWith({
    String? id,
    String? vehicleId,
    DateTime? date,
    int? mileage,
    List<String>? performedItems,
    List<String>? customParts,
    String? invoiceUrl,
    String? notes,
    double? cost,
    String? technicianId,
  }) {
    return MaintenanceLog(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      mileage: mileage ?? this.mileage,
      performedItems: performedItems ?? this.performedItems,
      customParts: customParts ?? this.customParts, // ✅ Copy custom parts
      invoiceUrl: invoiceUrl ?? this.invoiceUrl,
      notes: notes ?? this.notes,
      cost: cost ?? this.cost,
      technicianId: technicianId ?? this.technicianId,
    );
  }
}

// -----------------------------------------------------------------------------
// 🛠️ CONSTANTS: MAINTENANCE ITEMS (The "Menu")
// -----------------------------------------------------------------------------
class MaintenanceItems {
  static const String oilChange = 'VIDANGE_MOTEUR';
  static const String oilFilter = 'FILTRE_HUILE';
  static const String airFilter = 'FILTRE_AIR';
  static const String fuelFilter = 'FILTRE_CARBURANT';
  static const String cabinFilter = 'FILTRE_HABITACLE';
  static const String brakesFront = 'PLAQUETTES_AVANT';
  static const String brakesRear = 'PLAQUETTES_ARRIERE';
  static const String tires = 'PNEUMATIQUES';
  static const String inspection = 'DIAGNOSTIC_GENERAL';

  static String getLabel(String key) {
    switch (key) {
      case oilChange: return '🛢️ Vidange Huile';
      case oilFilter: return '💨 Filtre Huile';
      case airFilter: return '🌪️ Filtre Air';
      case fuelFilter: return '⛽ Filtre Gasoil';
      case cabinFilter: return '❄️ Filtre Clim';
      case brakesFront: return '🛑 Freins AV';
      case brakesRear: return '🛑 Freins AR';
      case tires: return '🍩 Pneus';
      case inspection: return '🔍 Diagnostic';
      default: return key;
    }
  }
}
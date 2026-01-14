// lib/models/vehicle.dart

// Vehicle management model for mission resources and fleet health

import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String? id;
  final String vehicleCode; // VEH-001, VEH-002...
  final String model; // Renault Duster
  final String plateNumber; // 12345-A-16
  final String fuelType; // Diesel, Essence, Hybrid, Electric
  final int capacity; // Passenger capacity
  final String color; // Blanc, Noir, etc.
  final int year; // 2023
  final String status; // available, in_use, maintenance
  final String? currentMissionId; // null or mission ID if in use
  final Map<String, dynamic>? currentMissionDates; // {start: timestamp, end: timestamp}

  // ---------------------------------------------------------------------------
  // ✅ NEW: FLEET VISUALS (The Car Photo)
  // ---------------------------------------------------------------------------
  final String? photoUrl; // The actual photo of the car

  // ---------------------------------------------------------------------------
  // ✅ NEW: COMPLIANCE (Legal Health / Digital Glovebox)
  // ---------------------------------------------------------------------------
  final DateTime? assuranceExpiry;
  final String? assurancePhotoUrl; // URL to the digital contract

  final DateTime? controlTechniqueExpiry;
  final String? controlTechniquePhotoUrl; // URL to the scanner/sticker

  final String? carteGrisePhotoUrl; // The ID of the car

  // ---------------------------------------------------------------------------
  // ✅ NEW: MAINTENANCE (Mechanical Health / Oil Algorithm)
  // ---------------------------------------------------------------------------
  final int currentMileage;          // Current Odometer reading (e.g., 145000)
  final int? lastOilChangeMileage;   // e.g., 140000 (Vidange faite à...)
  final int? nextOilChangeMileage;   // e.g., 150000 (Prochaine vidange à...)
  final String tireStatus;           // 'good', 'warning', 'critical'

  final DateTime createdAt;

  Vehicle({
    this.id,
    required this.vehicleCode,
    required this.model,
    required this.plateNumber,
    required this.fuelType,
    required this.capacity,
    required this.color,
    required this.year,
    this.status = 'available',
    this.currentMissionId,
    this.currentMissionDates,

    // Visuals
    this.photoUrl,

    // Compliance
    this.assuranceExpiry,
    this.assurancePhotoUrl,
    this.controlTechniqueExpiry,
    this.controlTechniquePhotoUrl,
    this.carteGrisePhotoUrl,

    // Maintenance
    this.currentMileage = 0,
    this.lastOilChangeMileage,
    this.nextOilChangeMileage,
    this.tireStatus = 'good',

    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'vehicleCode': vehicleCode,
      'model': model,
      'plateNumber': plateNumber,
      'fuelType': fuelType,
      'capacity': capacity,
      'color': color,
      'year': year,
      'status': status,
      'currentMissionId': currentMissionId,
      'currentMissionDates': currentMissionDates,
      'createdAt': Timestamp.fromDate(createdAt),

      // Visuals
      'photoUrl': photoUrl,

      // New Compliance Fields
      'assuranceExpiry': assuranceExpiry != null ? Timestamp.fromDate(assuranceExpiry!) : null,
      'assurancePhotoUrl': assurancePhotoUrl,
      'controlTechniqueExpiry': controlTechniqueExpiry != null ? Timestamp.fromDate(controlTechniqueExpiry!) : null,
      'controlTechniquePhotoUrl': controlTechniquePhotoUrl,
      'carteGrisePhotoUrl': carteGrisePhotoUrl,

      // New Maintenance Fields
      'currentMileage': currentMileage,
      'lastOilChangeMileage': lastOilChangeMileage,
      'nextOilChangeMileage': nextOilChangeMileage,
      'tireStatus': tireStatus,
    };
  }

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Vehicle(
      id: doc.id,
      vehicleCode: data['vehicleCode'] as String? ?? 'N/A',
      model: data['model'] as String? ?? 'Unknown Model',
      plateNumber: data['plateNumber'] as String? ?? 'Unknown Plate',
      fuelType: data['fuelType'] as String? ?? 'Diesel',
      // ✅ FIX: Safe capacity parsing (handles String or int)
      capacity: _parseCapacity(data['capacity']),
      color: data['color'] as String? ?? 'Blanc',
      // ✅ FIX: Safe year parsing (handles String or int)
      year: _parseYear(data['year']),
      status: data['status'] as String? ?? 'available',
      currentMissionId: data['currentMissionId'] as String?,
      // ✅ FIX: Safe map parsing (handles String, Map, or null)
      currentMissionDates: _parseMap(data['currentMissionDates']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),

      // Load Visuals
      photoUrl: data['photoUrl'] as String?,

      // Load Compliance (Safe date parsing)
      assuranceExpiry: (data['assuranceExpiry'] as Timestamp?)?.toDate(),
      assurancePhotoUrl: data['assurancePhotoUrl'] as String?,
      controlTechniqueExpiry: (data['controlTechniqueExpiry'] as Timestamp?)?.toDate(),
      controlTechniquePhotoUrl: data['controlTechniquePhotoUrl'] as String?,
      carteGrisePhotoUrl: data['carteGrisePhotoUrl'] as String?,

      // Load Maintenance (Safe int parsing)
      currentMileage: _parseInt(data['currentMileage']) ?? 0,
      lastOilChangeMileage: _parseInt(data['lastOilChangeMileage']),
      nextOilChangeMileage: _parseInt(data['nextOilChangeMileage']),
      tireStatus: data['tireStatus'] as String? ?? 'good',
    );
  }

  // ---------------------------------------------------------------------------
  // 🧠 SMART HELPERS (For the "Pro 2026" UI)
  // ---------------------------------------------------------------------------

  // Is the Assurance expired or expiring soon (30 days)?
  bool get isAssuranceCritical {
    if (assuranceExpiry == null) return true; // No data = Critical
    final daysLeft = assuranceExpiry!.difference(DateTime.now()).inDays;
    return daysLeft < 0; // Expired
  }

  bool get isAssuranceWarning {
    if (assuranceExpiry == null) return false;
    final daysLeft = assuranceExpiry!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 30; // Less than a month left
  }

  // Is Oil Change needed?
  bool get needsOilChange {
    if (nextOilChangeMileage == null) return false;
    // If we have driven MORE than the limit (or are within 500km)
    return currentMileage >= (nextOilChangeMileage! - 500);
  }

  String get displayName => '$model ($plateNumber)';
  bool get isAvailable => status == 'available' && currentMissionId == null;
  String get fullInfo => '$vehicleCode - $model - $plateNumber - $year';

  // ---------------------------------------------------------------------------
  // 🛡️ SAFE PARSING HELPERS
  // ---------------------------------------------------------------------------

  // ✅ Helper: Parse year field (handles String, int, or null)
  static int _parseYear(dynamic value) {
    if (value == null) return DateTime.now().year;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now().year; // Default fallback
  }

  // ✅ Helper: Parse capacity field (handles String, int, or null)
  static int _parseCapacity(dynamic value) {
    if (value == null) return 5; // Default 5 passengers
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 5; // Default fallback
  }

  // ✅ Helper: Parse generic int field (handles String or int)
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  // ✅ Helper: Parse Map field (handles String, Map, or null)
  static Map<String, dynamic>? _parseMap(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      // Convert to Map<String, dynamic>
      return Map<String, dynamic>.from(value);
    }
    if (value is String && value.toLowerCase() == 'null') {
      return null; // Handle "null" string
    }
    return null; // Default fallback
  }

  Vehicle copyWith({
    String? id,
    String? vehicleCode,
    String? model,
    String? plateNumber,
    String? fuelType,
    int? capacity,
    String? color,
    int? year,
    String? status,
    String? currentMissionId,
    Map<String, dynamic>? currentMissionDates,
    DateTime? createdAt,
    String? photoUrl,
    DateTime? assuranceExpiry,
    String? assurancePhotoUrl,
    DateTime? controlTechniqueExpiry,
    String? controlTechniquePhotoUrl,
    String? carteGrisePhotoUrl,
    int? currentMileage,
    int? lastOilChangeMileage,
    int? nextOilChangeMileage,
    String? tireStatus,
  }) {
    return Vehicle(
      id: id ?? this.id,
      vehicleCode: vehicleCode ?? this.vehicleCode,
      model: model ?? this.model,
      plateNumber: plateNumber ?? this.plateNumber,
      fuelType: fuelType ?? this.fuelType,
      capacity: capacity ?? this.capacity,
      color: color ?? this.color,
      year: year ?? this.year,
      status: status ?? this.status,
      currentMissionId: currentMissionId ?? this.currentMissionId,
      currentMissionDates: currentMissionDates ?? this.currentMissionDates,
      createdAt: createdAt ?? this.createdAt,
      photoUrl: photoUrl ?? this.photoUrl,
      assuranceExpiry: assuranceExpiry ?? this.assuranceExpiry,
      assurancePhotoUrl: assurancePhotoUrl ?? this.assurancePhotoUrl,
      controlTechniqueExpiry: controlTechniqueExpiry ?? this.controlTechniqueExpiry,
      controlTechniquePhotoUrl: controlTechniquePhotoUrl ?? this.controlTechniquePhotoUrl,
      carteGrisePhotoUrl: carteGrisePhotoUrl ?? this.carteGrisePhotoUrl,
      currentMileage: currentMileage ?? this.currentMileage,
      lastOilChangeMileage: lastOilChangeMileage ?? this.lastOilChangeMileage,
      nextOilChangeMileage: nextOilChangeMileage ?? this.nextOilChangeMileage,
      tireStatus: tireStatus ?? this.tireStatus,
    );
  }

  @override
  String toString() => 'Vehicle($vehicleCode - $model - $plateNumber)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Vehicle && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
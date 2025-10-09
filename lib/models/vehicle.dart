// lib/models/vehicle.dart

// Vehicle management model for mission resources

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
    };
  }

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Vehicle(
      id: doc.id,
      vehicleCode: data['vehicleCode'] as String? ?? 'N/A',
      model: data['model'] as String,
      plateNumber: data['plateNumber'] as String,
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
    );
  }

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

  // Helper: Display name for vehicle
  String get displayName => '$model ($plateNumber)';

  // Helper: Check if available
  bool get isAvailable => status == 'available' && currentMissionId == null;

  // Helper: Full vehicle info
  String get fullInfo => '$vehicleCode - $model - $plateNumber - $year';

  // Create a copy of Vehicle with updated fields
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

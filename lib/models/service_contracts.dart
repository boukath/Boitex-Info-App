// lib/models/service_contracts.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// 🛠 Represents the Manufacturer Warranty (Garantie Constructeur)
/// This is embedded inside an Equipment document.
class EquipmentWarranty {
  final DateTime startDate;
  final DateTime endDate;
  final bool isExtended; // Has the warranty been extended?
  final String? notes; // E.g., "Extended by 6 months due to repair"

  EquipmentWarranty({
    required this.startDate,
    required this.endDate,
    this.isExtended = false,
    this.notes,
  });

  /// 🟢 Helper: Check if currently valid
  bool get isValid {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  /// 🟠 Helper: Check if expiring soon (e.g., in 30 days)
  bool get isExpiringSoon {
    if (!isValid) return false; // Already expired
    final daysRemaining = endDate.difference(DateTime.now()).inDays;
    return daysRemaining <= 30;
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isExtended': isExtended,
      'notes': notes,
    };
  }

  factory EquipmentWarranty.fromMap(Map<String, dynamic> map) {
    return EquipmentWarranty(
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      isExtended: map['isExtended'] ?? false,
      notes: map['notes'],
    );
  }

  /// ⚡️ Factory to create a default 1-year warranty from installation date
  factory EquipmentWarranty.defaultOneYear(DateTime installationDate) {
    return EquipmentWarranty(
      startDate: installationDate,
      endDate: installationDate.add(const Duration(days: 365)),
    );
  }
}

/// 📄 Represents a Maintenance Contract (Contrat de Maintenance)
/// This is embedded inside a Store or Client document.
class MaintenanceContract {
  final String id;
  final String type; // E.g., "Standard", "VIP", "Preventive"
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String? docUrl; // Link to the PDF contract
  final double coveragePercentage; // 100% free or partially billable?

  MaintenanceContract({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.docUrl,
    this.coveragePercentage = 100.0,
  });

  /// 🟢 Helper: Check if the contract allows service today
  bool get isValidNow {
    if (!isActive) return false;
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'docUrl': docUrl,
      'coveragePercentage': coveragePercentage,
    };
  }

  factory MaintenanceContract.fromMap(Map<String, dynamic> map) {
    return MaintenanceContract(
      id: map['id'] ?? '',
      type: map['type'] ?? 'Standard',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
      docUrl: map['docUrl'],
      coveragePercentage: (map['coveragePercentage'] as num?)?.toDouble() ?? 100.0,
    );
  }
}
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
  /// ✅ FIXED: Made inclusive so it doesn't fail on the exact same day
  bool get isValid {
    final now = DateTime.now();
    bool isAfterOrSame = now.compareTo(startDate) >= 0;
    bool isBeforeOrSame = now.compareTo(endDate) <= 0;

    return isAfterOrSame && isBeforeOrSame;
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
///
/// 🔄 UPDATED: Now uses a "Credit System" instead of "Gold/Premium" types.
class MaintenanceContract {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String? docUrl; // Link to the PDF contract

  // 🔹 QUOTA BUCKETS (The "Wallet")
  final int quotaPreventive; // Total preventive visits allowed per year (e.g., 2)
  final int quotaCorrective; // Total repair visits allowed per year (e.g., 10)

  // 🔸 USAGE TRACKERS (Consumed Credits)
  final int usedPreventive;
  final int usedCorrective;

  MaintenanceContract({
    required this.id,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.docUrl,
    required this.quotaPreventive,
    required this.quotaCorrective,
    this.usedPreventive = 0,
    this.usedCorrective = 0,
  });

  /// 🟢 Helper: Check if the contract is active (Date-wise)
  /// ✅ FIXED: Made inclusive to prevent exact-date false negatives
  bool get isValidNow {
    if (!isActive) return false;
    final now = DateTime.now();
    bool isAfterOrSame = now.compareTo(startDate) >= 0;
    bool isBeforeOrSame = now.compareTo(endDate) <= 0;

    return isAfterOrSame && isBeforeOrSame;
  }

  // 📊 CALCULATED GETTERS

  int get remainingPreventive => quotaPreventive - usedPreventive;
  int get remainingCorrective => quotaCorrective - usedCorrective;

  bool get hasCreditPreventive => remainingPreventive > 0;
  bool get hasCreditCorrective => remainingCorrective > 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'docUrl': docUrl,
      // Save Quotas & Usage
      'quotaPreventive': quotaPreventive,
      'quotaCorrective': quotaCorrective,
      'usedPreventive': usedPreventive,
      'usedCorrective': usedCorrective,
    };
  }

  factory MaintenanceContract.fromMap(Map<String, dynamic> map) {
    return MaintenanceContract(
      id: map['id'] ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
      docUrl: map['docUrl'],
      // Load Quotas (Default to 0 if missing)
      quotaPreventive: map['quotaPreventive'] ?? 0,
      quotaCorrective: map['quotaCorrective'] ?? 0,
      // Load Usage (Default to 0)
      usedPreventive: map['usedPreventive'] ?? 0,
      usedCorrective: map['usedCorrective'] ?? 0,
    );
  }
}
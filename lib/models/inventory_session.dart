// lib/models/inventory_session.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum InventoryStatus { inProgress, reviewing, approved, rejected }

/// Represents a single product counted during an inventory
class InventoryItem {
  final String productId;
  final String productName;
  final String productReference;
  final String category; // Useful for grouping in reports
  final int systemQuantity; // What Firestore said we had
  final int countedQuantity; // What the technician found
  final int difference; // counted - system
  final String scannedByUid;
  final DateTime scannedAt;

  InventoryItem({
    required this.productId,
    required this.productName,
    required this.productReference,
    required this.category,
    required this.systemQuantity,
    required this.countedQuantity,
    required this.scannedByUid,
    required this.scannedAt,
  }) : difference = countedQuantity - systemQuantity;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productReference': productReference,
      'category': category,
      'systemQuantity': systemQuantity,
      'countedQuantity': countedQuantity,
      'difference': difference,
      'scannedByUid': scannedByUid,
      'scannedAt': Timestamp.fromDate(scannedAt),
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? 'Inconnu',
      productReference: map['productReference'] ?? '',
      category: map['category'] ?? '',
      systemQuantity: map['systemQuantity'] ?? 0,
      countedQuantity: map['countedQuantity'] ?? 0,
      scannedByUid: map['scannedByUid'] ?? '',
      scannedAt: (map['scannedAt'] as Timestamp).toDate(),
    );
  }
}

/// Represents the overall Inventory Session
class InventorySession {
  final String id;
  final String createdByUid;
  final String createdByName;
  final DateTime createdAt;
  final InventoryStatus status;
  final String scope; // e.g., 'Global', 'Antivol', 'TPV'
  final int totalItemsScanned;
  final DateTime? completedAt;
  final DateTime? approvedAt;
  final String? approvedBy;

  InventorySession({
    required this.id,
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
    required this.status,
    required this.scope,
    required this.totalItemsScanned,
    this.completedAt,
    this.approvedAt,
    this.approvedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.name, // Stores as string: 'inProgress'
      'scope': scope,
      'totalItemsScanned': totalItemsScanned,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
    };
  }

  factory InventorySession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InventorySession(
      id: doc.id,
      createdByUid: data['createdByUid'] ?? '',
      createdByName: data['createdByName'] ?? 'Inconnu',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: InventoryStatus.values.firstWhere(
            (e) => e.name == (data['status'] ?? 'inProgress'),
        orElse: () => InventoryStatus.inProgress,
      ),
      scope: data['scope'] ?? 'Global',
      totalItemsScanned: data['totalItemsScanned'] ?? 0,
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      approvedAt: data['approvedAt'] != null ? (data['approvedAt'] as Timestamp).toDate() : null,
      approvedBy: data['approvedBy'],
    );
  }
}
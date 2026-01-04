// lib/models/quarantine_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class QuarantineItem {
  final String id;
  final String productId;
  final String productName;
  final String productReference;
  final int quantity;
  final String reason;
  final String? photoUrl;

  // Who reported it?
  final String reportedBy;
  final String reportedByUid;
  final DateTime reportedAt;

  // 🚦 STATUS FLOW:
  // 'PENDING'       -> Just reported, waiting in quarantine.
  // 'AT_SUPPLIER'   -> Sent to supplier (RMA).
  // 'IN_REPAIR'     -> Technician is fixing it internally.
  // 'RESOLVED'      -> Returned to stock or Destroyed (Archived).
  final String status;

  // 📝 HISTORY LOG (For tracking: "Sent to supplier on...", "Received back on...")
  final List<Map<String, dynamic>> history;

  QuarantineItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productReference,
    required this.quantity,
    required this.reason,
    this.photoUrl,
    required this.reportedBy,
    required this.reportedByUid,
    required this.reportedAt,
    required this.status,
    required this.history,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productReference': productReference,
      'quantity': quantity,
      'reason': reason,
      'photoUrl': photoUrl,
      'reportedBy': reportedBy,
      'reportedByUid': reportedByUid,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'status': status,
      'history': history,
    };
  }

  // Create from Firestore Document
  factory QuarantineItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuarantineItem(
      id: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? 'Inconnu',
      productReference: data['productReference'] ?? '',
      quantity: data['quantity'] ?? 0,
      reason: data['reason'] ?? '',
      photoUrl: data['photoUrl'],
      reportedBy: data['reportedBy'] ?? 'Inconnu',
      reportedByUid: data['reportedByUid'] ?? '',
      reportedAt: (data['reportedAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'PENDING',
      history: List<Map<String, dynamic>>.from(data['history'] ?? []),
    );
  }
}
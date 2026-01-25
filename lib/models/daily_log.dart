// lib/models/daily_log.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DailyLog {
  final String id;
  final DateTime timestamp;
  final String type; // 'work', 'blockage', 'info', 'material'
  final String technicianId;
  final String technicianName;
  final String description;
  final List<String> mediaUrls;

  // ⚡ New: specific status for media uploads
  // 'uploading' = show spinner, 'ready' = show image, 'error' = show retry
  final String mediaStatus;

  // 🛠 Flexible field for extra data (e.g., weather, specific part serial numbers)
  final Map<String, dynamic> meta;

  DailyLog({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.technicianId,
    required this.technicianName,
    required this.description,
    required this.mediaUrls,
    this.mediaStatus = 'ready',
    this.meta = const {},
  });

  // Convert from Firestore Document
  factory DailyLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyLog(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: data['type'] ?? 'info',
      technicianId: data['technicianId'] ?? '',
      technicianName: data['technicianName'] ?? 'Unknown',
      description: data['description'] ?? '',
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      mediaStatus: data['mediaStatus'] ?? 'ready',
      meta: data['meta'] ?? {},
    );
  }

  // Convert to Firestore Document
  Map<String, dynamic> toJson() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'description': description,
      'mediaUrls': mediaUrls,
      'mediaStatus': mediaStatus,
      'meta': meta,
    };
  }
}
// lib/models/sav_journal_entry.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// 1. Define the types of events that can happen on the workbench
enum JournalEntryType {
  text,           // Standard typed note
  audio,          // Voice transcribed note
  photo,          // Photo uploaded during diagnosis/repair
  part_consumed,  // A part was scanned/deducted from stock
  status_change,  // The ticket moved to a new phase
  system_log,     // Automated background events
}

class SavJournalEntry {
  final String id;
  final DateTime timestamp;
  final String authorName;
  final String authorId;
  final JournalEntryType type;

  // The main content (Text, URL for image/audio, or Part Name)
  final String content;

  // Extra data (e.g., {'previousStatus': 'Nouveau', 'newStatus': 'En Diagnostic'})
  final Map<String, dynamic>? metadata;

  SavJournalEntry({
    required this.id,
    required this.timestamp,
    required this.authorName,
    required this.authorId,
    required this.type,
    required this.content,
    this.metadata,
  });

  // Convert to Firebase Map
  Map<String, dynamic> toJson() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'authorName': authorName,
      'authorId': authorId,
      'type': type.name, // saves as 'text', 'photo', etc.
      'content': content,
      'metadata': metadata,
    };
  }

  // Parse from Firebase Document
  factory SavJournalEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavJournalEntry(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      authorName: data['authorName'] ?? 'Unknown',
      authorId: data['authorId'] ?? '',
      type: JournalEntryType.values.firstWhere(
            (e) => e.name == data['type'],
        orElse: () => JournalEntryType.system_log,
      ),
      content: data['content'] ?? '',
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }
}
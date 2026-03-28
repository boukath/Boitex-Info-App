// lib/models/story_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class StoryItem {
  final String id;
  final String userId;
  final String userName;
  final String storeName;
  final String? storeLogoUrl;
  final String location;
  final String description;
  final String badgeText;
  final List<String> mediaUrls; // 🚀 NEW: Added mediaUrls
  final DateTime timestamp;

  StoryItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.storeName,
    this.storeLogoUrl,
    required this.location,
    required this.description,
    required this.badgeText,
    required this.mediaUrls, // 🚀 NEW
    required this.timestamp,
  });

  factory StoryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StoryItem(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Technicien',
      storeName: data['storeName'] ?? 'Boutique',
      storeLogoUrl: data['storeLogoUrl'],
      location: data['location'] ?? '',
      description: data['description'] ?? '',
      badgeText: data['badgeText'] ?? 'INFO',
      // 🚀 NEW: Safely parse the mediaUrls array
      mediaUrls: data['mediaUrls'] != null ? List<String>.from(data['mediaUrls']) : [],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'storeName': storeName,
      'storeLogoUrl': storeLogoUrl,
      'location': location,
      'description': description,
      'badgeText': badgeText,
      'mediaUrls': mediaUrls, // 🚀 NEW
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'intervention',
    };
  }
}
// lib/models/story_item.dart

// 🚀 FIX: Added the missing Firestore import!
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
  final List<String> mediaUrls;
  final DateTime timestamp;
  final String type;
  final List<String> viewedBy; // 🚀 Tracks who has seen this story

  StoryItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.storeName,
    this.storeLogoUrl,
    required this.location,
    required this.description,
    required this.badgeText,
    required this.mediaUrls,
    required this.timestamp,
    required this.type,
    required this.viewedBy,
  });

  factory StoryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // 🚀 Ensure viewedBy is ALWAYS a mutable, growable list.
    List<String> parsedViewedBy = [];
    if (data['viewedBy'] != null) {
      // Create a brand new, growable list from the dynamic list
      parsedViewedBy = List<String>.from(data['viewedBy']).toList();
    }

    return StoryItem(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Technicien',
      storeName: data['storeName'] ?? 'Boutique',
      storeLogoUrl: data['storeLogoUrl'],
      location: data['location'] ?? '',
      description: data['description'] ?? '',
      badgeText: data['badgeText'] ?? 'INFO',
      mediaUrls: data['mediaUrls'] != null ? List<String>.from(data['mediaUrls']) : [],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] ?? 'intervention',
      viewedBy: parsedViewedBy, // 🚀 Use the new mutable list
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
      'mediaUrls': mediaUrls,
      'timestamp': timestamp,
      'type': type,
      'viewedBy': viewedBy,
    };
  }
}
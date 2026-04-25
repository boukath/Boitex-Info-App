// lib/models/story_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class StoryItem {
  final String id;
  final String? interventionId;
  final String? installationId; // 🚀 NEW: Added for installations
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
  final List<String> viewedBy;

  // 🚀 Tracks all reactions [{'uid': '123', 'name': 'Jean', 'emoji': '❤️'}, ...]
  final List<Map<String, dynamic>> reactions;

  // 💬 🚀 NEW: Tracks all comments [{'uid': '...', 'name': '...', 'text': '...', 'timestamp': '...'}, ...]
  final List<Map<String, dynamic>> comments;

  StoryItem({
    required this.id,
    this.interventionId,
    this.installationId, // 🚀 NEW
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
    required this.reactions,
    required this.comments, // 🚀 NEW
  });

  factory StoryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    List<String> parsedViewedBy = [];
    if (data['viewedBy'] != null) {
      parsedViewedBy = List<String>.from(data['viewedBy']).toList();
    }

    // 🚀 Safely parse the reactions list
    List<Map<String, dynamic>> parsedReactions = [];
    if (data['reactions'] != null) {
      parsedReactions = List<Map<String, dynamic>>.from(
          (data['reactions'] as List).map((e) => Map<String, dynamic>.from(e))
      );
    }

    // 💬 🚀 NEW: Safely parse the comments list
    List<Map<String, dynamic>> parsedComments = [];
    if (data['comments'] != null) {
      parsedComments = List<Map<String, dynamic>>.from(
          (data['comments'] as List).map((e) => Map<String, dynamic>.from(e))
      );
    }

    return StoryItem(
      id: doc.id,
      interventionId: data['interventionId'],
      installationId: data['installationId'], // 🚀 NEW
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
      viewedBy: parsedViewedBy,
      reactions: parsedReactions,
      comments: parsedComments, // 🚀 NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'interventionId': interventionId,
      'installationId': installationId, // 🚀 NEW
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
      'reactions': reactions,
      'comments': comments, // 🚀 NEW
    };
  }
}
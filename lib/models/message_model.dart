// lib/models/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final Timestamp timestamp;

  // Fields for different message types
  final String messageType; // 'text', 'image', 'video', 'pdf', 'file'
  final String? text;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize; // ✅ --- ADDED ---

  // Field for reactions
  final Map<String, List<String>> reactions;

  // Stores a list of UIDs for all users mentioned in the message
  final List<String> mentionedUserIds;

  // Tracks if a message has been edited
  final bool isEdited;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    required this.messageType,
    this.text,
    this.fileUrl,
    this.fileName,
    this.fileSize, // ✅ --- ADDED ---
    required this.reactions,
    required this.mentionedUserIds,
    required this.isEdited,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;

    Map<String, List<String>> parsedReactions = {};
    if (data['reactions'] != null) {
      (data['reactions'] as Map<String, dynamic>).forEach((emoji, userList) {
        if (userList is List) {
          parsedReactions[emoji] = List<String>.from(userList.map((id) => id.toString()));
        }
      });
    }

    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      messageType: data['messageType'] ?? 'text',
      text: data['text'],
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
      fileSize: data['fileSize'], // ✅ --- ADDED --- (will be null if not present)
      reactions: parsedReactions,
      mentionedUserIds: List<String>.from(data['mentionedUserIds'] ?? []),
      isEdited: data['isEdited'] ?? false,
    );
  }
}
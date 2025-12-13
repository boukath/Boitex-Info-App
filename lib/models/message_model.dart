// lib/models/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final Timestamp timestamp;

  // Fields for different message types
  final String messageType; // 'text', 'image', 'video', 'pdf', 'apk', 'file'
  final String? text;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;

  // ✅ NEXT GEN FEATURE: Reactions
  final Map<String, List<String>> reactions;

  // ✅ NEXT GEN FEATURE: Mentions
  final List<String> mentionedUserIds;

  // ✅ NEXT GEN FEATURE: Edit History
  final bool isEdited;

  // 🚀 NEW: Context (Threaded Replies)
  // We store these directly on the message so we don't have to fetch the old message to show a preview.
  final String? replyToMessageId; // ID of the message being replied to
  final String? replyToSenderName; // Name of the person we are replying to
  final String? replyToText;       // A snippet of the text/file name we are replying to

  // 🚀 NEW: Tracking (Read Receipts)
  // A list of User UIDs who have seen this message.
  final List<String> readBy;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    required this.messageType,
    this.text,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    required this.reactions,
    required this.mentionedUserIds,
    required this.isEdited,
    this.replyToMessageId,
    this.replyToSenderName,
    this.replyToText,
    required this.readBy,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;

    // Helper to safely parse reactions
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
      senderName: data['senderName'] ?? 'Utilisateur Inconnu',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      messageType: data['messageType'] ?? 'text',
      text: data['text'],
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
      fileSize: data['fileSize'],
      reactions: parsedReactions,
      mentionedUserIds: List<String>.from(data['mentionedUserIds'] ?? []),
      isEdited: data['isEdited'] ?? false,
      // 🚀 Mapping the New Fields
      replyToMessageId: data['replyToMessageId'],
      replyToSenderName: data['replyToSenderName'],
      replyToText: data['replyToText'],
      readBy: List<String>.from(data['readBy'] ?? []),
    );
  }
}
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

  // Field for reactions
  final Map<String, List<String>> reactions;

  // Constructor without thread fields
  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    required this.messageType,
    this.text,
    this.fileUrl,
    this.fileName,
    required this.reactions,
  });

  // Updated factory constructor without thread fields
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;

    // Helper to parse reactions (remains the same)
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
      reactions: parsedReactions,
    );
  }
}
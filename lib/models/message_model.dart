import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final Timestamp timestamp;

  // Fields for different message types
  final String messageType; // 'text', 'image', 'video', 'file'
  final String? text;
  final String? fileUrl;
  final String? fileName;

  // Field for reactions
  final Map<String, List<String>> reactions;

  // *** NEW FIELDS FOR THREADS ***
  final String? threadParentId; // ID of the message this is replying to (if any)
  final int replyCount;       // Number of direct replies this message has

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
    this.threadParentId, // Make it optional in constructor
    required this.replyCount, // Make it required
  });

  // Updated factory constructor
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;

    // Helper to parse reactions
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
      // *** PARSE NEW FIELDS ***
      threadParentId: data['threadParentId'], // Directly get the value (can be null)
      replyCount: data['replyCount'] ?? 0,   // Default to 0 if field doesn't exist
    );
  }
}
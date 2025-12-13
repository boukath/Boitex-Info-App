// lib/services/announce_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:boitex_info_app/models/channel_model.dart';
import 'package:boitex_info_app/models/message_model.dart';
import 'package:file_picker/file_picker.dart';

class AnnounceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final CollectionReference _channelsCollection =
  FirebaseFirestore.instance.collection('channels');
  final CollectionReference _usersCollection =
  FirebaseFirestore.instance.collection('users');

  // --- Channel Methods ---
  Stream<List<ChannelModel>> getChannels() {
    return _channelsCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ChannelModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> createChannel(String name, String description) async {
    if (name.trim().isEmpty) {
      throw Exception('Channel name cannot be empty');
    }
    try {
      await _channelsCollection.add({
        'name': name.trim(),
        'description': description.trim().isNotEmpty ? description.trim() : null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      print('Error creating channel: $e');
      rethrow;
    }
  }

  /// Updates an existing channel's details
  Future<void> updateChannel(
      String channelId, String name, String description) async {
    if (name.trim().isEmpty) {
      throw Exception('Channel name cannot be empty');
    }
    try {
      await _channelsCollection.doc(channelId).update({
        'name': name.trim(),
        'description': description.trim().isNotEmpty ? description.trim() : null,
      });
    } on FirebaseException catch (e) {
      print('Error updating channel: $e');
      rethrow;
    }
  }

  /// Deletes a channel and all messages within it
  Future<void> deleteChannel(String channelId) async {
    try {
      // 1. Get the 'messages' subcollection
      final messagesCollection =
      _channelsCollection.doc(channelId).collection('messages');

      // 2. Get all message documents
      final messagesSnapshot = await messagesCollection.get();

      // 3. Create a batch write to delete all messages
      final WriteBatch batch = _firestore.batch();
      for (final DocumentSnapshot doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 4. Commit the batch deletion
      await batch.commit();

      // 5. After all messages are deleted, delete the channel itself
      await _channelsCollection.doc(channelId).delete();
    } on FirebaseException catch (e) {
      print('Error deleting channel: $e');
      rethrow;
    }
  }

  // --- Message Methods ---

  Stream<List<MessageModel>> getMessages(String channelId) {
    return _channelsCollection
        .doc(channelId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      // Useful debug print, can be removed in production if noisy
      // print('[AnnounceService] getMessages Snapshot: ${snapshot.docs.length} docs for channel $channelId');
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<String> _getSenderName() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return 'Unknown User';

    try {
      final userDoc = await _usersCollection.doc(currentUser.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        // Use the displayName field from Firestore
        return userData['displayName'] ?? currentUser.email ?? 'Unknown User';
      } else {
        return currentUser.email ?? 'Unknown User';
      }
    } catch (e) {
      print("Error fetching user displayName: $e");
      return currentUser.email ?? 'Unknown User';
    }
  }

  Future<List<String>> searchUserDisplayNames(String query) async {
    try {
      Query queryBuilder;

      if (query.isEmpty) {
        queryBuilder = _usersCollection.orderBy('displayName').limit(10);
      } else {
        queryBuilder = _usersCollection
            .where('displayName', isGreaterThanOrEqualTo: query)
            .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(10);
      }

      final querySnapshot = await queryBuilder.get();

      final suggestions = querySnapshot.docs
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['displayName'] as String? ?? '';
      })
          .where((name) => name.isNotEmpty)
          .toList();

      return suggestions;
    } catch (e) {
      print("Error searching user display names: $e");
      return [];
    }
  }

  // 🛡️ UPDATED: Robust Mention Parsing (Handles >10 users limit)
  Future<List<String>> _parseMentionsForUids(String text) async {
    final RegExp mentionRegex = RegExp(r'@(\w+)');
    final List<String> mentionedNames = mentionRegex
        .allMatches(text)
        .map((match) => match.group(1)!)
        .toSet()
        .toList();

    if (mentionedNames.isEmpty) return [];

    final Set<String> mentionedUids = {};

    // Firestore 'whereIn' supports max 10 items. We must chunk it.
    for (var i = 0; i < mentionedNames.length; i += 10) {
      final end = (i + 10 < mentionedNames.length)
          ? i + 10
          : mentionedNames.length;
      final chunk = mentionedNames.sublist(i, end);

      try {
        final querySnapshot = await _usersCollection
            .where('displayName', whereIn: chunk)
            .get();

        for (final doc in querySnapshot.docs) {
          mentionedUids.add(doc.id);
        }
      } catch (e) {
        print("Error looking up mentioned users chunk: $e");
      }
    }

    return mentionedUids.toList();
  }

  // 🚀 UPDATED: Sending Text with Reply Context & Read Receipts
  Future<void> sendTextMessage(String channelId, String text, {MessageModel? replyTo}) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final String senderName = await _getSenderName();
    final String trimmedText = text.trim();

    // Regex to check if the message is a URL ending in .apk
    final RegExp apkLinkRegex = RegExp(r'^https?:\/\/.+\.apk$', caseSensitive: false);
    final bool isApkLink = apkLinkRegex.hasMatch(trimmedText);

    // Prepare Reply Data (Denormalization for speed)
    final String? replyToId = replyTo?.id;
    final String? replyToName = replyTo?.senderName;
    String? replyToTextContent;

    if (replyTo != null) {
      // Create a nice preview of what we are replying to
      if (replyTo.messageType == 'text') {
        replyToTextContent = replyTo.text;
      } else {
        replyToTextContent = "📎 ${replyTo.fileName ?? 'Fichier'}";
      }
      // Truncate if too long
      if (replyToTextContent != null && replyToTextContent.length > 50) {
        replyToTextContent = "${replyToTextContent.substring(0, 50)}...";
      }
    }

    Map<String, dynamic> newMessageData;

    if (isApkLink) {
      // --- It's an APK link ---
      String fileName = trimmedText.split('/').last.split('?').first;
      newMessageData = {
        'senderId': currentUser.uid,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
        'messageType': 'apk',
        'text': null,
        'fileUrl': trimmedText,
        'fileName': fileName,
        'fileSize': null,
        'reactions': {},
        'mentionedUserIds': [],
        'isEdited': false,
        // New Context Fields
        'replyToMessageId': replyToId,
        'replyToSenderName': replyToName,
        'replyToText': replyToTextContent,
        'readBy': [currentUser.uid], // Mark as read by sender immediately
      };
    } else {
      // --- It's a regular text message ---
      final List<String> mentionedUids = await _parseMentionsForUids(trimmedText);

      newMessageData = {
        'senderId': currentUser.uid,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
        'messageType': 'text',
        'text': trimmedText,
        'fileUrl': null,
        'fileName': null,
        'fileSize': null,
        'reactions': {},
        'mentionedUserIds': mentionedUids,
        'isEdited': false,
        // New Context Fields
        'replyToMessageId': replyToId,
        'replyToSenderName': replyToName,
        'replyToText': replyToTextContent,
        'readBy': [currentUser.uid],
      };
    }

    await _channelsCollection
        .doc(channelId)
        .collection('messages')
        .add(newMessageData);
  }

  // 🚀 UPDATED: Sending Files with Reply Context
  Future<void> saveFileMessageWithUrl({
    required String channelId,
    required String fileUrl,
    required String fileName,
    required String messageType,
    required int fileSize,
    MessageModel? replyTo, // Optional Reply
  }) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final String senderName = await _getSenderName();

      // Reply Logic
      final String? replyToId = replyTo?.id;
      final String? replyToName = replyTo?.senderName;
      String? replyToTextContent;
      if (replyTo != null) {
        replyToTextContent = replyTo.messageType == 'text'
            ? replyTo.text
            : "📎 ${replyTo.fileName ?? 'Fichier'}";
      }

      final newMessageData = {
        'senderId': currentUser.uid,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
        'messageType': messageType,
        'text': null,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'reactions': {},
        'mentionedUserIds': [], // Files don't have mentions
        'isEdited': false,
        // New Context Fields
        'replyToMessageId': replyToId,
        'replyToSenderName': replyToName,
        'replyToText': replyToTextContent,
        'readBy': [currentUser.uid],
      };

      await _channelsCollection
          .doc(channelId)
          .collection('messages')
          .add(newMessageData);
    } on FirebaseException catch (e) {
      print("Error saving file message to Firestore: $e");
      rethrow;
    }
  }

  /// Sends a file message (Legacy/Fallback direct upload)
  Future<void> sendFileMessage(String channelId, PlatformFile file) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    String messageType = 'file';
    final String extension = file.extension?.toLowerCase() ?? '';
    if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
      messageType = 'image';
    } else if (['mp4', 'mov', 'avi', 'mkv'].contains(extension)) {
      messageType = 'video';
    } else if (extension == 'pdf') {
      messageType = 'pdf';
    }

    final String uniqueFileName =
        '${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final String path = 'announcements/$channelId/$uniqueFileName';
    if (file.path == null) {
      print("Error: File path is null for ${file.name}");
      throw Exception("Cannot upload file without a valid path.");
    }
    final File localFile = File(file.path!);

    try {
      final UploadTask uploadTask =
      _storage.ref().child(path).putFile(localFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      final String senderName = await _getSenderName();

      final newMessageData = {
        'senderId': currentUser.uid,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
        'messageType': messageType,
        'text': null,
        'fileUrl': downloadUrl,
        'fileName': file.name,
        'fileSize': file.size,
        'reactions': {},
        'mentionedUserIds': [],
        'isEdited': false,
        // Initialize basic context fields for legacy uploads
        'replyToMessageId': null,
        'replyToSenderName': null,
        'replyToText': null,
        'readBy': [currentUser.uid],
      };

      await _channelsCollection
          .doc(channelId)
          .collection('messages')
          .add(newMessageData);
    } on FirebaseException catch (e) {
      print("Error uploading file to storage or saving message: $e");
      rethrow;
    }
  }

  // 🚀 NEW: Mark Message as Read (Read Receipts)
  Future<void> markMessageAsRead(String channelId, String messageId) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // We use arrayUnion so it only adds the ID if it's not already there.
      // This saves us from reading the doc first.
      await _channelsCollection
          .doc(channelId)
          .collection('messages')
          .doc(messageId)
          .update({
        'readBy': FieldValue.arrayUnion([currentUser.uid]),
      });
    } catch (e) {
      // Fail silently (e.g., message deleted)
      print("Error marking message as read: $e");
    }
  }

  /// Updates an existing text message
  Future<void> updateMessage(
      String channelId, String messageId, String newText) async {
    try {
      // Re-parse mentions, just like when sending a new message
      final List<String> mentionedUids = await _parseMentionsForUids(newText);

      await _channelsCollection
          .doc(channelId)
          .collection('messages')
          .doc(messageId)
          .update({
        'text': newText,
        'isEdited': true,
        'mentionedUserIds': mentionedUids, // Update mentions as well
        'lastUpdatedAt': FieldValue.serverTimestamp(), // Good to track
      });
    } catch (e) {
      print("Error updating message: $e");
      rethrow;
    }
  }

  /// Deletes a message (works for any type)
  Future<void> deleteMessage(String channelId, String messageId) async {
    try {
      await _channelsCollection
          .doc(channelId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      print("Error deleting message: $e");
      rethrow;
    }
  }

  /// Toggles an emoji reaction
  Future<void> toggleReaction(
      String channelId, String messageId, String emoji) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final String userId = currentUser.uid;

    final DocumentReference messageRef = _channelsCollection
        .doc(channelId)
        .collection('messages')
        .doc(messageId);

    try {
      await _firestore.runTransaction((transaction) async {
        final DocumentSnapshot messageSnap = await transaction.get(messageRef);
        if (!messageSnap.exists) {
          throw Exception("Message does not exist!");
        }
        final messageData = messageSnap.data() as Map<String, dynamic>?;
        Map<String, dynamic> reactions =
            messageData?['reactions'] as Map<String, dynamic>? ?? {};
        List<dynamic> userList = reactions[emoji] as List<dynamic>? ?? [];
        Set<String> userSet = userList.map((id) => id.toString()).toSet();

        if (userSet.contains(userId)) {
          userSet.remove(userId);
        } else {
          userSet.add(userId);
        }

        if (userSet.isEmpty) {
          reactions.remove(emoji);
        } else {
          reactions[emoji] = userSet.toList();
        }
        transaction.update(messageRef, {'reactions': reactions});
      });
    } catch (e) {
      print("Failed to toggle reaction: $e");
    }
  }
}
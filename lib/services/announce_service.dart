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

  // --- Message Methods ---

  /// Gets messages for the main channel (excluding replies)
  Stream<List<MessageModel>> getMessages(String channelId) {
    return _channelsCollection
        .doc(channelId)
        .collection('messages')
    // *** NEW: Filter out replies ***
        .where('threadParentId', isNull: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
    });
  }

  // *** NEW: Gets replies for a specific thread ***
  Stream<List<MessageModel>> getReplies(
      String channelId, String threadParentId) {
    return _channelsCollection
        .doc(channelId)
        .collection('messages')
    // Filter by the parent message ID
        .where('threadParentId', isEqualTo: threadParentId)
    // Order replies chronologically (oldest first in the thread view)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
    });
  }

  // *** NEW: Gets a single message by its ID (for the thread page header) ***
  Future<MessageModel?> getMessageById(
      String channelId, String messageId) async {
    try {
      final docSnapshot = await _channelsCollection
          .doc(channelId)
          .collection('messages')
          .doc(messageId)
          .get();
      if (docSnapshot.exists) {
        return MessageModel.fromFirestore(docSnapshot);
      }
      return null;
    } catch (e) {
      print("Error fetching message by ID: $e");
      return null;
    }
  }

  String _getSenderName() {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return 'Unknown User';
    return currentUser.displayName ?? currentUser.email ?? 'Unknown User';
  }

  /// Sends a text message, optionally as a reply within a thread
  Future<void> sendTextMessage(String channelId, String text,
      {String? threadParentId}) async { // *** Added threadParentId parameter ***
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final String senderName = _getSenderName();

    final newMessageData = {
      'senderId': currentUser.uid,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
      'messageType': 'text',
      'text': text,
      'fileUrl': null,
      'fileName': null,
      'reactions': {},
      'replyCount': 0, // *** Initialize replyCount ***
      'threadParentId': threadParentId, // *** Add threadParentId ***
    };

    // Use a transaction to safely increment replyCount if this is a reply
    if (threadParentId != null) {
      final DocumentReference parentMessageRef =
      _channelsCollection.doc(channelId).collection('messages').doc(threadParentId);
      final DocumentReference newMessageRef =
      _channelsCollection.doc(channelId).collection('messages').doc(); // Generate new ID

      await _firestore.runTransaction((transaction) async {
        // Increment replyCount on the parent
        transaction.update(parentMessageRef, {
          'replyCount': FieldValue.increment(1),
        });
        // Create the new reply message
        transaction.set(newMessageRef, newMessageData);
      });
    } else {
      // Just add the message if it's not a reply
      await _channelsCollection
          .doc(channelId)
          .collection('messages')
          .add(newMessageData);
    }
  }

  /// Sends a file message, optionally as a reply within a thread
  Future<void> sendFileMessage(String channelId, PlatformFile file,
      {String? threadParentId}) async { // *** Added threadParentId parameter ***
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // 1. Determine Message Type (unchanged)
    String messageType = 'file';
    final String extension = file.extension?.toLowerCase() ?? '';
    if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
      messageType = 'image';
    } else if (['mp4', 'mov', 'avi'].contains(extension)) {
      messageType = 'video';
    } else if (extension == 'pdf') {
      messageType = 'pdf';
    }

    // 2. Upload file to Firebase Storage (unchanged)
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final String path = 'announcements/$channelId/$fileName';
    final File localFile = File(file.path!);
    final UploadTask uploadTask = _storage.ref().child(path).putFile(localFile);
    final TaskSnapshot snapshot = await uploadTask;
    final String downloadUrl = await snapshot.ref.getDownloadURL();

    // 3. Prepare message data
    final String senderName = _getSenderName();
    final newMessageData = {
      'senderId': currentUser.uid,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
      'messageType': messageType,
      'text': null,
      'fileUrl': downloadUrl,
      'fileName': file.name,
      'reactions': {},
      'replyCount': 0, // *** Initialize replyCount ***
      'threadParentId': threadParentId, // *** Add threadParentId ***
    };

    // Use a transaction to safely increment replyCount if this is a reply
    if (threadParentId != null) {
      final DocumentReference parentMessageRef =
      _channelsCollection.doc(channelId).collection('messages').doc(threadParentId);
      final DocumentReference newMessageRef =
      _channelsCollection.doc(channelId).collection('messages').doc(); // Generate new ID

      await _firestore.runTransaction((transaction) async {
        // Increment replyCount on the parent
        transaction.update(parentMessageRef, {
          'replyCount': FieldValue.increment(1),
        });
        // Create the new reply message
        transaction.set(newMessageRef, newMessageData);
      });
    } else {
      // Just add the message if it's not a reply
      await _channelsCollection
          .doc(channelId)
          .collection('messages')
          .add(newMessageData);
    }
  }

  Future<void> toggleReaction(
      String channelId, String messageId, String emoji) async {
    // ... (This function remains unchanged)
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
        Map<String, dynamic> reactions =
            (messageSnap.data() as Map<String, dynamic>)['reactions'] ?? {};
        List<dynamic> userList = reactions[emoji] ?? [];
        if (userList.contains(userId)) {
          userList.remove(userId);
        } else {
          userList.add(userId);
        }
        if (userList.isEmpty) {
          reactions.remove(emoji);
        } else {
          reactions[emoji] = userList;
        }
        transaction.update(messageRef, {'reactions': reactions});
      });
    } catch (e) {
      print("Failed to toggle reaction: $e");
    }
  }
}
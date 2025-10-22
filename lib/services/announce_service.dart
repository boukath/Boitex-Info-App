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

  /// Gets a real-time stream of all channels
  Stream<List<ChannelModel>> getChannels() {
    return _channelsCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ChannelModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Creates a new channel (Salon)
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
      // Handle potential errors, e.g., permissions
      print('Error creating channel: $e');
      rethrow;
    }
  }

  // --- Message Methods ---

  /// Gets a real-time stream of messages for a specific channel, ordered by time
  Stream<List<MessageModel>> getMessages(String channelId) {
    return _channelsCollection
        .doc(channelId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Helper to get current user's name
  String _getSenderName() {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return 'Unknown User';
    return currentUser.displayName ?? currentUser.email ?? 'Unknown User';
  }

  /// Sends a new text message to a channel
  Future<void> sendTextMessage(String channelId, String text) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return; // Not logged in

    final String senderName = _getSenderName();

    final newMessage = {
      'senderId': currentUser.uid,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
      'messageType': 'text',
      'text': text,
      'fileUrl': null,
      'fileName': null,
      'reactions': {}, // Initialize reactions
    };

    await _channelsCollection
        .doc(channelId)
        .collection('messages')
        .add(newMessage);
  }

  /// Uploads a file and sends the corresponding message
  Future<void> sendFileMessage(String channelId, PlatformFile file) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // 1. Determine Message Type
    String messageType = 'file';
    final String extension = file.extension?.toLowerCase() ?? '';
    if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
      messageType = 'image';
    } else if (['mp4', 'mov', 'avi'].contains(extension)) {
      messageType = 'video';
    } else if (extension == 'pdf') {
      messageType = 'pdf';
    }

    // 2. Upload file to Firebase Storage
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final String path = 'announcements/$channelId/$fileName';
    final File localFile = File(file.path!);

    final UploadTask uploadTask = _storage.ref().child(path).putFile(localFile);
    final TaskSnapshot snapshot = await uploadTask;
    final String downloadUrl = await snapshot.ref.getDownloadURL();

    // 3. Create the message in Firestore
    final String senderName = _getSenderName();
    final newMessage = {
      'senderId': currentUser.uid,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
      'messageType': messageType,
      'text': null,
      'fileUrl': downloadUrl,
      'fileName': file.name, // Store original file name
      'reactions': {}, // Initialize reactions
    };

    await _channelsCollection
        .doc(channelId)
        .collection('messages')
        .add(newMessage);
  }

  /// Toggles an emoji reaction on a message
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

        // Get current reactions, ensuring it's a Map<String, dynamic>
        Map<String, dynamic> reactions =
            (messageSnap.data() as Map<String, dynamic>)['reactions'] ?? {};

        // Get the list of users for this emoji, ensuring it's a List<dynamic>
        List<dynamic> userList = reactions[emoji] ?? [];

        if (userList.contains(userId)) {
          // User has reacted, remove their reaction
          userList.remove(userId);
        } else {
          // User has not reacted, add their reaction
          userList.add(userId);
        }

        // Update the reactions map
        if (userList.isEmpty) {
          // If no one has this reaction anymore, remove the emoji key
          reactions.remove(emoji);
        } else {
          reactions[emoji] = userList;
        }

        // Commit the change
        transaction.update(messageRef, {'reactions': reactions});
      });
    } catch (e) {
      print("Failed to toggle reaction: $e");
      // Optionally show a snackbar to the user
    }
  }
}
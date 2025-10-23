import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:boitex_info_app/models/channel_model.dart';
import 'package:boitex_info_app/models/message_model.dart'; // Uses simplified model
import 'package:file_picker/file_picker.dart';

class AnnounceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final CollectionReference _channelsCollection =
  FirebaseFirestore.instance.collection('channels');
  // *** NEW: Reference to users collection ***
  final CollectionReference _usersCollection =
  FirebaseFirestore.instance.collection('users');

  // --- Channel Methods (Unchanged) ---

  Stream<List<ChannelModel>> getChannels() {
    // ... same as before ...
    return _channelsCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ChannelModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> createChannel(String name, String description) async {
    // ... same as before ...
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

  /// Gets ALL messages for a specific channel, ordered chronologically (oldest first)
  Stream<List<MessageModel>> getMessages(String channelId) {
    // ... same as before ...
    return _channelsCollection
        .doc(channelId)
        .collection('messages')
        .orderBy('timestamp', descending: false) // Standard chat order
        .snapshots()
        .map((snapshot) {
      print('[AnnounceService] getMessages Snapshot: ${snapshot.docs.length} docs for channel $channelId');
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
    });
  }


  // *** UPDATED: Now async and fetches from Firestore ***
  Future<String> _getSenderName() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return 'Unknown User';

    try {
      // Fetch the user document from Firestore
      final userDoc = await _usersCollection.doc(currentUser.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        // Use the displayName field from Firestore
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['displayName'] ?? currentUser.email ?? 'Unknown User';
      } else {
        // Fallback if user document doesn't exist
        return currentUser.email ?? 'Unknown User';
      }
    } catch (e) {
      print("Error fetching user displayName: $e");
      // Fallback on error
      return currentUser.email ?? 'Unknown User';
    }
  }

  /// Sends a text message (no thread parameters)
  Future<void> sendTextMessage(String channelId, String text) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // *** Await the Firestore fetch ***
    final String senderName = await _getSenderName();

    final newMessageData = {
      'senderId': currentUser.uid,
      'senderName': senderName, // Use name fetched from Firestore
      'timestamp': FieldValue.serverTimestamp(),
      'messageType': 'text',
      'text': text,
      'fileUrl': null,
      'fileName': null,
      'reactions': {},
    };

    await _channelsCollection
        .doc(channelId)
        .collection('messages')
        .add(newMessageData);
  }

  /// Sends a file message (no thread parameters)
  Future<void> sendFileMessage(String channelId, PlatformFile file) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Determine Message Type
    String messageType = 'file';
    // ... (rest of type determination code unchanged) ...
    final String extension = file.extension?.toLowerCase() ?? '';
    if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
      messageType = 'image';
    } else if (['mp4', 'mov', 'avi', 'mkv'].contains(extension)) {
      messageType = 'video';
    } else if (extension == 'pdf') {
      messageType = 'pdf';
    }


    // Upload file to Firebase Storage
    final String uniqueFileName = '${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final String path = 'announcements/$channelId/$uniqueFileName';
    if (file.path == null) {
      print("Error: File path is null for ${file.name}");
      throw Exception("Cannot upload file without a valid path.");
    }
    final File localFile = File(file.path!);

    try {
      final UploadTask uploadTask = _storage.ref().child(path).putFile(localFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // *** Await the Firestore fetch ***
      final String senderName = await _getSenderName();

      // Prepare message data
      final newMessageData = {
        'senderId': currentUser.uid,
        'senderName': senderName, // Use name fetched from Firestore
        'timestamp': FieldValue.serverTimestamp(),
        'messageType': messageType,
        'text': null,
        'fileUrl': downloadUrl,
        'fileName': file.name,
        'reactions': {},
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

  /// Toggles an emoji reaction (Unchanged)
  Future<void> toggleReaction(
      String channelId, String messageId, String emoji) async {
    // ... same as before ...
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
        Map<String, dynamic> reactions = messageData?['reactions'] as Map<String, dynamic>? ?? {};
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
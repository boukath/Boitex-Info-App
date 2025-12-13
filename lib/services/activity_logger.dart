// lib/services/activity_logger.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityLogger {
  static Future<void> logActivity({
    required String message,
    required String category,
    String? interventionId,
    String? interventionCode,
    String? storeName,
    String? storeLocation,
    String? invoiceUrl,
    String? clientName,
    String? replacementRequestId,
    // ADDED: Parameters for completion proof
    List<String>? completionPhotoUrls,
    String? completionSignatureUrl,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['displayName'] ?? user.email;

      await FirebaseFirestore.instance.collection('global_activity_log').add({
        'message': message,
        'category': category,
        'interventionId': interventionId,
        'interventionCode': interventionCode,
        'storeName': storeName,
        'storeLocation': storeLocation,
        'invoiceUrl': invoiceUrl,
        'clientName': clientName,
        'replacementRequestId': replacementRequestId,
        'completionPhotoUrls': completionPhotoUrls,     // ADDED
        'completionSignatureUrl': completionSignatureUrl, // ADDED
        'userId': user.uid,
        'userEmail': user.email,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging activity: $e');
    }
  }
}
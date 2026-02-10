// lib/screens/settings/widgets/profile_header.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class ProfileHeader extends StatefulWidget {
  const ProfileHeader({super.key});

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  // B2 Configuration (Same as your other files)
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  Future<void> _handlePhotoChange() async {
    try {
      // 1. Pick Image
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, // Resize for avatar optimization
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();

      // 2. Upload to B2
      final String? photoUrl = await _uploadToB2(bytes);

      if (photoUrl != null) {
        // 3. Update Firebase Auth (Immediate Local Update)
        await currentUser?.updatePhotoURL(photoUrl);

        // 4. Update Firestore (For other users to see)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser?.uid)
            .update({'photoUrl': photoUrl});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Photo de profil mise à jour !"), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      debugPrint("Error updating photo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<String?> _uploadToB2(Uint8List bytes) async {
    try {
      // A. Get Upload URL
      final authResponse = await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (authResponse.statusCode != 200) throw "Auth B2 Failed";
      final creds = json.decode(authResponse.body);

      // B. Prepare Upload
      final fileName = 'user_avatars/${currentUser?.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final sha1Hash = sha1.convert(bytes).toString();

      // C. Upload
      final uploadResponse = await http.post(
        Uri.parse(creds['uploadUrl']),
        headers: {
          'Authorization': creds['authorizationToken'],
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': 'image/jpeg',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': bytes.length.toString(),
        },
        body: bytes,
      );

      if (uploadResponse.statusCode == 200) {
        final body = json.decode(uploadResponse.body);
        return creds['downloadUrlPrefix'] + Uri.encodeComponent(body['fileName']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 VIBE: Premium Gradient for fallback
    const gradientColors = [Color(0xFF2962FF), Color(0xFF00E676)];

    // Get current photo from Auth (fastest)
    final photoUrl = currentUser?.photoURL;
    final initials = (currentUser?.displayName?.isNotEmpty == true)
        ? currentUser!.displayName!.trim().substring(0, 2).toUpperCase()
        : "US";

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        // Premium shadow at bottom only
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 10),
            blurRadius: 20,
          )
        ],
      ),
      child: Column(
        children: [
          // --- AVATAR SECTION ---
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              // The Avatar Circle
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: photoUrl == null ? const LinearGradient(colors: gradientColors) : null,
                  image: photoUrl != null
                      ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                      : null,
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
                  ],
                ),
                child: photoUrl == null
                    ? Center(
                  child: Text(
                    initials,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                  ),
                )
                    : null,
              ),

              // The Edit Badge (Glassmorphism Vibe)
              GestureDetector(
                onTap: _isUploading ? null : _handlePhotoChange,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
                  ),
                  child: _isUploading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.camera_alt, size: 20, color: Color(0xFF2962FF)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // --- NAME & EMAIL ---
          Text(
            currentUser?.displayName ?? "Utilisateur",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            currentUser?.email ?? "",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
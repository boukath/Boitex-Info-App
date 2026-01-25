// lib/screens/service_technique/widgets/add_log_sheet.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
// ignore: unused_import
import 'package:path_provider/path_provider.dart';

// ✅ NETWORK IMPORTS
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';

// 📦 Data Class for Local Media
class LocalMedia {
  final XFile file;
  final bool isVideo;
  final Uint8List? thumbnailBytes;

  LocalMedia({
    required this.file,
    this.isVideo = false,
    this.thumbnailBytes,
  });
}

class AddLogSheet extends StatefulWidget {
  final String installationId;

  const AddLogSheet({super.key, required this.installationId});

  @override
  State<AddLogSheet> createState() => _AddLogSheetState();
}

class _AddLogSheetState extends State<AddLogSheet> {
  final TextEditingController _noteController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<LocalMedia> _attachments = [];

  String _selectedType = 'work';
  bool _isSubmitting = false;

  // ☁️ URL DIRECTE (On utilise celle-ci car on est sûr de la région)
  final String _b2CloudFunctionUrl =
      'https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl';

  final Map<String, dynamic> _logTypes = {
    'work': {'label': 'Travail', 'icon': Icons.build, 'color': Colors.blue},
    'blockage': {
      'label': 'Blocage',
      'icon': Icons.warning_amber,
      'color': Colors.red
    },
    'material': {
      'label': 'Matériel',
      'icon': Icons.inventory_2,
      'color': Colors.orange
    },
    'info': {
      'label': 'Info',
      'icon': Icons.info_outline,
      'color': Colors.grey
    },
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 16,
          right: 16,
          top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Nouveau Log",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Type Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _logTypes.entries.map((entry) {
                final isSelected = _selectedType == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(entry.value['label']),
                    avatar: Icon(entry.value['icon'],
                        size: 16,
                        color: isSelected ? Colors.white : entry.value['color']),
                    selected: isSelected,
                    selectedColor: entry.value['color'],
                    labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87),
                    onSelected: _isSubmitting
                        ? null
                        : (bool selected) {
                      setState(() => _selectedType = entry.key);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Text Input
          TextField(
            controller: _noteController,
            maxLines: 3,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              hintText: "Décrivez l'action...",
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),

          // Media Section
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildAddButton(
                  icon: Icons.camera_alt,
                  label: "Caméra",
                  color: Colors.blue.shade50,
                  iconColor: Colors.blue,
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 8),
                _buildAddButton(
                  icon: Icons.photo_library,
                  label: "Galerie",
                  color: Colors.purple.shade50,
                  iconColor: Colors.purple,
                  onTap: _showGalleryOptions,
                ),
                const SizedBox(width: 12),
                ..._attachments.map((media) => _buildMediaPreview(media)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitLog,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                _isSubmitting ? Colors.grey : Colors.blue.shade800,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white),
              label: Text(
                _isSubmitting ? "ENREGISTREMENT..." : "ENREGISTRER",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------------
  // ☁️ B2 UPLOAD LOGIC (FIXED: Manual Authenticated HTTP Call)
  // ------------------------------------------------------------------------

  // 1. Get Credentials
  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("❌ Erreur: Utilisateur non connecté.");
        return null;
      }

      // ✅ 1. Récupérer le Token Auth Firebase
      final token = await user.getIdToken();

      // ✅ 2. Appel HTTP manuel sécurisé (Contourne les problèmes de région du SDK)
      // Note: On utilise POST car c'est une fonction 'onCall' (Callable)
      final response = await http.post(
        Uri.parse(_b2CloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // 🔑 La clé manquante !
        },
        // Le format standard pour les fonctions Callable est { "data": ... }
        body: json.encode({'data': {}}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        // Les fonctions Callable retournent le résultat dans un champ "result"
        final data = jsonResponse['result'] ?? jsonResponse;
        return Map<String, dynamic>.from(data);
      } else {
        debugPrint(
            '❌ Erreur HTTP Cloud Function: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Exception Cloud Function: $e');
      return null;
    }
  }

  // 2. Upload File (Updated to use XFile and correct MimeType)
  Future<String?> _uploadFileToB2(
      XFile file, Map<String, dynamic> b2Credentials) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final Uri uploadUri = Uri.parse(b2Credentials['uploadUrl']);

      // Generate a clean filename with timestamp
      final String fileName =
          "logs/${DateTime.now().millisecondsSinceEpoch}_${file.name.split('/').last}";

      // ✅ DETECT REAL MIME TYPE
      final String mimeType = file.mimeType ?? 'application/octet-stream';

      final response = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Credentials['authorizationToken'],
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': mimeType,
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        return b2Credentials['downloadUrlPrefix'] +
            (responseBody['fileName'] as String)
                .split('/')
                .map(Uri.encodeComponent)
                .join('/');
      } else {
        debugPrint('Failed to upload to B2: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file to B2: $e');
      return null;
    }
  }

  // ------------------------------------------------------------------------
  // 🚀 SUBMIT WORKFLOW
  // ------------------------------------------------------------------------

  Future<void> _submitLog() async {
    if (_noteController.text.isEmpty && _attachments.isEmpty) return;

    // 1. Lock UI
    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final batch = FirebaseFirestore.instance.batch();
      List<String> uploadedUrls = [];

      // 2. Upload Media FIRST
      if (_attachments.isNotEmpty) {
        // ✅ Récupération des clés avec la nouvelle méthode HTTP
        final credentials = await _getB2UploadCredentials();

        if (credentials != null) {
          for (var media in _attachments) {
            final String? url = await _uploadFileToB2(media.file, credentials);
            if (url != null) {
              uploadedUrls.add(url);
            }
          }
        } else {
          // ⚠️ Ici, l'erreur est propagée pour être affichée dans le SnackBar
          throw Exception("Échec de l'authentification B2 (Clés nulles).");
        }
      }

      // 3. Prepare Log Data
      final logRef = FirebaseFirestore.instance
          .collection('installations')
          .doc(widget.installationId)
          .collection('daily_logs')
          .doc();

      final logData = {
        'id': logRef.id,
        'type': _selectedType,
        'description': _noteController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'technicianId': user?.uid ?? 'unknown',
        'technicianName': user?.displayName ?? 'Technicien',
        'mediaUrls': uploadedUrls,
        'mediaStatus':
        _attachments.isNotEmpty && uploadedUrls.isEmpty ? 'error' : 'ready',
      };

      // 4. Batch Updates & Status Logic
      final installationRef = FirebaseFirestore.instance
          .collection('installations')
          .doc(widget.installationId);

      // 🔍 READ FIRST: Check current status to decide if we update it
      // This prevents re-opening 'Terminée' jobs accidentally.
      final installationDoc = await installationRef.get();

      Map<String, dynamic> installationUpdateData = {
        'lastActivity': FieldValue.serverTimestamp(),
      };

      String feedbackMessage = "Log ajouté avec succès !";

      if (installationDoc.exists) {
        final currentStatus = installationDoc.data()?['status'];

        // ✅ AUTO-UPDATE LOGIC:
        // Only switch to 'En Cours' if it is currently 'Planifiée'
        if (currentStatus == 'Planifiée') {
          installationUpdateData['status'] = 'En Cours';
          feedbackMessage = "Log ajouté & Installation démarrée (En Cours) 🚀";
        }
      }

      // Add operations to batch
      batch.set(logRef, logData);
      batch.update(installationRef, installationUpdateData);

      // Commit all changes atomically
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(feedbackMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // ✅ Affiche l'erreur réelle à l'utilisateur pour le débogage
      debugPrint("Error submitting log: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Erreur: ${e.toString().replaceAll("Exception:", "")}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------------------
  // 📸 UI HELPERS
  // ------------------------------------------------------------------------

  Widget _buildAddButton(
      {required IconData icon,
        required String label,
        required Color color,
        required Color iconColor,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: _isSubmitting ? null : onTap,
      child: Container(
        width: 80,
        decoration:
        BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: iconColor,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(LocalMedia media) {
    return Stack(
      children: [
        Container(
          width: 80,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black,
            image: media.isVideo && media.thumbnailBytes != null
                ? DecorationImage(
                image: MemoryImage(media.thumbnailBytes!),
                fit: BoxFit.cover,
                opacity: 0.7)
                : DecorationImage(
                image: FileImage(File(media.file.path)), fit: BoxFit.cover),
          ),
          child: media.isVideo
              ? const Center(
              child: Icon(Icons.play_circle_fill,
                  color: Colors.white, size: 30))
              : null,
        ),
        if (!_isSubmitting)
          Positioned(
            top: 2,
            right: 10,
            child: GestureDetector(
              onTap: () => setState(() => _attachments.remove(media)),
              child: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.close, size: 14, color: Colors.red)),
            ),
          )
      ],
    );
  }

  void _showGalleryOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.image, color: Colors.blue),
            title: const Text("Photos (Multiples)"),
            onTap: () {
              Navigator.pop(ctx);
              _pickMultiImages();
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: Colors.purple),
            title: const Text("Vidéo"),
            onTap: () {
              Navigator.pop(ctx);
              _pickVideo();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image =
    await _picker.pickImage(source: source, imageQuality: 50);
    if (image != null) {
      setState(() => _attachments.add(LocalMedia(file: image, isVideo: false)));
    }
  }

  Future<void> _pickMultiImages() async {
    final List<XFile> images = await _picker.pickMultiImage(imageQuality: 50);
    if (images.isNotEmpty) {
      setState(() {
        _attachments
            .addAll(images.map((x) => LocalMedia(file: x, isVideo: false)));
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      final Uint8List? thumb = await VideoThumbnail.thumbnailData(
        video: video.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 128,
        quality: 50,
      );
      setState(() {
        _attachments.add(
            LocalMedia(file: video, isVideo: true, thumbnailBytes: thumb));
      });
    }
  }
}
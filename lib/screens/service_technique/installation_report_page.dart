// lib/screens/service_technique/installation_report_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'package:url_launcher/url_launcher.dart';

// Imports for B2 Upload
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class InstallationReportPage extends StatefulWidget {
  final String installationId;
  const InstallationReportPage({super.key, required this.installationId});

  @override
  State<InstallationReportPage> createState() => _InstallationReportPageState();
}

class _InstallationReportPageState extends State<InstallationReportPage> {
  DocumentSnapshot? _installationDoc;
  bool _isLoadingData = true;
  bool _isSaving = false;

  final _notesController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<XFile> _mediaFilesToUpload = [];
  List<String> _existingMediaUrls = [];

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  // The URL for our deployed Cloud Function
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';

  @override
  void initState() {
    super.initState();
    _fetchInstallationDetails();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _fetchInstallationDetails() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('installations')
          .doc(widget.installationId)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _installationDoc = snapshot;
          _notesController.text = data['notes'] ?? '';
          // Load existing media URLs (supports old 'photoUrls' field for compatibility)
          _existingMediaUrls =
          List<String>.from(data['mediaUrls'] ?? data['photoUrls'] ?? []);
          _isLoadingData = false;
        });
      } else {
        setState(() {
          _isLoadingData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Installation non trouvée.')));
      }
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _pickMedia() async {
    final List<XFile> pickedFiles = await _picker.pickMultipleMedia();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _mediaFilesToUpload.addAll(pickedFiles);
      });
    }
  }

  // --- START: B2 UPLOAD LOGIC ---

  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response =
      await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to get B2 credentials: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error calling Cloud Function: $e');
      return null;
    }
  }

  Future<String?> _uploadFileToB2(
      XFile file, Map<String, dynamic> b2Credentials) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final Uri uploadUri = Uri.parse(b2Credentials['uploadUrl']);
      final String fileName = file.name.split('/').last;

      final response = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Credentials['authorizationToken'],
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': file.mimeType ?? 'b2/x-auto',
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
        print('Failed to upload to B2: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading file to B2: $e');
      return null;
    }
  }

  // --- END: B2 UPLOAD LOGIC ---

  // ✅ --- START: UPDATED _saveReport FUNCTION ---
  Future<void> _saveReport() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      String? signatureUrl;

      // 1. Upload Signature (Unchanged)
      if (signatureBytes != null) {
        final storageRef = FirebaseStorage.instance.ref().child(
            'signatures/installations/${widget.installationId}_${DateTime.now().millisecondsSinceEpoch}.png');
        final uploadTask = storageRef.putData(signatureBytes);
        final snapshot = await uploadTask.whenComplete(() => {});
        signatureUrl = await snapshot.ref.getDownloadURL();
      }

      // 2. Upload Media to Backblaze B2
      List<String> uploadedMediaUrls = List.from(_existingMediaUrls);
      for (XFile file in _mediaFilesToUpload) {
        // 1. Get temporary credentials
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) {
          throw Exception('Could not get B2 upload credentials.');
        }
        // 2. Upload the file
        final downloadUrl = await _uploadFileToB2(file, b2Credentials);
        if (downloadUrl != null) {
          uploadedMediaUrls.add(downloadUrl);
        } else {
          print('Skipping file due to upload failure: ${file.name}');
        }
      }

      // 3. Update Firestore Document
      await FirebaseFirestore.instance
          .collection('installations')
          .doc(widget.installationId)
          .update({
        'status': 'Terminé',
        'notes': _notesController.text,
        'signatureUrl': signatureUrl,
        'mediaUrls': uploadedMediaUrls, // <-- Save to the new 'mediaUrls' field
        'photoUrls': FieldValue.delete(), // <-- Delete the old 'photoUrls' field
        'completedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rapport enregistré avec succès!')));
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement: $e')));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  // ✅ --- END: UPDATED _saveReport FUNCTION ---

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
          appBar: AppBar(title: const Text('Rapport d\'Installation')),
          body: const Center(child: CircularProgressIndicator()));
    }

    final data = _installationDoc?.data() as Map<String, dynamic>?;
    final clientName = data?['clientName'] ?? 'N/A';
    final storeName = data?['storeName'] ?? 'N/A';

    // Check if the report is read-only (already completed)
    final bool isReadOnly = (_installationDoc?.data()
    as Map<String, dynamic>?)?['status'] ==
        'Terminé';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport d\'Installation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(clientName,
                style: Theme.of(context).textTheme.headlineSmall),
            Text(storeName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            TextField(
              controller: _notesController,
              readOnly: isReadOnly, // Make read-only if completed
              decoration: const InputDecoration(
                labelText: 'Notes d\'installation',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 24),

            // ✅ REPLACED GridView with our new _buildMediaSection
            _buildMediaSection(isReadOnly),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Signature du Client',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (!isReadOnly) // Only show "Clear" button if editable
                  TextButton(
                      child: const Text('Effacer'),
                      onPressed: () => _signatureController.clear())
              ],
            ),
            const SizedBox(height: 8),

            // Handle Signature display
            _buildSignatureSection(isReadOnly, data?['signatureUrl']),

            const SizedBox(height: 32),
            if (_isSaving)
              const Center(child: CircularProgressIndicator())
            else if (!isReadOnly) // Only show "Save" button if editable
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveReport,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Terminer l\'Installation'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ --- START: ADDED MEDIA SECTION WIDGETS ---

  Widget _buildMediaSection(bool isReadOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photos & Vidéos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_existingMediaUrls.isEmpty && _mediaFilesToUpload.isEmpty)
          const Text('Aucun fichier ajouté.', style: TextStyle(color: Colors.grey)),

        // Display existing media from Backblaze
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: _existingMediaUrls
              .asMap() // Get index for the gallery
              .map((index, url) => MapEntry(
            index,
            _buildMediaThumbnail(
              url: url,
              isReadOnly: isReadOnly,
              onTap: () => _openMedia(url),
            ),
          ))
              .values
              .toList(),
        ),

        // Display new media to be uploaded
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: _mediaFilesToUpload
              .map((file) => _buildMediaThumbnail(
            file: file,
            isReadOnly: isReadOnly,
          ))
              .toList(),
        ),

        const SizedBox(height: 16),
        if (!isReadOnly)
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Ajouter Photos/Vidéos'),
              onPressed: _pickMedia,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }

  // Helper function to check for common video extensions
  bool _isVideoUrl(String path) {
    final lowercasePath = path.toLowerCase();
    return lowercasePath.endsWith('.mp4') ||
        lowercasePath.endsWith('.mov') ||
        lowercasePath.endsWith('.avi') ||
        lowercasePath.endsWith('.mkv');
  }

  // New function to handle opening the correct media player
  void _openMedia(String url) {
    if (_isVideoUrl(url)) {
      // --- Open the Video Player Page ---
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(videoUrl: url),
        ),
      );
    } else {
      // --- Open the Image Gallery Page ---

      // 1. Filter the list to get only image URLs
      final List<String> imageLinks =
      _existingMediaUrls.where((link) => !_isVideoUrl(link)).toList();

      // 2. Find the index of the image that was tapped
      final int initialIndex = imageLinks.indexOf(url);
      if (imageLinks.isEmpty) return; // No images to show

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImageGalleryPage(
            imageUrls: imageLinks,
            initialIndex: (initialIndex != -1) ? initialIndex : 0,
          ),
        ),
      );
    }
  }

  Widget _buildMediaThumbnail({
    String? url,
    XFile? file,
    required bool isReadOnly,
    VoidCallback? onTap,
  }) {
    bool isVideo = (url != null && _isVideoUrl(url)) || (file != null && _isVideoUrl(file.path));
    Widget mediaContent;

    if (file != null) {
      // New file (XFile)
      if (isVideo) {
        mediaContent = const Center(
            child: Icon(Icons.videocam, size: 40, color: Colors.black54));
      } else {
        mediaContent = ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.file(File(file.path),
              width: 100, height: 100, fit: BoxFit.cover),
        );
      }
    } else if (url != null && url.isNotEmpty) {
      // Existing file (URL)
      if (isVideo) {
        mediaContent = const Center(
            child: Icon(Icons.videocam, size: 40, color: Colors.black54));
      } else {
        mediaContent = Hero(
          tag: url, // Tag for hero animation
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.network(
              url,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
              progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
      }
    } else {
      mediaContent = const Icon(Icons.image_not_supported, color: Colors.grey);
    }

    return GestureDetector(
      onTap: (onTap != null)
          ? onTap
          : () {
        // Handle tap for new files (XFile)
        if (file != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Veuillez d\'abord enregistrer pour voir ce fichier.')),
          );
        }
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade200,
        ),
        child: Stack(
          children: [
            mediaContent,
            if (!isReadOnly && file != null)
              Positioned(
                top: -10,
                right: -10,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  onPressed: () {
                    setState(() {
                      _mediaFilesToUpload.remove(file);
                    });
                  },
                ),
              ),
            if (!isReadOnly && url != null)
              Positioned(
                top: -10,
                right: -10,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  onPressed: () {
                    setState(() {
                      _existingMediaUrls.remove(url);
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ ADDED: Widget to handle signature display
  Widget _buildSignatureSection(bool isReadOnly, String? signatureUrl) {
    if (isReadOnly && signatureUrl != null) {
      // If report is read-only and has a signature, display it
      return Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Image.network(
            signatureUrl,
            loadingBuilder: (context, child, progress) =>
            progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (context, error, stackTrace) =>
            const Text('Impossible de charger la signature'),
          ),
        ),
      );
    } else {
      // Otherwise, show the signature pad
      return Container(
        height: 150,
        decoration:
        BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
        child: Signature(
            controller: _signatureController,
            backgroundColor: Colors.grey[200]!),
      );
    }
  }
// ✅ --- END: ADDED MEDIA SECTION WIDGETS ---
}
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

// ✅ 1. ADD THIS IMPORT AT THE TOP OF THE FILE
import 'package:video_thumbnail/video_thumbnail.dart';

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

  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';

  // File size limit (50MB in bytes)
  static const int _maxFileSizeInBytes = 50 * 1024 * 1024;

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
          _existingMediaUrls =
          List<String>.from(data['mediaUrls'] ?? data['photoUrls'] ?? []);
          _isLoadingData = false;
        });
      } else {
        setState(() {
          _isLoadingData = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Installation non trouvée.')));
      }
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  // Pick media with file size check
  Future<void> _pickMedia() async {
    final List<XFile> pickedFiles = await _picker.pickMultipleMedia();
    if (pickedFiles.isEmpty) return;

    final List<XFile> validFiles = [];
    final List<String> rejectedFiles = [];

    for (final file in pickedFiles) {
      final int fileSize = await file.length();
      final bool isVideo = _isVideoUrl(file.name); // Using helper function

      if (isVideo && fileSize > _maxFileSizeInBytes) {
        rejectedFiles.add(
          '${file.name} (${(fileSize / 1024 / 1024).toStringAsFixed(1)} Mo)',
        );
      } else {
        validFiles.add(file);
      }
    }

    if (validFiles.isNotEmpty) {
      setState(() => _mediaFilesToUpload.addAll(validFiles));
    }

    if (rejectedFiles.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
          content: Text(
            'Fichiers suivants non ajoutés (limite 50 Mo):\n${rejectedFiles.join('\n')}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  // --- B2 UPLOAD LOGIC (Unchanged) ---
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
  // --- END B2 UPLOAD ---

  Future<void> _saveReport() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      String? signatureUrl;

      // 1. Upload Signature
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
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) {
          throw Exception('Could not get B2 upload credentials.');
        }
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
        'status': 'Terminée',
        'notes': _notesController.text,
        'signatureUrl': signatureUrl,
        'mediaUrls': uploadedMediaUrls,
        'photoUrls': FieldValue.delete(),
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rapport enregistré avec succès!')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

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
    final bool isReadOnly = data?['status'] == 'Terminée';

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
              readOnly: isReadOnly,
              decoration: const InputDecoration(
                labelText: 'Notes d\'installation',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 24),

            _buildMediaSection(isReadOnly), // Uses the modified thumbnail widget

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Signature du Client',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (!isReadOnly)
                  TextButton(
                      child: const Text('Effacer'),
                      onPressed: () => _signatureController.clear())
              ],
            ),
            const SizedBox(height: 8),

            _buildSignatureSection(isReadOnly, data?['signatureUrl']),

            const SizedBox(height: 32),
            if (_isSaving)
              const Center(child: CircularProgressIndicator())
            else if (!isReadOnly)
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

  // --- START: MEDIA SECTION WIDGETS ---

  Widget _buildMediaSection(bool isReadOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photos & Vidéos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_existingMediaUrls.isEmpty && _mediaFilesToUpload.isEmpty)
          const Text('Aucun fichier ajouté.',
              style: TextStyle(color: Colors.grey)),

        // Existing media
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: _existingMediaUrls
              .asMap()
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

        // New media
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

  // Helper to check for video extensions
  bool _isVideoUrl(String path) {
    final lowercasePath = path.toLowerCase();
    return lowercasePath.endsWith('.mp4') ||
        lowercasePath.endsWith('.mov') ||
        lowercasePath.endsWith('.avi') ||
        lowercasePath.endsWith('.mkv');
  }

  // Open the correct media player
  void _openMedia(String url) {
    if (_isVideoUrl(url)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(videoUrl: url),
        ),
      );
    } else {
      final List<String> imageLinks =
      _existingMediaUrls.where((link) => !_isVideoUrl(link)).toList();
      final int initialIndex = imageLinks.indexOf(url);
      if (imageLinks.isEmpty) return;

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

  // ✅ 2. THIS IS THE MODIFIED THUMBNAIL WIDGET
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
        // --- START NEW LOGIC FOR LOCAL VIDEO ---
        mediaContent = FutureBuilder<Uint8List?>(
          future: VideoThumbnail.thumbnailData(
            video: file.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 100,
            quality: 30,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasData && snapshot.data != null) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(11), // Match image border radius
                child: Image.memory(
                  snapshot.data!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              );
            }
            // Fallback icon
            return const Center(
                child: Icon(Icons.videocam, size: 40, color: Colors.black54));
          },
        );
        // --- END NEW LOGIC FOR LOCAL VIDEO ---
      } else {
        // Local Image
        mediaContent = ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.file(File(file.path),
              width: 100, height: 100, fit: BoxFit.cover),
        );
      }
    } else if (url != null && url.isNotEmpty) {
      // Existing file (URL)
      if (isVideo) {
        // --- START NEW LOGIC FOR NETWORK VIDEO ---
        mediaContent = FutureBuilder<Uint8List?>(
          future: VideoThumbnail.thumbnailData(
            video: url,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 100,
            quality: 30,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasData && snapshot.data != null) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.memory(
                  snapshot.data!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              );
            }
            // Fallback icon
            return const Center(
                child: Icon(Icons.videocam, size: 40, color: Colors.black54));
          },
        );
        // --- END NEW LOGIC FOR NETWORK VIDEO ---
      } else {
        // Network Image
        mediaContent = Hero(
          tag: url,
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

    // --- NO CHANGES to the GestureDetector or Container below ---
    return GestureDetector(
      onTap: (onTap != null)
          ? onTap
          : () {
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
          clipBehavior: Clip.none, // Allow overflow for the remove button
          children: [
            mediaContent, // This is now the FutureBuilder for videos
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

  // Widget to handle signature display
  Widget _buildSignatureSection(bool isReadOnly, String? signatureUrl) {
    if (isReadOnly && signatureUrl != null) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Image.network(
            signatureUrl,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (context, error, stackTrace) =>
            const Text('Impossible de charger la signature'),
          ),
        ),
      );
    } else {
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
// --- END: MEDIA SECTION WIDGETS ---
}
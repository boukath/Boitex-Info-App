// lib/screens/service_technique/intervention_details_page.dart

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:boitex_info_app/services/intervention_pdf_service.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';

// ✅ In‑app media viewers
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';

// ✅ 1. ADD THIS IMPORT AT THE TOP OF THE FILE
import 'package:video_thumbnail/video_thumbnail.dart';

// ----------------------------------------------------------------------
// Data model
// ----------------------------------------------------------------------
class AppUser {
  final String uid;
  final String displayName;

  AppUser({required this.uid, required this.displayName});

  @override
  bool operator ==(Object other) => other is AppUser && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}

// ----------------------------------------------------------------------
// Page
// ----------------------------------------------------------------------
class InterventionDetailsPage extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> interventionDoc;

  const InterventionDetailsPage({super.key, required this.interventionDoc});

  @override
  State<InterventionDetailsPage> createState() =>
      _InterventionDetailsPageState();
}

class _InterventionDetailsPageState extends State<InterventionDetailsPage> {
  // Controllers
  late final TextEditingController _managerNameController;
  late final TextEditingController _managerPhoneController;
  late final TextEditingController _managerEmailController; // ✅ ADDED
  late final TextEditingController _diagnosticController;
  late final TextEditingController _workDoneController;
  late final SignatureController _signatureController;

  // State
  String? _signatureImageUrl;
  String _currentStatus = 'Nouveau';
  List<AppUser> _allTechnicians = [];
  List<AppUser> _selectedTechnicians = [];
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _mediaFilesToUpload = [];
  final List<String> _existingMediaUrls = [];

  // Backblaze B2 helper function endpoint
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';

  // File size limit (50MB in bytes)
  static const int _maxFileSizeInBytes = 50 * 1024 * 1024;

  // Status options derived from current doc
  List<String> get statusOptions {
    final current =
        (widget.interventionDoc.data() ?? {})['status'] as String? ?? 'Nouveau';
    if (current == 'Clôturé' || current == 'Facturé') {
      return ['Clôturé', 'Facturé'];
    }
    return ['Nouveau', 'En cours', 'Terminé', 'En attente'];
  }

  // Read-only when closed or invoiced
  bool get isReadOnly {
    final status =
        (widget.interventionDoc.data() ?? {})['status'] as String? ?? 'Nouveau';
    return ['Clôturé', 'Facturé'].contains(status);
  }

  @override
  void initState() {
    super.initState();
    final data = widget.interventionDoc.data() ?? {};

    _managerNameController =
        TextEditingController(text: data['managerName'] ?? '');
    _managerPhoneController =
        TextEditingController(text: data['managerPhone'] ?? '');
    _managerEmailController =
        TextEditingController(text: data['managerEmail'] ?? ''); // ✅ ADDED
    _diagnosticController =
        TextEditingController(text: data['diagnostic'] ?? '');
    _workDoneController = TextEditingController(text: data['workDone'] ?? '');
    _signatureController = SignatureController();

    _signatureImageUrl = data['signatureUrl'] as String?;
    _currentStatus = data['status'] ?? 'Nouveau';
    _existingMediaUrls
        .addAll(List<String>.from(data['mediaUrls'] ?? const []));

    _fetchTechnicians().then((_) {
      final List<dynamic> assigned =
      List.from(data['assignedTechnicians'] ?? const []);
      _selectedTechnicians = _allTechnicians.where((tech) {
        return assigned.any((a) => (a is Map && a['uid'] == tech.uid));
      }).toList();
      if (mounted) setState(() {});
    });
  }

  // ----------------------------------------------------------------------
  // Theme to match Stock/Product pages
  // ----------------------------------------------------------------------
  ThemeData _interventionTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData( // <-- was CardTheme
        color: Colors.white.withOpacity(0.95),
        elevation: 8,
        shadowColor: const Color(0xFF667EEA).withOpacity(0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: TextStyle(color: Colors.grey.shade700),
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF667EEA),
          foregroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
      ),
      dividerTheme:
      const DividerThemeData(color: Color(0xFFE5E7EB), thickness: 1),
    );
  }

  // ----------------------------------------------------------------------
  // Data helpers
  // ----------------------------------------------------------------------
  Future<void> _fetchTechnicians() async {
    try {
      final query = await FirebaseFirestore.instance.collection('users').get();
      _allTechnicians = query.docs
          .map((doc) => AppUser(
        uid: doc.id,
        displayName: (doc.data()['displayName'] ?? 'No Name') as String,
      ))
          .toList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement des techniciens: $e')),
      );
    }
  }

  // Helper function for checking video type
  bool _isVideoPath(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv');
  }

  // Pick media with file size check
  Future<void> _pickMedia() async {
    final List<XFile> pickedFiles = await _picker.pickMultipleMedia();
    if (pickedFiles.isEmpty) return;

    final List<XFile> validFiles = [];
    final List<String> rejectedFiles = [];

    for (final file in pickedFiles) {
      final int fileSize = await file.length();
      final bool isVideo = _isVideoPath(file.name);

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

  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response =
      await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('Failed to get B2 credentials: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error calling Cloud Function: $e');
      return null;
    }
  }

  Future<String?> _uploadFileToB2(
      XFile file, Map<String, dynamic> b2Creds) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);

      final fileName = file.name.split('/').last;

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': file.mimeType ?? 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final encodedPath = (body['fileName'] as String)
            .split('/')
            .map(Uri.encodeComponent)
            .join('/');
        return (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
      } else {
        debugPrint('Failed to upload to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file to B2: $e');
      return null;
    }
  }

  // ✅ CORRECTED FUNCTION TO PREVENT RUNTIME ERROR
  Future<void> _saveReport() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    // Capture context-dependent variables BEFORE async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // 1) Signature
      String? newSignatureUrl = _signatureImageUrl;
      if (_signatureController.isNotEmpty) {
        final png = await _signatureController.toPngBytes();
        if (png != null) {
          final ref = FirebaseStorage.instance.ref().child(
              'signatures/interventions/${widget.interventionDoc.id}_${DateTime.now().millisecondsSinceEpoch}.png');
          final snap = await ref.putData(png).whenComplete(() {});
          newSignatureUrl = await snap.ref.getDownloadURL();
        }
      }

      // 2) Media uploads to B2
      final uploaded = List<String>.from(_existingMediaUrls);
      for (final file in _mediaFilesToUpload) {
        final creds = await _getB2UploadCredentials();
        if (creds == null) {
          throw Exception('Impossible de récupérer les accès B2.');
        }
        final url = await _uploadFileToB2(file, creds);
        if (url != null) {
          uploaded.add(url);
        } else {
          debugPrint('Skipping file due to upload failure: ${file.name}');
        }
      }

      // 3) Persist
      final Map<String, dynamic> reportData = {
        'managerName': _managerNameController.text.trim(),
        'managerPhone': _managerPhoneController.text.trim(),
        'managerEmail': _managerEmailController.text.trim(), // ✅ YOUR EMAIL FIELD
        'diagnostic': _diagnosticController.text.trim(),
        'workDone': _workDoneController.text.trim(),
        'signatureUrl': newSignatureUrl,
        'status': _currentStatus,
        'assignedTechnicians': _selectedTechnicians
            .map((t) => {'uid': t.uid, 'name': t.displayName})
            .toList(),
        'mediaUrls': uploaded,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final prevStatus = (widget.interventionDoc.data() ?? {})['status'];
      if (_currentStatus == 'Clôturé' && prevStatus != 'Clôturé') {
        reportData['closedAt'] = FieldValue.serverTimestamp();
      }

      await widget.interventionDoc.reference.update(reportData);

      // Check if mounted BEFORE showing snackbar and popping
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Rapport enregistré avec succès!')),
      );
      navigator.pop();

    } catch (e) {
      // Check if mounted BEFORE showing error
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'enregistrement: $e')),
      );
    } finally {
      // Add a mounted check here to prevent calling setState on a disposed widget
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ----------------------------------------------------------------------
  // PDF
  // ----------------------------------------------------------------------
  Future<void> _generateAndSharePdf() async {
    setState(() => _isLoading = true);
    try {
      final data = widget.interventionDoc.data() ?? {};
      Uint8List? signatureBytes;
      if (data['signatureUrl'] != null) {
        final r = await http.get(Uri.parse(data['signatureUrl'] as String));
        if (r.statusCode == 200) signatureBytes = r.bodyBytes;
      }
      final pdfData = {...data, 'signatureUrl': signatureBytes};
      await InterventionPdfService.generateAndSharePdf(pdfData);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la génération du PDF : $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ CORRECTED FUNCTION SYNTAX
  Future<void> _generateAndPrintPdf() async {
    setState(() => _isLoading = true);
    try {
      final data = widget.interventionDoc.data() ?? {};
      Uint8List? signatureBytes;
      if (data['signatureUrl'] != null) {
        final r = await http.get(Uri.parse(data['signatureUrl'] as String));
        if (r.statusCode == 200) signatureBytes = r.bodyBytes;
      }
      final pdfData = {...data, 'signatureUrl': signatureBytes};
      await InterventionPdfService.generateAndPrintPdf(pdfData);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar( // Corrected line
        SnackBar(content: Text('Erreur lors de l\'affichage du PDF : $e')),
      ); // Corrected line
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAndShowPdfViewer() async {
    setState(() => _isLoading = true);
    try {
      final data = widget.interventionDoc.data() ?? {};
      Uint8List? signatureBytes;
      if (data['signatureUrl'] != null) {
        final r = await http.get(Uri.parse(data['signatureUrl'] as String));
        if (r.statusCode == 200) signatureBytes = r.bodyBytes;
      }
      final pdfData = {...data, 'signatureUrl': signatureBytes};
      final Uint8List pdfBytes =
      await InterventionPdfService.generatePdfBytes(pdfData);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerPage(
            pdfBytes: pdfBytes,
            title: data['interventionCode'] ?? 'Aperçu',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la génération du PDF : $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    _managerEmailController.dispose(); // ✅ ADDED
    _diagnosticController.dispose();
    _workDoneController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // UI
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final data = widget.interventionDoc.data() ?? {};
    final createdAt = (data['createdAt'] as Timestamp).toDate();

    return Theme(
      data: _interventionTheme(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "${data['interventionCode'] ?? 'Détails'} - ${data['storeName'] ?? ''}",
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Aperçu PDF',
              onPressed: _isLoading ? null : _generateAndShowPdfViewer,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Partager PDF',
              onPressed: _isLoading ? null : _generateAndSharePdf,
            ),
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x33667EEA),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.purple.shade50,
                Colors.pink.shade50,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(data, createdAt),
                  const SizedBox(height: 24),
                  _buildReportForm(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> data, DateTime createdAt) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Demandé par ${data['createdByName']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Client: ${data['clientName']} - Magasin: ${data['storeName']}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              'Date de création: ${DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR').format(createdAt)}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Description du Problème:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(data['description'] ?? 'Non spécifié'),
          ],
        ),
      ),
    );
  }

  Widget _buildReportForm(BuildContext context) {
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Rapport d'Intervention",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _managerNameController,
            readOnly: isReadOnly,
            decoration:
            const InputDecoration(labelText: 'Nom du contact sur site'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _managerPhoneController,
            readOnly: isReadOnly,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone du contact'),
          ),
          const SizedBox(height: 16),

          // ✅ ADDED THIS BLOCK
          TextFormField(
            controller: _managerEmailController,
            readOnly: isReadOnly,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email du contact',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          // ✅ END OF ADDED BLOCK

          MultiSelectDialogField<AppUser>(
            items: _allTechnicians
                .map((t) => MultiSelectItem<AppUser>(t, t.displayName))
                .toList(),
            title: const Text('Techniciens'),
            selectedColor: const Color(0xFF667EEA),
            buttonText: const Text('Techniciens Assignés'),
            onConfirm: (results) {
              if (!isReadOnly) {
                setState(() => _selectedTechnicians = results);
              }
            },
            initialValue: _selectedTechnicians,
            chipDisplay: MultiSelectChipDisplay(
              onTap: (value) {
                if (!isReadOnly) {
                  setState(() => _selectedTechnicians.remove(value));
                }
              },
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC), // Match TextFormField
              border: Border.all(color: Colors.grey.shade200, width: 1),
              borderRadius: BorderRadius.circular(20),
            ),
            dialogWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _diagnosticController,
            readOnly: isReadOnly,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Diagnostique / Panne Signalée',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _workDoneController,
            readOnly: isReadOnly,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Travaux Effectués',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          _buildMediaSection(), // Uses the modified thumbnail widget
          const SizedBox(height: 24),
          const Text('Signature du Client',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_signatureImageUrl != null && _signatureController.isEmpty)
            Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFFF1F5F9), // Match empty signature bg
              ),
              child: Center(
                  child: Image.network(_signatureImageUrl!,
                      fit: BoxFit.contain)),
            )
          else if (!isReadOnly)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Signature(
                controller: _signatureController,
                height: 150,
                backgroundColor: const Color(0xFFF1F5F9),
              ),
            ),
          if (!isReadOnly)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _signatureController.clear();
                  setState(() => _signatureImageUrl = null);
                },
                child: const Text('Effacer la signature'),
              ),
            ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _currentStatus,
            items: statusOptions
                .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                .toList(),
            onChanged:
            isReadOnly ? null : (v) => setState(() => _currentStatus = v!),
            decoration:
            const InputDecoration(labelText: "Statut de l'intervention"),
          ),
          const SizedBox(height: 24),
          if (!isReadOnly)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveReport,
                child: _isLoading
                    ? const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3)
                    : const Text('Enregistrer le Rapport'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photos & Vidéos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_existingMediaUrls.isEmpty && _mediaFilesToUpload.isEmpty)
          const Text('Aucun fichier ajouté.',
              style: TextStyle(color: Colors.grey)),

        // Existing (uploaded) media
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _existingMediaUrls
              .map((url) => _buildMediaThumbnail(url: url))
              .toList(),
        ),

        // Pending (local) media
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _mediaFilesToUpload
              .map((file) => _buildMediaThumbnail(file: file))
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
                backgroundColor: Colors.white, // Different style
                foregroundColor: const Color(0xFF667EEA),
                side: const BorderSide(color: Color(0xFF667EEA)),
              ),
            ),
          ),
      ],
    );
  }

  // ✅ 2. THIS IS THE MODIFIED THUMBNAIL WIDGET
  Widget _buildMediaThumbnail({String? url, XFile? file}) {
    final bool isVideo = (url != null && _isVideoPath(url)) ||
        (file != null && _isVideoPath(file.path));

    Widget content;
    if (file != null) {
      // Local not-yet-uploaded file
      if (isVideo) {
        // --- START NEW LOGIC FOR LOCAL VIDEO ---
        content = FutureBuilder<Uint8List?>(
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
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  snapshot.data!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              );
            }
            return const Center(
                child: Icon(Icons.videocam, size: 40, color: Colors.black54));
          },
        );
        // --- END NEW LOGIC FOR LOCAL VIDEO ---
      } else {
        // Local Image
        content = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(file.path),
              width: 100, height: 100, fit: BoxFit.cover),
        );
      }
    } else if (url != null && url.isNotEmpty) {
      // Existing URL
      if (isVideo) {
        // --- START NEW LOGIC FOR NETWORK VIDEO ---
        content = FutureBuilder<Uint8List?>(
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
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  snapshot.data!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              );
            }
            return const Center(
                child: Icon(Icons.videocam, size: 40, color: Colors.black54));
          },
        );
        // --- END NEW LOGIC FOR NETWORK VIDEO ---
      } else {
        // Network Image (No change)
        content = Hero(
          tag: url,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              loadingBuilder: (c, child, prog) => prog == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (c, e, s) =>
              const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
      }
    } else {
      content = const Icon(Icons.image_not_supported, color: Colors.grey);
    }

    return GestureDetector(
      onTap: () {
        // Local media can't be previewed in viewer until uploaded
        if (url == null || url.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                Text('Veuillez d\'abord enregistrer pour voir ce fichier.')),
          );
          return;
        }
        if (isVideo) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => VideoPlayerPage(videoUrl: url)),
          );
        } else {
          final images =
          _existingMediaUrls.where((u) => !_isVideoPath(u)).toList();
          if (images.isEmpty) return;
          final initial = images.indexOf(url);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ImageGalleryPage(
                imageUrls: images,
                initialIndex: initial != -1 ? initial : 0,
              ),
            ),
          );
        }
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          color: const Color(0xFFF1F5F9),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: content),

            // Remove button for local pending file
            if (!isReadOnly && file != null)
              Positioned(
                top: -10,
                right: -10,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  onPressed: () =>
                      setState(() => _mediaFilesToUpload.remove(file)),
                ),
              ),

            // Remove button for existing URL
            if (!isReadOnly && url != null)
              Positioned(
                top: -10,
                right: -10,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  onPressed: () =>
                      setState(() => _existingMediaUrls.remove(url)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
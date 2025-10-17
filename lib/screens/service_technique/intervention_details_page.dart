// lib/screens/service_technique/intervention_details_page.dart

import 'dart:io';
import 'dart:convert'; // ✅ ADDED for JSON decoding
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
import 'package:crypto/crypto.dart'; // ✅ ADDED for SHA1 hash

// Data model for users (unchanged)
class AppUser {
  final String uid;
  final String displayName;
  AppUser({required this.uid, required this.displayName});

  @override
  bool operator ==(Object other) => other is AppUser && other.uid == uid;
  @override
  int get hashCode => uid.hashCode;
}

class InterventionDetailsPage extends StatefulWidget {
  final DocumentSnapshot interventionDoc;
  const InterventionDetailsPage({super.key, required this.interventionDoc});
  @override
  State<InterventionDetailsPage> createState() => _InterventionDetailsPageState();
}

class _InterventionDetailsPageState extends State<InterventionDetailsPage> {
  // State variables (unchanged)
  late TextEditingController _managerNameController;
  late TextEditingController _managerPhoneController;
  late TextEditingController _diagnosticController;
  late TextEditingController _workDoneController;
  late SignatureController _signatureController;
  String? _signatureImageUrl;
  String _currentStatus = 'Nouveau';
  List<AppUser> _allTechnicians = [];
  List<AppUser> _selectedTechnicians = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  List<XFile> _mediaFilesToUpload = [];
  List<String> _existingMediaUrls = [];

  // ✅ NEW: The URL for our deployed Cloud Function
  final String _getB2UploadUrlCloudFunctionUrl = 'https://getb2uploadurl-onxwq446zq-ew.a.run.app';


  List<String> get statusOptions {
    final current = widget.interventionDoc['status'];
    if (current == 'Clôturé' || current == 'Facturé') {
      return ['Clôturé', 'Facturé'];
    }
    return ['Nouveau', 'En cours', 'Terminé', 'En attente', 'Clôturé'];
  }

  bool get isReadOnly => ['Clôturé', 'Facturé'].contains(_currentStatus);

  @override
  void initState() {
    super.initState();
    final data = widget.interventionDoc.data() as Map<String, dynamic>;

    // ✅ FIXED: Added null checks to prevent LateInitializationError
    _managerNameController = TextEditingController(text: data['managerName'] ?? '');
    _managerPhoneController = TextEditingController(text: data['managerPhone'] ?? '');
    _diagnosticController = TextEditingController(text: data['diagnostic'] ?? '');
    _workDoneController = TextEditingController(text: data['workDone'] ?? '');
    _signatureController = SignatureController();
    _signatureImageUrl = data['signatureUrl'];
    _currentStatus = data['status'] ?? 'Nouveau';
    _existingMediaUrls = List<String>.from(data['mediaUrls'] ?? []);

    _fetchTechnicians().then((_) {
      final List<dynamic> assignedTechnicians = data['assignedTechnicians'] ?? [];
      _selectedTechnicians = _allTechnicians.where((tech) {
        return assignedTechnicians.any((assigned) => assigned['uid'] == tech.uid);
      }).toList();
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _fetchTechnicians() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('users').get();
      _allTechnicians = querySnapshot.docs.map((doc) => AppUser(uid: doc.id, displayName: doc.data()['displayName'] ?? 'No Name')).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur de chargement des techniciens: $e')));
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

  // ✅ --- START: NEW BACKBLAZE UPLOAD LOGIC ---

  /// Calls our Cloud Function to get a temporary upload URL from Backblaze.
  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response = await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
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

  /// Uploads a single file directly to Backblaze using the temporary credentials.
  Future<String?> _uploadFileToB2(XFile file, Map<String, dynamic> b2Credentials) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final Uri uploadUri = Uri.parse(b2Credentials['uploadUrl']);

      final response = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Credentials['authorizationToken'],
          'X-Bz-File-Name': Uri.encodeComponent(file.name), // URL-encode the file name
          'Content-Type': file.mimeType ?? 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        // The final, permanent URL is the prefix + the file name returned by B2.
        return b2Credentials['downloadUrlPrefix'] + responseBody['fileName'];
      } else {
        print('Failed to upload to B2: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading file to B2: $e');
      return null;
    }
  }

  // ✅ --- END: NEW BACKBLAZE UPLOAD LOGIC ---


  // ✅ UPDATED: The save function now uses the Backblaze upload logic
  Future<void> _saveReport() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // Signature upload logic remains the same (using Firebase Storage)
      String? newSignatureUrl = _signatureImageUrl;
      if (_signatureController.isNotEmpty) {
        final signatureBytes = await _signatureController.toPngBytes();
        if (signatureBytes != null) {
          final storageRef = FirebaseStorage.instance.ref().child('signatures/interventions/${widget.interventionDoc.id}_${DateTime.now().millisecondsSinceEpoch}.png');
          final uploadTask = storageRef.putData(signatureBytes);
          final snapshot = await uploadTask.whenComplete(() => {});
          newSignatureUrl = await snapshot.ref.getDownloadURL();
        }
      }

      // ✅ NEW: Upload media files to Backblaze B2
      List<String> uploadedMediaUrls = List.from(_existingMediaUrls);
      for (XFile file in _mediaFilesToUpload) {
        // 1. Get temporary credentials from our Cloud Function
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) {
          throw Exception('Could not get B2 upload credentials.');
        }

        // 2. Upload the file to Backblaze
        final downloadUrl = await _uploadFileToB2(file, b2Credentials);
        if (downloadUrl != null) {
          uploadedMediaUrls.add(downloadUrl);
        } else {
          print('Skipping file due to upload failure: ${file.name}');
        }
      }

      // Firestore update logic remains the same
      final reportData = {
        'managerName': _managerNameController.text.trim(),
        'managerPhone': _managerPhoneController.text.trim(),
        'diagnostic': _diagnosticController.text.trim(),
        'workDone': _workDoneController.text.trim(),
        'signatureUrl': newSignatureUrl,
        'status': _currentStatus,
        'assignedTechnicians': _selectedTechnicians.map((tech) => {'uid': tech.uid, 'name': tech.displayName}).toList(),
        'mediaUrls': uploadedMediaUrls, // ✅ NOW saves Backblaze URLs
        'updatedAt': FieldValue.serverTimestamp(),
        if (_currentStatus == 'Clôturé' && widget.interventionDoc['status'] != 'Clôturé') 'closedAt': FieldValue.serverTimestamp(),
      };

      await widget.interventionDoc.reference.update(reportData);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapport enregistré avec succès!')));
      Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de l\'enregistrement: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    _diagnosticController.dispose();
    _workDoneController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  // ✅ NEW: PDF Generation and Sharing Logic
  Future<void> _generateAndSharePdf() async {
    setState(() => _isLoading = true);
    try {
      final data = widget.interventionDoc.data() as Map<String, dynamic>;

      // Fetch signature image if it exists
      Uint8List? signatureBytes;
      if (data['signatureUrl'] != null) {
        final response = await http.get(Uri.parse(data['signatureUrl']));
        if (response.statusCode == 200) {
          signatureBytes = response.bodyBytes;
        }
      }

      final Map<String, dynamic> pdfData = {
        ...data,
        'signatureUrl': signatureBytes,
      };

      await InterventionPdfService.generateAndSharePdf(pdfData);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la génération du PDF : $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAndPrintPdf() async {
    setState(() => _isLoading = true);
    try {
      final data = widget.interventionDoc.data() as Map<String, dynamic>;

      Uint8List? signatureBytes;
      if (data['signatureUrl'] != null) {
        final response = await http.get(Uri.parse(data['signatureUrl']));
        if (response.statusCode == 200) {
          signatureBytes = response.bodyBytes;
        }
      }

      final Map<String, dynamic> pdfData = {
        ...data,
        'signatureUrl': signatureBytes,
      };

      await InterventionPdfService.generateAndPrintPdf(pdfData);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'affichage du PDF : $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final interventionData = widget.interventionDoc.data() as Map<String, dynamic>;
    final primaryColor = Theme.of(context).primaryColor;
    final createdAt = (interventionData['createdAt'] as Timestamp).toDate();

    return Scaffold(
      appBar: AppBar(
        title: Text(interventionData['interventionCode'] ?? 'Détails'),
        // ✅ ADDED: PDF and Share icons in the AppBar
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _isLoading ? null : _generateAndPrintPdf,
            tooltip: 'Aperçu PDF',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _isLoading ? null : _generateAndSharePdf,
            tooltip: 'Partager PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(interventionData, createdAt, primaryColor),
            const SizedBox(height: 24),
            _buildReportForm(primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> data, DateTime createdAt, Color primaryColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Demandé par ${data['creatorName']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Client: ${data['clientName']} - Magasin: ${data['storeName']}', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 4),
            Text('Date de création: ${DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR').format(createdAt)}', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Description du Problème:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(data['problemDescription'] ?? 'Non spécifié'),
          ],
        ),
      ),
    );
  }

  Widget _buildReportForm(Color primaryColor) {
    final defaultBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.grey));
    final focusedBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2));

    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rapport d\'Intervention', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _managerNameController,
            readOnly: isReadOnly,
            decoration: InputDecoration(labelText: 'Nom du contact sur site', border: defaultBorder, focusedBorder: focusedBorder),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _managerPhoneController,
            readOnly: isReadOnly,
            decoration: InputDecoration(labelText: 'Téléphone du contact', border: defaultBorder, focusedBorder: focusedBorder),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          // Multi-select for technicians
          MultiSelectDialogField<AppUser>(
            items: _allTechnicians.map((tech) => MultiSelectItem(tech, tech.displayName)).toList(),
            title: const Text("Techniciens"),
            selectedColor: primaryColor,
            buttonText: const Text("Techniciens Assignés"),
            onConfirm: (results) {
              if (!isReadOnly) {
                setState(() {
                  _selectedTechnicians = results;
                });
              }
            },
            initialValue: _selectedTechnicians,
            chipDisplay: MultiSelectChipDisplay(
              onTap: (value) {
                if (!isReadOnly) {
                  setState(() {
                    _selectedTechnicians.remove(value);
                  });
                }
              },
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          const SizedBox(height: 16),
          TextFormField(
            controller: _diagnosticController,
            readOnly: isReadOnly,
            decoration: InputDecoration(labelText: 'Diagnostique / Panne Signalée', border: defaultBorder, focusedBorder: focusedBorder, alignLabelWithHint: true),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _workDoneController,
            readOnly: isReadOnly,
            decoration: InputDecoration(labelText: 'Travaux Effectués', border: defaultBorder, focusedBorder: focusedBorder, alignLabelWithHint: true),
            maxLines: 4,
          ),
          const SizedBox(height: 24),

          // ✅ NEW: Media upload section is here
          _buildMediaSection(),

          const SizedBox(height: 24),
          const Text('Signature du Client', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (_signatureImageUrl != null && _signatureController.isEmpty)
            Container(
                height: 150,
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Image.network(_signatureImageUrl!))
            )
          else if (!isReadOnly)
            Signature(
              controller: _signatureController,
              height: 150,
              backgroundColor: Colors.grey[200]!,
            ),

          if (!isReadOnly)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                child: const Text('Effacer la signature'),
                onPressed: () {
                  _signatureController.clear();
                  setState(() { _signatureImageUrl = null; });
                },
              ),
            ),

          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _currentStatus,
            decoration: InputDecoration(border: defaultBorder, focusedBorder: focusedBorder, labelText: 'Statut de l\\\'intervention'),
            items: statusOptions.map((String status) => DropdownMenuItem<String>(value: status, child: Text(status))).toList(),
            onChanged: isReadOnly ? null : (newValue) => setState(() { _currentStatus = newValue!; }),
          ),
          const SizedBox(height: 24),
          if (!isReadOnly)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveReport,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Enregistrer le Rapport'),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ NEW: Widget for the media section
  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photos & Vidéos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_existingMediaUrls.isEmpty && _mediaFilesToUpload.isEmpty)
          const Text('Aucun fichier ajouté.', style: TextStyle(color: Colors.grey)),

        // Display existing media
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: _existingMediaUrls.map((url) => _buildMediaThumbnail(url: url)).toList(),
        ),

        // Display newly selected media
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: _mediaFilesToUpload.map((file) => _buildMediaThumbnail(file: file)).toList(),
        ),

        const SizedBox(height: 16),
        if (!isReadOnly)
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Ajouter Photos/Vidéos'),
              onPressed: _pickMedia,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }

  // ✅ NEW: Widget to display a single media thumbnail
  Widget _buildMediaThumbnail({String? url, XFile? file}) {
    bool isVideo = (url?.contains('.mp4') ?? file?.path.endsWith('.mp4')) ?? false;

    return GestureDetector(
      onTap: () async {
        // ✅ FIXED: Added robust check for null or empty URLs
        if (url == null || url.isEmpty) {
          print("URL is null or empty, cannot launch.");
          return; // Stop execution if the URL is invalid
        }

        try {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            // Use external application mode for better behavior on mobile
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            print("Could not launch $uri");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Impossible d\'ouvrir le lien')),
              );
            }
          }
        } catch (e) {
          print("Error parsing or launching URL: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lien invalide : $url')),
            );
          }
        }
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          image: url != null && url.isNotEmpty && !isVideo
              ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
              : null,
          color: Colors.grey.shade200,
        ),
        child: Stack(
          children: [
            if (file != null && !file.path.endsWith('.mp4'))
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(File(file.path), width: 100, height: 100, fit: BoxFit.cover),
              ),
            if (isVideo)
              const Center(child: Icon(Icons.videocam, size: 40, color: Colors.black54)),
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
}
// lib/screens/portal/store_request_page.dart

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart'; // ✅ Added for Date Formatting

// ✅ IMPORTS FOR MEDIA & B2
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart'; // For SHA1
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
// Removed image_picker import
import 'package:video_thumbnail/video_thumbnail.dart';

class StoreRequestPage extends StatefulWidget {
  final String storeId;
  final String token;

  const StoreRequestPage({
    super.key,
    required this.storeId,
    required this.token,
  });

  @override
  State<StoreRequestPage> createState() => _StoreRequestPageState();
}

class _StoreRequestPageState extends State<StoreRequestPage> {
  // --- STATE ---
  bool _isLoading = true;
  bool _isValidSession = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // --- DATA ---
  DocumentSnapshot? _storeDoc;
  DocumentSnapshot? _clientDoc;

  // --- FORM CONTROLLERS ---
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // --- MEDIA STATE (B2) ---
  // Using PlatformFile from file_picker to handle both Web (bytes) and Mobile (path) safely
  List<PlatformFile> _localFilesToUpload = [];
  List<String> _uploadedMediaUrls = [];
  bool _isUploadingMedia = false;

  // ☁️ Cloud Function for B2 Auth
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl';

  @override
  void initState() {
    super.initState();
    _verifyAndLoadData();
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _storeNameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// --------------------------------------------------------------------------
  /// 1. SMART DATA LOADING
  /// --------------------------------------------------------------------------
  Future<void> _verifyAndLoadData() async {
    try {
      QuerySnapshot? storeQuery;

      // Attempt 1: Query by 'id'
      try {
        storeQuery = await FirebaseFirestore.instance
            .collectionGroup('stores')
            .where('id', isEqualTo: widget.storeId)
            .get();
      } catch (e) {
        debugPrint("Primary query failed (Index missing): $e");
      }

      // Attempt 2: Fallback to 'qr_access_token'
      if (storeQuery == null || storeQuery.docs.isEmpty) {
        storeQuery = await FirebaseFirestore.instance
            .collectionGroup('stores')
            .where('qr_access_token', isEqualTo: widget.token)
            .get();
      }

      if (storeQuery.docs.isEmpty) {
        throw "Magasin introuvable (ID ou Token invalide).";
      }

      final storeDoc = storeQuery.docs.first;
      final storeData = storeDoc.data() as Map<String, dynamic>;

      if (storeData['qr_access_token'] != widget.token) {
        throw "Lien expiré ou non autorisé.";
      }

      final clientRef = storeDoc.reference.parent.parent;
      if (clientRef == null) throw "Structure de données invalide.";
      final clientDoc = await clientRef.get();
      final clientData = clientDoc.data() as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _storeDoc = storeDoc;
          _clientDoc = clientDoc;
          _clientNameController.text = clientData['name'] ?? 'Client Inconnu';
          _storeNameController.text = storeData['name'] ?? 'Magasin Inconnu';
          _isValidSession = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isValidSession = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// --------------------------------------------------------------------------
  /// 2. B2 CLOUD STORAGE LOGIC
  /// --------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response = await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
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

  Future<String?> _uploadFileToB2(PlatformFile file, Map<String, dynamic> b2Creds) async {
    try {
      // Handle bytes: Web uses file.bytes, Mobile reads from file.path
      Uint8List fileBytes;
      if (kIsWeb) {
        fileBytes = file.bytes!;
      } else {
        fileBytes = await File(file.path!).readAsBytes();
      }

      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final fileName = file.name;

      String? mimeType;
      final extension = path.extension(fileName).toLowerCase();
      if (extension == '.jpg' || extension == '.jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == '.png') {
        mimeType = 'image/png';
      } else if (extension == '.mp4' || extension == '.mov') {
        mimeType = 'video/mp4';
      } else if (extension == '.pdf') {
        mimeType = 'application/pdf';
      } else {
        mimeType = 'b2/x-auto';
      }

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': mimeType,
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final encodedPath = (body['fileName'] as String).split('/').map(Uri.encodeComponent).join('/');
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

  // --- MEDIA PICKER HELPERS ---
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'pdf'],
      allowMultiple: true,
      withData: kIsWeb, // Crucial for Web
    );
    if (result != null) {
      setState(() {
        _localFilesToUpload.addAll(result.files);
      });
    }
  }

  // --- THUMBNAIL GENERATOR ---
  Future<Widget> _getThumbnail(PlatformFile file) async {
    final extension = path.extension(file.name).toLowerCase();

    // 1. IMAGES
    if (extension == '.jpg' || extension == '.jpeg' || extension == '.png') {
      if (kIsWeb) {
        // Use bytes for web preview
        return Image.memory(
          file.bytes!,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (c, o, s) => const Icon(Icons.broken_image, color: Colors.grey),
        );
      } else {
        return Image.file(
            File(file.path!),
            width: 50,
            height: 50,
            fit: BoxFit.cover
        );
      }
    }

    // 2. VIDEOS
    else if (extension == '.mp4' || extension == '.mov') {
      if (kIsWeb) {
        return Container(
          width: 50, height: 50, color: Colors.black12,
          child: const Icon(Icons.videocam, color: Colors.purple),
        );
      }

      try {
        final thumbPath = await VideoThumbnail.thumbnailFile(
          video: file.path!,
          imageFormat: ImageFormat.JPEG,
          maxHeight: 64,
          quality: 50,
        );
        if (thumbPath != null) {
          return Image.file(File(thumbPath), width: 50, height: 50, fit: BoxFit.cover);
        }
      } catch (e) {
        // Fallback
      }
      return const Icon(Icons.videocam, color: Colors.purple);
    }

    // 3. PDF
    else if (extension == '.pdf') {
      return const Icon(Icons.picture_as_pdf, color: Colors.red);
    }

    return const Icon(Icons.insert_drive_file, color: Colors.blue);
  }

  /// --------------------------------------------------------------------------
  /// 3. SUBMIT & UPLOAD LOGIC
  /// --------------------------------------------------------------------------
  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _isUploadingMedia = true;
      _uploadedMediaUrls = [];
    });

    try {
      // A. Upload Media to B2
      if (_localFilesToUpload.isNotEmpty) {
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) throw Exception("Impossible de connecter au serveur de fichiers (B2).");

        for (var file in _localFilesToUpload) {
          final url = await _uploadFileToB2(file, b2Credentials);
          if (url != null) _uploadedMediaUrls.add(url);
        }
      }

      setState(() => _isUploadingMedia = false);

      // B. Prepare References & Data
      final clientData = _clientDoc!.data() as Map<String, dynamic>;
      final storeData = _storeDoc!.data() as Map<String, dynamic>;

      final currentYear = DateFormat('yyyy').format(DateTime.now());
      final counterRef = FirebaseFirestore.instance
          .collection('counters')
          .doc('intervention_counter_$currentYear');
      final interventionRef = FirebaseFirestore.instance.collection('interventions').doc();


      // 🔍 AUTO-DETECT SERVICE TYPE
      String detectedServiceType = 'Service Technique'; // Default fallback
      if (clientData['services'] != null && (clientData['services'] as List).isNotEmpty) {
        // We take the first service available as the default for this ticket
        detectedServiceType = (clientData['services'] as List).first.toString();
      }

      // C. EXECUTE TRANSACTION
      // This ensures we read the counter, increment it, and save the intervention atomically.
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterDoc = await transaction.get(counterRef);

        int newCount;
        if (counterDoc.exists) {
          final data = counterDoc.data() as Map<String, dynamic>;
          final lastResetYear = data['lastReset'] as String?;
          final currentCount = data['count'] as int? ?? 0;

          if (lastResetYear == currentYear) {
            newCount = currentCount + 1;
          } else {
            // Reset for new year if needed
            newCount = 1;
          }
        } else {
          // Document doesn't exist yet
          newCount = 1;
        }

        // Generate the Code: INT-51/2026
        final interventionCode = 'INT-$newCount/$currentYear';

        final interventionData = {
          'interventionCode': interventionCode, // ✅ THE GENERATED CODE
          'clientId': _clientDoc!.id,
          'storeId': _storeDoc!.id,
          'clientName': clientData['name'],
          'storeName': storeData['name'],
          'storeLocation': storeData['location'] ?? '',
          'status': 'Nouvelle Demande',
          'priority': 'Moyenne',
          'type': 'Dépannage',
          'source': 'QR_Portal',
          'serviceType': detectedServiceType, // ✅ AUTO-ASSIGNED SERVICE TYPE

          // ✅ FIELD NAMES FIXED FOR ADMIN DASHBOARD MAPPING
          'requestDescription': _descriptionController.text.trim(), // Admin looks for 'requestDescription'
          'managerName': _contactController.text.trim(),            // Admin looks for 'managerName'
          'createdByName': _contactController.text.trim(),          // Shows name in "Demandé par"

          'clientPhone': _phoneController.text.trim(),
          'mediaUrls': _uploadedMediaUrls,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': 'Portal Guest', // Kept for technical audit
        };

        // Write both operations
        transaction.set(interventionRef, interventionData);
        transaction.set(counterRef, {
          'count': newCount,
          'lastReset': currentYear,
        });
      });

      if (mounted) {
        _showSuccessDialog();
      }

    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _isUploadingMedia = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: const Text(
          "Demande Envoyée !\n\nNos techniciens ont été notifiés.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _descriptionController.clear();
                _phoneController.clear();
                _localFilesToUpload.clear();
                _uploadedMediaUrls.clear();
                _isSubmitting = false;
              });
            },
            child: const Text("OK", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// 4. UI BUILDER
  /// --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Chargement du portail..."),
            ],
          ),
        ),
      );
    }

    if (!_isValidSession) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 80, color: Colors.red),
                const SizedBox(height: 24),
                Text("Accès Refusé", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(_errorMessage ?? "QR Code invalide.", textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Card(
                  elevation: 8,
                  shadowColor: const Color(0x33667EEA),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- HEADER ---
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF667EEA).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.add_task, color: Color(0xFF667EEA), size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Nouvelle Demande",
                                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    const Text(
                                      "Portail de Support Client",
                                      style: TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 40),

                          // --- SECTIONS ---
                          _buildSectionTitle("Localisation (Automatique)"),
                          const SizedBox(height: 12),
                          _buildReadOnlyField("Client", _clientNameController, Icons.business),
                          const SizedBox(height: 12),
                          _buildReadOnlyField("Magasin", _storeNameController, Icons.store),
                          const SizedBox(height: 24),

                          _buildSectionTitle("Contact & Problème"),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _contactController,
                            decoration: _buildInputDecoration("Votre Nom / Poste", Icons.person),
                            validator: (val) => val == null || val.isEmpty ? "Requis" : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: _buildInputDecoration("Numéro de Téléphone *", Icons.phone),
                            validator: (val) => val == null || val.length < 9 ? "Numéro valide requis" : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: _buildInputDecoration("Description de la panne...", Icons.description),
                            validator: (val) => val == null || val.isEmpty ? "Veuillez décrire le problème" : null,
                          ),
                          const SizedBox(height: 24),

                          // --- MEDIA SECTION (Updated) ---
                          _buildSectionTitle("Preuve / Photo / Vidéo"),
                          const SizedBox(height: 12),

                          // Single Upload Button (No Camera)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isUploadingMedia || _isSubmitting ? null : _pickFiles,
                              icon: const Icon(Icons.file_upload_outlined),
                              label: const Text('Ajouter Photos / Vidéos / Fichiers'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF667EEA),
                                elevation: 0,
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),

                          // 📸 THUMBNAIL GRID
                          if (_localFilesToUpload.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _localFilesToUpload.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final file = _localFilesToUpload[index];
                                  return Stack(
                                    children: [
                                      // Thumbnail
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: FutureBuilder<Widget>(
                                            future: _getThumbnail(file),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                              }
                                              return snapshot.data ?? const SizedBox();
                                            },
                                          ),
                                        ),
                                      ),
                                      // Remove X
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: GestureDetector(
                                          onTap: () {
                                            if (!_isSubmitting) {
                                              setState(() => _localFilesToUpload.removeAt(index));
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),

                          const SizedBox(height: 32),

                          // --- SUBMIT BUTTON ---
                          SizedBox(
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitRequest,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF667EEA),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isSubmitting
                                  ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                  const SizedBox(width: 12),
                                  Text(_isUploadingMedia ? "Envoi des fichiers..." : "Enregistrement..."),
                                ],
                              )
                                  : const Text(
                                "ENVOYER LA DEMANDE",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildReadOnlyField(String label, TextEditingController controller, IconData icon) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF667EEA)),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2)),
    );
  }
}
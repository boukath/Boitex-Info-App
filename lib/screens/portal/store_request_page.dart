// lib/screens/portal/store_request_page.dart

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui'; // ✅ REQUIRED FOR BACKDROP FILTER (GLASS EFFECT)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

// ✅ IMPORTS FOR MEDIA & B2
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart'; // For SHA1
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:video_thumbnail/video_thumbnail.dart';

// ✅ IMPORT SERVICE CONTRACTS MODEL
import 'package:boitex_info_app/models/service_contracts.dart';

// 🎨 --- 2026 PREMIUM APPLE COLORS & CONSTANTS --- 🎨
const kTextDark = Color(0xFF1D1D1F);
const kTextSecondary = Color(0xFF86868B);
const kAppleBlue = Color(0xFF007AFF);
const kApplePurple = Color(0xFFAF52DE);
const double kRadius = 32.0;

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

  // --- CONTRACT STATE ---
  MaintenanceContract? _activeContract;
  bool _isQuotaExceeded = false; // Checks if credit is 0
  bool _hasContract = false;

  // --- DATA ---
  DocumentSnapshot? _storeDoc;
  DocumentSnapshot? _clientDoc;

  // --- FORM CONTROLLERS ---
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(); // ✅ NEW EMAIL FIELD
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // --- MEDIA STATE (B2) ---
  final List<PlatformFile> _localFilesToUpload = [];
  List<String> _uploadedMediaUrls = [];
  bool _isUploadingMedia = false;

  // ☁️ Cloud Function for B2 Auth
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

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
    _emailController.dispose(); // ✅ DISPOSE
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// --------------------------------------------------------------------------
  /// 1. SMART DATA LOADING & CONTRACT CHECK
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

      // Attempt 2: Fallback to 'qrToken' (FIXED FIELD NAME)
      if (storeQuery == null || storeQuery.docs.isEmpty) {
        storeQuery = await FirebaseFirestore.instance
            .collectionGroup('stores')
            .where('qrToken', isEqualTo: widget.token)
            .get();
      }

      if (storeQuery.docs.isEmpty) {
        throw "Magasin introuvable (ID ou Token invalide).";
      }

      final storeDoc = storeQuery.docs.first;
      final storeData = storeDoc.data() as Map<String, dynamic>;

      if (storeData['qrToken'] != widget.token) {
        throw "Lien expiré ou non autorisé.";
      }

      final clientRef = storeDoc.reference.parent.parent;
      if (clientRef == null) throw "Structure de données invalide.";
      final clientDoc = await clientRef.get();
      final clientData = clientDoc.data() as Map<String, dynamic>;

      // ✅ 1. CHECK MAINTENANCE CONTRACT
      MaintenanceContract? foundContract;
      try {
        if (storeData.containsKey('maintenance_contract') && storeData['maintenance_contract'] != null) {
          final contractMap = storeData['maintenance_contract'] as Map<String, dynamic>;
          final c = MaintenanceContract.fromMap(contractMap);
          if (c.isActive && c.isValidNow) {
            foundContract = c;
          }
        }
      } catch (e) {
        debugPrint("Error parsing contract from store data: $e");
      }

      bool quotaExceeded = false;
      bool hasContract = false;

      if (foundContract != null) {
        hasContract = true;
        // Check Credit: If 0, BLOCK them.
        if (foundContract.remainingCorrective <= 0) {
          quotaExceeded = true;
        }
      }

      // ✅ PREPARE STORE NAME & LOCATION STRING
      String storeName = storeData['name'] ?? 'Magasin Inconnu';
      String finalStoreDisplay = storeName;
      dynamic rawLocation = storeData['location'];

      if (rawLocation is String && rawLocation.isNotEmpty) {
        finalStoreDisplay = "$storeName - $rawLocation";
      }

      if (mounted) {
        setState(() {
          _storeDoc = storeDoc;
          _clientDoc = clientDoc;
          _clientNameController.text = clientData['name'] ?? 'Client Inconnu';
          _storeNameController.text = finalStoreDisplay;
          _activeContract = foundContract;
          _hasContract = hasContract;
          _isQuotaExceeded = quotaExceeded;
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
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<String?> _uploadFileToB2(PlatformFile file, Map<String, dynamic> b2Creds) async {
    try {
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

      if (extension == '.jpg' || extension == '.jpeg') mimeType = 'image/jpeg';
      else if (extension == '.png') mimeType = 'image/png';
      else if (extension == '.mp4' || extension == '.mov') mimeType = 'video/mp4';
      else if (extension == '.pdf') mimeType = 'application/pdf';
      else mimeType = 'b2/x-auto';

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
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'pdf'],
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result != null) {
      setState(() => _localFilesToUpload.addAll(result.files));
    }
  }

  Future<Widget> _getThumbnail(PlatformFile file) async {
    final extension = path.extension(file.name).toLowerCase();
    if (extension == '.jpg' || extension == '.jpeg' || extension == '.png') {
      if (kIsWeb) {
        return Image.memory(file.bytes!, fit: BoxFit.cover, errorBuilder: (c, o, s) => const Icon(Icons.broken_image, color: Colors.white54));
      } else {
        return Image.file(File(file.path!), fit: BoxFit.cover);
      }
    } else if (extension == '.mp4' || extension == '.mov') {
      if (kIsWeb) return const Center(child: Icon(Icons.videocam_rounded, color: Colors.white));
      try {
        final thumbPath = await VideoThumbnail.thumbnailFile(video: file.path!, imageFormat: ImageFormat.JPEG, maxHeight: 120, quality: 50);
        if (thumbPath != null) return Stack(fit: StackFit.expand, children: [Image.file(File(thumbPath), fit: BoxFit.cover), Container(color: Colors.black26, child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 32))]);
      } catch (e) {}
      return const Center(child: Icon(Icons.videocam_rounded, color: Colors.white));
    } else if (extension == '.pdf') {
      return const Center(child: Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 32));
    }
    return const Center(child: Icon(Icons.insert_drive_file_rounded, color: Colors.white54, size: 32));
  }

  /// --------------------------------------------------------------------------
  /// 3. SUBMIT & UPLOAD LOGIC
  /// --------------------------------------------------------------------------
  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isQuotaExceeded) return; // Prevent submission

    setState(() {
      _isSubmitting = true;
      _isUploadingMedia = true;
      _uploadedMediaUrls = [];
    });

    try {
      if (_localFilesToUpload.isNotEmpty) {
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) throw Exception("Impossible de connecter au serveur de fichiers (B2).");
        for (var file in _localFilesToUpload) {
          final url = await _uploadFileToB2(file, b2Credentials);
          if (url != null) _uploadedMediaUrls.add(url);
        }
      }
      setState(() => _isUploadingMedia = false);

      final clientData = _clientDoc!.data() as Map<String, dynamic>;
      final storeData = _storeDoc!.data() as Map<String, dynamic>;

      String detectedServiceType = 'Service Technique';
      if (clientData['services'] != null && (clientData['services'] as List).isNotEmpty) {
        detectedServiceType = (clientData['services'] as List).first.toString();
      }

      String finalInterventionType = _hasContract ? 'Corrective' : 'Facturable';

      await FirebaseFirestore.instance.collection('interventions').add({
        'interventionCode': 'PENDING',
        'clientId': _clientDoc!.id,
        'storeId': _storeDoc!.id,
        'clientName': clientData['name'],
        'storeName': storeData['name'],
        'storeLocation': storeData['location'] ?? '',
        'status': 'En Attente Validation',
        'priority': 'Moyenne',
        'interventionType': finalInterventionType,
        'source': 'QR_Portal',
        'serviceType': detectedServiceType,
        'contractId': _activeContract?.id,
        'requestDescription': _descriptionController.text.trim(),
        'managerName': _contactController.text.trim(),
        'clientEmail': _emailController.text.trim(), // ✅ NEW EMAIL FIELD IN FIRESTORE
        'createdByName': _contactController.text.trim(),
        'clientPhone': _phoneController.text.trim(),
        'mediaUrls': _uploadedMediaUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'Portal Guest',
      });

      if (mounted) _showSuccessDialog();

    } catch (e) {
      setState(() { _isSubmitting = false; _isUploadingMedia = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e", style: GoogleFonts.inter())));
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      // ✅ FIX 1: Removed backgroundColor from showDialog itself
      barrierColor: Colors.black.withOpacity(0.3), // Optional: Dim the background slightly
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Dialog(
          backgroundColor: Colors.white.withOpacity(0.8),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius), side: BorderSide(color: Colors.white.withOpacity(0.9), width: 1.5)),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: kAppleBlue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: kAppleBlue, size: 64),
                ),
                const SizedBox(height: 24),
                Text("Demande Envoyée", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -0.5)),
                const SizedBox(height: 12),
                Text("Nos équipes vont valider votre demande rapidement.", textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 15, color: kTextSecondary, height: 1.5)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _descriptionController.clear();
                        _phoneController.clear();
                        _emailController.clear();
                        _localFilesToUpload.clear();
                        _uploadedMediaUrls.clear();
                        _isSubmitting = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTextDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text("Terminer", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// 4. 2026 APPLE UI BUILDER
  /// --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // LOADING STATE
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ FIX 2: Removed 'const' keyword
              CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),
              Text("Vérification de l'accès...", style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    // INVALID SESSION STATE
    if (!_isValidSession) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person_rounded, size: 80, color: Colors.redAccent),
                const SizedBox(height: 24),
                Text("Accès Refusé", style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -1.0)),
                const SizedBox(height: 12),
                Text(_errorMessage ?? "Lien invalide.", textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 16, color: kTextSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    // QUOTA EXCEEDED BLOCKER
    if (_isQuotaExceeded) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.block_rounded, size: 64, color: Colors.redAccent),
                ),
                const SizedBox(height: 32),
                Text("Quota Épuisé", style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -1.0)),
                const SizedBox(height: 16),
                Text(
                  "Votre crédit d'interventions est à 0.\nVeuillez contacter l'administration pour demander une intervention facturable.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 16, color: kTextSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 🌟 MAIN PREMIUM UI 🌟
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent, // Handled by Stack
      body: Stack(
        children: [
          // 1. DYNAMIC VIBRANT MESH BACKGROUND (Apple iOS 2026 Aesthetic)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.3, 0.6, 1.0],
                  colors: [
                    Color(0xFFFFD194), // Warm Peach
                    Color(0xFFF3A183), // Soft Rose
                    Color(0xFF9CB8FF), // Cool Blue
                    Color(0xFFE8F1F5), // White-ish Blue
                  ],
                ),
              ),
            ),
          ),

          // 2. EXTREME BLUR LAYER (Frosted Global Effect)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.white.withOpacity(0.1)),
            ),
          ),

          // 3. MAIN FORM CONTENT
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650), // Responsive constraint
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(kRadius),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.65), // Glass Core
                          borderRadius: BorderRadius.circular(kRadius),
                          border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 40, spreadRadius: -5, offset: const Offset(0, 20))
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // --- HEADER ---
                              Center(
                                child: Container(
                                  width: 64, height: 64,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [kAppleBlue, kApplePurple], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [BoxShadow(color: kAppleBlue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                                  ),
                                  child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 32),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text("Support Technique", textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -1.0)),
                              const SizedBox(height: 8),
                              Text("Portail Client Sécurisé", textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 15, color: kTextSecondary, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 32),

                              // --- CONTRACT STATUS BADGE ---
                              if (_hasContract && _activeContract != null)
                                _buildStatusBadge(Icons.verified_rounded, Colors.green, "Sous Contrat (Crédit : ${_activeContract!.remainingCorrective})")
                              else
                                _buildStatusBadge(Icons.info_outline_rounded, Colors.orange, "Intervention Hors Contrat (Facturable)"),

                              const SizedBox(height: 32),

                              // --- READ-ONLY LOCATION INFO ---
                              _buildSectionTitle("Localisation"),
                              const SizedBox(height: 12),
                              _buildGlassReadOnlyField(_clientNameController, Icons.business_rounded),
                              const SizedBox(height: 12),
                              _buildGlassReadOnlyField(_storeNameController, Icons.storefront_rounded),
                              const SizedBox(height: 32),

                              // --- USER INPUTS ---
                              _buildSectionTitle("Détails du Signalement"),
                              const SizedBox(height: 12),
                              _buildGlassInputField(_contactController, "Nom et Poste (ex: Jean - Gérant)", Icons.person_rounded, TextInputType.name, true),
                              const SizedBox(height: 12),

                              // ✅ NEW EMAIL FIELD
                              _buildGlassInputField(
                                  _emailController,
                                  "Adresse Email",
                                  Icons.alternate_email_rounded,
                                  TextInputType.emailAddress,
                                  true,
                                  isEmail: true
                              ),
                              const SizedBox(height: 12),

                              _buildGlassInputField(_phoneController, "Numéro de Téléphone", Icons.phone_rounded, TextInputType.phone, true),
                              const SizedBox(height: 12),
                              _buildGlassInputField(_descriptionController, "Décrivez la panne ou la demande...", Icons.notes_rounded, TextInputType.multiline, true, maxLines: 4),
                              const SizedBox(height: 32),

                              // --- MEDIA SECTION ---
                              _buildSectionTitle("Pièces Jointes (Photos/Vidéos)"),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _isUploadingMedia || _isSubmitting ? null : _pickFiles,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: kAppleBlue.withOpacity(0.3), width: 1.5),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_rounded, color: kAppleBlue.withOpacity(0.8)),
                                      const SizedBox(width: 12),
                                      Text("Ajouter des fichiers", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kAppleBlue)),
                                    ],
                                  ),
                                ),
                              ),

                              // MEDIA PREVIEWS
                              if (_localFilesToUpload.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 16),
                                  height: 90,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _localFilesToUpload.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final file = _localFilesToUpload[index];
                                      return Stack(
                                        children: [
                                          Container(
                                            width: 90, height: 90,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.4),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(14),
                                              child: FutureBuilder<Widget>(
                                                future: _getThumbnail(file),
                                                builder: (context, snapshot) {
                                                  // ✅ FIX 3: Removed invalid const here
                                                  if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(strokeWidth: 2));
                                                  return snapshot.data ?? const SizedBox();
                                                },
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: -4, right: -4,
                                            child: IconButton(
                                              onPressed: _isSubmitting ? null : () => setState(() => _localFilesToUpload.removeAt(index)),
                                              icon: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),

                              const SizedBox(height: 48),

                              // --- SUBMIT BUTTON ---
                              SizedBox(
                                height: 60,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submitRequest,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kTextDark, // True Apple Dark Mode Button
                                    foregroundColor: Colors.white,
                                    elevation: 10,
                                    shadowColor: kTextDark.withOpacity(0.3),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  child: _isSubmitting
                                  // ✅ FIX 4: Replaced CupertinoActivityIndicator with safe CircularProgressIndicator
                                      ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                      : Text("Envoyer la Demande", style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600)),
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
        ],
      ),
    );
  }

  // --- 2026 UI HELPERS ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.0),
    );
  }

  Widget _buildStatusBadge(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildGlassReadOnlyField(TextEditingController controller, IconData icon) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: GoogleFonts.inter(color: kTextDark, fontWeight: FontWeight.w600, fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: kTextSecondary, size: 22),
        filled: true,
        fillColor: Colors.white.withOpacity(0.4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(18),
      ),
    );
  }

  Widget _buildGlassInputField(TextEditingController controller, String hint, IconData icon, TextInputType type, bool isRequired, {int maxLines = 1, bool isEmail = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      style: GoogleFonts.inter(color: kTextDark, fontWeight: FontWeight.w500, fontSize: 15),
      validator: (val) {
        if (isRequired && (val == null || val.trim().isEmpty)) return "Ce champ est requis.";
        if (isEmail && val != null && val.isNotEmpty) {
          final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
          if (!emailRegex.hasMatch(val)) return "Adresse email invalide.";
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: kTextSecondary.withOpacity(0.7)),
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: maxLines > 1 ? (maxLines * 16.0 - 16.0) : 0), // Align icon to top for multiline
          child: Icon(icon, color: kTextDark.withOpacity(0.7), size: 22),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kAppleBlue, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 1.5)),
        contentPadding: const EdgeInsets.all(18),
      ),
    );
  }
}
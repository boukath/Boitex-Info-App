// lib/screens/service_technique/finalize_sav_return_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ 2026 Typography
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signature/signature.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class FinalizeSavReturnPage extends StatefulWidget {
  final SavTicket ticket;

  const FinalizeSavReturnPage({super.key, required this.ticket});

  @override
  State<FinalizeSavReturnPage> createState() => _FinalizeSavReturnPageState();
}

class _FinalizeSavReturnPageState extends State<FinalizeSavReturnPage> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _clientEmailController = TextEditingController();

  // Signature setup
  final _signatureController = SignatureController(
    penStrokeWidth: 3, // Slightly thicker for a premium feel
    penColor: const Color(0xFF111827), // Pitch Black
    exportBackgroundColor: Colors.white,
  );

  File? _proofMediaFile;
  bool _isVideo = false;
  bool _isSaving = false;

  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  @override
  void dispose() {
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _clientEmailController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // LOGIC (Unchanged)
  // ===========================================================================

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media);

    if (result != null && result.files.single.path != null) {
      final pickedFile = File(result.files.single.path!);
      const maxFileSize = 50 * 1024 * 1024;
      if (pickedFile.lengthSync() > maxFileSize) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Le fichier dépasse la limite de 50 Mo.'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      setState(() {
        _proofMediaFile = pickedFile;
        _isVideo = _isVideoPath(_proofMediaFile!.path);
      });
    }
  }

  bool _isVideoPath(String filePath) {
    final p = filePath.toLowerCase();
    return p.endsWith('.mp4') || p.endsWith('.mov') || p.endsWith('.avi') || p.endsWith('.mkv');
  }

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
      debugPrint('Error calling Cloud Function for B2 credentials: $e');
      return null;
    }
  }

  Future<String?> _uploadBytesToB2(Uint8List bytes, String fileName, Map<String, dynamic> b2Creds) async {
    try {
      final sha1Hash = sha1.convert(bytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl']);

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'],
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': 'image/png',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': bytes.length.toString(),
        },
        body: bytes,
      );
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        final encodedPath = (body['fileName'] as String).split('/').map(Uri.encodeComponent).join('/');
        return (b2Creds['downloadUrlPrefix']) + encodedPath;
      }
      return null;
    } catch (e) {
      print('B2 Bytes Upload Error: $e');
      return null;
    }
  }

  Future<String?> _uploadFileToB2(File file, Map<String, dynamic> b2Creds, String desiredFileName) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);

      String? mimeType;
      final lcFileName = desiredFileName.toLowerCase();
      if (lcFileName.endsWith('.jpg') || lcFileName.endsWith('.jpeg')) mimeType = 'image/jpeg';
      else if (lcFileName.endsWith('.png')) mimeType = 'image/png';
      else if (lcFileName.endsWith('.mp4')) mimeType = 'video/mp4';
      else if (lcFileName.endsWith('.mov')) mimeType = 'video/quicktime';
      else if (lcFileName.endsWith('.avi')) mimeType = 'video/x-msvideo';
      else if (lcFileName.endsWith('.mkv')) mimeType = 'video/x-matroska';

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(desiredFileName),
          'Content-Type': mimeType ?? 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final b2FileName = body['fileName'] as String;
        final encodedPath = b2FileName.split('/').map(Uri.encodeComponent).join('/');
        return (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
      } else {
        debugPrint('Failed to upload proof media to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading proof media file to B2: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La signature du client est requise.'), backgroundColor: Colors.red));
      return;
    }
    if (_proofMediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Une photo ou vidéo de preuve est requise.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final b2Credentials = await _getB2UploadCredentials();
      if (b2Credentials == null) throw Exception('Impossible de récupérer les accès B2.');

      final signatureFileName = 'sav_returns/signatures/${widget.ticket.savCode}-$timestamp.png';
      final signatureUrl = await _uploadBytesToB2(signatureBytes!, signatureFileName, b2Credentials);

      final fileExtension = path.extension(_proofMediaFile!.path);
      final mediaFolder = _isVideo ? 'videos' : 'photos';
      final mediaFileName = 'sav_returns/$mediaFolder/${widget.ticket.savCode}-$timestamp$fileExtension';
      final mediaUrl = await _uploadFileToB2(_proofMediaFile!, b2Credentials, mediaFileName);

      if (signatureUrl == null || mediaUrl == null) throw Exception('Échec de l\'upload d\'un ou plusieurs fichiers.');

      await FirebaseFirestore.instance.collection('sav_tickets').doc(widget.ticket.id).update({
        'status': 'Retourné',
        'returnClientName': _clientNameController.text.trim(),
        'returnClientPhone': _clientPhoneController.text.trim(),
        'returnClientEmail': _clientEmailController.text.trim(),
        'returnSignatureUrl': signatureUrl,
        'returnPhotoUrl': mediaUrl,
        'closedAt': FieldValue.serverTimestamp(),
      });

      await ActivityLogger.logActivity(
        message: "Le ticket SAV ${widget.ticket.savCode} a été finalisé et retourné au client.",
        interventionId: widget.ticket.id,
        category: 'SAV',
      );

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Retour finalisé avec succès.'), backgroundColor: Colors.green));
      navigator.pop();
      navigator.pop();

    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ===========================================================================
  // 💎 2026 UI ARCHITECTURE
  // ===========================================================================

  InputDecoration _premiumInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: const Color(0xFF6B7280), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 2), // Emerald Green Focus
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Clean off-white background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        title: Text(
          'Restitution Client',
          style: GoogleFonts.inter(
            color: const Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProductVerificationCard(),
              const SizedBox(height: 32),

              Text(
                'Informations du Client',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF374151)),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _clientNameController,
                // ✅ FIXED: Changed 500 to FontWeight.w500
                style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: const Color(0xFF111827)),
                decoration: _premiumInputDecoration('Nom et Prénom / Gérant', Icons.person_outline_rounded),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un nom.' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _clientPhoneController,
                keyboardType: TextInputType.phone,
                // ✅ FIXED: Changed 500 to FontWeight.w500
                style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: const Color(0xFF111827)),
                decoration: _premiumInputDecoration('Numéro de téléphone', Icons.phone_outlined),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _clientEmailController,
                keyboardType: TextInputType.emailAddress,
                // ✅ FIXED: Changed 500 to FontWeight.w500
                style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: const Color(0xFF111827)),
                decoration: _premiumInputDecoration('Email (Optionnel)', Icons.email_outlined),
              ),

              const SizedBox(height: 32),

              // --- MEDIA SECTION ---
              Text(
                'Preuve Visuelle',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF374151)),
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: _pickMedia,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5, style: BorderStyle.solid),
                  ),
                  child: _proofMediaFile == null
                      ? Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
                        child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF6B7280), size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text('Ajouter une photo ou vidéo', style: GoogleFonts.inter(color: const Color(0xFF4B5563), fontWeight: FontWeight.w600)),
                    ],
                  )
                      : Column(
                    children: [
                      Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _isVideo
                              ? FutureBuilder<Uint8List?>(
                            future: VideoThumbnail.thumbnailData(video: _proofMediaFile!.path, imageFormat: ImageFormat.JPEG, maxWidth: 300, quality: 50),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
                              if (snapshot.hasData && snapshot.data != null) return Stack(fit: StackFit.expand, children: [Image.memory(snapshot.data!, fit: BoxFit.cover), Container(color: Colors.black26), const Center(child: Icon(Icons.play_circle_fill, size: 40, color: Colors.white))]);
                              return const Center(child: Icon(Icons.error_outline, color: Colors.red));
                            },
                          )
                              : Image.file(_proofMediaFile!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Changer le média', style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // --- SIGNATURE SECTION ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Signature du Client', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF374151))),
                  GestureDetector(
                    onTap: () => _signatureController.clear(),
                    child: Text('Effacer', style: GoogleFonts.inter(color: Colors.red.shade400, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFF111827).withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Signature(
                    controller: _signatureController,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // --- BIG PREMIUM SUBMIT BUTTON ---
              Container(
                decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
                    ]
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981), // Emerald Green
                    disabledBackgroundColor: const Color(0xFF10B981).withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Clôturer le Ticket',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  // 💎 2026 UI: The Product Verification Card
  Widget _buildProductVerificationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withOpacity(0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.devices_other_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Matériel à Restituer',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF111827), letterSpacing: -0.3),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),
          _buildInfoRow(Icons.qr_code_rounded, 'Ticket', widget.ticket.savCode),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.inventory_2_outlined, 'Produit', widget.ticket.productName),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.tag_rounded, 'Série', widget.ticket.serialNumber),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF6B7280))),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF111827)),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
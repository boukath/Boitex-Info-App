// lib/screens/service_technique/finalize_sav_return_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Still needed for signature
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
  // ✅ ADDED Phone and Email controllers
  final _clientPhoneController = TextEditingController();
  final _clientEmailController = TextEditingController();
  final _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  File? _proofMediaFile;
  bool _isVideo = false;
  bool _isSaving = false;

  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';


  @override
  void dispose() {
    _clientNameController.dispose();
    // ✅ ADDED controllers to dispose
    _clientPhoneController.dispose();
    _clientEmailController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
    );

    if (result != null && result.files.single.path != null) {
      final pickedFile = File(result.files.single.path!);
      const maxFileSize = 50 * 1024 * 1024;
      if (pickedFile.lengthSync() > maxFileSize) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Le fichier dépasse la limite de 50 Mo.'),
              backgroundColor: Colors.red,
            ),
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
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv');
  }

  // --- Firebase Storage Upload Helper (ONLY for Signature) ---
  Future<String?> _uploadSignatureToFirebase(Uint8List fileData, String storagePath) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      final uploadTask = ref.putData(fileData);
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload signature: ${e.toString()}')),
        );
      }
      return null;
    }
  }
  // --- END Firebase Upload Helper ---

  // --- B2 HELPER FUNCTIONS ---
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
      debugPrint('Error calling Cloud Function for B2 credentials: $e');
      return null;
    }
  }

  Future<String?> _uploadFileToB2(
      File file, Map<String, dynamic> b2Creds, String desiredFileName) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);

      String? mimeType;
      final lcFileName = desiredFileName.toLowerCase();
      if (lcFileName.endsWith('.jpg') || lcFileName.endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (lcFileName.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (lcFileName.endsWith('.mp4')) {
        mimeType = 'video/mp4';
      } else if (lcFileName.endsWith('.mov')) {
        mimeType = 'video/quicktime';
      } else if (lcFileName.endsWith('.avi')) {
        mimeType = 'video/x-msvideo';
      } else if (lcFileName.endsWith('.mkv')) {
        mimeType = 'video/x-matroska';
      }

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
  // --- END B2 HELPER FUNCTIONS ---

  // ✅ MODIFIED to save phone and email
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La signature du client est requise.'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (_proofMediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Une photo ou vidéo de preuve est requise.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 1. Upload Signature (Firebase Storage)
      final signatureFirebasePath = 'sav_returns/signatures/${widget.ticket.savCode}-$timestamp.png';
      final signatureUrl = await _uploadSignatureToFirebase(
        signatureBytes!,
        signatureFirebasePath,
      );

      // 2. Upload Media (Backblaze B2)
      final fileExtension = path.extension(_proofMediaFile!.path);
      final mediaFolder = _isVideo ? 'videos' : 'photos';
      final b2FileName =
          'sav_returns/$mediaFolder/${widget.ticket.savCode}-$timestamp$fileExtension';

      final b2Credentials = await _getB2UploadCredentials();
      if (b2Credentials == null) {
        throw Exception('Impossible de récupérer les accès B2 pour le média de preuve.');
      }

      final mediaUrl = await _uploadFileToB2(
        _proofMediaFile!,
        b2Credentials,
        b2FileName,
      );

      if (signatureUrl == null || mediaUrl == null) {
        throw Exception('Échec de l\'upload d\'un ou plusieurs fichiers de preuve.');
      }

      // 3. Update Firestore (ADDED phone and email)
      await FirebaseFirestore.instance
          .collection('sav_tickets')
          .doc(widget.ticket.id)
          .update({
        'status': 'Retourné',
        'returnClientName': _clientNameController.text.trim(),
        'returnClientPhone': _clientPhoneController.text.trim(), // ✅ ADDED
        'returnClientEmail': _clientEmailController.text.trim(), // ✅ ADDED
        'returnSignatureUrl': signatureUrl,
        'returnPhotoUrl': mediaUrl,
      });

      // 4. Log Activity
      await ActivityLogger.logActivity(
        message:
        "Le ticket SAV ${widget.ticket.savCode} a été finalisé et retourné au client.",
        interventionId: widget.ticket.id,
        category: 'SAV',
      );

      // 5. Success Feedback & Navigation
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            content: Text('Retour du ticket SAV finalisé avec succès.'),
            backgroundColor: Colors.green),
      );
      navigator.pop();
      navigator.pop();

    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Finaliser Retour: ${widget.ticket.savCode}'),
        backgroundColor: Colors.green,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProductVerificationCard(),
              const SizedBox(height: 24),

              Text(
                'Confirmation de Réception Client',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clientNameController,
                decoration: const InputDecoration(
                  labelText: 'Gérant de magasin / Nom du Client', // Updated Label
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) =>
                value == null || value.isEmpty ? 'Veuillez entrer un nom.' : null,
              ),
              const SizedBox(height: 16), // Spacing after name

              // ✅ ADDED Phone Number Field
              TextFormField(
                controller: _clientPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Numéro de téléphone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                // Optional: Add validation if needed
                // validator: (value) { ... }
              ),
              const SizedBox(height: 16), // Spacing after phone

              // ✅ ADDED Email Field
              TextFormField(
                controller: _clientEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email (Optionnel)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                // Optional: Add validation if needed
                // validator: (value) { ... }
              ),
              // ✅ End Added Fields

              const SizedBox(height: 24), // Keep spacing before media proof
              const Text('Photo / Vidéo de preuve',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickMedia,
                icon: const Icon(Icons.perm_media_outlined),
                label: Text(_proofMediaFile == null
                    ? 'Prendre / Uploader Photo ou Vidéo'
                    : 'Changer le fichier'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              if (_proofMediaFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _isVideo
                        ? FutureBuilder<Uint8List?>(
                      future: VideoThumbnail.thumbnailData(
                        video: _proofMediaFile!.path, imageFormat: ImageFormat.JPEG, maxWidth: 300, quality: 50,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasData && snapshot.data != null) {
                          return Image.memory(snapshot.data!, fit: BoxFit.contain);
                        }
                        return const Center(child: Icon(Icons.error_outline, color: Colors.red));
                      },
                    )
                        : Image.file(_proofMediaFile!, fit: BoxFit.contain),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Signature du client',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => _signatureController.clear(),
                    child: const Text('Effacer'),
                  ),
                ],
              ),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Signature(
                    controller: _signatureController,
                    backgroundColor: Colors.grey[200]!,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                onPressed: _submitForm,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Finaliser et Clôturer le Ticket'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductVerificationCard() {
    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300)
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Article à Retourner',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Produit:', widget.ticket.productName),
            _buildInfoRow('N° Série:', widget.ticket.serialNumber),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

}
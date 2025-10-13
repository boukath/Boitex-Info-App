// lib/screens/service_technique/finalize_sav_return_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signature/signature.dart';

class FinalizeSavReturnPage extends StatefulWidget {
  final SavTicket ticket;

  const FinalizeSavReturnPage({super.key, required this.ticket});

  @override
  State<FinalizeSavReturnPage> createState() => _FinalizeSavReturnPageState();
}

class _FinalizeSavReturnPageState extends State<FinalizeSavReturnPage> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  File? _proofPhoto;
  bool _isSaving = false;

  @override
  void dispose() {
    _clientNameController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _proofPhoto = File(result.files.single.path!);
      });
    }
  }

  Future<String?> _uploadFile(dynamic fileData, String path) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      UploadTask uploadTask;

      if (fileData is File) {
        uploadTask = ref.putFile(fileData);
      } else if (fileData is Uint8List) {
        uploadTask = ref.putData(fileData);
      } else {
        return null;
      }

      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'upload: ${e.toString()}')),
      );
      return null;
    }
  }

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
    if (_proofPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Une photo de preuve est requise.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final signatureUrl = await _uploadFile(
        signatureBytes,
        'sav_returns/signatures/${widget.ticket.savCode}-$timestamp.png',
      );

      final photoUrl = await _uploadFile(
        _proofPhoto!,
        'sav_returns/photos/${widget.ticket.savCode}-$timestamp.jpg',
      );

      if (signatureUrl == null || photoUrl == null) {
        throw Exception('Erreur lors de l\'upload des fichiers de preuve.');
      }

      await FirebaseFirestore.instance
          .collection('sav_tickets')
          .doc(widget.ticket.id)
          .update({
        'status': 'Retourné',
        'returnClientName': _clientNameController.text.trim(),
        'returnSignatureUrl': signatureUrl,
        'returnPhotoUrl': photoUrl,
      });

      // ✅ FIXED: Corrected the ActivityLogger call
      await ActivityLogger.logActivity(
        message:
        "Le ticket SAV ${widget.ticket.savCode} a été finalisé et retourné au client.",
        interventionId: widget.ticket.id,
        category: 'SAV',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Retour du ticket SAV finalisé avec succès.'),
              backgroundColor: Colors.green),
        );
        // Pop twice to go back to the main list page
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
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
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Confirmation de Réception Client',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _clientNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom complet du client',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) =>
                value == null || value.isEmpty ? 'Veuillez entrer un nom.' : null,
              ),
              const SizedBox(height: 24),
              const Text('Photo de preuve',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(_proofPhoto == null
                    ? 'Prendre / Uploader une photo'
                    : 'Changer la photo'),
              ),
              if (_proofPhoto != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Image.file(_proofPhoto!, height: 150),
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
                ),
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.grey[200]!,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
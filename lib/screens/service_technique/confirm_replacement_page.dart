// lib/screens/service_technique/confirm_replacement_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signature/signature.dart';
import 'package:path/path.dart' as path;

class ConfirmReplacementPage extends StatefulWidget {
  final String requestId;
  const ConfirmReplacementPage({super.key, required this.requestId});

  @override
  State<ConfirmReplacementPage> createState() => _ConfirmReplacementPageState();
}

class _ConfirmReplacementPageState extends State<ConfirmReplacementPage> {
  Map<String, dynamic>? _requestData;
  bool _isLoadingData = true;
  bool _isCompleting = false;

  List<File> _pickedPhotos = [];
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _fetchRequestDetails();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequestDetails() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('replacementRequests').doc(widget.requestId).get();
      if (mounted) setState(() => _requestData = doc.data());
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (result != null) {
      setState(() {
        _pickedPhotos = result.paths.map((path) => File(path!)).toList();
      });
    }
  }

  Future<void> _completeReplacement() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La signature du responsable est requise.')));
      return;
    }
    if (_pickedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez télécharger au moins une photo.')));
      return;
    }

    setState(() => _isCompleting = true);

    try {
      // 1. Upload Signature
      final Uint8List? signatureData = await _signatureController.toPngBytes();
      final signatureStorageRef = FirebaseStorage.instance.ref().child('replacement_confirmations/${widget.requestId}/signature.png');
      await signatureStorageRef.putData(signatureData!);
      final signatureUrl = await signatureStorageRef.getDownloadURL();

      // 2. Upload Photos
      List<String> photoUrls = [];
      for (var file in _pickedPhotos) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
        final photoStorageRef = FirebaseStorage.instance.ref().child('replacement_confirmations/${widget.requestId}/$fileName');
        await photoStorageRef.putFile(file);
        photoUrls.add(await photoStorageRef.getDownloadURL());
      }

      // 3. Update Firestore Document
      await FirebaseFirestore.instance.collection('replacementRequests').doc(widget.requestId).update({
        'requestStatus': 'Remplacement Effectué',
        'completionSignatureUrl': signatureUrl,
        'completionPhotoUrls': photoUrls,
        'completedAt': Timestamp.now(),
      });

      // 4. Log to History
      await ActivityLogger.logActivity(
        message: "Remplacement pour ${_requestData!['savCode']} effectué.",
        category: "Remplacements",
        replacementRequestId: widget.requestId,
        clientName: _requestData!['clientName'],
        completionPhotoUrls: photoUrls,
        completionSignatureUrl: signatureUrl,
      );

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remplacement confirmé avec succès !'), backgroundColor: Colors.green,));
        // Pop twice to go back past the details page to the list
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmer le Remplacement'),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _requestData == null
          ? const Center(child: Text('Demande introuvable.'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Demande: ${_requestData!['replacementRequestCode']}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Client: ${_requestData!['clientName']}'),
            Text('Produit: ${_requestData!['productName']}'),
            const Divider(height: 32),

            const Text('Preuve par Photos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickPhotos,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text('Ajouter des photos (${_pickedPhotos.length})'),
            ),
            if (_pickedPhotos.isNotEmpty)
              Container(
                height: 100,
                margin: const EdgeInsets.only(top: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pickedPhotos.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Image.file(_pickedPhotos[index], width: 100, height: 100, fit: BoxFit.cover),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Signature du Responsable', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(child: const Text('Effacer'), onPressed: () => _signatureController.clear())
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)),
              child: Signature(controller: _signatureController, backgroundColor: Colors.grey[200]!),
            ),
            const SizedBox(height: 32),

            if (_isCompleting)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _completeReplacement,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Terminer le Remplacement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
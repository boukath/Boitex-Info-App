// lib/screens/service_technique/installation_report_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signature/signature.dart';
import 'package:path/path.dart' as path;

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
  List<File> _pickedPhotos = [];
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2, penColor: Colors.black, exportBackgroundColor: Colors.white,
  );

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
      final doc = await FirebaseFirestore.instance.collection('installations').doc(widget.installationId).get();
      if (mounted) setState(() => _installationDoc = doc);
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

  Future<void> _saveReport() async {
    if (_signatureController.isEmpty || _pickedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La signature et au moins une photo sont requises.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Upload Signature
      final signatureData = await _signatureController.toPngBytes();
      final sigRef = FirebaseStorage.instance.ref().child('installation_reports/${widget.installationId}/signature.png');
      await sigRef.putData(signatureData!);
      final signatureUrl = await sigRef.getDownloadURL();

      // Upload Photos
      List<String> photoUrls = [];
      for (var file in _pickedPhotos) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
        final photoRef = FirebaseStorage.instance.ref().child('installation_reports/${widget.installationId}/$fileName');
        await photoRef.putFile(file);
        photoUrls.add(await photoRef.getDownloadURL());
      }

      // Update Firestore
      await FirebaseFirestore.instance.collection('installations').doc(widget.installationId).update({
        'status': 'Terminée',
        'reportNotes': _notesController.text,
        'reportPhotoUrls': photoUrls,
        'reportSignatureUrl': signatureUrl,
        'completedAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapport enregistré avec succès!'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _installationDoc?.data() as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport d\'Installation')),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client: ${data?['clientName'] ?? '...'}', style: Theme.of(context).textTheme.headlineSmall),
            const Divider(height: 32),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Travaux effectués', border: OutlineInputBorder(), alignLabelWithHint: true),
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            const Text('Preuve par Photos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _pickPhotos, icon: const Icon(Icons.camera_alt_outlined), label: Text('Ajouter des photos (${_pickedPhotos.length})')),
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
                const Text('Signature du Client', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(child: const Text('Effacer'), onPressed: () => _signatureController.clear())
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
              child: Signature(controller: _signatureController, backgroundColor: Colors.grey[200]!),
            ),
            const SizedBox(height: 32),
            if (_isSaving)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveReport,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Terminer l\'Installation'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
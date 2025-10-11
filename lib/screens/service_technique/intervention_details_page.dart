// lib/screens/service_technique/intervention_details_page.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
// ✅ ADDED: Import the new PDF service
import 'package:boitex_info_app/services/intervention_pdf_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


// Data model for users in the multi-select dropdown
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

  // Define the status options based on the intervention's current status
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

    _managerNameController = TextEditingController(text: data['managerName']);
    _managerPhoneController = TextEditingController(text: data['managerPhone']);
    _diagnosticController = TextEditingController(text: data['diagnostic']);
    _workDoneController = TextEditingController(text: data['workDone']);
    _signatureController = SignatureController();
    _signatureImageUrl = data['signatureUrl'];
    _currentStatus = data['status'] ?? 'Nouveau';

    _fetchTechnicians().then((_) {
      // Initialize selected technicians after fetching all users
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

  Future<void> _saveReport() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
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

      final reportData = {
        'managerName': _managerNameController.text.trim(),
        'managerPhone': _managerPhoneController.text.trim(),
        'diagnostic': _diagnosticController.text.trim(),
        'workDone': _workDoneController.text.trim(),
        'signatureUrl': newSignatureUrl,
        'status': _currentStatus,
        'assignedTechnicians': _selectedTechnicians.map((tech) => {'uid': tech.uid, 'name': tech.displayName}).toList(),
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
}
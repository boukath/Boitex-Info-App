// lib/screens/service_technique/intervention_details_page.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:boitex_info_app/utils/report_generator.dart';

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
  late String _currentStatus;
  late String _initialStatus;
  TimeOfDay? _arrivalTime;
  TimeOfDay? _departureTime;
  bool _isLoading = false;
  late SignatureController _signatureController;
  String? _signatureImageUrl;
  List<AppUser> _techniciansList = [];
  List<AppUser> _selectedTechnicians = [];
  bool _isLoadingTechnicians = true;

  @override
  void initState() {
    super.initState();
    final data = widget.interventionDoc.data() as Map<String, dynamic>;

    _currentStatus = data['status'] ?? 'Inconnu';
    _initialStatus = data['status'] ?? 'Inconnu';
    _managerNameController = TextEditingController(text: data['report_managerName']);
    _managerPhoneController = TextEditingController(text: data['report_managerPhone']);
    _diagnosticController = TextEditingController(text: data['report_diagnostic']);
    _workDoneController = TextEditingController(text: data['report_workDone']);

    if (data['report_arrivalTime'] != null) {
      _arrivalTime = TimeOfDay.fromDateTime((data['report_arrivalTime'] as Timestamp).toDate());
    }
    if (data['report_departureTime'] != null) {
      _departureTime = TimeOfDay.fromDateTime((data['report_departureTime'] as Timestamp).toDate());
    }

    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _signatureImageUrl = data['report_signatureImageUrl'];

    _fetchTechnicians(data['report_technicians'] as List<dynamic>?);
  }

  Future<void> _fetchTechnicians(List<dynamic>? savedTechnicians) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users')
          .where('role', whereIn: [
        'Responsable Technique', 'Responsable IT', 'Chef de Projet',
        'Technique Technicien', 'Technicien IT'
      ]).get();

      final allTechnicians = snapshot.docs.map((doc) {
        return AppUser(uid: doc.id, displayName: doc.data()['displayName']);
      }).toList();

      final initiallySelected = <AppUser>[];
      if (savedTechnicians != null) {
        for (var savedTech in savedTechnicians) {
          final foundTech = allTechnicians.where((t) => t.uid == savedTech['uid']);
          if (foundTech.isNotEmpty) {
            initiallySelected.add(foundTech.first);
          }
        }
      }

      if(mounted) setState(() {
        _techniciansList = allTechnicians;
        _selectedTechnicians = initiallySelected;
        _isLoadingTechnicians = false;
      });
    } catch (e) {
      print("Error fetching technicians: $e");
      if(mounted) setState(() { _isLoadingTechnicians = false; });
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

  Future<void> _selectTime(BuildContext context, bool isArrivalTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isArrivalTime ? (_arrivalTime ?? TimeOfDay.now()) : (_departureTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isArrivalTime) { _arrivalTime = picked; }
        else { _departureTime = picked; }
      });
    }
  }

  Future<void> _saveReport() async {
    setState(() { _isLoading = true; });
    try {
      final interventionDate = (widget.interventionDoc['interventionDate'] as Timestamp).toDate();
      String? signatureUrlToSave = _signatureImageUrl;
      if (_signatureController.isNotEmpty) {
        final Uint8List? data = await _signatureController.toPngBytes();
        if (data != null) {
          final storageRef = FirebaseStorage.instance.ref().child('signatures/${widget.interventionDoc.id}_${DateTime.now().millisecondsSinceEpoch}.png');
          await storageRef.putData(data);
          signatureUrlToSave = await storageRef.getDownloadURL();
        }
      }
      final techniciansToSave = _selectedTechnicians.map((user) => {'uid': user.uid, 'displayName': user.displayName}).toList();
      await FirebaseFirestore.instance
          .collection('interventions')
          .doc(widget.interventionDoc.id)
          .update({
        'status': _currentStatus,
        'report_managerName': _managerNameController.text,
        'report_managerPhone': _managerPhoneController.text,
        'report_diagnostic': _diagnosticController.text,
        'report_workDone': _workDoneController.text,
        'report_arrivalTime': _arrivalTime != null ? Timestamp.fromDate(DateTime(interventionDate.year, interventionDate.month, interventionDate.day, _arrivalTime!.hour, _arrivalTime!.minute)) : null,
        'report_departureTime': _departureTime != null ? Timestamp.fromDate(DateTime(interventionDate.year, interventionDate.month, interventionDate.day, _departureTime!.hour, _departureTime!.minute)) : null,
        'report_signatureImageUrl': signatureUrlToSave,
        'report_technicians': techniciansToSave,
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapport enregistré avec succès'), backgroundColor: Colors.green));

        if (_currentStatus == 'Terminé' || _currentStatus == 'Clôturé') {
          Navigator.of(context).pop();
        } else {
          setState(() {
            _initialStatus = _currentStatus;
            _signatureImageUrl = signatureUrlToSave;
            if(_signatureController.isNotEmpty) { _signatureController.clear(); }
          });
        }
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  void _shareReport() {
    final data = widget.interventionDoc.data() as Map<String, dynamic>;
    Share.share('Rapport d\'intervention pour ${data['clientName']} - ${data['interventionCode']}');
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.interventionDoc.data() as Map<String, dynamic>;
    final bool isReadOnly = _initialStatus == 'Terminé' || _initialStatus == 'Clôturé';
    const Color primaryColor = Colors.blue;
    final OutlineInputBorder defaultBorder = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(12.0),
    );
    final OutlineInputBorder focusedBorder = OutlineInputBorder(
      borderSide: const BorderSide(color: primaryColor, width: 2.0),
      borderRadius: BorderRadius.circular(12.0),
    );

    // MODIFIED: Create the list of dropdown options dynamically
    final List<String> statusOptions = ['Nouveau', 'En cours', 'En attente', 'Terminé'];
    // If the intervention is ALREADY 'Clôturé', add it to the list
    // so the dropdown can display it. Otherwise, it's not an option.
    if (_initialStatus == 'Clôturé') {
      statusOptions.add('Clôturé');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Détails ${data['interventionCode']}'),
        backgroundColor: primaryColor,
        actions: isReadOnly ? [
          IconButton(icon: const Icon(Icons.picture_as_pdf), tooltip: 'Exporter en PDF', onPressed: () => ReportGenerator.generateAndSharePdf(data)),
          IconButton(icon: const Icon(Icons.share), tooltip: 'Partager', onPressed: _shareReport),
        ] : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ... The rest of your UI remains the same ...
          _buildSectionHeader('Résumé de la Demande'),
          ListTile(
            title: const Text('Client / Magasin'),
            subtitle: Text('${data['clientName']}\n${data['storeName']} - ${data['storeLocation']}', style: const TextStyle(fontSize: 16)),
            isThreeLine: true,
          ),
          ListTile(
            title: const Text('Date d\'intervention'),
            subtitle: Text(DateFormat('dd MMMM yyyy', 'fr_FR').format((data['interventionDate'] as Timestamp).toDate()), style: const TextStyle(fontSize: 16)),
          ),
          ListTile(
            title: const Text('Description du problème'),
            subtitle: Text(data['description'], style: const TextStyle(fontSize: 16)),
          ),

          _buildSectionHeader('Techniciens'),
          if (_isLoadingTechnicians)
            const Center(child: CircularProgressIndicator())
          else if (!isReadOnly)
            MultiSelectDialogField<AppUser>(
              items: _techniciansList.map((user) => MultiSelectItem(user, user.displayName)).toList(),
              initialValue: _selectedTechnicians,
              title: const Text("Sélectionner Techniciens"),
              buttonText: const Text("Techniciens affectés"),
              buttonIcon: const Icon(Icons.people),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)),
              onConfirm: (results) => setState(() { _selectedTechnicians = results; }),
              chipDisplay: MultiSelectChipDisplay(
                onTap: (value) => setState(() { _selectedTechnicians.remove(value); }),
              ),
            )
          else if (_selectedTechnicians.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text("Techniciens affectés"),
                subtitle: Text(_selectedTechnicians.map((e) => e.displayName).join(', ')),
              ),

          _buildSectionHeader('Rapport d\'Intervention'),
          const SizedBox(height: 16),
          TextFormField(controller: _managerNameController, readOnly: isReadOnly, decoration: InputDecoration(labelText: 'Nom du responsable', border: defaultBorder, focusedBorder: focusedBorder, floatingLabelStyle: const TextStyle(color: primaryColor))),
          const SizedBox(height: 16),
          TextFormField(controller: _managerPhoneController, readOnly: isReadOnly, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Numéro du responsable', border: defaultBorder, focusedBorder: focusedBorder, floatingLabelStyle: const TextStyle(color: primaryColor))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: InkWell(onTap: isReadOnly ? null : () => _selectTime(context, true), child: InputDecorator(
              decoration: InputDecoration(labelText: 'Heure d\'arrivée', border: defaultBorder, focusedBorder: focusedBorder, floatingLabelStyle: const TextStyle(color: primaryColor)),
              child: Text(_arrivalTime?.format(context) ?? 'Non définie'),
            ))),
            const SizedBox(width: 16),
            Expanded(child: InkWell(onTap: isReadOnly ? null : () => _selectTime(context, false), child: InputDecorator(
              decoration: InputDecoration(labelText: 'Heure de départ', border: defaultBorder, focusedBorder: focusedBorder, floatingLabelStyle: const TextStyle(color: primaryColor)),
              child: Text(_departureTime?.format(context) ?? 'Non définie'),
            ))),
          ]),
          const SizedBox(height: 16),
          TextFormField(controller: _diagnosticController, readOnly: isReadOnly, decoration: InputDecoration(labelText: 'Diagnostic', border: defaultBorder, focusedBorder: focusedBorder, alignLabelWithHint: true, floatingLabelStyle: const TextStyle(color: primaryColor)), maxLines: 4),
          const SizedBox(height: 16),
          TextFormField(controller: _workDoneController, readOnly: isReadOnly, decoration: InputDecoration(labelText: 'Travaux effectués', border: defaultBorder, focusedBorder: focusedBorder, alignLabelWithHint: true, floatingLabelStyle: const TextStyle(color: primaryColor)), maxLines: 4),

          _buildSectionHeader('Signature du Responsable'),
          const SizedBox(height: 8),
          Container(
            height: 150,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
            child: isReadOnly && _signatureImageUrl != null
                ? Image.network(_signatureImageUrl!, fit: BoxFit.contain)
                : Signature(controller: _signatureController, backgroundColor: Colors.grey[200]!),
          ),
          if(!isReadOnly)
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
            decoration: InputDecoration(border: defaultBorder, focusedBorder: focusedBorder, labelText: 'Statut de l\'intervention'),
            // MODIFIED: Use the dynamic list of options
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
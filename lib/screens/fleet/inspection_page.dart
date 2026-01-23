// lib/screens/fleet/inspection_page.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/vehicle.dart';
import 'package:boitex_info_app/models/inspection.dart';
import 'package:boitex_info_app/screens/fleet/widgets/car_inspection_widget.dart';

const Color kRacingRed = Color(0xFFFF2800);
const Color kCarbonBlack = Color(0xFF1C1C1C);

class InspectionPage extends StatefulWidget {
  final Vehicle vehicle;
  final String inspectionType; // 'DEPART' or 'RETOUR'

  const InspectionPage({
    super.key,
    required this.vehicle,
    this.inspectionType = 'ROUTINE',
  });

  @override
  State<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends State<InspectionPage> {
  final List<Defect> _defects = [];
  bool _isSavingSession = false;

  // ---------------------------------------------------------------------------
  // 🖱️ INTERACTION: TAP ON CAR
  // ---------------------------------------------------------------------------

  void _handleMapTap(double x, double y, String viewId) {
    _openDefectDialog(x: x, y: y, viewId: viewId);
  }

  // ---------------------------------------------------------------------------
  // 🛠️ INTERACTION: GENERAL ISSUE (Engine, noise, smell...)
  // ---------------------------------------------------------------------------

  void _handleGeneralIssue() {
    // We use x=-1, y=-1 to indicate "No Position"
    _openDefectDialog(x: -1, y: -1, viewId: 'general');
  }

  void _openDefectDialog({required double x, required double y, required String viewId}) async {
    final Defect? newDefect = await showModalBottomSheet<Defect>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddDefectDialog(
        vehicleCode: widget.vehicle.vehicleCode,
        x: x,
        y: y,
        viewId: viewId,
      ),
    );

    if (newDefect != null) {
      setState(() {
        _defects.add(newDefect);
      });
      HapticFeedback.heavyImpact();
    }
  }

  // ---------------------------------------------------------------------------
  // 💾 SAVING: COMMIT THE SESSION
  // ---------------------------------------------------------------------------

  Future<void> _finishInspection() async {
    setState(() => _isSavingSession = true);

    try {
      final inspection = Inspection(
        id: '', // Firestore will generate
        vehicleId: widget.vehicle.id!,
        date: DateTime.now(),
        inspectorId: 'CURRENT_USER_ID', // Replace with Auth ID
        type: widget.vehicle.currentMissionId != null ? 'RETOUR' : 'DEPART',
        defects: _defects,
        isCompleted: true,
      );

      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.vehicle.id)
          .collection('inspections')
          .add(inspection.toMap());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("INSPECTION ENREGISTRÉE (${_defects.length} DÉFAUTS)"),
            backgroundColor: const Color(0xFF00C853),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving inspection: $e");
      setState(() => _isSavingSession = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🎨 UI BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Separate defects into "Visual" (on map) and "General" (list)
    final generalDefects = _defects.where((d) => d.viewId == 'general').toList();
    final visualDefects = _defects.where((d) => d.viewId != 'general').toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "INSPECTION 360°",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Colors.black, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      // 🔹 1. THE "ADD GENERAL ISSUE" BUTTON (FAB)
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0), // Move up above the "Save" button
        child: FloatingActionButton.extended(
          onPressed: _handleGeneralIssue,
          backgroundColor: kCarbonBlack,
          icon: const Icon(Icons.build_circle, color: Colors.white),
          label: const Text("SIGNALER AUTRE PROBLÈME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),

      body: Column(
        children: [
          // INSTRUCTIONS
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFF8F9FA),
            width: double.infinity,
            child: const Text(
              "Touchez le véhicule pour les rayures. Utilisez le bouton 'Signaler Autre' pour les problèmes mécaniques.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),

          // 2. THE CAR BLUEPRINT (Visual Defects)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CarInspectionWidget(
                defects: visualDefects, // Only pass visual defects to the map
                onTap: _handleMapTap,
                onPinTap: (defect) => _showDefectOptions(defect),
              ),
            ),
          ),

          // 3. THE GENERAL ISSUES LIST (Mechanical/Smell/Noise)
          if (generalDefects.isNotEmpty) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(left: 24, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("PROBLÈMES GÉNÉRAUX / MÉCANIQUE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey)),
              ),
            ),
            Expanded(
              flex: 1,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: generalDefects.length,
                itemBuilder: (context, index) {
                  final d = generalDefects[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.red.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade100)),
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: kRacingRed),
                      title: Text(d.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(d.photoUrl != null ? "Photo jointe" : "Aucune photo", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
                        onPressed: () => setState(() => _defects.remove(d)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 4. ACTION BUTTON
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _defects.isEmpty ? const Color(0xFF00C853) : kRacingRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  onPressed: _isSavingSession ? null : _finishInspection,
                  child: _isSavingSession
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : Text(
                    _defects.isEmpty ? "R.A.S - VALIDER" : "ENREGISTRER DOMMAGES (${_defects.length})",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDefectOptions(Defect defect) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(defect.label),
        message: Text("Position: ${defect.viewId}"),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _defects.removeWhere((d) => d.id == defect.id);
              });
            },
            isDestructiveAction: true,
            child: const Text("Supprimer ce défaut"),
          )
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Annuler"),
        ),
      ),
    );
  }
}

// =============================================================================
// 🛠️ INTERNAL WIDGET: ADD DEFECT DIALOG (Updated)
// =============================================================================

class _AddDefectDialog extends StatefulWidget {
  final String vehicleCode;
  final double x;
  final double y;
  final String viewId;

  const _AddDefectDialog({
    required this.vehicleCode,
    required this.x,
    required this.y,
    required this.viewId,
  });

  @override
  State<_AddDefectDialog> createState() => _AddDefectDialogState();
}

class _AddDefectDialogState extends State<_AddDefectDialog> {
  String _selectedType = 'Rayure';
  final TextEditingController _commentCtrl = TextEditingController();

  // Different lists based on context
  late List<String> _types;

  File? _image;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Logic: If it's a "General" issue, show mechanical tags. If visual, show visual tags.
    if (widget.viewId == 'general') {
      _types = ['Moteur', 'Freins', 'Bruit', 'Odeur', 'Intérieur', 'Électronique', 'Pneu', 'Autre'];
      _selectedType = 'Moteur';
    } else {
      _types = ['Rayure', 'Bosse', 'Impact', 'Fissure', 'Cassé', 'Manquant', 'Saleté', 'Autre'];
    }
  }

  Future<String?> _uploadPhoto() async {
    if (_image == null) return null;
    setState(() => _isUploading = true);
    try {
      final uri = Uri.parse('https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl');
      final configResponse = await http.get(uri);
      if (configResponse.statusCode != 200) throw Exception('Auth Error');
      final config = jsonDecode(configResponse.body);

      final fileName = 'inspections/${widget.vehicleCode}/${DateTime.now().millisecondsSinceEpoch}${path.extension(_image!.path)}';
      final bytes = await _image!.readAsBytes();
      final sha1Checksum = sha1.convert(bytes).toString();

      final uploadResponse = await http.post(
        Uri.parse(config['uploadUrl']),
        headers: {
          'Authorization': config['authorizationToken'],
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Checksum,
        },
        body: bytes,
      );

      if (uploadResponse.statusCode != 200) throw Exception('Upload Failed');
      return '${config['downloadUrlPrefix']}$fileName';
    } catch (e) {
      debugPrint("Upload Error: $e");
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _confirm() async {
    // 🔹 VALIDATION: If "Autre" is selected, text must not be empty
    if (_selectedType == 'Autre' && _commentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veuillez décrire le problème pour la catégorie 'Autre'."),
            backgroundColor: Colors.red,
          )
      );
      return;
    }

    String? url;
    if (_image != null) {
      url = await _uploadPhoto();
      if (url == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur photo")));
        return;
      }
    }

    // 🔹 FORMATTING:
    // If "Autre", label is just the comment (e.g. "Radio HS")
    // If "Moteur", label is "Moteur: Bruit"
    String finalLabel;
    if (_selectedType == 'Autre') {
      finalLabel = _commentCtrl.text.trim();
    } else {
      if (_commentCtrl.text.isNotEmpty) {
        finalLabel = "$_selectedType: ${_commentCtrl.text}";
      } else {
        finalLabel = _selectedType;
      }
    }

    final defect = Defect(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      x: widget.x,
      y: widget.y,
      label: finalLabel,
      photoUrl: url,
      isRepaired: false,
      viewId: widget.viewId,
    );

    if (mounted) Navigator.pop(context, defect);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          top: 24, left: 24, right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24 // Handle Keyboard
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  widget.viewId == 'general' ? "SIGNALEMENT GÉNÉRAL" : "DOMMAGE VISUEL",
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5, fontSize: 12)
              ),
              if (widget.viewId != 'general')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                  child: Text(widget.viewId.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                )
            ],
          ),
          const SizedBox(height: 20),

          // 1. TYPE TAGS
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _types.map((type) {
              final isSelected = _selectedType == type;
              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                selectedColor: kCarbonBlack,
                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                onSelected: (val) => setState(() => _selectedType = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // 2. DESCRIPTION TEXT FIELD
          // We change the label based on selection
          TextField(
            controller: _commentCtrl,
            decoration: InputDecoration(
              // If "Autre", imply it is required
              labelText: _selectedType == 'Autre' ? "Description du problème (Requis)*" : "Description (Optionnel)",
              hintText: _selectedType == 'Autre' ? "Ex: Radio ne s'allume pas..." : "Ex: Bruit étrange, claquement...",
              filled: true,
              fillColor: const Color(0xFFF2F3F5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.edit_note, color: Colors.grey),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          // 3. PHOTO BUTTON
          Row(
            children: [
              InkWell(
                onTap: () async {
                  final picker = ImagePicker();
                  final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                  if (img != null) setState(() => _image = File(img.path));
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: _image != null ? Colors.green.shade50 : const Color(0xFFF2F3F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _image != null ? Colors.green : Colors.transparent),
                  ),
                  child: _image != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_image!, fit: BoxFit.cover))
                      : const Icon(CupertinoIcons.camera_fill, color: Colors.grey, size: 30),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  "Ajouter une photo (Recommandé pour les dommages).",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // 4. CONFIRM BUTTON
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kRacingRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isUploading ? null : _confirm,
              child: _isUploading
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Text("CONFIRMER LE POINT", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
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
import 'package:boitex_info_app/models/inspection.dart'; // ✅ Step 1
import 'package:boitex_info_app/screens/fleet/widgets/car_inspection_widget.dart'; // ✅ Step 2

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

  void _handleMapTap(double x, double y) async {
    // Open the "Add Defect" Dialog
    final Defect? newDefect = await showModalBottomSheet<Defect>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddDefectDialog(
        vehicleCode: widget.vehicle.vehicleCode,
        x: x,
        y: y,
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
      // 1. Create the Master Inspection Object
      final inspection = Inspection(
        id: '', // Firestore will generate
        vehicleId: widget.vehicle.id!,
        date: DateTime.now(),
        inspectorId: 'CURRENT_USER_ID', // Replace with Auth ID
        type: widget.vehicle.currentMissionId != null ? 'RETOUR' : 'DEPART',
        defects: _defects,
        isCompleted: true,
      );

      // 2. Save to Sub-Collection
      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.vehicle.id)
          .collection('inspections')
          .add(inspection.toMap());

      // 3. Update Vehicle Status (Optional: Block vehicle if critical defects?)
      // For now, we just log it.

      if (mounted) {
        Navigator.pop(context); // Close Page
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "INSPECTION 360°",
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Colors.black, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // 1. INSTRUCTIONS
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF8F9FA),
            width: double.infinity,
            child: const Text(
              "Appuyez sur la zone exacte du véhicule pour signaler un dommage (rayure, impact, bosse...).",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),

          // 2. THE INTERACTIVE BLUEPRINT
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: CarInspectionWidget(
                  defects: _defects,
                  onTap: _handleMapTap,
                  onPinTap: (defect) {
                    // TODO: Show details or allow delete
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(defect.label)));
                  },
                ),
              ),
            ),
          ),

          // 3. DEFECT LIST SUMMARY
          if (_defects.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _defects.length,
                itemBuilder: (context, index) {
                  final d = _defects[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kCarbonBlack,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: kRacingRed, size: 14),
                        const SizedBox(width: 8),
                        Text(d.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),

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
                    backgroundColor: _defects.isEmpty ? const Color(0xFF00C853) : kRacingRed, // Green if clean, Red if damages
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  onPressed: _isSavingSession ? null : _finishInspection,
                  child: _isSavingSession
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : Text(
                    _defects.isEmpty ? "R.A.S - VALIDER" : "ENREGISTRER DOMMAGES",
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
}

// =============================================================================
// 🛠️ INTERNAL WIDGET: ADD DEFECT DIALOG (With Upload)
// =============================================================================

class _AddDefectDialog extends StatefulWidget {
  final String vehicleCode;
  final double x;
  final double y;

  const _AddDefectDialog({required this.vehicleCode, required this.x, required this.y});

  @override
  State<_AddDefectDialog> createState() => _AddDefectDialogState();
}

class _AddDefectDialogState extends State<_AddDefectDialog> {
  String _selectedType = 'Rayure';
  final List<String> _types = ['Rayure', 'Bosse', 'Fissure', 'Cassé', 'Manquant', 'Saleté', 'Autre'];
  File? _image;
  bool _isUploading = false;

  Future<String?> _uploadPhoto() async {
    if (_image == null) return null;
    setState(() => _isUploading = true);

    try {
      // 1. Config
      final uri = Uri.parse('https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl');
      final configResponse = await http.get(uri);
      if (configResponse.statusCode != 200) throw Exception('Auth Error');
      final config = jsonDecode(configResponse.body);

      // 2. Prepare
      final fileName = 'inspections/${widget.vehicleCode}/${DateTime.now().millisecondsSinceEpoch}${path.extension(_image!.path)}';
      final bytes = await _image!.readAsBytes();
      final sha1Checksum = sha1.convert(bytes).toString();

      // 3. Upload
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
    String? url;
    if (_image != null) {
      url = await _uploadPhoto();
      if (url == null) {
        // Upload failed
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur photo")));
        return;
      }
    }

    final defect = Defect(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Temp ID
      x: widget.x,
      y: widget.y,
      label: _selectedType,
      photoUrl: url,
      isRepaired: false,
    );

    if (mounted) Navigator.pop(context, defect);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SIGNALER UN DOMMAGE", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5, fontSize: 12)),
          const SizedBox(height: 20),

          // 1. TYPE SELECTOR
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
          const SizedBox(height: 24),

          // 2. PHOTO BUTTON
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
                  "Prenez une photo du dommage pour preuve (Optionnel mais recommandé).",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // 3. CONFIRM BUTTON
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
          Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom)),
        ],
      ),
    );
  }
}
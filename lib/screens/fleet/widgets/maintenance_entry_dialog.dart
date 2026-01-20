// lib/screens/fleet/widgets/maintenance_entry_dialog.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart'; // For SHA1
import 'package:path/path.dart' as path;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/vehicle.dart';
import 'package:boitex_info_app/models/maintenance_log.dart';

// 🏎️ SCUDERIA THEME
const Color kRacingRed = Color(0xFFFF2800);
const Color kCarbonBlack = Color(0xFF1C1C1C);
const Color kAsphaltGrey = Color(0xFFF2F3F5);
const Color kMechanicBlue = Color(0xFF2962FF); // New color for custom parts

class MaintenanceEntryDialog extends StatefulWidget {
  final Vehicle vehicle;

  const MaintenanceEntryDialog({super.key, required this.vehicle});

  @override
  State<MaintenanceEntryDialog> createState() => _MaintenanceEntryDialogState();
}

class _MaintenanceEntryDialogState extends State<MaintenanceEntryDialog> {
  late TextEditingController _mileageCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _customPartCtrl; // ✅ NEW CONTROLLER

  // Selection State
  final List<String> _selectedItems = [MaintenanceItems.oilChange]; // Default to Oil Change
  final List<String> _customParts = []; // ✅ NEW LIST FOR CUSTOM PARTS

  File? _invoiceImage;
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _mileageCtrl = TextEditingController(text: widget.vehicle.currentMileage.toString());
    _costCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _customPartCtrl = TextEditingController(); // ✅ INIT
  }

  @override
  void dispose() {
    _mileageCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    _customPartCtrl.dispose(); // ✅ DISPOSE
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // ➕ CUSTOM PART LOGIC
  // ---------------------------------------------------------------------------

  void _addCustomPart() {
    final text = _customPartCtrl.text.trim();
    if (text.isNotEmpty && !_customParts.contains(text)) {
      setState(() {
        _customParts.add(text);
        _customPartCtrl.clear();
      });
      HapticFeedback.lightImpact();
    }
  }

  void _removeCustomPart(String part) {
    setState(() {
      _customParts.remove(part);
    });
    HapticFeedback.selectionClick();
  }

  // ---------------------------------------------------------------------------
  // 📸 B2 UPLOAD LOGIC
  // ---------------------------------------------------------------------------

  Future<String?> _uploadInvoiceToB2() async {
    if (_invoiceImage == null) return null;

    setState(() => _isUploading = true);

    try {
      final uri = Uri.parse('https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl');
      final configResponse = await http.get(uri);

      if (configResponse.statusCode != 200) throw Exception('Backend Auth Error');

      final config = jsonDecode(configResponse.body);
      final uploadUrl = config['uploadUrl'];
      final authToken = config['authorizationToken'];
      final downloadUrlPrefix = config['downloadUrlPrefix'];

      final fileName = 'maintenance/${widget.vehicle.vehicleCode}/invoice_${DateTime.now().millisecondsSinceEpoch}${path.extension(_invoiceImage!.path)}';
      final bytes = await _invoiceImage!.readAsBytes();
      final sha1Checksum = sha1.convert(bytes).toString();

      final uploadResponse = await http.post(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': authToken,
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Checksum,
        },
        body: bytes,
      );

      if (uploadResponse.statusCode != 200) throw Exception('B2 Upload Failed');

      return '$downloadUrlPrefix$fileName';

    } catch (e) {
      debugPrint("❌ Upload Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Échec de l'upload de la facture"), backgroundColor: Colors.red),
      );
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 💾 SAVE LOGIC
  // ---------------------------------------------------------------------------

  Future<void> _submitMaintenance() async {
    final int? mileage = int.tryParse(_mileageCtrl.text.replaceAll(' ', ''));
    if (mileage == null || mileage < 0) return;

    if (widget.vehicle.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur: ID Véhicule manquant")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? invoiceUrl = await _uploadInvoiceToB2();

      final batch = FirebaseFirestore.instance.batch();
      final vehicleRef = FirebaseFirestore.instance.collection('vehicles').doc(widget.vehicle.id);
      final logRef = vehicleRef.collection('maintenance_logs').doc();

      final newLog = MaintenanceLog(
        id: logRef.id,
        vehicleId: widget.vehicle.id!,
        date: DateTime.now(),
        mileage: mileage,
        performedItems: _selectedItems,
        customParts: _customParts, // ✅ SAVE THE NEW LIST
        invoiceUrl: invoiceUrl,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        cost: double.tryParse(_costCtrl.text.replaceAll(',', '.')),
        technicianId: 'CURRENT_USER_ID',
      );

      final Map<String, dynamic> vehicleUpdates = {
        'currentMileage': (mileage > widget.vehicle.currentMileage) ? mileage : widget.vehicle.currentMileage,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_selectedItems.contains(MaintenanceItems.oilChange)) {
        vehicleUpdates['lastOilChangeMileage'] = mileage;
        vehicleUpdates['nextOilChangeMileage'] = mileage + 10000;
      }

      batch.set(logRef, newLog.toMap());
      batch.update(vehicleRef, vehicleUpdates);

      await batch.commit();

      if (mounted) {
        Navigator.pop(context, true);
      }

    } catch (e) {
      debugPrint("Save Error: $e");
      setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🎨 UI COMPONENTS
  // ---------------------------------------------------------------------------

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
          // Drag Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "NOUVEL ENTRETIEN",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5),
              ),
              if (_isUploading)
                const CupertinoActivityIndicator(radius: 10),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Mileage Input
          TextField(
            controller: _mileageCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: kCarbonBlack),
            decoration: InputDecoration(
              suffixText: "KM",
              suffixStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
              border: InputBorder.none,
              filled: true,
              fillColor: kAsphaltGrey,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kRacingRed, width: 2)),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),

          const SizedBox(height: 24),
          const Text("OPÉRATIONS STANDARDS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),

          // 2. The Smart Chips Matrix (Standard)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildChip(MaintenanceItems.oilChange),
              _buildChip(MaintenanceItems.oilFilter),
              _buildChip(MaintenanceItems.airFilter),
              _buildChip(MaintenanceItems.fuelFilter),
              _buildChip(MaintenanceItems.cabinFilter),
              _buildChip(MaintenanceItems.brakesFront),
              _buildChip(MaintenanceItems.brakesRear),
            ],
          ),

          const SizedBox(height: 24),

          // 3. ✅ NEW: CUSTOM PARTS BUILDER
          const Text("AUTRES INTERVENTIONS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),

          // The Input Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customPartCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: "Ex: Alternateur, Durite...",
                    filled: true,
                    fillColor: kAsphaltGrey,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _addCustomPart(),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _addCustomPart,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: kMechanicBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(CupertinoIcons.add, color: Colors.white),
                ),
              ),
            ],
          ),

          // The Custom Chips Display
          if (_customParts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _customParts.map((part) => _buildCustomChip(part)).toList(),
            ),
          ],

          const SizedBox(height: 24),

          // 4. Invoice Camera & Cost
          Row(
            children: [
              InkWell(
                onTap: () async {
                  final picker = ImagePicker();
                  final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (img != null) setState(() => _invoiceImage = File(img.path));
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80, height: 60,
                  decoration: BoxDecoration(
                    color: _invoiceImage != null ? Colors.green.shade50 : kAsphaltGrey,
                    borderRadius: BorderRadius.circular(12),
                    border: _invoiceImage != null ? Border.all(color: Colors.green) : null,
                  ),
                  child: _invoiceImage != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_invoiceImage!, fit: BoxFit.cover))
                      : const Icon(CupertinoIcons.camera_fill, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Coût Total (DA)",
                    filled: true,
                    fillColor: kAsphaltGrey,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // 5. Save Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kRacingRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: kRacingRed.withOpacity(0.4),
              ),
              onPressed: (_isSaving || _isUploading) ? null : _submitMaintenance,
              child: _isSaving
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Text("VALIDER L'ENTRETIEN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
            ),
          ),

          Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom)),
        ],
      ),
    );
  }

  // 🔹 Standard Neon Chip
  Widget _buildChip(String itemKey) {
    final isSelected = _selectedItems.contains(itemKey);
    final label = MaintenanceItems.getLabel(itemKey);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          isSelected ? _selectedItems.remove(itemKey) : _selectedItems.add(itemKey);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? kCarbonBlack : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kCarbonBlack : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: kCarbonBlack.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : kCarbonBlack,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // 🔹 ✅ NEW: Custom Blue Chip
  Widget _buildCustomChip(String label) {
    return GestureDetector(
      onTap: () => _removeCustomPart(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: kMechanicBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kMechanicBlue),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: kMechanicBlue,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.close, size: 14, color: kMechanicBlue),
          ],
        ),
      ),
    );
  }
}
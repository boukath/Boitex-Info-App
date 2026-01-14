// lib/screens/fleet/edit_vehicle_compliance_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Added for Save Logic
import 'package:boitex_info_app/models/vehicle.dart';
import 'package:intl/intl.dart';

class EditVehicleCompliancePage extends StatefulWidget {
  final Vehicle vehicle;

  const EditVehicleCompliancePage({super.key, required this.vehicle});

  @override
  State<EditVehicleCompliancePage> createState() => _EditVehicleCompliancePageState();
}

class _EditVehicleCompliancePageState extends State<EditVehicleCompliancePage> {
  // Controllers
  late TextEditingController _mileageController;
  DateTime? _assuranceDate;
  DateTime? _controlDate;

  // Dirty Flag (to show Save button)
  bool _isModified = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // ✅ Initialize Text Controller with current value
    _mileageController = TextEditingController(text: widget.vehicle.currentMileage.toString());
    _assuranceDate = widget.vehicle.assuranceExpiry;
    _controlDate = widget.vehicle.controlTechniqueExpiry;
  }

  @override
  void dispose() {
    _mileageController.dispose();
    super.dispose();
  }

  void _markModified() {
    if (!_isModified) setState(() => _isModified = true);
  }

  // 💾 SAVE LOGIC
  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final int newMileage = int.tryParse(_mileageController.text.replaceAll(' ', '')) ?? widget.vehicle.currentMileage;

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.vehicle.id)
          .update({
        'currentMileage': newMileage,
        'assuranceExpiry': _assuranceDate,
        'controlTechniqueExpiry': _controlDate,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Success Feedback
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mise à jour effectuée avec succès !"),
          backgroundColor: Color(0xFF34C759),
        ),
      );
      Navigator.pop(context); // Close Page

    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Mise à jour Flotte",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: CupertinoActivityIndicator()))
          else if (_isModified)
            TextButton(
              onPressed: _saveChanges, // ✅ Calls the Save Logic
              child: const Text(
                "SAUVEGARDER",
                style: TextStyle(color: CupertinoColors.activeBlue, fontWeight: FontWeight.bold),
              ),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 1. MILEAGE UPDATER (Direct Input)
            _buildSectionHeader("KILOMÉTRAGE ACTUEL"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: _surfaceDecoration(),
              child: Column(
                children: [
                  // ✅ NEW: Simple Text Field Input
                  TextFormField(
                    controller: _mileageController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: -1.5),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(7), // Max 9,999,999 km
                    ],
                    decoration: InputDecoration(
                      hintText: "0",
                      suffixText: " km",
                      suffixStyle: TextStyle(fontSize: 24, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) => _markModified(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Touchez le chiffre pour modifier",
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 2. ASSURANCE RENEWAL (Smart Chips)
            _buildSectionHeader("RENOUVELLEMENT ASSURANCE"),
            const SizedBox(height: 16),
            _buildDateSelector(
              label: "Date d'expiration",
              currentDate: _assuranceDate,
              onDateSelected: (date) {
                setState(() => _assuranceDate = date);
                _markModified();
              },
              quickActions: [
                _buildQuickChip("+6 Mois", 6, (d) => setState(() => _assuranceDate = d)),
                _buildQuickChip("+1 An", 12, (d) => setState(() => _assuranceDate = d)),
              ],
              isCritical: widget.vehicle.isAssuranceCritical,
            ),

            const SizedBox(height: 32),

            // 3. CONTROL TECHNIQUE
            _buildSectionHeader("CONTRÔLE TECHNIQUE"),
            const SizedBox(height: 16),
            _buildDateSelector(
              label: "Prochaine visite",
              currentDate: _controlDate,
              onDateSelected: (date) {
                setState(() => _controlDate = date);
                _markModified();
              },
              quickActions: [
                _buildQuickChip("+1 An", 12, (d) => setState(() => _controlDate = d)),
              ],
              isCritical: false,
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🧩 PREMIUM WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.grey.shade500,
        fontWeight: FontWeight.w600,
        fontSize: 11,
        letterSpacing: 1.5,
      ),
    );
  }

  BoxDecoration _surfaceDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.grey.shade100),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime? currentDate,
    required Function(DateTime) onDateSelected,
    required List<Widget> quickActions,
    bool isCritical = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _surfaceDecoration().copyWith(
        border: isCritical ? Border.all(color: Colors.red.shade100, width: 2) : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.calendar, color: Colors.blue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      currentDate != null ? DateFormat('dd MMMM yyyy', 'fr').format(currentDate) : "Non défini",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // Camera Scan Button (Premium Touch)
              IconButton(
                onPressed: () {
                  // TODO: Trigger Camera Scan
                  HapticFeedback.lightImpact();
                },
                icon: const Icon(CupertinoIcons.viewfinder, size: 28),
                color: Colors.black,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Quick Chips Row
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text("Choisir une date", style: TextStyle(color: Colors.black, fontSize: 14)),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) onDateSelected(d);
                  },
                ),
              ),
              const SizedBox(width: 12),
              ...quickActions,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, int monthsToAdd, Function(DateTime) onApply) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        onTap: () {
          final newDate = DateTime.now().add(Duration(days: monthsToAdd * 30));
          onApply(newDate);
          _markModified();
          HapticFeedback.selectionClick();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
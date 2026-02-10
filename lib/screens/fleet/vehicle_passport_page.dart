// lib/screens/fleet/vehicle_passport_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui'; // Required for ImageFilter (Glass Effect)
import 'dart:math' as math;
import 'package:crypto/crypto.dart'; // For SHA1
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // For Gallery
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/vehicle.dart';
import 'package:boitex_info_app/models/maintenance_log.dart'; // ✅ STEP 1 IMPORT
import 'package:boitex_info_app/screens/fleet/edit_vehicle_compliance_page.dart';
import 'package:boitex_info_app/screens/fleet/widgets/maintenance_entry_dialog.dart'; // ✅ STEP 2 IMPORT
import 'package:boitex_info_app/screens/fleet/widgets/maintenance_details_sheet.dart'; // ✅ STEP 3 IMPORT (New Sheet)
// ✅ Import Inspection Page
import 'package:boitex_info_app/screens/fleet/inspection_page.dart';

// ✅ NEW IMPORTS FOR REPAIR MODULE
import 'package:boitex_info_app/screens/fleet/create_repair_order_page.dart';
import 'package:boitex_info_app/screens/fleet/repair_orders_list_page.dart';

// 🏎️ SCUDERIA THEME CONSTANTS
const Color kCeramicWhite = Color(0xFFFFFFFF);
const Color kRacingRed = Color(0xFFFF2800); // Rosso Corsa
const Color kCarbonBlack = Color(0xFF1C1C1C);
const Color kAsphaltGrey = Color(0xFFF2F3F5);
const Color kMechanicBlue = Color(0xFF2962FF); // New color for custom parts
const double kPadding = 24.0;

class VehiclePassportPage extends StatefulWidget {
  final Vehicle vehicle;

  const VehiclePassportPage({super.key, required this.vehicle});

  @override
  State<VehiclePassportPage> createState() => _VehiclePassportPageState();
}

class _VehiclePassportPageState extends State<VehiclePassportPage> with TickerProviderStateMixin {
  late Vehicle _vehicle;
  bool _isUploading = false;

  // 🎬 Animations
  late AnimationController _pulseController;
  late AnimationController _gaugeController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;

    // 1. Heartbeat Pulse (For Status)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 2. Gauge Sweep (Entrance)
    _gaugeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _gaugeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 📸 UPLOAD LOGIC (Kept Intact)
  // ---------------------------------------------------------------------------

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final File file = File(image.path);
      final String fileName = 'vehicles/${_vehicle.vehicleCode}/profile_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';

      final uploadConfig = await _getB2UploadConfig();

      await _uploadFileToB2(
        file: file,
        fileName: fileName,
        uploadUrl: uploadConfig['uploadUrl'],
        authToken: uploadConfig['authorizationToken'],
      );

      final String publicUrl = '${uploadConfig['downloadUrlPrefix']}$fileName';

      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(_vehicle.id)
          .update({'photoUrl': publicUrl});

      if (mounted) {
        setState(() {
          _vehicle = _vehicle.copyWith(photoUrl: publicUrl);
          _isUploading = false;
        });
        HapticFeedback.heavyImpact();
        _showScuderiaSnackBar("VISUEL MIS À JOUR", kRacingRed);
      }
    } catch (e) {
      debugPrint("❌ Error uploading photo: $e");
      if (mounted) {
        setState(() => _isUploading = false);
        _showScuderiaSnackBar("ÉCHEC ENVOI", kCarbonBlack);
      }
    }
  }

  Future<Map<String, dynamic>> _getB2UploadConfig() async {
    final uri = Uri.parse('https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Backend error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> _uploadFileToB2({
    required File file,
    required String fileName,
    required String uploadUrl,
    required String authToken,
  }) async {
    final bytes = await file.readAsBytes();
    final String sha1Checksum = sha1.convert(bytes).toString();

    final response = await http.post(
      Uri.parse(uploadUrl),
      headers: {
        'Authorization': authToken,
        'X-Bz-File-Name': Uri.encodeComponent(fileName),
        'Content-Type': 'b2/x-auto',
        'X-Bz-Content-Sha1': sha1Checksum,
      },
      body: bytes,
    );

    if (response.statusCode != 200) {
      throw Exception('B2 Upload failed: ${response.body}');
    }
  }

  void _showScuderiaSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontStyle: FontStyle.italic),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 📝 MILEAGE EDIT LOGIC (THE PENCIL)
  // ---------------------------------------------------------------------------

  void _showMileageEditDialog() {
    final TextEditingController mileageCtrl = TextEditingController(text: _vehicle.currentMileage.toString());
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "MISE À JOUR KILOMÉTRAGE",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: mileageCtrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kCarbonBlack),
                      decoration: InputDecoration(
                        suffixText: "KM",
                        suffixStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
                        border: InputBorder.none,
                        filled: true,
                        fillColor: kAsphaltGrey,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kRacingRed, width: 2),
                        ),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Actuel : ${NumberFormat('#,###').format(_vehicle.currentMileage)} KM",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kCarbonBlack,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                          final newVal = int.tryParse(mileageCtrl.text);
                          if (newVal != null) {
                            setModalState(() => isSaving = true);
                            await _updateMileage(newVal);
                            Navigator.pop(context);
                          }
                        },
                        child: isSaving
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : const Text("VALIDER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateMileage(int newMileage) async {
    try {
      await FirebaseFirestore.instance.collection('vehicles').doc(_vehicle.id).update({
        'currentMileage': newMileage,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _vehicle = _vehicle.copyWith(currentMileage: newMileage);
      });

      HapticFeedback.mediumImpact();
      _showScuderiaSnackBar("KILOMÉTRAGE MIS À JOUR", Colors.black);

      if (_vehicle.needsOilChange) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _showScuderiaSnackBar("⚠️ ENTRETIEN REQUIS", kRacingRed);
          HapticFeedback.heavyImpact();
        });
      }
    } catch (e) {
      debugPrint("Error updating mileage: $e");
      _showScuderiaSnackBar("ÉCHEC MISE À JOUR", kRacingRed);
    }
  }

  // ---------------------------------------------------------------------------
  // 🛠️ SERVICE RESET LOGIC (NEW: MAINTENANCE COCKPIT)
  // ---------------------------------------------------------------------------

  Future<void> _showServiceResetDialog() async {
    // We launch the new Cockpit Dialog.
    // It handles its own saving to 'maintenance_logs' and updates the vehicle doc.
    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MaintenanceEntryDialog(vehicle: _vehicle),
    );

    // If the dialog returned true, it means an operation was saved.
    // We must refresh the local Vehicle state to reflect new mileage/oil status.
    if (result == true && mounted) {
      try {
        final updatedDoc = await FirebaseFirestore.instance.collection('vehicles').doc(_vehicle.id).get();
        if (updatedDoc.exists) {
          setState(() {
            _vehicle = Vehicle.fromFirestore(updatedDoc);
          });
          HapticFeedback.heavyImpact();
          _showScuderiaSnackBar("ENTRETIEN ENREGISTRÉ", const Color(0xFF00C853)); // Green
        }
      } catch (e) {
        debugPrint("Error refreshing vehicle: $e");
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🎨 UI BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Light Status Bar for White Theme
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: kCeramicWhite,
      extendBodyBehindAppBar: true, // Glass Header Effect
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          // ✅ ADD BUTTON: The new button you requested in the AppBar
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            child: IconButton(
              icon: const Icon(CupertinoIcons.add, color: kRacingRed),
              onPressed: () {
                HapticFeedback.lightImpact();
                // Navigate to InspectionPage
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => InspectionPage(vehicle: _vehicle)),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            child: IconButton(
              icon: const Icon(CupertinoIcons.pencil, color: kRacingRed),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditVehicleCompliancePage(vehicle: _vehicle),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. AERO-GLASS HERO
            _buildAeroHero(),

            const SizedBox(height: 30),

            // 2. TWIN TURBO GAUGES
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kPadding),
              child: _buildSectionHeader("TÉLÉMÉTRIE"),
            ),
            const SizedBox(height: 20),
            _buildTwinTurboGauges(),

            const SizedBox(height: 40),

            // 3. FLUID INTEGRITY MONITOR (Prev. Fuel Injection)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kPadding),
              child: _buildSectionHeader("MÉCANIQUE & FLUIDES"),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kPadding),
              // ✅ UPDATED: New Segmented LED Telemetry System
              child: _buildFluidIntegrityMonitor(),
            ),

            const SizedBox(height: 40),

            // 4. DATA VAULT (CAROUSEL)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kPadding),
              child: _buildSectionHeader("DOCUMENTS DE BORD"),
            ),
            const SizedBox(height: 20),
            _buildDataCarousel(),

            const SizedBox(height: 40),

            // 🛠️ 5. ✅ NEW: REPAIR SHOP MODULE
            _buildWorkshopSection(),

            const SizedBox(height: 40),

            // 6. ✅ SERVICE HISTORY TIMELINE WITH ADD BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader("HISTORIQUE D'ENTRETIEN"),

                  // ✨ THE NEW VISIBLE BUTTON ✨
                  InkWell(
                    onTap: _showServiceResetDialog, // Opens the Cockpit
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: kRacingRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kRacingRed.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(CupertinoIcons.add, size: 14, color: kRacingRed),
                          SizedBox(width: 4),
                          Text(
                            "AJOUTER",
                            style: TextStyle(
                              color: kRacingRed,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildMaintenanceTimeline(),

            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🏭 WORKSHOP SECTION (NEW)
  // ---------------------------------------------------------------------------

  Widget _buildWorkshopSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kPadding),
          child: _buildSectionHeader("ATELIER & RÉPARATIONS"),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: kPadding),
          child: Row(
            children: [
              Expanded(
                child: _buildWorkshopButton(
                  label: "NOUVEL ORDRE",
                  icon: Icons.build_circle_outlined,
                  color: kCarbonBlack,
                  onTap: () {
                    // Navigate to Create Repair Order
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CreateRepairOrderPage(vehicle: _vehicle)),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildWorkshopButton(
                  label: "SUIVI ATELIER",
                  icon: Icons.history,
                  color: kMechanicBlue,
                  onTap: () {
                    // Navigate to Repair List
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RepairOrdersListPage()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkshopButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 📜 TIMELINE WIDGET
  // ---------------------------------------------------------------------------

  Widget _buildMaintenanceTimeline() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vehicles')
          .doc(_vehicle.id)
          .collection('maintenance_logs')
          .orderBy('date', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CupertinoActivityIndicator());

        final logs = snapshot.data!.docs;

        if (logs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text("Aucun historique disponible", style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true, // Crucial for nesting in ScrollView
          physics: const NeverScrollableScrollPhysics(), // Scroll managed by parent
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final data = logs[index].data() as Map<String, dynamic>;
            final log = MaintenanceLog.fromMap(data, logs[index].id);
            return _buildTimelineItem(log, isLast: index == logs.length - 1);
          },
        );
      },
    );
  }

  Widget _buildTimelineItem(MaintenanceLog log, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Date Column
          SizedBox(
            width: 70,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kPadding, vertical: 4),
              child: Column(
                children: [
                  Text(
                    DateFormat('dd').format(log.date),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kCarbonBlack),
                  ),
                  Text(
                    DateFormat('MMM').format(log.date).toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),

          // 2. Timeline Line
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: kRacingRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: kRacingRed.withOpacity(0.3), blurRadius: 4)],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: kAsphaltGrey,
                  ),
                ),
            ],
          ),

          // 3. Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: kPadding, bottom: 24),
              // ✅ MODIFICATION: Wrapped in InkWell to open MaintenanceDetailsSheet
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true, // Crucial for 85% height
                    backgroundColor: Colors.transparent,
                    builder: (context) => MaintenanceDetailsSheet(log: log),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${NumberFormat('#,###').format(log.mileage)} KM",
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          // Keep icon, but now tapping anywhere works
                          if (log.invoiceUrl != null)
                            const Icon(Icons.receipt_long, size: 18, color: kRacingRed),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ✅ HYBRID DISPLAY: STANDARD ICONS + CUSTOM TEXT BADGES
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Standard Items (Icons)
                          ...log.performedItems.map((item) => _buildItemIcon(item)),
                          // Custom Parts (Text Badges)
                          ...log.customParts.map((part) => _buildCustomBadge(part)),
                        ],
                      ),

                      if (log.notes != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            log.notes!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Maps Tags to Visual Icons
  Widget _buildItemIcon(String itemKey) {
    IconData icon;
    Color color = Colors.grey.shade700;

    switch (itemKey) {
      case MaintenanceItems.oilChange: icon = CupertinoIcons.drop_fill; color = Colors.black; break;
      case MaintenanceItems.oilFilter: icon = CupertinoIcons.tornado; break; // Wind/Filter
      case MaintenanceItems.airFilter: icon = CupertinoIcons.wind; break;
      case MaintenanceItems.brakesFront: icon = CupertinoIcons.stop_circle_fill; color = Colors.red; break;
      case MaintenanceItems.brakesRear: icon = CupertinoIcons.stop_circle; color = Colors.red; break;
      case MaintenanceItems.tires: icon = CupertinoIcons.circle_grid_hex; break;
      default: icon = CupertinoIcons.wrench_fill;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: kAsphaltGrey,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }

  // 🔹 ✅ NEW: Custom Text Badge for Timeline
  Widget _buildCustomBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kMechanicBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMechanicBlue.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kMechanicBlue,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _showInvoice(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 10, right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🏎️ HERO SECTION: Edge-to-Edge with Aero Glass
  // ---------------------------------------------------------------------------

  Widget _buildAeroHero() {
    return SizedBox(
      height: 420,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. The Car Image (Parallax potential)
          _vehicle.photoUrl != null
              ? Image.network(
            _vehicle.photoUrl!,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          )
              : Container(
            color: kAsphaltGrey,
            child: Center(
              child: Icon(CupertinoIcons.car_detailed, size: 100, color: Colors.grey.shade400),
            ),
          ),

          // 2. The Loading Overlay
          if (_isUploading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CupertinoActivityIndicator(color: Colors.white, radius: 15),
              ),
            ),

          // 3. The Aero-Glass Panel (Bottom)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Premium Blur
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85), // Frosted White
                    border: Border.all(color: Colors.white.withOpacity(0.6)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _vehicle.vehicleCode,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic, // SPEED VIBE
                              color: kCarbonBlack,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "SCUDERIA BOITEX // 2026",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade600,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                      // The Heartbeat Halo
                      _buildHeartbeatBadge(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Camera Fab (Floating on glass edge)
          Positioned(
            bottom: 100, // Just above the glass panel
            right: 40,
            child: FloatingActionButton(
              onPressed: _isUploading ? null : _pickAndUploadPhoto,
              backgroundColor: kRacingRed,
              elevation: 10,
              child: const Icon(CupertinoIcons.camera_fill, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartbeatBadge() {
    bool isCrit = _vehicle.isAssuranceCritical || _vehicle.assuranceExpiry == null;
    Color statusColor = isCrit ? kRacingRed : const Color(0xFF00C853); // Bright Green

    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing Ring
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 30 * _pulseAnimation.value,
              height: 30 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withOpacity(0.3 / _pulseAnimation.value),
              ),
            );
          },
        ),
        // Core Dot
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ⏱️ WIDGETS: TWIN TURBO GAUGES
  // ---------------------------------------------------------------------------

  Widget _buildTwinTurboGauges() {
    // Data
    int assDays = _vehicle.assuranceExpiry?.difference(DateTime.now()).inDays ?? 0;
    double assPercent = (assDays / 365).clamp(0.0, 1.0);

    int ctDays = _vehicle.controlTechniqueExpiry?.difference(DateTime.now()).inDays ?? 0;
    double ctPercent = (ctDays / 365).clamp(0.0, 1.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildOpenArcGauge(
          label: "ASSURANCE",
          value: assDays < 0 ? "EXP" : "$assDays",
          unit: "JOURS",
          percent: assPercent,
        ),
        _buildOpenArcGauge(
          label: "CONTRÔLE TECH",
          value: ctDays < 0 ? "EXP" : "$ctDays",
          unit: "JOURS",
          percent: ctPercent,
        ),
      ],
    );
  }

  Widget _buildOpenArcGauge({
    required String label,
    required String value,
    required String unit,
    required double percent,
  }) {
    return Column(
      children: [
        SizedBox(
          height: 140,
          width: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Custom Paint Gauge
              AnimatedBuilder(
                animation: _gaugeController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(140, 140),
                    painter: OpenArcPainter(
                      percent: percent * _gaugeController.value,
                      color: kRacingRed,
                    ),
                  );
                },
              ),
              // Center Text
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: kCarbonBlack,
                    ),
                  ),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.0),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 🎛️ FLUID INTEGRITY MONITOR (The "F1" Style Gauge)
  // ---------------------------------------------------------------------------

  Widget _buildFluidIntegrityMonitor() {
    // 1. Get Data from Smart Model
    // If last/next mileage is null, we consider the sensor "Uncalibrated"
    final bool isCalibrated = _vehicle.lastOilChangeMileage != null && _vehicle.nextOilChangeMileage != null;

    // 2. Calculate Math
    final double percentage = _vehicle.oilLifePercentage; // 0.0 to 1.0
    final int totalSegments = 20;
    final int activeSegments = (percentage * totalSegments).round();

    // 3. Determine Color Dynamic (Blue -> Amber -> Red)
    Color statusColor;
    if (!isCalibrated) {
      statusColor = Colors.grey.shade400; // Dead sensor
    } else if (percentage > 0.4) {
      statusColor = kMechanicBlue; // Safe (Cool Operation)
    } else if (percentage > 0.15) {
      statusColor = Colors.amber; // Warning (Heat rising)
    } else {
      statusColor = kRacingRed; // Critical
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Deep Carbon Background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER: Title + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.drop_fill, color: statusColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "INTEGRITY MONITOR",
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  isCalibrated ? "${(percentage * 100).toInt()}%" : "NO DATA",
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 📊 THE SEGMENTED LED BAR
          SizedBox(
            height: 24, // Height of the bars
            child: Row(
              children: List.generate(totalSegments, (index) {
                // Determine if this specific block is "lit"
                // We fill from left to right.
                bool isActive = index < activeSegments;

                // If uncalibrated, maybe show a "scanning" pattern or just grey
                if (!isCalibrated) isActive = false;

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isActive ? statusColor : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: isActive
                          ? [BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 4)]
                          : [],
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 24),

          // 📉 TELEMETRY DATA (Big Numbers)
          isCalibrated
              ? _buildTelemetryData(statusColor)
              : _buildUncalibratedState(),
        ],
      ),
    );
  }

  // ✅ UPDATED: DUAL DISPLAY COCKPIT (Fixed Overflow)
  Widget _buildTelemetryData(Color color) {
    final int remainingKm = (_vehicle.nextOilChangeMileage ?? 0) - _vehicle.currentMileage;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 1. LEFT: REALITY (Current Mileage)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Use FittedBox to scale text down if it gets too large
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  "${NumberFormat('#,###').format(_vehicle.currentMileage)} KM",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24, // Slightly smaller to fit both
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              Text(
                "KILOMÉTRAGE ACTUEL",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // 2. CENTER: DIVIDER
        Container(
          height: 40,
          width: 1,
          color: Colors.white.withOpacity(0.1),
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),

        // 3. RIGHT: TARGET (Countdown) + RESET
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ✅ FIXED: Wrapped in Expanded to allow text wrapping/shrinking
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "${NumberFormat('#,###').format(remainingKm)} KM",
                        style: TextStyle(
                          color: color, // Uses the status color (Blue/Amber/Red)
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                    Text(
                      "DISTANCE RESTANTE",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis, // ✅ Prevent overflow
                      maxLines: 1,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8), // ✅ Add spacing before button

              // Reset Button (The "Cockpit" Trigger)
              InkWell(
                onTap: _showServiceResetDialog,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Icon(CupertinoIcons.wrench_fill, color: color, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper: Shows the "Setup" button when data is missing
  Widget _buildUncalibratedState() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kRacingRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kRacingRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: kRacingRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "CAPTEUR NON CALIBRÉ",
                  style: TextStyle(color: kRacingRed, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  "Configurez le dernier entretien.",
                  style: TextStyle(color: kRacingRed.withOpacity(0.7), fontSize: 10),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showServiceResetDialog,
            style: TextButton.styleFrom(
              backgroundColor: kRacingRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text("SETUP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🏁 WIDGETS: DATA CAROUSEL
  // ---------------------------------------------------------------------------

  Widget _buildDataCarousel() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kPadding),
        children: [
          _buildCarbonCard("CARTE GRISE", _vehicle.carteGrisePhotoUrl != null),
          const SizedBox(width: 16),
          _buildCarbonCard("ASSURANCE", _vehicle.assurancePhotoUrl != null),
          const SizedBox(width: 16),
          _buildCarbonCard("CONTRÔLE TECH", _vehicle.controlTechniquePhotoUrl != null),
        ],
      ),
    );
  }

  Widget _buildCarbonCard(String title, bool isActive) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: isActive ? kRacingRed : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isActive ? Icons.check_circle : Icons.error_outline,
                color: isActive ? kCarbonBlack : Colors.grey.shade300,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.0,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🖌️ CUSTOM PAINTERS: OPEN ARC GAUGE
// ---------------------------------------------------------------------------

class OpenArcPainter extends CustomPainter {
  final double percent;
  final Color color;

  OpenArcPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const startAngle = 135 * (math.pi / 180); // Start at bottom left
    const sweepAngle = 270 * (math.pi / 180); // Sweep 270 degrees

    // 1. Background Arc
    final bgPaint = Paint()
      ..color = kAsphaltGrey
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, bgPaint);

    // 2. Active Arc
    final activePaint = Paint()
      ..color = color
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4); // Soft Neon Glow effect

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle * percent, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
// lib/screens/fleet/vehicle_passport_page.dart

import 'dart:convert';
import 'dart:io';
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
import 'package:boitex_info_app/screens/fleet/edit_vehicle_compliance_page.dart';

class VehiclePassportPage extends StatefulWidget {
  final Vehicle vehicle;

  const VehiclePassportPage({super.key, required this.vehicle});

  @override
  State<VehiclePassportPage> createState() => _VehiclePassportPageState();
}

class _VehiclePassportPageState extends State<VehiclePassportPage> {
  late Vehicle _vehicle;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
  }

  // ---------------------------------------------------------------------------
  // 📸 UPLOAD LOGIC (Cloud Function + Direct B2)
  // ---------------------------------------------------------------------------

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    // 1. Pick Image from Gallery
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920, // Full HD is enough for app usage
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      // 2. Prepare File
      final File file = File(image.path);
      final String fileName = 'vehicles/${_vehicle.vehicleCode}/profile_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';

      // 3. Get Upload Credentials from YOUR Backend
      final uploadConfig = await _getB2UploadConfig();

      // 4. Direct Upload to Backblaze
      await _uploadFileToB2(
        file: file,
        fileName: fileName,
        uploadUrl: uploadConfig['uploadUrl'],
        authToken: uploadConfig['authorizationToken'],
      );

      // 5. Construct Public URL
      // The Cloud Function returns a prefix like: https://f002.backblazeb2.com/file/BoitexInfo/
      final String publicUrl = '${uploadConfig['downloadUrlPrefix']}$fileName';

      // 6. Update Firestore
      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(_vehicle.id)
          .update({'photoUrl': publicUrl});

      // 7. Update Local UI
      if (mounted) {
        setState(() {
          _vehicle = _vehicle.copyWith(photoUrl: publicUrl);
          _isUploading = false;
        });
        HapticFeedback.heavyImpact();
      }

    } catch (e) {
      debugPrint("❌ Error uploading photo: $e");
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Échec de l'upload: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Calls your Firebase Cloud Function 'getB2UploadUrl'
  Future<Map<String, dynamic>> _getB2UploadConfig() async {
    // ⚠️ Ensure this URL matches your deployed region/project
    final uri = Uri.parse('https://europe-west1-boitex-info-app.cloudfunctions.net/getB2UploadUrl');

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Backend error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Performs the actual byte transfer to Backblaze
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

  // ---------------------------------------------------------------------------
  // 🎨 UI BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _vehicle.vehicleCode,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.5,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // ✏️ EDIT BUTTON
          IconButton(
            icon: const Icon(CupertinoIcons.pencil_circle_fill, size: 28),
            color: Colors.black,
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
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 1. HERO SECTION (The Glowing Car + Upload)
            _buildHeroSection(),

            const SizedBox(height: 32),

            // 2. LEGAL HEALTH RINGS
            _buildSectionTitle("SANTÉ JURIDIQUE"),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildHealthRing(
                    title: "Assurance",
                    expiryDate: _vehicle.assuranceExpiry,
                    color: const Color(0xFF007AFF), // iOS Blue
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildHealthRing(
                    title: "Contrôle Tech",
                    expiryDate: _vehicle.controlTechniqueExpiry,
                    color: const Color(0xFFFF9500), // iOS Orange
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // 3. MECHANICAL HEALTH
            _buildSectionTitle("MAINTENANCE MOTEUR"),
            const SizedBox(height: 16),
            _buildOilLifeCard(),

            const SizedBox(height: 32),

            // 4. DIGITAL GLOVEBOX
            _buildSectionTitle("BOÎTE À GANTS NUMÉRIQUE"),
            const SizedBox(height: 16),
            _buildDigitalGlovebox(),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🧩 WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildHeroSection() {
    Color statusColor = const Color(0xFF34C759); // Green
    String statusText = "Conforme";

    if (_vehicle.isAssuranceCritical || _vehicle.assuranceExpiry == null) {
      statusColor = const Color(0xFFFF3B30); // Red
      statusText = "Non Conforme";
    } else if (_vehicle.isAssuranceWarning) {
      statusColor = const Color(0xFFFF9500); // Orange
      statusText = "Attention";
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 20),
                spreadRadius: -5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // PHOTO
                _vehicle.photoUrl != null
                    ? Image.network(
                  _vehicle.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) =>
                  const Center(child: Icon(CupertinoIcons.car_detailed, size: 80, color: Colors.grey)),
                )
                    : const Center(child: Icon(CupertinoIcons.car_detailed, size: 80, color: Colors.grey)),

                // Gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.2)],
                    ),
                  ),
                ),

                // LOADING SPINNER
                if (_isUploading)
                  Container(
                    color: Colors.black.withOpacity(0.4),
                    child: const Center(
                      child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
                    ),
                  ),

                // UPLOAD BUTTON (Gallery Icon)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Material(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _isUploading ? null : _pickAndUploadPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        child: const Icon(CupertinoIcons.photo_on_rectangle, color: Colors.black, size: 22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Status Badge
        Positioned(
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthRing({required String title, required DateTime? expiryDate, required Color color}) {
    int daysLeft = 0;
    double percent = 0.0;
    String daysText = "N/A";

    if (expiryDate != null) {
      daysLeft = expiryDate.difference(DateTime.now()).inDays;
      if (daysLeft < 0) {
        daysText = "Expiré";
      } else {
        daysText = "$daysLeft Jours";
      }
      percent = (daysLeft / 365).clamp(0.0, 1.0);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
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
      ),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            width: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(value: 1.0, color: Colors.grey.shade100, strokeWidth: 6),
                CircularProgressIndicator(
                  value: percent,
                  color: daysLeft < 30 ? Colors.red : color,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Icon(
                    daysLeft < 0 ? Icons.warning_rounded : Icons.check_circle_rounded,
                    color: daysLeft < 30 ? Colors.red : color,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(daysText, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildOilLifeCard() {
    final int current = _vehicle.currentMileage;
    final int next = _vehicle.nextOilChangeMileage ?? (current + 10000);
    final int last = _vehicle.lastOilChangeMileage ?? (current - 5000);
    final int totalInterval = next - last;
    final int drivenSinceLast = current - last;
    double progress = (drivenSinceLast / totalInterval).clamp(0.0, 1.0);
    int remainingKm = next - current;

    Color barColor = const Color(0xFF34C759);
    if (progress > 0.8) barColor = const Color(0xFFFF9500);
    if (progress > 0.95) barColor = const Color(0xFFFF3B30);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
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
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("État de l'huile", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text("${(progress * 100).toInt()}% Usure", style: TextStyle(color: barColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade100, color: barColor, minHeight: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatColumn("Kilométrage", "${NumberFormat('#,###').format(current)} km"),
              _buildStatColumn("Prochaine", "${NumberFormat('#,###').format(next)} km"),
              _buildStatColumn("Restant", "$remainingKm km"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  Widget _buildDigitalGlovebox() {
    return Column(
      children: [
        _buildDocTile("Carte Grise", "Numérisé", CupertinoIcons.doc_text_fill, Colors.purple, _vehicle.carteGrisePhotoUrl != null),
        const SizedBox(height: 12),
        _buildDocTile("Assurance", "Expire dans ${_vehicle.assuranceExpiry?.difference(DateTime.now()).inDays ?? '?'} j", CupertinoIcons.shield_fill, Colors.blue, _vehicle.assurancePhotoUrl != null),
        const SizedBox(height: 12),
        _buildDocTile("Contrôle Tech", "Validité", CupertinoIcons.checkmark_seal_fill, Colors.orange, _vehicle.controlTechniquePhotoUrl != null),
      ],
    );
  }

  Widget _buildDocTile(String title, String subtitle, IconData icon, Color color, bool isPresent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ]),
          ),
          if (isPresent)
            Icon(Icons.visibility_rounded, color: Colors.grey.shade300)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Text("Scan", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 1.5));
  }
}
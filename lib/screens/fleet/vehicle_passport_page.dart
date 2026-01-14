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
import 'package:boitex_info_app/screens/fleet/edit_vehicle_compliance_page.dart';

// 🏎️ SCUDERIA THEME CONSTANTS
const Color kCeramicWhite = Color(0xFFFFFFFF);
const Color kRacingRed = Color(0xFFFF2800); // Rosso Corsa
const Color kCarbonBlack = Color(0xFF1C1C1C);
const Color kAsphaltGrey = Color(0xFFF2F3F5);
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
        _showScuderiaSnackBar("VISUAL UPDATED", kRacingRed);
      }
    } catch (e) {
      debugPrint("❌ Error uploading photo: $e");
      if (mounted) {
        setState(() => _isUploading = false);
        _showScuderiaSnackBar("UPLOAD FAILED", kCarbonBlack);
      }
    }
  }

  Future<Map<String, dynamic>> _getB2UploadConfig() async {
    final uri = Uri.parse('https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl');
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
              child: _buildSectionHeader("TELEMETRY"),
            ),
            const SizedBox(height: 20),
            _buildTwinTurboGauges(),

            const SizedBox(height: 40),

            // 3. FUEL INJECTION (FLUIDS)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kPadding),
              child: _buildSectionHeader("FLUID SYSTEMS"),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kPadding),
              child: _buildFuelInjectionSystem(),
            ),

            const SizedBox(height: 40),

            // 4. DATA VAULT (CAROUSEL)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kPadding),
              child: _buildSectionHeader("DATA VAULT"),
            ),
            const SizedBox(height: 20),
            _buildDataCarousel(),

            const SizedBox(height: 50),
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
          label: "INSURANCE",
          value: assDays < 0 ? "EXP" : "$assDays",
          unit: "DAYS",
          percent: assPercent,
        ),
        _buildOpenArcGauge(
          label: "TECH CONTROL",
          value: ctDays < 0 ? "EXP" : "$ctDays",
          unit: "DAYS",
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
  // ⛽ WIDGETS: FUEL INJECTION (FLUIDS)
  // ---------------------------------------------------------------------------

  Widget _buildFuelInjectionSystem() {
    final int current = _vehicle.currentMileage;
    final int next = _vehicle.nextOilChangeMileage ?? (current + 10000);
    final int last = _vehicle.lastOilChangeMileage ?? (current - 5000);
    final int totalInterval = next - last;
    final int drivenSinceLast = current - last;
    double depletion = (drivenSinceLast / totalInterval).clamp(0.0, 1.0);
    double remaining = 1.0 - depletion;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("OIL INTEGRITY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text("${(remaining * 100).toInt()}%", style: const TextStyle(color: kRacingRed, fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 20),
          // The Fuel Line
          SizedBox(
            height: 20,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    // Track
                    Container(
                      width: width,
                      height: 12,
                      decoration: BoxDecoration(
                        color: kAsphaltGrey,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    // Liquid Gradient
                    AnimatedContainer(
                      duration: const Duration(seconds: 1),
                      curve: Curves.easeOutExpo,
                      width: width * remaining,
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [kRacingRed, Color(0xFFFF5252)],
                        ),
                        boxShadow: [
                          BoxShadow(color: kRacingRed.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                    ),
                    // Droplet Icon Slider
                    AnimatedPositioned(
                      duration: const Duration(seconds: 1),
                      curve: Curves.easeOutExpo,
                      left: (width * remaining) - 14,
                      top: -6,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5),
                          ],
                        ),
                        child: const Icon(CupertinoIcons.drop_fill, color: kRacingRed, size: 16),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${NumberFormat('#,###').format(current)} KM", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              Text("NEXT: ${NumberFormat('#,###').format(next)}", style: const TextStyle(fontWeight: FontWeight.w900, color: kCarbonBlack)),
            ],
          ),
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
          _buildCarbonCard("REGISTRATION", _vehicle.carteGrisePhotoUrl != null),
          const SizedBox(width: 16),
          _buildCarbonCard("INSURANCE", _vehicle.assurancePhotoUrl != null),
          const SizedBox(width: 16),
          _buildCarbonCard("TECH REPORT", _vehicle.controlTechniquePhotoUrl != null),
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
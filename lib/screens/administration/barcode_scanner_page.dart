// lib/screens/administration/barcode_scanner_page.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:just_audio/just_audio.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> with TickerProviderStateMixin {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.all],
  );

  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _manualEntryController = TextEditingController();

  bool _isScanned = false;
  bool _isFlashOn = false;

  // Pro Feature: Smooth Pinch-to-Zoom state
  double _currentZoom = 0.0;
  double _baseZoom = 0.0;

  // Pro Feature: Google Lens Sweeping Laser
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  // Viewfinder pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initAudio();

    // 1. Setup Viewfinder Breathing Pulse
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    // 2. Setup AI Sweeping Laser
    _laserController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _laserAnimation = Tween<double>(begin: 0.0, end: 240.0).animate(CurvedAnimation(parent: _laserController, curve: Curves.easeInOut));
  }

  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setAsset('assets/sounds/beep.mp3');
      await _audioPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint("Error loading beep sound: $e");
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      _triggerSuccess(barcodes.first.rawValue!);
    }
  }

  void _triggerSuccess(String code) async {
    setState(() {
      _isScanned = true;
      _laserController.stop(); // Stop the laser
    });

    HapticFeedback.heavyImpact();
    if (_audioPlayer.playing) await _audioPlayer.stop();
    _audioPlayer.play();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.of(context).pop(code);
    });
  }

  void _toggleFlash() {
    HapticFeedback.selectionClick();
    _cameraController.toggleTorch();
    setState(() => _isFlashOn = !_isFlashOn);
  }

  // --- PRO FEATURE: Damaged Label Manual Entry ---
  void _showManualEntrySheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  const Text("Saisie Manuelle", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("L'étiquette est illisible ? Entrez le code ci-dessous.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 24),
                  CupertinoTextField(
                    controller: _manualEntryController,
                    placeholder: "Ex: SN-84930284",
                    placeholderStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 1.5),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.2))),
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        Navigator.pop(context); // Close sheet
                        _triggerSuccess(value); // Trigger success flow
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _cameraController.dispose();
    _audioPlayer.dispose();
    _pulseController.dispose();
    _laserController.dispose();
    _manualEntryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. APPLE-STYLE PINCH-TO-ZOOM CAMERA
          GestureDetector(
            onScaleStart: (details) {
              _baseZoom = _currentZoom;
            },
            onScaleUpdate: (details) {
              // Calculate smooth zoom
              double zoom = (_baseZoom + (details.scale - 1)).clamp(0.0, 1.0);
              setState(() => _currentZoom = zoom);
              _cameraController.setZoomScale(zoom);

              // Micro-haptics when hitting zoom extremes
              if (zoom == 0.0 || zoom == 1.0) HapticFeedback.lightImpact();
            },
            child: MobileScanner(
              controller: _cameraController,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) => const Center(child: Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.white, size: 40)),
            ),
          ),

          // 2. DARKENED OVERLAY MASK
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.srcOut),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)),
                Center(child: Container(height: 250, width: 250, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)))),
              ],
            ),
          ),

          // 3. PRO VIEWFINDER & ANIMATED LASER
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseAnimation, _laserAnimation]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _isScanned ? 1.05 : _pulseAnimation.value,
                  child: Container(
                    height: 250,
                    width: 250,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _isScanned ? Colors.greenAccent : Colors.white.withOpacity(0.5), width: _isScanned ? 4.0 : 2.0),
                      boxShadow: _isScanned ? [const BoxShadow(color: Colors.greenAccent, blurRadius: 20, spreadRadius: 5)] : [],
                    ),
                    child: Stack(
                      children: [
                        // Google Lens Sweeping Laser
                        if (!_isScanned)
                          Positioned(
                            top: _laserAnimation.value,
                            left: 0, right: 0,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.8), blurRadius: 10, spreadRadius: 2)],
                              ),
                            ),
                          ),
                        // Success Checkmark
                        if (_isScanned)
                          const Center(child: Icon(CupertinoIcons.checkmark_alt, color: Colors.greenAccent, size: 80)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 4. TOP BACK BUTTON
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            child: _buildGlassButton(icon: CupertinoIcons.xmark, onTap: () { HapticFeedback.lightImpact(); Navigator.of(context).pop(); }),
          ),

          // 5. SMART INSTRUCTION TEXT
          Positioned(
            top: MediaQuery.of(context).padding.top + 100,
            left: 0, right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _isScanned ? "Code détecté !" : "Recherche de code-barres...",
                key: ValueKey(_isScanned),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isScanned ? Colors.greenAccent : Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.2,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ),
          ),

          // 6. BOTTOM PRO CONTROL BAR (Flash & Manual Entry)
          Positioned(
            bottom: 50, left: 20, right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.2))),
                  child: Row(
                    children: [
                      // Flashlight
                      _buildCircleButton(
                        icon: _isFlashOn ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt_slash_fill,
                        isActive: _isFlashOn,
                        onTap: _toggleFlash,
                      ),

                      const SizedBox(width: 12),

                      // Manual Entry Button (Fills remaining space)
                      Expanded(
                        child: GestureDetector(
                          onTap: _showManualEntrySheet,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(25)),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.keyboard, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text("Saisie Manuelle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
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

  // --- UI Helpers ---
  Widget _buildGlassButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.2))),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50, height: 50,
        decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? Colors.white : Colors.transparent),
        child: Icon(icon, color: isActive ? Colors.black : Colors.white, size: 24),
      ),
    );
  }
}
// lib/screens/administration/product_scanner_page.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:just_audio/just_audio.dart';

class ProductScannerPage extends StatefulWidget {
  const ProductScannerPage({super.key});

  @override
  State<ProductScannerPage> createState() => _ProductScannerPageState();
}

class _ProductScannerPageState extends State<ProductScannerPage> with TickerProviderStateMixin {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.all],
  );

  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _manualEntryController = TextEditingController();

  // States
  bool _isScanned = false;
  bool _isError = false; // For Smart Rejection
  bool _isFlashOn = false;
  String _dynamicIslandText = "";

  // Pro Feature: Batch Mode
  bool _isBatchMode = false;
  List<String> _batchScannedCodes = [];

  // Proactive Assist Timer
  Timer? _struggleTimer;
  bool _userIsStruggling = false;

  // Smooth Pinch-to-Zoom state
  double _currentZoom = 0.0;
  double _baseZoom = 0.0;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _lockOnController;
  late Animation<double> _lockOnAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initAudio();

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _lockOnController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _lockOnAnimation = Tween<double>(begin: 250.0, end: 180.0).animate(CurvedAnimation(parent: _lockOnController, curve: Curves.easeOutBack));

    _startStruggleTimer();
  }

  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setAsset('assets/sounds/beep.mp3');
      await _audioPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint("Error loading beep sound: $e");
    }
  }

  void _startStruggleTimer() {
    _struggleTimer?.cancel();
    _struggleTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isScanned && !_isFlashOn) {
        setState(() => _userIsStruggling = true); // Triggers flashlight pulse
      }
    });
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isScanned || _isError) return;
    _struggleTimer?.cancel();
    setState(() => _userIsStruggling = false);

    final List<Barcode> barcodes = capture.barcodes.where((b) => b.rawValue != null).toList();
    if (barcodes.isEmpty) return;

    if (barcodes.length == 1) {
      _processCode(barcodes.first.rawValue!);
    } else {
      _cameraController.stop();
      HapticFeedback.heavyImpact();
      _showMultiCodeResolverSheet(barcodes);
    }
  }

  // --- PRO FEATURE: Smart Rejection Logic ---
  void _processCode(String code) {
    // Basic validation: Reject obvious URLs or insanely short codes
    if (code.startsWith("http") || code.length < 4) {
      _triggerError();
      return;
    }

    if (_isBatchMode) {
      if (!_batchScannedCodes.contains(code)) {
        _batchScannedCodes.add(code);
        _triggerSuccess(code, isBatch: true);
      } else {
        // Already scanned in batch
        _triggerError(customMessage: "Déjà scanné");
      }
    } else {
      _triggerSuccess(code);
    }
  }

  void _triggerError({String customMessage = "Code Invalide"}) {
    setState(() {
      _isError = true;
      _dynamicIslandText = customMessage;
    });

    HapticFeedback.vibrate(); // Double buzz feel
    Future.delayed(const Duration(milliseconds: 150), () => HapticFeedback.vibrate());

    _lockOnController.forward();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _isError = false);
        _lockOnController.reverse();
        _startStruggleTimer();
      }
    });
  }

  void _triggerSuccess(String code, {bool isBatch = false}) async {
    setState(() {
      _isScanned = true;
      _dynamicIslandText = isBatch ? "${_batchScannedCodes.length} Produit(s)" : code;
    });

    _pulseController.stop();
    _lockOnController.forward();

    HapticFeedback.heavyImpact();
    if (_audioPlayer.playing) await _audioPlayer.stop();
    _audioPlayer.play();

    if (isBatch) {
      // In batch mode, brief pause then resume scanning
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() => _isScanned = false);
          _lockOnController.reverse();
          _pulseController.repeat(reverse: true);
          _startStruggleTimer();
        }
      });
    } else {
      // Single scan mode -> return the code
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Navigator.of(context).pop(code);
      });
    }
  }

  void _toggleFlash() {
    HapticFeedback.selectionClick();
    _cameraController.toggleTorch();
    setState(() {
      _isFlashOn = !_isFlashOn;
      _userIsStruggling = false; // User took action
    });
  }

  void _finishBatch() {
    HapticFeedback.lightImpact();
    // Return all batch codes joined by comma, or as a List if your app supports it
    Navigator.of(context).pop(_batchScannedCodes.join(","));
  }

  // --- Multi-Code Resolver Sheet ---
  void _showMultiCodeResolverSheet(List<Barcode> barcodes) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2)))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.viewfinder_circle_fill, color: Colors.blueAccent, size: 50),
                const SizedBox(height: 12),
                const Text("Plusieurs codes détectés", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ...barcodes.map((barcode) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _cameraController.start();
                      _processCode(barcode.rawValue!);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.2))),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.barcode, color: Colors.white),
                          const SizedBox(width: 16),
                          Expanded(child: Text(barcode.rawValue!, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
                          const Icon(CupertinoIcons.chevron_right, color: Colors.white54, size: 20),
                        ],
                      ),
                    ),
                  ),
                )),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _cameraController.start();
                    _startStruggleTimer();
                  },
                  child: const Text("Annuler et rescanner", style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Manual Entry ---
  void _showManualEntrySheet() {
    HapticFeedback.mediumImpact();
    _cameraController.stop();
    _struggleTimer?.cancel();
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
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2)))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  const Text("Saisie Manuelle", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  CupertinoTextField(
                    controller: _manualEntryController,
                    placeholder: "Ex: PRD-84930284",
                    style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 1.5),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.2))),
                    autofocus: true,
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        Navigator.pop(context);
                        _processCode(value);
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
    ).whenComplete(() {
      if (!_isScanned && !_isError) {
        _cameraController.start();
        _startStruggleTimer();
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _cameraController.dispose();
    _audioPlayer.dispose();
    _pulseController.dispose();
    _lockOnController.dispose();
    _manualEntryController.dispose();
    _struggleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic colors based on state
    Color lockColor = Colors.white.withOpacity(0.5);
    if (_isScanned) lockColor = Colors.greenAccent;
    if (_isError) lockColor = Colors.redAccent;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. PINCH-TO-ZOOM CAMERA
          GestureDetector(
            onScaleStart: (details) => _baseZoom = _currentZoom,
            onScaleUpdate: (details) {
              double zoom = (_baseZoom + (details.scale - 1)).clamp(0.0, 1.0);
              setState(() => _currentZoom = zoom);
              _cameraController.setZoomScale(zoom);
            },
            child: MobileScanner(
              controller: _cameraController,
              onDetect: _onDetect,
            ),
          ),

          // 2. DARKENED OVERLAY
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.srcOut),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)),
                Center(child: Container(height: 300, width: 300, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)))),
              ],
            ),
          ),

          // 3. PRO DYNAMIC LOCK-ON VIEWFINDER
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseAnimation, _lockOnAnimation]),
              builder: (context, child) {
                final size = (_isScanned || _isError) ? _lockOnAnimation.value : 250.0 * _pulseAnimation.value;
                return Container(
                  height: size,
                  width: size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular((_isScanned || _isError) ? 40 : 24),
                    border: Border.all(color: lockColor, width: (_isScanned || _isError) ? 5.0 : 2.0),
                    boxShadow: (_isScanned || _isError) ? [BoxShadow(color: lockColor, blurRadius: 30, spreadRadius: 10)] : [],
                  ),
                  child: _isScanned
                      ? const Center(child: Icon(CupertinoIcons.checkmark_alt, color: Colors.greenAccent, size: 80))
                      : _isError
                      ? const Center(child: Icon(CupertinoIcons.xmark, color: Colors.redAccent, size: 80))
                      : null,
                );
              },
            ),
          ),

          // 4. TOP APP BAR (Back Button & Batch Done Button)
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGlassButton(icon: CupertinoIcons.xmark, onTap: () { HapticFeedback.lightImpact(); Navigator.of(context).pop(); }),

                // Show "Done" button only if in batch mode and items scanned
                if (_isBatchMode && _batchScannedCodes.isNotEmpty)
                  GestureDetector(
                    onTap: _finishBatch,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(25)),
                          child: const Row(
                            children: [
                              Text("Terminer", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              SizedBox(width: 8),
                              Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.black, size: 20)
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 5. PRO DYNAMIC ISLAND TOAST (Top Center)
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 80, right: 80,
            child: AnimatedSlide(
              offset: (_isScanned || _isError || (_isBatchMode && _batchScannedCodes.isNotEmpty)) ? Offset.zero : const Offset(0, -3.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                        color: _isError ? Colors.redAccent.withOpacity(0.2) : Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: _isError ? Colors.redAccent.withOpacity(0.5) : Colors.white.withOpacity(0.2))
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            _isError ? CupertinoIcons.exclamationmark_triangle_fill : CupertinoIcons.checkmark_seal_fill,
                            color: _isError ? Colors.redAccent : Colors.greenAccent, size: 20
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              _dynamicIslandText.isEmpty && _isBatchMode ? "${_batchScannedCodes.length} Produit(s)" : _dynamicIslandText,
                              textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 6. BOTTOM PRO CONTROL BAR
          Positioned(
            bottom: 50, left: 20, right: 20,
            child: AnimatedOpacity(
              opacity: (_isScanned || _isError) ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.2))),
                    child: Row(
                      children: [
                        // Flashlight with Proactive Assist Pulse
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: _userIsStruggling ? [BoxShadow(color: Colors.yellowAccent.withOpacity(0.6), blurRadius: 15, spreadRadius: 5)] : [],
                          ),
                          child: _buildCircleButton(icon: _isFlashOn ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt_slash_fill, isActive: _isFlashOn, onTap: _toggleFlash),
                        ),

                        const SizedBox(width: 8),

                        // Batch Mode Toggle
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _isBatchMode = !_isBatchMode);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _isBatchMode ? Colors.blueAccent.withOpacity(0.8) : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(_isBatchMode ? CupertinoIcons.square_stack_3d_up_fill : CupertinoIcons.square, color: Colors.white, size: 20),
                                const SizedBox(width: 6),
                                Text(_isBatchMode ? "Lot" : "Unique", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Manual Entry Button
                        GestureDetector(
                          onTap: _showManualEntrySheet,
                          child: Container(
                            height: 50, width: 50,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                            child: const Icon(CupertinoIcons.keyboard, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
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
        decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? Colors.white : Colors.black54),
        child: Icon(icon, color: isActive ? Colors.black : Colors.white, size: 24),
      ),
    );
  }
}
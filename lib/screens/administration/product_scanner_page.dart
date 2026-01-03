// lib/screens/administration/product_scanner_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:just_audio/just_audio.dart'; // ✅ Audio Feedback

class ProductScannerPage extends StatefulWidget {
  const ProductScannerPage({super.key});

  @override
  State<ProductScannerPage> createState() => _ProductScannerPageState();
}

class _ProductScannerPageState extends State<ProductScannerPage> {
  // ✅ 1. Controller with optimized settings
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  // ✅ 2. Audio Player
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      // Ensure 'assets/sounds/beep.mp3' is in your pubspec.yaml
      await _audioPlayer.setAsset('assets/sounds/beep.mp3');
      await _audioPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint("Error loading beep sound: $e");
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ✅ 3. Feedback Method
  void _playSuccessFeedback() {
    try {
      _audioPlayer.seek(Duration.zero);
      _audioPlayer.play();
    } catch (e) {
      // Ignore errors
    }
    HapticFeedback.heavyImpact(); // Industrial vibration feel
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? scannedCode = barcodes.first.rawValue;

      if (scannedCode != null) {
        // ✅ Play feedback immediately
        _playSuccessFeedback();

        setState(() {
          _isProcessing = true;
        });

        // Return the scanned code
        Navigator.of(context).pop(scannedCode);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 4. Define Scan Window Dimensions
    final double scanWindowWidth = 280;
    final double scanWindowHeight = 180; // Slightly wider for product labels

    // Calculate the Rect for the scanner
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(Offset.zero),
      width: scanWindowWidth,
      height: scanWindowHeight,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scanner un Produit'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // ✅ 5. Torch Toggle
          ValueListenableBuilder(
            valueListenable: _scannerController,
            builder: (context, state, child) {
              final bool isTorchOn = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(
                  isTorchOn ? Icons.flash_on : Icons.flash_off,
                  color: isTorchOn ? Colors.yellowAccent : Colors.grey,
                ),
                tooltip: 'Lampe Torche',
                onPressed: () => _scannerController.toggleTorch(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            // ✅ 6. Apply Scan Window (Camera ignores outside)
            scanWindow: scanWindow,
            onDetect: _onDetect,
          ),

          // ✅ 7. Dark Overlay with Cutout
          CustomPaint(
            painter: ScannerOverlayPainter(scanWindow),
            child: Container(),
          ),

          // ✅ 8. Red Target Box
          Center(
            child: Container(
              width: scanWindowWidth,
              height: scanWindowHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.redAccent, width: 2.0),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
              ),
            ),
          ),

          // Instruction Text
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Veuillez centrer le code-barres du produit',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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

// ✅ Reusable Painter for the Dark Overlay
class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;

  ScannerOverlayPainter(this.scanWindow);

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanWindow, const Radius.circular(12)));

    // Create the "Hole" effect using difference
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        backgroundPath,
        cutoutPath,
      ),
      Paint()..color = Colors.black.withOpacity(0.5), // Darken background
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
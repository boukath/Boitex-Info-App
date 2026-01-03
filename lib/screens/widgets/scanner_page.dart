// lib/screens/widgets/scanner_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:just_audio/just_audio.dart';

class ScannerPage extends StatefulWidget {
  final Function(String) onScan;
  final String? title;

  const ScannerPage({
    super.key,
    required this.onScan,
    this.title,
  });

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isScanProcessed = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setAsset('assets/sounds/beep.mp3');
      await _audioPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint("Error loading beep sound: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playSuccessFeedback() {
    try {
      _audioPlayer.seek(Duration.zero);
      _audioPlayer.play();
    } catch (e) {
      // Ignore
    }
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 1. Define the Scan Window Size
    final double scanWindowWidth = 280;
    final double scanWindowHeight = 280;

    // ✅ 2. Calculate the specific Rect for the scanner
    // This tells the camera exactly where to look relative to the screen
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(Offset.zero),
      width: scanWindowWidth,
      height: scanWindowHeight,
    );

    return Scaffold(
      backgroundColor: Colors.black, // Dark background looks better with camera
      appBar: AppBar(
        title: Text(widget.title ?? 'Scanner le Code-barres'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, child) {
              final bool isTorchOn = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(
                  isTorchOn ? Icons.flash_on : Icons.flash_off,
                  color: isTorchOn ? Colors.yellowAccent : Colors.grey,
                ),
                tooltip: 'Lampe Torche',
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            // ✅ 3. Apply the 'scanWindow' property
            // The camera will now IGNORE anything outside this box
            scanWindow: scanWindow,
            onDetect: (capture) {
              if (_isScanProcessed) return;

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? scannedId = barcodes.first.rawValue;
                if (scannedId != null) {
                  _playSuccessFeedback();

                  setState(() {
                    _isScanProcessed = true;
                  });

                  _controller.stop();
                  widget.onScan(scannedId);

                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                }
              }
            },
          ),

          // ✅ 4. Visual Overlay (The "Dark Mask" around the box)
          // This makes it obvious to the user that they must scan inside the box
          CustomPaint(
            painter: ScannerOverlayPainter(scanWindow),
            child: Container(),
          ),

          // ✅ 5. The Red Border Box
          Center(
            child: Container(
              width: scanWindowWidth,
              height: scanWindowHeight,
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.redAccent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ]
              ),
            ),
          ),

          // Instruction Text
          Positioned(
            bottom: 80,
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
                  "Placez le code-barres dans le cadre",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ Helper Class to draw the dark overlay around the scan window
class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;

  ScannerOverlayPainter(this.scanWindow);

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanWindow, const Radius.circular(12)));

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5) // 50% opacity mask
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut; // This creates the "Hole"

    // Draw the background with the hole cut out
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        backgroundPath,
        cutoutPath,
      ),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
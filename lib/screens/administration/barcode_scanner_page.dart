// lib/screens/administration/barcode_scanner_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:just_audio/just_audio.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  final AudioPlayer _audioPlayer = AudioPlayer();
  final StringBuffer _keyBuffer = StringBuffer();
  Timer? _bufferTimer;

  bool _isPopped = false;

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
    _cameraController.dispose();
    _bufferTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _handleScan(String code) {
    if (!mounted || _isPopped) return;
    if (code.isEmpty) return;

    _playSuccessFeedback();

    setState(() {
      _isPopped = true;
    });

    Navigator.of(context).pop(code);
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

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final String? character = event.character;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_keyBuffer.isNotEmpty) {
        String scanData = _keyBuffer.toString().trim();
        _keyBuffer.clear();
        _handleScan(scanData);
      }
      return;
    }

    if (character != null && character.isNotEmpty) {
      _keyBuffer.write(character);
      _bufferTimer?.cancel();
      _bufferTimer = Timer(const Duration(milliseconds: 200), () {
        _keyBuffer.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 1. Define Scan Window
    final double scanWindowWidth = 280;
    final double scanWindowHeight = 280;

    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(Offset.zero),
      width: scanWindowWidth,
      height: scanWindowHeight,
    );

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _onKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Scanner le code-barres'),
          actions: [
            ValueListenableBuilder(
              valueListenable: _cameraController,
              builder: (context, state, child) {
                final bool isTorchOn = state.torchState == TorchState.on;

                return IconButton(
                  icon: Icon(
                    isTorchOn ? Icons.flash_on : Icons.flash_off,
                    color: isTorchOn ? Colors.yellowAccent : Colors.grey,
                  ),
                  tooltip: 'Lampe Torche',
                  onPressed: () => _cameraController.toggleTorch(),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _cameraController,
              // ✅ 2. Apply Scan Window
              scanWindow: scanWindow,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String code = barcodes.first.rawValue ?? "";
                  _handleScan(code);
                }
              },
            ),

            // ✅ 3. Visual Overlay
            CustomPaint(
              painter: ScannerOverlayPainter(scanWindow), // Using the same painter class
              child: Container(),
            ),

            // ✅ 4. Red Box
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

            // Mode Indicator
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.qr_code_scanner, color: Colors.white, size: 30),
                      SizedBox(height: 8),
                      Text(
                        "Mode Hybride Actif",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Caméra (Cadre) + Laser",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ Reusable Painter (Can be copied to both files or put in a shared file)
class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;

  ScannerOverlayPainter(this.scanWindow);

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanWindow, const Radius.circular(12)));

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
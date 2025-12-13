import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  // Controller for the camera (Engine A)
  final MobileScannerController _cameraController = MobileScannerController();

  // Buffer to capture rapid keystrokes from the Yokoscan (Engine B)
  final StringBuffer _keyBuffer = StringBuffer();
  Timer? _bufferTimer;

  bool _isPopped = false;

  @override
  void dispose() {
    _cameraController.dispose();
    _bufferTimer?.cancel();
    super.dispose();
  }

  // Unified handler for both Camera and Hardware scans
  void _handleScan(String code) {
    if (!mounted || _isPopped) return;
    if (code.isEmpty) return;

    setState(() {
      _isPopped = true;
    });

    // Play a little beep or haptic feedback if you want (optional)
    HapticFeedback.lightImpact();

    // Return the code to the previous screen
    Navigator.of(context).pop(code);
  }

  // 👇 The "Magic": Captures hardware keystrokes
  void _onKeyEvent(KeyEvent event) {
    // We only care about key DOWN events
    if (event is! KeyDownEvent) return;

    final String? character = event.character;

    // 1. Detect the "Enter" key (signal that scan is complete)
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_keyBuffer.isNotEmpty) {
        // We have a full barcode in the buffer!
        String scanData = _keyBuffer.toString().trim();
        _keyBuffer.clear();
        _handleScan(scanData);
      }
      return;
    }

    // 2. Accumulate characters (numbers/letters)
    if (character != null && character.isNotEmpty) {
      _keyBuffer.write(character);

      // Security Timer: If we don't get another key within 200ms,
      // it's likely manual typing, not a scanner. Clear the buffer.
      _bufferTimer?.cancel();
      _bufferTimer = Timer(const Duration(milliseconds: 200), () {
        _keyBuffer.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🛡️ The Focus widget is the "Trap" that catches the keystrokes
    return Focus(
      autofocus: true, // Auto-focus immediately so we are ready to scan
      onKeyEvent: (node, event) {
        _onKeyEvent(event);
        return KeyEventResult.handled; // Stop the keys from triggering other things
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Scanner le code-barres')),
        body: Stack(
          children: [
            // ENGINE 1: Camera Scanner (Backup for standard phones)
            MobileScanner(
              controller: _cameraController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String code = barcodes.first.rawValue ?? "";
                  _handleScan(code);
                }
              },
            ),

            // ENGINE 2: UI Overlay telling the user what to do
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
                      SizedBox(height: 4),
                      Text(
                        "1. Visez avec la caméra\nOU\n2. Appuyez sur le bouton latéral (Laser)",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 13),
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
// lib/screens/widgets/scanner_page.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// ✅ Made this a StatefulWidget to manage the camera controller and scan state
class ScannerPage extends StatefulWidget {
  final Function(String) onScan;
  final String? title; // ✅ Added title parameter to customize the AppBar

  const ScannerPage({
    super.key,
    required this.onScan,
    this.title, // ✅ Added to constructor
  });

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanProcessed = false; // Prevents multiple scans

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ Use the custom title if provided, otherwise default
      appBar: AppBar(
        title: Text(widget.title ?? 'Scanner le Code-barres'),
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          // Only process the first scan detected
          if (_isScanProcessed) return;

          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? scannedId = barcodes.first.rawValue;
            if (scannedId != null) {
              setState(() {
                _isScanProcessed = true; // Mark as processed
              });

              // ✅ This is the key change: Stop the camera first!
              _controller.stop();

              // Call the original onScan function
              widget.onScan(scannedId);

              // Then, safely pop the screen
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
            }
          }
        },
      ),
    );
  }
}
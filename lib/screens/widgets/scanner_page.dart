import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerPage extends StatelessWidget {
  final Function(String) onScan;
  const ScannerPage({super.key, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner le Code-barres')),
      body: MobileScanner(
        onDetect: (capture) {
          final List barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? scannedId = barcodes.first.rawValue;
            if (scannedId != null) {
              onScan(scannedId);
              Navigator.of(context).pop(scannedId);
            }
          }
        },
      ),
    );
  }
}

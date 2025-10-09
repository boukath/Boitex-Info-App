import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner le Numéro de Série'),
        backgroundColor: Colors.black,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? scannedCode = barcodes.first.rawValue;
            if (scannedCode != null) {
              // When a code is detected, close this screen and send the code back
              Navigator.of(context).pop(scannedCode);
            }
          }
        },
      ),
    );
  }
}
// lib/widgets/serial_number_scanner_dialog.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/screens/widgets/scanner_page.dart';

class SerialNumberScannerDialog extends StatefulWidget {
  final ProductSelection productSelection;

  const SerialNumberScannerDialog({super.key, required this.productSelection});

  @override
  State<SerialNumberScannerDialog> createState() => _SerialNumberScannerDialogState();
}

class _SerialNumberScannerDialogState extends State<SerialNumberScannerDialog> {
  late List<String> _serialNumbers;

  @override
  void initState() {
    super.initState();
    _serialNumbers = List.from(widget.productSelection.serialNumbers);
  }

  Future<void> _scanSerialNumber() async {
    // Rule: Don't allow scanning more serials than the product quantity
    if (_serialNumbers.length >= widget.productSelection.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantité maximale de numéros de série atteinte.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? scannedCode;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerPage(onScan: (code) {
          scannedCode = code;
        }),
      ),
    );

    if (scannedCode != null && scannedCode!.isNotEmpty) {
      setState(() {
        // Rule: Don't add duplicate serial numbers
        if (!_serialNumbers.contains(scannedCode!.trim())) {
          _serialNumbers.add(scannedCode!.trim());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ce numéro de série a déjà été scanné.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Numéros de Série pour ${widget.productSelection.productName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: _scanSerialNumber,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scanner un N° de Série'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 16),
            Text('Scanné: ${_serialNumbers.length} / ${widget.productSelection.quantity}'),
            const Divider(),
            Expanded(
              child: _serialNumbers.isEmpty
                  ? const Center(child: Text('Aucun numéro de série scanné.'))
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: _serialNumbers.length,
                itemBuilder: (context, index) {
                  final sn = _serialNumbers[index];
                  return ListTile(
                    title: Text(sn),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _serialNumbers.removeAt(index);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          // Pass the updated list of serial numbers back when confirming
          onPressed: () => Navigator.of(context).pop(_serialNumbers),
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}
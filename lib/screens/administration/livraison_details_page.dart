// lib/screens/administration/livraison_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:boitex_info_app/screens/widgets/scanner_page.dart';
import 'package:signature/signature.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class LivraisonDetailsPage extends StatefulWidget {
  final String livraisonId;
  const LivraisonDetailsPage({super.key, required this.livraisonId});

  @override
  State<LivraisonDetailsPage> createState() => _LivraisonDetailsPageState();
}

class _LivraisonDetailsPageState extends State<LivraisonDetailsPage> {
  DocumentSnapshot? _livraisonDoc;
  // ✅ RESTRUCTURED: This list now holds individual physical items to be scanned.
  List<Map<String, dynamic>> _itemsToScan = [];
  bool _isLoading = true;
  bool _isCompleting = false;

  bool get _allScanned =>
      _itemsToScan.isNotEmpty &&
          _itemsToScan.every((item) => item['scanned'] == true);

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _loadLivraisonDetails();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }


  // ✅ REWRITTEN: This function now "flattens" the product list.
  Future<void> _loadLivraisonDetails() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('livraisons')
          .doc(widget.livraisonId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final products = data['products'] as List<dynamic>? ?? [];
        final List<Map<String, dynamic>> flattenedItems = [];

        // Loop through each product type in the delivery
        for (final product in products) {
          final serials = product['serialNumbers'] as List<dynamic>? ?? [];

          if (serials.isNotEmpty) {
            // If there are serial numbers, create one item for each serial
            for (final sn in serials) {
              flattenedItems.add({
                'productName': product['productName'] ?? 'N/A',
                'partNumber': product['partNumber'] ?? 'N/A',
                'serialNumber': sn.toString(),
                'scanTarget': sn.toString(), // The target to scan is the serial number
                'scanned': false,
              });
            }
          } else {
            // If no serials, create one item for each quantity of the part number
            final int quantity = product['quantity'] ?? 0;
            for (int i = 0; i < quantity; i++) {
              flattenedItems.add({
                'productName': product['productName'] ?? 'N/A',
                'partNumber': product['partNumber'] ?? 'N/A',
                'serialNumber': null, // No serial number for this item
                'scanTarget': product['partNumber'], // The target is the part number
                'scanned': false,
              });
            }
          }
        }

        setState(() {
          _livraisonDoc = doc;
          _itemsToScan = flattenedItems;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement: $e')),
      );
    }
  }

  // ✅ UPDATED: The scanning logic now compares against the 'scanTarget'
  void _scanItem(Map<String, dynamic> itemToScan) async {
    String? scannedCode;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerPage(onScan: (code) {
          scannedCode = code;
        }),
      ),
    );

    if (scannedCode != null) {
      if (scannedCode!.trim() == itemToScan['scanTarget']) {
        setState(() {
          itemToScan['scanned'] = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mauvais article scanné.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<String?> _uploadSignature() async {
    if (_signatureController.isEmpty) return null;
    final Uint8List? data = await _signatureController.toPngBytes();
    if (data == null) return null;

    final storageRef = FirebaseStorage.instance.ref().child(
        'livraison_signatures/${widget.livraisonId}/${DateTime.now().toIso8601String()}.png');
    final uploadTask = storageRef.putData(data);
    final snapshot = await uploadTask.whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _completeLivraison() async {
    setState(() => _isCompleting = true);

    try {
      final signatureUrl = await _uploadSignature();

      // Phase 3 logic will go here in the next step
      // For now, we just complete the delivery

      await FirebaseFirestore.instance
          .collection('livraisons')
          .doc(widget.livraisonId)
          .update({
        'status': 'Livré',
        'completedAt': FieldValue.serverTimestamp(),
        'signatureUrl': signatureUrl,
      });

      await ActivityLogger.logActivity(
        message: 'a confirmé la livraison pour le client ${_livraisonDoc?['clientName'] ?? ''}.',
        category: 'Livraison',
        clientName: _livraisonDoc?['clientName'],
        storeName: _livraisonDoc?['storeName'],
        completionSignatureUrl: signatureUrl,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détails de la Livraison')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final data = _livraisonDoc?.data() as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(data['bonLivraisonCode'] ?? 'Détails de la Livraison'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.business),
                title: Text(data['clientName'] ?? 'Client Inconnu'),
                subtitle: Text(
                    'Magasin: ${data['storeName'] ?? 'N/A'}\nAdresse: ${data['deliveryAddress'] ?? 'N/A'}'),
              ),
            ),
            const SizedBox(height: 16),

            Text('Produits à Scanner',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                // ✅ UPDATED: The UI now displays Part Number and Serial Number.
                children: _itemsToScan.map((item) {
                  return ListTile(
                    leading: item['scanned']
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.qr_code_scanner),
                    title: Text(item['productName']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Réf: ${item['partNumber']}'),
                        if (item['serialNumber'] != null)
                          Text('N/S: ${item['serialNumber']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    onTap: item['scanned'] ? null : () => _scanItem(item),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 32),

            Text('Preuve de Livraison',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Signature du Client'),
                        TextButton(
                            child: const Text('Effacer'),
                            onPressed: () => _signatureController.clear())
                      ],
                    ),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400)),
                      child: Signature(
                          controller: _signatureController,
                          backgroundColor: Colors.grey[200]!),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                (_isCompleting || !_allScanned) ? null : _completeLivraison,
                icon: const Icon(Icons.check_circle),
                label: const Text('Confirmer la Livraison'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
            if (_isCompleting)
              const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}
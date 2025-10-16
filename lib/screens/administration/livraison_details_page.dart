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

        for (final product in products) {
          final partNumber = product['partNumber'] as String?;
          final serials = product['serialNumbers'] as List<dynamic>? ?? [];
          final bool isPartNumberMissing = partNumber == null || partNumber.trim().isEmpty;

          if (serials.isNotEmpty) {
            for (final sn in serials) {
              flattenedItems.add({
                'productName': product['productName'] ?? 'N/A',
                'partNumber': partNumber,
                'serialNumber': sn.toString(),
                'isPartNumberMissing': isPartNumberMissing,
                'isSerialNumberMissing': false,
                'scanned': false,
              });
            }
          } else {
            final int quantity = product['quantity'] ?? 0;
            for (int i = 0; i < quantity; i++) {
              flattenedItems.add({
                'productName': product['productName'] ?? 'N/A',
                'partNumber': partNumber,
                'serialNumber': null,
                'isPartNumberMissing': isPartNumberMissing,
                'isSerialNumberMissing': true,
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Livraison non trouvée.')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  /// ✅ NEW: Dedicated function to scan only the Part Number (Reference).
  void _scanPartNumber(Map<String, dynamic> item) async {
    String? scannedCode;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => ScannerPage(onScan: (code) => scannedCode = code)),
    );

    final code = scannedCode?.trim();
    if (code == null || code.isEmpty) return;

    setState(() {
      item['partNumber'] = code;
      item['isPartNumberMissing'] = false;
    });
  }

  /// ✅ NEW: Dedicated function to scan only the Serial Number.
  void _scanSerialNumber(Map<String, dynamic> item) async {
    String? scannedCode;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => ScannerPage(onScan: (code) => scannedCode = code)),
    );

    final code = scannedCode?.trim();
    if (code == null || code.isEmpty) return;

    if (code == item['partNumber']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Le numéro de série ne peut pas être identique à la référence.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() {
      item['serialNumber'] = code;
      item['isSerialNumberMissing'] = false;
      item['scanned'] = true; // Item is now fully scanned and complete.
    });
  }

  /// This is the verification scan for items that had all data from the start.
  void _verifyItem(Map<String, dynamic> item) async {
    String? scannedCode;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => ScannerPage(onScan: (code) => scannedCode = code)),
    );

    final code = scannedCode?.trim();
    if (code == null || code.isEmpty) return;

    final target = item['serialNumber'] ?? item['partNumber'];
    if (code == target) {
      setState(() {
        item['scanned'] = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mauvais article scanné. Veuillez réessayer.'),
        backgroundColor: Colors.red,
      ));
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
    if (_livraisonDoc == null) return;
    setState(() => _isCompleting = true);

    try {
      final signatureUrl = await _uploadSignature();
      final livraisonData = _livraisonDoc!.data() as Map<String, dynamic>;
      final clientId = livraisonData['clientId'];
      final storeId = livraisonData['storeId'];

      if (storeId == null || storeId.isEmpty) {
        throw Exception('Impossible de sauvegarder l\'historique: Magasin non spécifié.');
      }

      final Map<String, dynamic> groupedProducts = {};
      for (final item in _itemsToScan) {
        final key = item['partNumber'];
        if (key == null) continue;

        if (!groupedProducts.containsKey(key)) {
          groupedProducts[key] = {
            'productName': item['productName'],
            'partNumber': item['partNumber'],
            'quantity': 0,
            'serialNumbers': <String>[],
          };
        }

        groupedProducts[key]['quantity']++;
        if (item['serialNumber'] != null) {
          groupedProducts[key]['serialNumbers'].add(item['serialNumber']);
        }
      }

      final List<Map<String, dynamic>> updatedProductsList =
      List<Map<String, dynamic>>.from(groupedProducts.values);

      final batch = FirebaseFirestore.instance.batch();
      final livraisonRef = FirebaseFirestore.instance.collection('livraisons').doc(widget.livraisonId);

      batch.update(livraisonRef, {
        'status': 'Livré',
        'completedAt': FieldValue.serverTimestamp(),
        'signatureUrl': signatureUrl,
        'products': updatedProductsList,
      });

      final materielCollectionRef = FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .doc(storeId)
          .collection('materiel_installe');

      for (final product in updatedProductsList) {
        final serials = product['serialNumbers'] as List<dynamic>? ?? [];
        if (serials.isNotEmpty) {
          for (final sn in serials) {
            final newMaterielDoc = materielCollectionRef.doc();
            batch.set(newMaterielDoc, {
              'productName': product['productName'],
              'partNumber': product['partNumber'],
              'serialNumber': sn,
              'installationDate': FieldValue.serverTimestamp(),
              'livraisonId': widget.livraisonId,
            });
          }
        }
      }

      await batch.commit();

      await ActivityLogger.logActivity(
        message: 'a confirmé la livraison pour le client ${livraisonData['clientName'] ?? ''}.',
        category: 'Livraison',
        clientName: livraisonData['clientName'],
        storeName: livraisonData['storeName'],
        completionSignatureUrl: signatureUrl,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
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
                children: _itemsToScan.map((item) {
                  final bool needsDataCapture = item['isPartNumberMissing'] || item['isSerialNumberMissing'];

                  return ListTile(
                    // ✅ NEW UI: Leading icon shows overall status.
                    leading: item['scanned']
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 30)
                        : const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 30),
                    title: Text(item['productName']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['isPartNumberMissing']
                              ? 'Réf: À scanner'
                              : 'Réf: ${item['partNumber'] ?? ''}',
                          style: TextStyle(
                            color: item['isPartNumberMissing'] ? Colors.orange.shade700 : null,
                            fontWeight: item['isPartNumberMissing'] ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        Text(
                          item['isSerialNumberMissing']
                              ? 'N/S: À scanner'
                              : 'N/S: ${item['serialNumber'] ?? ''}',
                          style: TextStyle(
                            color: item['isSerialNumberMissing'] ? Colors.orange.shade700 : null,
                            fontWeight: item['isSerialNumberMissing'] ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    // ✅ NEW UI: Trailing icons provide specific actions.
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Show button to scan PART NUMBER
                        if (item['isPartNumberMissing'] == true)
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            color: Colors.orange.shade700,
                            tooltip: 'Scanner la Référence',
                            onPressed: () => _scanPartNumber(item),
                          ),
                        // Show button to scan SERIAL NUMBER
                        if (item['isPartNumberMissing'] == false && item['isSerialNumberMissing'] == true)
                          IconButton(
                            icon: const Icon(Icons.qr_code),
                            color: Colors.blue.shade700,
                            tooltip: 'Scanner le Numéro de Série',
                            onPressed: () => _scanSerialNumber(item),
                          ),
                        // Show button to VERIFY item
                        if (!needsDataCapture && !item['scanned'])
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            tooltip: 'Vérifier l\'article',
                            onPressed: () => _verifyItem(item),
                          ),
                      ],
                    ),
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
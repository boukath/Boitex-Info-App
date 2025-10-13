// lib/screens/administration/livraison_details_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:boitex_info_app/screens/widgets/scanner_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signature/signature.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';

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
      _itemsToScan.isNotEmpty && _itemsToScan.every((item) => item['scanned'] == true);

  List<File> _pickedPhotos = [];
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

  // ✅ FIXED: Safely handles missing 'products' field.
  Future<void> _loadLivraisonDetails() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('livraisons')
          .doc(widget.livraisonId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        // Safely get the products list, defaulting to an empty list if it doesn't exist.
        final products = data['products'] as List<dynamic>? ?? [];

        setState(() {
          _livraisonDoc = doc;
          _itemsToScan = products
              .map((p) => {
            'productId': p['productId'],
            'productName': p['productName'],
            'quantity': p['quantity'],
            'scanned': false,
          })
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        // Handle case where document doesn't exist
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement: $e')),
      );
    }
  }

  void _scanItem(Map<String, dynamic> itemToScan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerPage(
          onScan: (scannedId) {
            if (scannedId == itemToScan['productId']) {
              setState(() {
                itemToScan['scanned'] = true;
              });
              Navigator.pop(context); // Close scanner on successful scan
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Mauvais produit scanné.'),
                backgroundColor: Colors.red,
              ));
            }
          },
        ),
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _pickedPhotos = result.paths.map((path) => File(path!)).toList();
      });
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
      // TODO: Handle photo uploads similarly

      await FirebaseFirestore.instance
          .collection('livraisons')
          .doc(widget.livraisonId)
          .update({
        'status': 'Livré',
        'completedAt': FieldValue.serverTimestamp(),
        'signatureUrl': signatureUrl,
        // 'photoUrls': photoUrls,
      });

      // Log the activity
      await ActivityLogger.logActivity(
        message: 'a confirmé la livraison pour le client ${_livraisonDoc?['clientName'] ?? ''}.',
        category: 'Livraison',
        clientName: _livraisonDoc?['clientName'],
        storeName: _livraisonDoc?['storeName'],
        completionSignatureUrl: signatureUrl,
      );

      if(mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if(mounted) setState(() => _isCompleting = false);
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
            // Client Info
            Card(
              child: ListTile(
                leading: const Icon(Icons.business),
                title: Text(data['clientName'] ?? 'Client Inconnu'),
                subtitle: Text(
                    'Magasin: ${data['storeName'] ?? 'N/A'}\nAdresse: ${data['deliveryAddress'] ?? 'N/A'}'),
              ),
            ),
            const SizedBox(height: 16),

            // Scan Items
            Text('Produits à Scanner', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: _itemsToScan.map((item) {
                  return ListTile(
                    leading: item['scanned']
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.qr_code_scanner),
                    title: Text(item['productName']),
                    subtitle: Text('ID: ${item['productId']}'),
                    onTap: item['scanned'] ? null : () => _scanItem(item),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 32),

            // Proof of Delivery
            Text('Preuve de Livraison',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Signature Pad
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
                    const SizedBox(height: 16),
                    // TODO: Add buttons to upload photos of signed doc / delivered items
                  ],
                ),
              ),
            ),
            const Divider(height: 32),

            // Completion Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isCompleting || !_allScanned)
                    ? null
                    : _completeLivraison,
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
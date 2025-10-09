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

  bool get _allScanned => _itemsToScan.isNotEmpty && _itemsToScan.every((item) => item['scanned'] == true);

  List<File> _pickedPhotos = [];
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2, penColor: Colors.black, exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _fetchLivraisonDetails();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _fetchLivraisonDetails() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('livraisons').doc(widget.livraisonId).get();
      if (mounted) {
        setState(() {
          _livraisonDoc = doc;
          _itemsToScan = List<Map<String, dynamic>>.from(doc.data()?['items'] ?? [])
              .map((item) => {...item, 'scanned': false})
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scanBarcode() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const ScannerPage()),
    );
    if (scannedCode == null) return;

    for (int i = 0; i < _itemsToScan.length; i++) {
      final item = _itemsToScan[i];
      if (item['scanned'] == false) {
        // In a real app, you'd check product['barcode'] == scannedCode
        // For this example, we assume any scan matches the next unscanned item.
        // This is a simplification. You'd need to fetch product barcodes.
        setState(() {
          _itemsToScan[i]['scanned'] = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item['productName']} scanné!'), backgroundColor: Colors.green));
        return; // Exit after one successful scan
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun article correspondant ou tous les articles déjà scannés.'), backgroundColor: Colors.orange));
  }

  Future<void> _pickPhotos() async {
    // ... photo picking logic
  }

  Future<void> _completeLivraison() async {
    if (!_allScanned) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez scanner tous les produits.')));
      return;
    }
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La signature du client est requise.')));
      return;
    }

    setState(() => _isCompleting = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      final signatureData = await _signatureController.toPngBytes();
      final sigRef = FirebaseStorage.instance.ref().child('livraison_proof/${widget.livraisonId}/signature.png');
      await sigRef.putData(signatureData!);
      final signatureUrl = await sigRef.getDownloadURL();

      // In a real app, you'd also upload photos of signed documents here

      await FirebaseFirestore.instance.collection('livraisons').doc(widget.livraisonId).update({
        'status': 'Livré',
        'deliveredAt': Timestamp.now(),
        'deliveredBy': user?.displayName ?? user?.email,
        'deliveryProofSignatureUrl': signatureUrl,
      });

      final data = _livraisonDoc!.data() as Map<String, dynamic>;
      await ActivityLogger.logActivity(
        message: "Livraison ${data['blCode']} effectuée.",
        category: "Livraisons",
        clientName: data['clientName'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Livraison confirmée!'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_livraisonDoc == null) return const Scaffold(body: Center(child: Text('Impossible de charger la livraison.')));

    final data = _livraisonDoc!.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(title: Text(data['blCode'] ?? 'Détails de Livraison')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Delivery Info
            Text('Pour: ${data['clientName']}', style: Theme.of(context).textTheme.titleLarge),
            Text('Destination: ${data['storeName']}'),
            const Divider(height: 32),

            // Barcode Scanning Section
            Text('1. Confirmation des Produits', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._itemsToScan.map((item) => ListTile(
              leading: Icon(
                item['scanned'] ? Icons.check_circle : Icons.radio_button_unchecked,
                color: item['scanned'] ? Colors.green : Colors.grey,
              ),
              title: Text(item['productName']),
              trailing: Text('Qté: ${item['quantity']}'),
            )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _allScanned ? null : _scanBarcode,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scanner un Produit'),
              ),
            ),
            if (_allScanned) Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Center(child: Text('Tous les articles sont confirmés!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
            ),
            const Divider(height: 32),

            // Proof of Delivery Section
            Text('2. Preuve de Livraison', style: Theme.of(context).textTheme.titleMedium),
            Opacity(
              opacity: _allScanned ? 1.0 : 0.3,
              child: AbsorbPointer(
                absorbing: !_allScanned,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Signature du Client'),
                        TextButton(child: const Text('Effacer'), onPressed: () => _signatureController.clear())
                      ],
                    ),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
                      child: Signature(controller: _signatureController, backgroundColor: Colors.grey[200]!),
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
                onPressed: (_isCompleting || !_allScanned) ? null : _completeLivraison,
                icon: const Icon(Icons.check_circle),
                label: const Text('Confirmer la Livraison'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)
                ),
              ),
            ),
            if (_isCompleting) const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}
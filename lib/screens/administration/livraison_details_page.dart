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
  List<Map<String, dynamic>> _serializedItems = [];
  List<Map<String, dynamic>> _bulkItems = [];
  bool _isLoading = true;
  bool _isCompleting = false;

  // ✅ FIXED: Completion logic now works for bulk-only OR serialized-only livraisons
  bool get _allCompleted {
    // At least one type of item must exist
    if (_serializedItems.isEmpty && _bulkItems.isEmpty) return false;

    // All serialized items must be scanned (if any exist)
    final serializedDone = _serializedItems.isEmpty ||
        _serializedItems.every((item) => item['scanned'] == true);

    // All bulk items must be delivered (if any exist)
    final bulkDone = _bulkItems.isEmpty ||
        _bulkItems.every((item) => item['delivered'] == true);

    return serializedDone && bulkDone;
  }

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
        final products = data['products'] as List? ?? [];

        final List<Map<String, dynamic>> serialized = [];
        final List<Map<String, dynamic>> bulk = [];

        for (final product in products) {
          final int quantity = product['quantity'] ?? 0;
          final String productName = product['productName'] ?? 'N/A';
          final String? partNumber = product['partNumber'] as String?;
          final List serials = product['serialNumbers'] as List? ?? [];

          // ✅ SMART DECISION: Quantity > 5 = Bulk item (no individual tracking)
          if (quantity > 5 && serials.isEmpty) {
            bulk.add({
              'productName': productName,
              'partNumber': partNumber,
              'quantity': quantity,
              'delivered': false,
              'type': 'bulk',
            });
          } else {
            // Serialized items - track individually
            if (serials.isNotEmpty) {
              for (final sn in serials) {
                serialized.add({
                  'productName': productName,
                  'partNumber': partNumber,
                  'serialNumber': sn.toString(),
                  'scanned': false,
                  'type': 'serialized',
                });
              }
            } else {
              // Small quantity without serials - still track individually
              for (int i = 0; i < quantity; i++) {
                serialized.add({
                  'productName': productName,
                  'partNumber': partNumber,
                  'serialNumber': null,
                  'scanned': false,
                  'type': 'serialized',
                });
              }
            }
          }
        }

        setState(() {
          _livraisonDoc = doc;
          _serializedItems = serialized;
          _bulkItems = bulk;
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

  void _scanSerializedItem(Map<String, dynamic> item) async {
    String? scannedCode;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ScannerPage(onScan: (code) => scannedCode = code)),
    );

    final code = scannedCode?.trim();
    if (code == null || code.isEmpty) return;

    setState(() {
      if (item['serialNumber'] == null) {
        item['serialNumber'] = code;
      }
      item['scanned'] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Article scanné avec succès'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _markBulkItemDelivered(Map<String, dynamic> item) {
    setState(() {
      item['delivered'] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ ${item['quantity']} x ${item['productName']} marqué comme livré'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _verifySingleFromBulk(Map<String, dynamic> item) async {
    String? scannedCode;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ScannerPage(onScan: (code) => scannedCode = code)),
    );

    final code = scannedCode?.trim();
    if (code == null || code.isEmpty) return;

    setState(() {
      item['delivered'] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Lot vérifié et marqué comme livré'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
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

      final Map<String, Map<String, dynamic>> groupedProducts = {};

      for (final item in _serializedItems) {
        final key = item['partNumber'] ?? item['productName'];
        if (!groupedProducts.containsKey(key)) {
          groupedProducts[key] = {
            'productName': item['productName'],
            'partNumber': item['partNumber'],
            'quantity': 0,
            'serialNumbers': [],
          };
        }
        groupedProducts[key]!['quantity'] = (groupedProducts[key]!['quantity'] as int) + 1;
        if (item['serialNumber'] != null) {
          (groupedProducts[key]!['serialNumbers'] as List).add(item['serialNumber']);
        }
      }

      for (final item in _bulkItems) {
        final key = item['partNumber'] ?? item['productName'];
        if (!groupedProducts.containsKey(key)) {
          groupedProducts[key] = {
            'productName': item['productName'],
            'partNumber': item['partNumber'],
            'quantity': item['quantity'],
            'serialNumbers': [],
          };
        }
      }

      final List<Map<String, dynamic>> updatedProductsList =
      List<Map<String, dynamic>>.from(groupedProducts.values);

      final batch = FirebaseFirestore.instance.batch();
      final livraisonRef =
      FirebaseFirestore.instance.collection('livraisons').doc(widget.livraisonId);

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
        final serials = product['serialNumbers'] as List? ?? [];
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
        message:
        'a confirmé la livraison pour le client ${livraisonData['clientName'] ?? ''}.',
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
    final int totalSerializedScanned =
        _serializedItems.where((item) => item['scanned'] == true).length;
    final int totalBulkDelivered =
        _bulkItems.where((item) => item['delivered'] == true).length;

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

            if (_serializedItems.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Produits avec N/S ($totalSerializedScanned/${_serializedItems.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: _serializedItems.map((item) {
                    return ListTile(
                      leading: item['scanned']
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 30)
                          : const Icon(Icons.inventory_2_outlined,
                          color: Colors.orange, size: 30),
                      title: Text(item['productName']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Réf: ${item['partNumber'] ?? 'À scanner'}'),
                          Text(
                            item['serialNumber'] != null
                                ? 'N/S: ${item['serialNumber']}'
                                : 'N/S: À scanner',
                            style: TextStyle(
                              color: item['serialNumber'] != null
                                  ? Colors.black87
                                  : Colors.orange.shade700,
                              fontWeight: item['serialNumber'] != null
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      trailing: !item['scanned']
                          ? IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        color: Colors.blue,
                        tooltip: 'Scanner',
                        onPressed: () => _scanSerializedItem(item),
                      )
                          : const Icon(Icons.check, color: Colors.green),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (_bulkItems.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.inventory, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Produits Cons ($totalBulkDelivered/${_bulkItems.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.green.shade50,
                child: Column(
                  children: _bulkItems.map((item) {
                    return ListTile(
                      leading: item['delivered']
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 30)
                          : const Icon(Icons.inventory_2_outlined,
                          color: Colors.grey, size: 30),
                      title: Text(
                        item['productName'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Réf: ${item['partNumber'] ?? 'N/A'}'),
                          Text(
                            'Quantité: ${item['quantity']}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      trailing: !item['delivered']
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            color: Colors.blue,
                            tooltip: 'Scanner (optionnel)',
                            onPressed: () => _verifySingleFromBulk(item),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _markBulkItemDelivered(item),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Livré'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      )
                          : const Icon(Icons.check, color: Colors.green, size: 28),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

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
                          onPressed: () => _signatureController.clear(),
                        )
                      ],
                    ),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
                      child: Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.grey[200]!,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isCompleting || !_allCompleted) ? null : _completeLivraison,
                icon: const Icon(Icons.check_circle),
                label: const Text('Confirmer la Livraison'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            if (_isCompleting)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

// lib/screens/widgets/batch_scanner_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/screens/widgets/scanner_page.dart';

// Enum to manage the current state of the scanner
enum BatchScanState { waitingForReference, waitingForSerial }

class BatchScannerPage extends StatefulWidget {
  final List<ProductSelection> initialProducts;

  const BatchScannerPage({super.key, required this.initialProducts});

  @override
  State<BatchScannerPage> createState() => _BatchScannerPageState();
}

class _BatchScannerPageState extends State<BatchScannerPage> {
  late List<ProductSelection> _scannedProducts;
  BatchScanState _currentState = BatchScanState.waitingForReference;
  ProductSelection? _currentProduct;

  @override
  void initState() {
    super.initState();
    _scannedProducts = List.from(widget.initialProducts);
  }

  // Main handler for scanned codes
  void _onCodeScanned(String code) {
    if (code.isEmpty) return;

    if (_currentState == BatchScanState.waitingForReference) {
      _handleReferenceScan(code);
    } else {
      _handleSerialScan(code);
    }
  }

  // Fetches product from Firestore based on reference
  Future<void> _handleReferenceScan(String reference) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('reference', isEqualTo: reference.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _showErrorSnackbar('Produit non trouvé.');
        return;
      }

      final productDoc = querySnapshot.docs.first;
      final productData = productDoc.data();
      final productId = productDoc.id;

      setState(() {
        // Check if this product is already in our main list
        final existingProductIndex =
        _scannedProducts.indexWhere((p) => p.productId == productId);

        if (existingProductIndex != -1) {
          _currentProduct = _scannedProducts[existingProductIndex];
        } else {
          _currentProduct = ProductSelection(
            productId: productId,
            productName: productData['nom'] ?? 'N/A',
            marque: productData['marque'] ?? 'N/A',
            partNumber: productData['reference'] ?? 'N/A',
            quantity: 0, // Start at 0, serials will increment it
          );
          _scannedProducts.add(_currentProduct!);
        }
        _currentState = BatchScanState.waitingForSerial;
      });
    } catch (e) {
      _showErrorSnackbar('Erreur: $e');
    }
  }

  // Adds a serial number to the current product
  void _handleSerialScan(String serialNumber) {
    if (_currentProduct == null) return;

    setState(() {
      if (!_currentProduct!.serialNumbers.contains(serialNumber.trim())) {
        _currentProduct!.serialNumbers.add(serialNumber.trim());
        _currentProduct!.quantity = _currentProduct!.serialNumbers.length;
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

  // Helper to show error messages
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Opens the scanner page
  Future<void> _startScan() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerPage(
          onScan: (code) {
            if (code != null) {
              _onCodeScanned(code);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Scanning'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _startScan,
            tooltip: 'Ouvrir le Scanner',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusHeader(),
          Expanded(child: _buildProductList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pop(_scannedProducts),
        icon: const Icon(Icons.check),
        label: const Text('Confirmer'),
      ),
    );
  }

  // The header that shows the current scanning state
  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      color: _currentState == BatchScanState.waitingForReference
          ? Colors.blue[800]
          : Colors.green[800],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentState == BatchScanState.waitingForReference
                ? 'En attente de la Référence Produit'
                : 'En attente des N° de Série',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          if (_currentState == BatchScanState.waitingForSerial &&
              _currentProduct != null) ...[
            const SizedBox(height: 4),
            Text(
              'Produit Actif: ${_currentProduct!.productName}',
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentState = BatchScanState.waitingForReference;
                    _currentProduct = null;
                  });
                },
                icon: const Icon(Icons.change_circle_outlined, color: Colors.white),
                label: const Text('Scanner un Autre Produit', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // The list of all scanned products and their serial numbers
  Widget _buildProductList() {
    if (_scannedProducts.isEmpty) {
      return const Center(child: Text('Aucun produit scanné.'));
    }
    return ListView.builder(
      itemCount: _scannedProducts.length,
      itemBuilder: (context, index) {
        final product = _scannedProducts[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            title: Text(product.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Réf: ${product.partNumber}'),
            trailing: Chip(
              label: Text('Qté: ${product.quantity}'),
              backgroundColor: Colors.blue[100],
            ),
            children: product.serialNumbers
                .map((sn) => ListTile(
              dense: true,
              title: Text(sn),
              leading: const Icon(Icons.qr_code),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () {
                  setState(() {
                    product.serialNumbers.remove(sn);
                    product.quantity = product.serialNumbers.length;
                  });
                },
              ),
            ))
                .toList(),
          ),
        );
      },
    );
  }
}
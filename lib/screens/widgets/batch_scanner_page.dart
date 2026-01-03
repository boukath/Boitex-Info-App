// lib/screens/widgets/batch_scanner_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // ✅ Scanning Engine
import 'package:just_audio/just_audio.dart'; // ✅ Audio Feedback
import 'package:boitex_info_app/models/selection_models.dart';

// Enum to manage the current state of the scanner
enum BatchScanState { waitingForReference, waitingForSerial }

class BatchScannerPage extends StatefulWidget {
  final List<ProductSelection> initialProducts;

  const BatchScannerPage({super.key, required this.initialProducts});

  @override
  State<BatchScannerPage> createState() => _BatchScannerPageState();
}

class _BatchScannerPageState extends State<BatchScannerPage> {
  // ✅ Data State
  late List<ProductSelection> _scannedProducts;
  BatchScanState _currentState = BatchScanState.waitingForReference;
  ProductSelection? _currentProduct;

  // ✅ Scanner State
  bool _isScanning = false; // Toggles between List View and Camera View
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  // ✅ Audio State
  final AudioPlayer _audioPlayer = AudioPlayer();
  DateTime? _lastScanTime; // Debounce to prevent double-beeps

  @override
  void initState() {
    super.initState();
    _scannedProducts = List.from(widget.initialProducts);
    _initAudio();
  }

  // Preload the beep sound for instant feedback
  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setAsset('assets/sounds/beep.mp3');
      await _audioPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint("Error loading beep sound: $e");
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ✅ Unified Feedback Method (Beep + Vibrate)
  void _playSuccessFeedback() {
    // Prevent spamming (limit to 1 beep per 500ms)
    if (_lastScanTime != null && DateTime.now().difference(_lastScanTime!).inMilliseconds < 500) {
      return;
    }
    _lastScanTime = DateTime.now();

    try {
      _audioPlayer.seek(Duration.zero);
      _audioPlayer.play();
    } catch (e) {
      // Ignore audio errors
    }
    HapticFeedback.heavyImpact(); // Industrial vibration feel
  }

  // Main handler for scanned codes
  void _onCodeScanned(String code) {
    if (code.isEmpty) return;

    // ✅ Play feedback immediately upon detection
    _playSuccessFeedback();

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
        _showErrorSnackbar('Produit non trouvé : $reference');
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
            quantity: 0,
          );
          _scannedProducts.add(_currentProduct!);
        }
        _currentState = BatchScanState.waitingForSerial;
      });

      // ✅ Visual feedback inside scanner
      _showSuccessSnackbar("Produit identifié : ${_currentProduct?.productName}");

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
        _showSuccessSnackbar("Série ajouté : $serialNumber");
      } else {
        _showErrorSnackbar('Série déjà scanné : $serialNumber');
      }
    });
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 2)),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green, duration: const Duration(milliseconds: 1000)),
    );
  }

  // Toggles the scanning mode
  void _toggleScanMode() {
    setState(() {
      _isScanning = !_isScanning;
      if (_isScanning) {
        _cameraController.start();
      } else {
        _cameraController.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Intercept Back Button to close scanner first
    return PopScope(
      canPop: !_isScanning,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _toggleScanMode();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isScanning ? 'Scanner en cours...' : 'Batch Scanning'),
          actions: [
            // ✅ Dynamic Torch Button (Only visible when scanning)
            if (_isScanning)
              ValueListenableBuilder(
                valueListenable: _cameraController,
                builder: (context, state, child) {
                  final bool isTorchOn = state.torchState == TorchState.on;
                  return IconButton(
                    icon: Icon(
                      isTorchOn ? Icons.flash_on : Icons.flash_off,
                      color: isTorchOn ? Colors.yellowAccent : Colors.grey,
                    ),
                    onPressed: () => _cameraController.toggleTorch(),
                  );
                },
              ),

            // ✅ Toggle Button (List <-> Scanner)
            IconButton(
              icon: Icon(_isScanning ? Icons.list : Icons.qr_code_scanner),
              onPressed: _toggleScanMode,
              tooltip: _isScanning ? 'Voir la liste' : 'Ouvrir le Scanner',
            ),
          ],
        ),
        body: Column(
          children: [
            // ✅ Status Header is always visible to guide the user
            _buildStatusHeader(),

            // ✅ Switch between Camera and List
            Expanded(
              child: _isScanning ? _buildScannerView() : _buildProductList(),
            ),
          ],
        ),
        // Only show confirm button when in List mode
        floatingActionButton: !_isScanning
            ? FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).pop(_scannedProducts),
          icon: const Icon(Icons.check),
          label: const Text('Confirmer'),
        )
            : null,
      ),
    );
  }

  // ✅ The Embedded Scanner View
  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _cameraController,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final String? code = barcodes.first.rawValue;
              if (code != null) {
                _onCodeScanned(code);
              }
            }
          },
        ),
        // Target Box Overlay
        Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.redAccent.withOpacity(0.8), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // Instruction Overlay at bottom
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "Visez le code-barres",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
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
                ? 'Etape 1: Scannez la Référence Produit'
                : 'Etape 2: Scannez les N° de Série',
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
            Text(
              'Qté scannée: ${_currentProduct!.quantity}',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
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
                label: const Text('Terminer ce produit / Changer', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  backgroundColor: Colors.white.withOpacity(0.1),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Aucun produit scanné.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggleScanMode,
              icon: const Icon(Icons.play_arrow),
              label: const Text("Commencer le Scan"),
            ),
          ],
        ),
      );
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
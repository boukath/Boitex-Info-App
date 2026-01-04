// lib/screens/administration/report_breakage_page.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

// ✅ SERVICES
import 'package:boitex_info_app/services/stock_service.dart';
import 'package:boitex_info_app/screens/administration/product_scanner_page.dart';
// ✅ NEW IMPORT
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';

class ReportBreakagePage extends StatefulWidget {
  final Map<String, dynamic>? initialProductData;
  final String? initialProductId;

  const ReportBreakagePage({
    super.key,
    this.initialProductData,
    this.initialProductId
  });

  @override
  State<ReportBreakagePage> createState() => _ReportBreakagePageState();
}

class _ReportBreakagePageState extends State<ReportBreakagePage> {
  // Logic State
  Map<String, dynamic>? _productData;
  String? _productId;
  bool _isLoading = false;

  // Form State
  int _quantityBroken = 1;
  final TextEditingController _reasonController = TextEditingController();
  File? _imageFile;

  // ✅ B2 CONFIG (Copied from your add_sav_ticket_page.dart)
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl';

  @override
  void initState() {
    super.initState();
    if (widget.initialProductData != null) {
      _productData = widget.initialProductData;
      _productId = widget.initialProductId;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 📸 1. TAKE PHOTO
  // ===========================================================================
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera, // Use Camera for evidence
      imageQuality: 50, // Optimize size
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // ===========================================================================
  // ☁️ 2. B2 UPLOAD LOGIC
  // ===========================================================================

  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response =
      await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('Failed to get B2 credentials: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error calling Cloud Function: $e');
      return null;
    }
  }

  Future<String?> _uploadFileToB2(File file, Map<String, dynamic> b2Creds) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final fileName = path.basename(file.path);

      // Determine Mime Type
      String mimeType = 'application/octet-stream';
      if (fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (fileName.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      }

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': mimeType,
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final encodedPath = (body['fileName'] as String)
            .split('/')
            .map(Uri.encodeComponent)
            .join('/');
        return (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
      } else {
        debugPrint('Failed to upload to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file to B2: $e');
      return null;
    }
  }

  // ===========================================================================
  // 🔍 3. PRODUCT SELECTION (SCAN OR SEARCH)
  // ===========================================================================

  // Option A: Scan Barcode
  Future<void> _scanProduct() async {
    final scannedRef = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProductScannerPage())
    );

    if (scannedRef != null && scannedRef is String) {
      _fetchProductByReference(scannedRef);
    }
  }

  // Option B: Manual Search (Global Search)
  Future<void> _searchProductManually() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GlobalProductSearchPage(
          isSelectionMode: true,
          onProductSelected: (productMap) {
            setState(() {
              _productData = productMap;
              // ✅ FIX 1: Capture the ID reliably
              if (productMap.containsKey('productId')) {
                _productId = productMap['productId'];
              } else if (productMap.containsKey('id')) {
                _productId = productMap['id'];
              }

              // Optional: Re-fetch only if necessary, but don't block
              if (productMap['reference'] != null || productMap['partNumber'] != null) {
                String ref = productMap['reference'] ?? productMap['partNumber'];
                _fetchProductByReference(ref);
              }
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // Helper to fetch full data
  Future<void> _fetchProductByReference(String reference) async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('reference', isEqualTo: reference)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _productData = snapshot.docs.first.data();
          _productId = snapshot.docs.first.id;
        });
      }
      // Removed the Snackbar "Product Introuvable" because it was confusing when offline
    } catch (e) {
      print("Offline or Error fetching product details: $e");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // 🚀 4. SUBMIT REPORT
  // ===========================================================================
  Future<void> _submitReport() async {
    if (_productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur: Aucun produit sélectionné (ID manquant)"), backgroundColor: Colors.red));
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez décrire la cause de la casse.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // A. Upload Image (If exists)
      String? photoUrl;
      if (_imageFile != null) {
        final b2Creds = await _getB2UploadCredentials();
        if (b2Creds != null) {
          photoUrl = await _uploadFileToB2(_imageFile!, b2Creds);
        }
      }

      // ✅ FIX 2: Handle Key Mismatch (Search vs Scan)
      // Search page uses 'productName'/'partNumber', Scan uses 'nom'/'reference'
      String safeName = _productData?['nom'] ?? _productData?['productName'] ?? 'Inconnu';
      String safeRef = _productData?['reference'] ?? _productData?['partNumber'] ?? 'N/A';

      // B. Update Database
      await StockService().reportInternalBreakage(
        productId: _productId!,
        productName: safeName,
        productReference: safeRef,
        quantityBroken: _quantityBroken,
        reason: _reasonController.text.trim(),
        photoUrl: photoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Casse déclarée avec succès"), backgroundColor: Colors.green)
        );
        Navigator.pop(context); // Close page
      }

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // 📱 BUILD UI
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Déclarer Casse / Dommage"),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- STEP 1: PRODUCT SELECTION ---
            _buildSectionTitle("1. Produit Concerné"),
            if (_productData == null)
              Row(
                children: [
                  // BUTTON 1: SCANNER
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _scanProduct,
                      icon: const Icon(Icons.qr_code_scanner, size: 28),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text("Scanner", style: TextStyle(fontSize: 16)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // BUTTON 2: MANUAL SEARCH
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _searchProductManually,
                      icon: const Icon(Icons.search, size: 28),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text("Rechercher", style: TextStyle(fontSize: 16)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              )
            else
              _buildProductCard(),

            const SizedBox(height: 24),

            // --- STEP 2: QUANTITY ---
            _buildSectionTitle("2. Quantité HS"),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    if (_quantityBroken > 1) setState(() => _quantityBroken--);
                  },
                ),
                Text(
                    "$_quantityBroken",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _quantityBroken++),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- STEP 3: EVIDENCE ---
            _buildSectionTitle("3. Preuve (Photo)"),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_imageFile!, fit: BoxFit.cover),
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_rounded, size: 50, color: Colors.grey.shade600),
                    const SizedBox(height: 8),
                    Text("Appuyer pour prendre une photo", style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- STEP 4: DETAILS ---
            _buildSectionTitle("4. Détails / Cause"),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Ex: Tombé du rayon, écrasé à la réception...",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 32),

            // --- SUBMIT ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _productData != null ? _submitReport : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                child: const Text("VALIDER LA CASSE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildProductCard() {
    // ✅ FIX 3: Also fix the display card so the user sees the name before submitting
    String displayName = _productData?['nom'] ?? _productData?['productName'] ?? 'Inconnu';
    String displayRef = _productData?['reference'] ?? _productData?['partNumber'] ?? 'N/A';
    // If quantity is missing (e.g. from GlobalSearch), show '?'
    String displayStock = _productData?['quantiteEnStock']?.toString() ?? '?';

    return Card(
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.inventory_2, color: Colors.indigo),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Réf: $displayRef\nStock Sain: $displayStock"),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() { _productData = null; _productId = null; }),
        ),
      ),
    );
  }
}
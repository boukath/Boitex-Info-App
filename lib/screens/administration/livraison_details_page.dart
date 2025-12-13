// lib/screens/administration/livraison_details_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ Added for kIsWeb
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:boitex_info_app/screens/widgets/scanner_page.dart';
import 'package:boitex_info_app/services/zebra_service.dart';
import 'package:signature/signature.dart';
import 'dart:typed_data';

// ✅ Custom viewers and file handling
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

// ✅ B2 Upload & File Saving
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart'; // ✅ ADDED for Web Download
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// ✅ Auth & Maps
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// ✅ PDF Service & Models
import 'package:boitex_info_app/services/livraison_pdf_service.dart';
import 'package:boitex_info_app/models/selection_models.dart';

class LivraisonDetailsPage extends StatefulWidget {
  final String livraisonId;
  const LivraisonDetailsPage({super.key, required this.livraisonId});

  @override
  State<LivraisonDetailsPage> createState() => _LivraisonDetailsPageState();
}

class _LivraisonDetailsPageState extends State<LivraisonDetailsPage> {
  final _proofFormKey = GlobalKey<FormState>();

  DocumentSnapshot? _livraisonDoc;

  // -- Delivery Mode Lists --
  List<Map<String, dynamic>> _serializedItems = [];
  List<Map<String, dynamic>> _bulkItems = [];

  // -- Picking Mode List --
  List<Map<String, dynamic>> _pickingItems = [];

  // ✅ Controllers for "Keyboard Wedge" Scanning
  final Map<int, TextEditingController> _pickingControllers = {};
  final Map<int, FocusNode> _pickingFocusNodes = {};

  // ✅ State for "Select & Shoot"
  int? _selectedPickingIndex;
  StreamSubscription? _zebraSubscription;

  String _status = '';
  bool _isLoading = true;
  bool _isCompleting = false;
  bool _isLivraisonCompleted = false;

  // ✅ ADDED: Status text for the loading indicator
  String _loadingStatus = '';

  List<dynamic> _existingMedia = [];
  List<PlatformFile> _pickedMediaFiles = [];
  bool _isUploadingMedia = false;
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';

  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _recipientEmailController = TextEditingController();

  double? _storeLat;
  double? _storeLng;
  bool _isLoadingGps = false;

  // ✅ PDF Generation State
  bool _isGeneratingPdf = false;

  bool get _isPickingMode => _status == 'À Préparer';

  bool get _allCompleted {
    if (_isLivraisonCompleted) return true;
    if (_serializedItems.isEmpty && _bulkItems.isEmpty) return false;

    final serializedDone = true;
    final bulkDone = _bulkItems.isEmpty ||
        _bulkItems.every((item) => item['delivered'] == true);
    return serializedDone && bulkDone;
  }

  // ✅ Updated Validation Logic to handle both Bulk and Serialized items
  bool get _allPicked {
    if (_pickingItems.isEmpty) return false;
    return _pickingItems.every((item) {
      final int qty = item['quantity'] as int? ?? 0;
      final bool isBulk = item['isBulk'] == true;
      if (isBulk) {
        // For bulk, check pickedQuantity
        final int picked = item['pickedQuantity'] as int? ?? 0;
        return picked >= qty;
      } else {
        // For serialized, check list length
        final List serials = item['serialNumbers'] as List? ?? [];
        return serials.length >= qty;
      }
    });
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

    // ✅ Initialize Zebra Listener
    _zebraSubscription = ZebraService().onScan.listen((code) {
      if (_isPickingMode && _selectedPickingIndex != null) {
        _processInputScan(_selectedPickingIndex!, code);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Sélectionnez un produit pour scanner"),
              duration: Duration(milliseconds: 1000)),
        );
      }
    });
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _recipientEmailController.dispose();
    for (var controller in _pickingControllers.values) {
      controller.dispose();
    }
    for (var node in _pickingFocusNodes.values) {
      node.dispose();
    }
    _zebraSubscription?.cancel();
    super.dispose();
  }

  // ... (Keep existing Fetch/Map/Upload helpers) ...
  Future<void> _fetchStoreCoordinates(String clientId, String storeId) async {
    setState(() => _isLoadingGps = true);
    try {
      final storeDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .doc(storeId)
          .get();

      if (storeDoc.exists) {
        final storeData = storeDoc.data();
        if (storeData != null &&
            storeData['latitude'] != null &&
            storeData['longitude'] != null) {
          setState(() {
            _storeLat = (storeData['latitude'] as num).toDouble();
            _storeLng = (storeData['longitude'] as num).toDouble();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching store GPS: $e");
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  Future<void> _launchMaps() async {
    if (_storeLat == null || _storeLng == null) return;
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$_storeLat,$_storeLng");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir la carte.")),
        );
      }
    }
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
        _status = data['status'] ?? 'À Préparer';

        if (data['clientId'] != null && data['storeId'] != null) {
          _fetchStoreCoordinates(data['clientId'], data['storeId']);
        }

        final rawProducts = data['products'] as List? ?? [];
        final deliveryMedia = data['deliveryMedia'] as List? ?? [];
        final bool isCompleted = _status == 'Livré';

        _recipientNameController.text = data['recipientName'] ?? '';
        _recipientPhoneController.text = data['recipientPhone'] ?? '';
        _recipientEmailController.text = data['recipientEmail'] ?? '';

        List<Map<String, dynamic>> pickingList = [];
        List<Map<String, dynamic>> serializedList = [];
        Map<String, Map<String, dynamic>> bulkMap = {};

        if (_status == 'À Préparer') {
          // ** PICKING MODE **
          pickingList = List<Map<String, dynamic>>.from(
              rawProducts.map((p) => Map<String, dynamic>.from(p)));

          // Auto-select first item
          if (pickingList.isNotEmpty) {
            _selectedPickingIndex = 0;
          }
        } else {
          // ** DELIVERY MODE **
          for (final product in rawProducts) {
            int quantity = 0;
            if (product['quantity'] is int) {
              quantity = product['quantity'];
            } else if (product['quantity'] is String) {
              quantity = int.tryParse(product['quantity']) ?? 0;
            }

            final String productName = product['productName'] ?? 'N/A';
            final String? partNumber = product['partNumber'] as String?;
            final String? productId = product['productId'] as String?;

            final List serials = product['serialNumbers'] as List? ?? [];
            final List serialsFound =
                product['serialNumbersFound'] as List? ?? [];
            final bool wasDelivered = isCompleted;

            bool isBulkItem = (quantity > 50) ||
                (quantity > 5 && serials.isEmpty && serialsFound.isEmpty);

            // Also treat as bulk if marked as such during picking
            if (product['isBulk'] == true) isBulkItem = true;

            if (isBulkItem) {
              String key = productId ?? productName;
              if (bulkMap.containsKey(key)) {
                bulkMap[key]!['quantity'] =
                    (bulkMap[key]!['quantity'] as int) + quantity;
              } else {
                bulkMap[key] = {
                  'productName': productName,
                  'partNumber': partNumber,
                  'quantity': quantity,
                  'delivered': wasDelivered,
                  'type': 'bulk',
                  'productId': productId,
                };
              }
            } else {
              int itemsToAdd = serials.isNotEmpty ? serials.length : quantity;
              for (int i = 0; i < itemsToAdd; i++) {
                serializedList.add({
                  'productName': productName,
                  'partNumber': partNumber,
                  'serialNumber':
                  (i < serialsFound.length) ? serialsFound[i] : null,
                  'originalSerialNumber':
                  (i < serials.length) ? serials[i] : null,
                  'scanned': wasDelivered,
                  'type': 'serialized',
                  'productId': productId,
                });
              }
            }
          }
        }

        setState(() {
          _livraisonDoc = doc;
          _isLivraisonCompleted = isCompleted;
          _pickingItems = pickingList;
          _serializedItems = serializedList;
          _bulkItems = bulkMap.values.toList();
          _existingMedia = deliveryMedia;
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
      debugPrint("Error loading livraison details: $e");
    }
  }

  // ===============================================================
  // ✅ NEW: CLIENT-SIDE ON-DEMAND PDF GENERATION (Web Download Fix)
  // ===============================================================

  Future<void> _generateAndOpenPdf() async {
    if (_livraisonDoc == null) return;
    setState(() => _isGeneratingPdf = true);

    try {
      // 1. Fetch Current Data
      final data = _livraisonDoc!.data() as Map<String, dynamic>;
      final clientId = data['clientId'];
      final bonCode = data['bonLivraisonCode'] ?? 'BL';

      // 2. Fetch Client Info
      final clientDoc = await FirebaseFirestore.instance.collection('clients').doc(clientId).get();
      final clientData = clientDoc.data() ?? {};

      // 3. Prepare Products List
      List<ProductSelection> pdfProducts = [];

      if (_status == 'À Préparer') {
        pdfProducts = _pickingItems.map((item) => ProductSelection.fromJson(item)).toList();
      } else {
        final Map<String, Map<String, dynamic>> groupedMap = {};

        // Serialized
        for (var item in _serializedItems) {
          final key = item['partNumber'] ?? item['productName'];
          if (!groupedMap.containsKey(key)) {
            groupedMap[key] = {
              'productId': item['productId'],
              'productName': item['productName'],
              'partNumber': item['partNumber'],
              'marque': item['marque'] ?? 'N/A',
              'quantity': 0,
              'serialNumbers': <String>[]
            };
          }
          groupedMap[key]!['quantity'] = (groupedMap[key]!['quantity'] as int) + 1;

          final sn = item['serialNumber'] ?? item['originalSerialNumber'];
          if (sn != null) {
            (groupedMap[key]!['serialNumbers'] as List<String>).add(sn);
          }
        }

        // Bulk
        for (var item in _bulkItems) {
          final key = item['partNumber'] ?? item['productName'];
          if (!groupedMap.containsKey(key)) {
            groupedMap[key] = {
              'productId': item['productId'],
              'productName': item['productName'],
              'partNumber': item['partNumber'],
              'marque': item['marque'] ?? 'N/A',
              'quantity': 0,
              'serialNumbers': <String>[]
            };
          }
          groupedMap[key]!['quantity'] = (groupedMap[key]!['quantity'] as int) + (item['quantity'] as int);
        }
        pdfProducts = groupedMap.values.map((map) => ProductSelection.fromJson(map)).toList();
      }

      // 4. Handle Signature
      Uint8List? signatureBytes;
      if (data['signatureUrl'] != null) {
        try {
          final resp = await http.get(Uri.parse(data['signatureUrl']));
          if (resp.statusCode == 200) {
            signatureBytes = resp.bodyBytes;
          }
        } catch (e) {
          debugPrint("Could not download signature: $e");
        }
      }

      // 5. Generate PDF in Memory
      final pdfBytes = await LivraisonPdfService().generateLivraisonPdf(
        livraisonData: data,
        products: pdfProducts,
        clientData: clientData,
        docId: widget.livraisonId, // ✅ ID passed correctly
        signatureBytes: signatureBytes,
      );

      // 6. Handle Output (Web vs Mobile)
      if (mounted) {
        if (kIsWeb) {
          // ✅ Web: Auto Download
          // Clean filename (remove slashes from BL code)
          final safeFileName = bonCode.replaceAll('/', '-');

          await FileSaver.instance.saveFile(
            name: safeFileName,
            bytes: pdfBytes,
            ext: 'pdf',
            mimeType: MimeType.pdf,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Téléchargement du PDF lancé...'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // ✅ Mobile: Open Viewer
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfViewerPage(
                pdfBytes: pdfBytes,
                title: "$bonCode.pdf",
              ),
            ),
          );
        }
      }

    } catch (e) {
      debugPrint("Error generating PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur génération PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // ... (Rest of existing methods) ...

  void _toggleBulkMode(int index) {
    setState(() {
      final isBulk = _pickingItems[index]['isBulk'] == true;
      _pickingItems[index]['isBulk'] = !isBulk;

      // Initialize pickedQuantity if switching to bulk
      if (!isBulk && _pickingItems[index]['pickedQuantity'] == null) {
        final List serials = _pickingItems[index]['serialNumbers'] ?? [];
        _pickingItems[index]['pickedQuantity'] = serials.length;
      }
    });
    _savePickingState();
  }

  void _manualIncrementBulk(int index, int delta) {
    final item = _pickingItems[index];
    final int quantity = item['quantity'] ?? 0;
    int picked = item['pickedQuantity'] as int? ?? 0;

    int newPicked = picked + delta;
    if (newPicked < 0) newPicked = 0;
    if (newPicked > quantity) newPicked = quantity;

    setState(() {
      _pickingItems[index]['pickedQuantity'] = newPicked;
    });
    _savePickingState();
  }

  // ✅ NEW: Direct Input Dialog for Large Quantities (e.g. 30,000 cables)
  void _showBulkQuantityDialog(int index) {
    final item = _pickingItems[index];
    final int current = item['pickedQuantity'] as int? ?? 0;
    final int max = item['quantity'] as int? ?? 0;
    final TextEditingController qtyCtrl =
    TextEditingController(text: current.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Définir la Quantité"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Total requis: $max"),
            const SizedBox(height: 10),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Quantité prélevée",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              int? val = int.tryParse(qtyCtrl.text);
              if (val != null) {
                if (val > max) {
                  val = max;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Ajusté au maximum requis.")));
                }
                if (val < 0) val = 0;

                setState(() {
                  _pickingItems[index]['pickedQuantity'] = val;
                });
                _savePickingState();
              }
              Navigator.pop(context);
            },
            child: const Text("Valider"),
          )
        ],
      ),
    );
  }

  void _processInputScan(int index, String code) {
    if (code.trim().isEmpty) return;

    final item = _pickingItems[index];
    final String? partNumber = item['partNumber'];
    final int quantity = item['quantity'] ?? 0;
    final bool isBulk = item['isBulk'] == true;

    // --- BULK MODE LOGIC ---
    if (isBulk) {
      int picked = item['pickedQuantity'] as int? ?? 0;
      if (picked >= quantity) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Quantité atteinte.')));
        _pickingControllers[index]?.clear();
        return;
      }

      // Check Reference
      if (partNumber != null &&
          code.trim().toUpperCase() != partNumber.trim().toUpperCase()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Mauvaise Référence! Attendu: $partNumber'),
              backgroundColor: Colors.red),
        );
        _pickingControllers[index]?.clear();
        _pickingFocusNodes[index]?.requestFocus();
        return;
      }

      // Increment
      setState(() {
        _pickingItems[index]['pickedQuantity'] = picked + 1;
      });
      _pickingControllers[index]?.clear();
      _pickingFocusNodes[index]?.requestFocus(); // Keep focus for rapid fire
      _savePickingState();
      return;
    }

    // --- SERIAL MODE LOGIC ---
    List<String> currentSerials =
    List<String>.from(item['serialNumbers'] ?? []);

    if (currentSerials.length >= quantity) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Quantité atteinte.')));
      _pickingControllers[index]?.clear();
      return;
    }

    // 1. Verification (Part Number check)
    if (partNumber != null &&
        code.trim().toUpperCase() == partNumber.trim().toUpperCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Référence OK. Scannez le N° de Série.'),
            backgroundColor: Colors.green),
      );
      _pickingControllers[index]?.clear();
      _pickingFocusNodes[index]?.requestFocus();
      return;
    }

    // 2. Serial Number Input
    final sn = code.trim();
    if (currentSerials.contains(sn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Déjà scanné!'), backgroundColor: Colors.orange),
      );
      _pickingControllers[index]?.clear();
      _pickingFocusNodes[index]?.requestFocus();
      return;
    }

    // 3. Add & Save
    setState(() {
      currentSerials.add(sn);
      _pickingItems[index]['serialNumbers'] = currentSerials;
    });

    _savePickingState();
    _pickingControllers[index]?.clear();

    if (currentSerials.length < quantity) {
      _pickingFocusNodes[index]?.requestFocus();
    } else {
      _pickingFocusNodes[index]?.unfocus();
    }
  }

  // Camera Fallback
  Future<void> _handlePickingScan(int index) async {
    setState(() => _selectedPickingIndex = index);

    // Check limits before opening camera
    final item = _pickingItems[index];
    final bool isBulk = item['isBulk'] == true;
    final int quantity = item['quantity'] ?? 0;

    if (isBulk) {
      int picked = item['pickedQuantity'] as int? ?? 0;
      if (picked >= quantity) return;
    } else {
      List serials = item['serialNumbers'] ?? [];
      if (serials.length >= quantity) return;
    }

    String? scannedSN;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerPage(
          onScan: (code) => scannedSN = code,
        ),
      ),
    );

    if (scannedSN != null) {
      _processInputScan(index, scannedSN!);
    }
  }

  Future<void> _savePickingState() async {
    try {
      await FirebaseFirestore.instance
          .collection('livraisons')
          .doc(widget.livraisonId)
          .update({'products': _pickingItems});
    } catch (e) {
      debugPrint("Error saving picking state: $e");
    }
  }

  Future<void> _validatePreparation() async {
    if (!_allPicked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez scanner tous les articles.')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isCompleting = true);

    try {
      final bonLivraisonCode = _livraisonDoc?.get('bonLivraisonCode') ?? 'N/A';

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final livraisonRef = FirebaseFirestore.instance
            .collection('livraisons')
            .doc(widget.livraisonId);

        // ============================================================
        // 1️⃣ PHASE 1: PRE-READ ALL DATA (Reads ONLY)
        // ============================================================
        // We store the snapshots in a list to use them later in Phase 2
        List<Map<String, dynamic>> transactionOperations = [];

        for (final item in _pickingItems) {
          final productId = item['productId'] as String?;
          final quantity = item['quantity'] as int? ?? 0;
          final productName = item['productName'] ?? 'Produit Inconnu';

          if (productId != null && quantity > 0) {
            final productDocRef = FirebaseFirestore.instance
                .collection('produits')
                .doc(productId);

            // READ OPERATION
            final productSnapshot = await transaction.get(productDocRef);

            if (!productSnapshot.exists) {
              throw Exception(
                  'Produit "$productName" introuvable dans la base.');
            }

            // Store the data we need for the write phase
            transactionOperations.add({
              'type': 'product_update',
              'productRef': productDocRef,
              'snapshot': productSnapshot,
              'item': item,
            });
          }
        }

        // ============================================================
        // 2️⃣ PHASE 2: EXECUTE WRITES (Writes ONLY)
        // ============================================================
        for (final operation in transactionOperations) {
          final DocumentReference productRef = operation['productRef'];
          final DocumentSnapshot snapshot = operation['snapshot'];
          final Map<String, dynamic> item = operation['item'];

          final int quantity = item['quantity'] as int? ?? 0;
          final String productName = item['productName'] ?? 'Produit Inconnu';
          final String partNumber = item['partNumber'] ?? 'N/A';

          final int currentStock =
              (snapshot.data() as Map<String, dynamic>)['quantiteEnStock'] ?? 0;
          final int newQuantity = currentStock - quantity;

          // 1. Update Product Stock
          transaction.update(productRef,
              {'quantiteEnStock': FieldValue.increment(-quantity)});

          // 2. Create Ledger Entry (Stock Movement)
          final ledgerDocRef =
          FirebaseFirestore.instance.collection('stock_movements').doc();
          transaction.set(ledgerDocRef, {
            'productId': item['productId'],
            'productRef': partNumber,
            'productName': productName,
            'quantityChange': -quantity,
            'oldQuantity': currentStock,
            'newQuantity': newQuantity,
            'type': 'PREPARATION',
            'notes': 'Sortie pour Livraison (Preparation) - $bonLivraisonCode',
            'userId': currentUser.uid,
            'userDisplayName': currentUser.displayName ?? currentUser.email,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        // 3. Final Update to Livraison
        transaction.update(livraisonRef, {
          'status': 'En Cours de Livraison',
          'preparedAt': FieldValue.serverTimestamp(),
          'preparedBy': currentUser.email,
          'products': _pickingItems,
        });
      });

      // ✅ NOTE: Removed _regeneratePdfAfterPicking() here because the PDF is now generated on-demand

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Préparation validée !'),
              backgroundColor: Colors.green),
        );
        _loadLivraisonDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur Transaction: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  // ===============================================================
  // END PICKING LOGIC
  // ===============================================================

  void _scanSerializedItem(Map<String, dynamic> item) async {
    if (_isLivraisonCompleted) return;
    String? scannedCode;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ScannerPage(
                onScan: (code) => scannedCode = code)));
    final code = scannedCode?.trim();
    if (code == null || code.isEmpty) return;
    setState(() {
      item['serialNumber'] = code;
      item['scanned'] = true;
    });
  }

  void _markBulkItemDelivered(Map<String, dynamic> item) {
    if (_isLivraisonCompleted) return;
    setState(() => item['delivered'] = true);
  }

  void _verifySingleFromBulk(Map<String, dynamic> item) async {
    if (_isLivraisonCompleted) return;
    String? scannedCode;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ScannerPage(
                onScan: (code) => scannedCode = code)));
    if (scannedCode != null && scannedCode!.isNotEmpty) {
      setState(() => item['delivered'] = true);
    }
  }

  Future<String?> _uploadSignature() async {
    if (_isLivraisonCompleted || _signatureController.isEmpty) return null;
    final Uint8List? data = await _signatureController.toPngBytes();
    if (data == null) return null;
    try {
      final b2Credentials = await _getB2UploadCredentials();
      if (b2Credentials == null) {
        throw Exception('Impossible de récupérer les accès B2.');
      }
      final fileName =
          'livraison_signatures/${widget.livraisonId}/${DateTime.now().toIso8601String()}.png';
      final uploadedFileMap = await _uploadBytesToB2(
          data, fileName, 'image/png', b2Credentials);
      return uploadedFileMap?['url'];
    } catch (e) {
      return null;
    }
  }

  Future<void> _completeLivraison() async {
    if (_isLivraisonCompleted) return;
    // ✅ FIX: Ensure form is validated inside a Form widget context
    if (_proofFormKey.currentState != null &&
        !_proofFormKey.currentState!.validate()) return;
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez signer la livraison.')));
      return;
    }

    if (_livraisonDoc == null) return;

    // 1. Capture Signature Bytes BEFORE transaction
    final Uint8List? signatureBytes = await _signatureController.toPngBytes();
    if (signatureBytes == null) return;

    setState(() => _isCompleting = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      String? signatureUrl = await _uploadSignature();
      final livraisonData = _livraisonDoc!.data() as Map<String, dynamic>;
      final clientId = livraisonData['clientId'];
      final storeId = livraisonData['storeId'];

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final livraisonRef = FirebaseFirestore.instance
            .collection('livraisons')
            .doc(widget.livraisonId);

        final Map<String, Map<String, dynamic>> groupedProducts = {};

        // ✅ AUTO-VALIDATION: Process ALL Serialized Items
        for (final item in _serializedItems) {
          final key = item['partNumber'] ?? item['productName'];
          // Skip logic here: removed the "check if scanned" condition.
          // We assume if it's on the list, it's being delivered.

          if (!groupedProducts.containsKey(key)) {
            groupedProducts[key] = {
              'productName': item['productName'],
              'partNumber': item['partNumber'],
              'quantity': 0,
              'productId': item['productId'],
              'serialNumbers': [],
              'serialNumbersFound': [],
            };
          }
          groupedProducts[key]!['quantity'] =
              (groupedProducts[key]!['quantity'] as int) + 1;

          final sn = item['serialNumber'] ?? item['originalSerialNumber'];
          if (sn != null) {
            (groupedProducts[key]!['serialNumbersFound'] as List).add(sn);
            (groupedProducts[key]!['serialNumbers'] as List).add(sn);
          }
        }

        // ✅ AUTO-VALIDATION: Process ALL Bulk Items
        for (final item in _bulkItems) {
          // Removed the check: if (item['delivered'] != true) continue;
          // We now assume everything on the list is delivered.
          final key = item['partNumber'] ?? item['productName'];
          if (!groupedProducts.containsKey(key)) {
            groupedProducts[key] = {
              'productName': item['productName'],
              'partNumber': item['partNumber'],
              'quantity': item['quantity'],
              'productId': item['productId'],
              'serialNumbers': [],
              'serialNumbersFound': [],
            };
          } else {
            groupedProducts[key]!['quantity'] =
                (groupedProducts[key]!['quantity'] as int) +
                    (item['quantity'] as int);
          }
        }

        final List<Map<String, dynamic>> updatedProductsList =
        List<Map<String, dynamic>>.from(groupedProducts.values);

        transaction.update(livraisonRef, {
          'status': 'Livré',
          'completedAt': FieldValue.serverTimestamp(),
          'signatureUrl': signatureUrl,
          'products': updatedProductsList,
          'recipientName': _recipientNameController.text.trim(),
          'recipientPhone': _recipientPhoneController.text.trim(),
          'recipientEmail': _recipientEmailController.text.trim(),
        });

        // Update Installed Material
        final materielCollectionRef = FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .collection('stores')
            .doc(storeId)
            .collection('materiel_installe');

        for (final productGroup in updatedProductsList) {
          final serialsFound =
              productGroup['serialNumbersFound'] as List? ?? [];
          for (final sn in serialsFound) {
            final newMaterielDoc = materielCollectionRef.doc(sn);
            transaction.set(newMaterielDoc, {
              'productName': productGroup['productName'],
              'partNumber': productGroup['partNumber'],
              'serialNumber': sn,
              'installationDate': FieldValue.serverTimestamp(),
              'livraisonId': widget.livraisonId,
            });
          }
        }
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Livraison terminée !'), backgroundColor: Colors.green)
        );
      }

    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la livraison: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  // Helpers
  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response =
      await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, String>?> _uploadBytesToB2(
      Uint8List fileBytes,
      String fileName,
      String? mimeType,
      Map<String, dynamic> b2Creds) async {
    try {
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'],
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': mimeType ?? 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString()
        },
        body: fileBytes,
      );
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final encodedPath = (body['fileName'] as String)
            .split('/')
            .map(Uri.encodeComponent)
            .join('/');
        final downloadUrl =
            (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
        return {'url': downloadUrl, 'fileName': fileName};
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, String>?> _uploadFileToB2(
      PlatformFile file, Map<String, dynamic> b2Creds) async {
    final fileBytes = file.bytes;
    if (fileBytes == null) return null;
    return await _uploadBytesToB2(fileBytes, file.name, null, b2Creds);
  }

  Future<void> _pickMediaFiles() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.media, allowMultiple: true, withData: true);
    if (result != null) setState(() => _pickedMediaFiles.addAll(result.files));
  }

  Future<void> _uploadAndSaveMedia() async {
    setState(() => _isUploadingMedia = true);
    try {
      final b2Credentials = await _getB2UploadCredentials();
      if (b2Credentials == null) return;
      List<Map<String, dynamic>> mediaList = List<Map<String, dynamic>>.from(
          _existingMedia.map((e) => e as Map<String, dynamic>));
      for (final file in _pickedMediaFiles) {
        final uploadedFileMap = await _uploadFileToB2(file, b2Credentials);
        if (uploadedFileMap != null) mediaList.add(uploadedFileMap);
      }
      await FirebaseFirestore.instance
          .collection('livraisons')
          .doc(widget.livraisonId)
          .update({'deliveryMedia': mediaList});
      setState(() {
        _existingMedia = mediaList;
        _pickedMediaFiles.clear();
      });
    } finally {
      setState(() => _isUploadingMedia = false);
    }
  }

  // ✅ MODIFIED: Check if Web to download/launch URL instead of using native viewer
  Future<void> _openFile(String? urlString, String? fileName) async {
    if (urlString == null) return;
    final extension = path.extension(fileName ?? '').toLowerCase();

    // 1. Web Check for PDF
    if (kIsWeb && extension == '.pdf') {
      await launchUrl(Uri.parse(urlString));
      return;
    }

    if (['.jpg', '.jpeg', '.png'].contains(extension)) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  ImageGalleryPage(imageUrls: [urlString], initialIndex: 0)));
    } else if (extension == '.pdf') {
      // 2. Mobile Logic (Fetch & View)
      final response = await http.get(Uri.parse(urlString));
      if (response.statusCode == 200) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => PdfViewerPage(
                    pdfBytes: response.bodyBytes, title: fileName ?? 'PDF')));
      }
    }
  }

  IconData _getFileIcon(String? fileName) => Icons.description;

  Widget _buildEditableSerializedItem(Map<String, dynamic> item, int index) {
    bool isScanned = item['scanned'] ?? false;
    final Key itemKey = ValueKey('item_${widget.livraisonId}_$index');
    final TextEditingController snController =
    TextEditingController(text: item['serialNumber'] ?? '');

    void updateItem(String value) {
      item['serialNumber'] = value;
      if (value.isNotEmpty) {
        item['scanned'] = true;
      } else {
        item['scanned'] = false;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Card(
        key: itemKey,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: isScanned ? Colors.green.shade50 : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item['productName'] ?? 'Produit Inconnu',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                        isScanned ? Colors.green.shade900 : Colors.black87,
                      ),
                    ),
                  ),
                  if (isScanned)
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 24)
                  else if (!_isLivraisonCompleted)
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      color: Colors.blue,
                      tooltip: 'Scanner',
                      onPressed: () => _scanSerializedItem(item),
                    ),
                ],
              ),
              Text('Réf: ${item['partNumber'] ?? 'N/A'}',
                  style: TextStyle(color: Colors.grey.shade700)),
              if (item['originalSerialNumber'] != null)
                Text('N/S Attendu: ${item['originalSerialNumber']}',
                    style: TextStyle(color: Colors.orange.shade700)),
              const SizedBox(height: 10),
              TextFormField(
                controller: snController,
                enabled: !_isLivraisonCompleted,
                decoration: const InputDecoration(
                  labelText: 'Numéro de Série Scanné/Saisi',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                  EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                ),
                onChanged: updateItem,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_livraisonDoc == null) {
      return const Scaffold(body: Center(child: Text("Erreur")));
    }

    final data = _livraisonDoc!.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: Text(data['bonLivraisonCode'] ?? 'Détails'),
        actions: [
          // ✅ ADDED: Always visible PDF button (generates on demand)
          if (_isGeneratingPdf)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Générer le Bon de Livraison',
              onPressed: _generateAndOpenPdf,
            ),

          if (_status == 'À Préparer')
            const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Chip(
                    label: Text('Préparation'),
                    backgroundColor: Colors.orange))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header Info
            Card(
              child: ListTile(
                title: Text(data['clientName'] ?? 'Client'),
                subtitle: Text(data['deliveryAddress'] ?? 'Adresse'),
                trailing: IconButton(
                    icon: const Icon(Icons.map), onPressed: _launchMaps),
              ),
            ),
            const SizedBox(height: 20),

            // ================== PICKING MODE ==================
            if (_isPickingMode) ...[
              Text('Liste de Préparation',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pickingItems.length,
                itemBuilder: (context, index) {
                  final item = _pickingItems[index];
                  final int qty = item['quantity'] ?? 0;
                  final bool isBulk = item['isBulk'] == true;

                  // Picking Progress
                  int pickedCount = 0;
                  if (isBulk) {
                    pickedCount = item['pickedQuantity'] as int? ?? 0;
                  } else {
                    pickedCount = (item['serialNumbers'] as List?)?.length ?? 0;
                  }

                  final bool isFull = pickedCount >= qty;
                  final bool isSelected = _selectedPickingIndex == index;

                  // Ensure Controller
                  if (!_pickingControllers.containsKey(index)) {
                    _pickingControllers[index] = TextEditingController();
                    _pickingFocusNodes[index] = FocusNode();
                  }

                  return GestureDetector(
                    onTap: () {
                      if (!isFull) setState(() => _selectedPickingIndex = index);
                    },
                    child: Card(
                      color: isFull
                          ? Colors.green.shade50
                          : (isSelected
                          ? Colors.blue.shade50
                          : Colors.white),
                      shape: isSelected
                          ? RoundedRectangleBorder(
                          side: const BorderSide(
                              color: Colors.blue, width: 2),
                          borderRadius: BorderRadius.circular(12))
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                    child: Text(
                                        item['productName'] ?? 'Produit',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold))),
                                // ✅ MODE TOGGLE
                                IconButton(
                                  icon: Icon(
                                      isBulk ? Icons.numbers : Icons.qr_code,
                                      color: Colors.blueGrey),
                                  tooltip: isBulk
                                      ? "Mode Quantité (Bulk)"
                                      : "Mode Série (Unique)",
                                  onPressed: () => _toggleBulkMode(index),
                                )
                              ],
                            ),
                            Text('Ref: ${item['partNumber'] ?? 'N/A'}'),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                                value: qty > 0 ? pickedCount / qty : 0,
                                backgroundColor: Colors.grey[200],
                                color: isFull ? Colors.green : Colors.blue),
                            const SizedBox(height: 8),

                            // Status Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                        '$pickedCount / $qty ${isBulk ? "unités" : "scannés"}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    // ✅ EDIT BUTTON FOR BULK
                                    if (isBulk)
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            size: 18, color: Colors.blue),
                                        onPressed: () =>
                                            _showBulkQuantityDialog(index),
                                        tooltip: "Saisir quantité",
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                                if (!isFull)
                                  TextButton.icon(
                                      icon: const Icon(Icons.camera_alt,
                                          size: 16),
                                      label: const Text('Cam'),
                                      onPressed: () =>
                                          _handlePickingScan(index))
                              ],
                            ),

                            // Input Area
                            if (!isFull && isSelected) ...[
                              const SizedBox(height: 8),
                              if (isBulk)
                              // BULK CONTROLS
                                Row(
                                  children: [
                                    IconButton(
                                        onPressed: () =>
                                            _manualIncrementBulk(index, -1),
                                        icon: const Icon(Icons.remove_circle,
                                            color: Colors.red)),
                                    Expanded(
                                      child: TextField(
                                        controller: _pickingControllers[index],
                                        focusNode: _pickingFocusNodes[index],
                                        decoration: const InputDecoration(
                                            labelText:
                                            'Scanner Référence (Optionnel)',
                                            border: OutlineInputBorder(),
                                            isDense: true),
                                        onSubmitted: (val) =>
                                            _processInputScan(index, val),
                                      ),
                                    ),
                                    IconButton(
                                        onPressed: () =>
                                            _manualIncrementBulk(index, 1),
                                        icon: const Icon(Icons.add_circle,
                                            color: Colors.green)),
                                  ],
                                )
                              else
                              // SERIAL CONTROLS
                                TextField(
                                  controller: _pickingControllers[index],
                                  focusNode: _pickingFocusNodes[index],
                                  decoration: const InputDecoration(
                                      labelText: 'Scanner N° Série',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.qr_code),
                                      isDense: true),
                                  onSubmitted: (val) =>
                                      _processInputScan(index, val),
                                ),
                            ],

                            // Serial List (Only for Serial Mode)
                            if (!isBulk &&
                                (item['serialNumbers'] as List? ?? [])
                                    .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                    spacing: 4,
                                    children: (item['serialNumbers'] as List)
                                        .map<Widget>((s) => Chip(
                                        label: Text(s),
                                        onDeleted: isFull
                                            ? null
                                            : () {
                                          setState(() {
                                            (item['serialNumbers']
                                            as List)
                                                .remove(s);
                                          });
                                          _savePickingState();
                                        }))
                                        .toList()),
                              )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                      onPressed: (_isCompleting || !_allPicked)
                          ? null
                          : _validatePreparation,
                      icon: const Icon(Icons.check),
                      label: const Text("Valider la Préparation"))),
            ]

            // ================== DELIVERY MODE ==================
            else ...[
              if (_serializedItems.isNotEmpty) ...[
                const Text("Produits Sérialisés",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _serializedItems.length,
                    itemBuilder: (context, index) {
                      final item = _serializedItems[index];
                      return _buildEditableSerializedItem(item, index);
                    })
              ],
              if (_bulkItems.isNotEmpty) ...[
                const Text("Produits Vrac",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _bulkItems.length,
                    itemBuilder: (context, index) {
                      final item = _bulkItems[index];
                      bool isDelivered = item['delivered'] == true;
                      return ListTile(
                        title: Text(item['productName']),
                        subtitle: Text('Qté: ${item['quantity']}'),
                        trailing: isDelivered
                            ? const Icon(Icons.check, color: Colors.green)
                            : ElevatedButton(
                            child: const Text("Livré"),
                            onPressed: () =>
                                setState(() => item['delivered'] = true)),
                      );
                    })
              ],
              const Divider(),
              // ✅ FIXED: Wrapped inputs in Form to prevent crash on validate()
              Form(
                key: _proofFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _recipientNameController,
                      decoration:
                      const InputDecoration(labelText: 'Réceptionnaire'),
                      validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Veuillez saisir le nom'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    if (!_isLivraisonCompleted)
                      Signature(
                          controller: _signatureController,
                          height: 150,
                          backgroundColor: Colors.grey[200]!),
                    const SizedBox(height: 20),
                    // ✅ MODIFIED: Show status text if completing delivery (generating PDF)
                    if (_isCompleting)
                      Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 8),
                          Text(_loadingStatus, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      )
                    else
                      SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                              onPressed: _completeLivraison,
                              child: const Text("Confirmer Livraison"))),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
// lib/screens/administration/livraison_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:boitex_info_app/screens/widgets/scanner_page.dart';
import 'package:signature/signature.dart';
import 'dart:typed_data';
// ❌ REMOVED: import 'package:firebase_storage/firebase_storage.dart';

// ✅ ADDED: Imports for custom viewers and file handling
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart'; // Import video player
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

// ✅ ADDED: Imports for B2 Upload
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:developer'; // for debugPrint
import 'package:video_thumbnail/video_thumbnail.dart'; // For video thumbs

// ✅ ADDED: Import for Firebase Auth to get current user
import 'package:firebase_auth/firebase_auth.dart';

// ❌ REMOVED: Import for unique ID generation
// import 'package:uuid/uuid.dart';

class LivraisonDetailsPage extends StatefulWidget {
  final String livraisonId;
  const LivraisonDetailsPage({super.key, required this.livraisonId});

  @override
  State<LivraisonDetailsPage> createState() => _LivraisonDetailsPageState();
}

class _LivraisonDetailsPageState extends State<LivraisonDetailsPage> {
  // GlobalKey for form validation
  final _proofFormKey = GlobalKey<FormState>(); // ✅ ADDED GlobalKey

  DocumentSnapshot? _livraisonDoc;
  List<Map<String, dynamic>> _serializedItems = [];
  List<Map<String, dynamic>> _bulkItems = [];
  bool _isLoading = true;
  bool _isCompleting = false;

  // ✅ NEW: Flag to track if the delivery is completed
  bool _isLivraisonCompleted = false;

  List<dynamic> _existingMedia = []; // From Firestore
  List<PlatformFile> _pickedMediaFiles = []; // Newly picked
  bool _isUploadingMedia = false;
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';

  // ✅ ADDED: Controllers for recipient details
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _recipientEmailController = TextEditingController();

  // ❌ REMOVED: Unique ID generator instance
  // final Uuid _uuid = const Uuid();

  // ❌ REMOVED: Function to generate a unique serial number
  /*
  String _generateSerialNumber() {
    // Generate a unique, recognizable serial number for items without one.
    // Format: 'GEN-YYYYMMDD-UUID_SHORT'
    final datePart = DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '');
    final shortUuid = _uuid.v4().substring(0, 8).toUpperCase();
    return 'GEN-$datePart-$shortUuid';
  }
  */

  bool get _allCompleted {
    // If already completed, don't re-evaluate
    if (_isLivraisonCompleted) return true;
    if (_serializedItems.isEmpty && _bulkItems.isEmpty) return false;
    final serializedDone = _serializedItems.isEmpty ||
        _serializedItems.every((item) => item['scanned'] == true);
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
    // ✅ ADDED: Dispose recipient controllers
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _recipientEmailController.dispose();
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
        final deliveryMedia = data['deliveryMedia'] as List? ?? [];

        // ✅ NEW: Check the status here
        final status = data['status'] as String?;
        final bool isCompleted = status == 'Livré';

        _recipientNameController.text = data['recipientName'] ?? '';
        _recipientPhoneController.text = data['recipientPhone'] ?? '';
        _recipientEmailController.text = data['recipientEmail'] ?? '';

        final List<Map<String, dynamic>> serialized = [];
        final List<Map<String, dynamic>> bulk = [];

        for (final product in products) {
          final int quantity = product['quantity'] ?? 0;
          final String productName = product['productName'] ?? 'N/A';
          final String? partNumber = product['partNumber'] as String?;
          final List serials = product['serialNumbers'] as List? ?? []; // Original serials expected
          final List serialsFound = product['serialNumbersFound'] as List? ?? []; // Serials actually scanned
          // ✅ If completed, assume items were delivered/scanned correctly
          final bool wasDelivered = isCompleted;

          // ✅ ADDED: Get the productId from the product map
          final String? productId = product['productId'] as String?;

          if (quantity > 0 && serials.isEmpty && serialsFound.isEmpty && quantity > 5) { // Treat as bulk only if no serials expected or found
            bulk.add({
              'productName': productName,
              'partNumber': partNumber,
              'quantity': quantity,
              'delivered': wasDelivered, // ✅ Use loaded status
              'type': 'bulk',
              'productId': productId, // ✅ ADDED
            });
          } else { // Treat as serialized if serials expected OR if serials were found (even if not expected)
            int itemsToAdd = quantity > 0 ? quantity : serialsFound.length; // Use quantity or found serials length
            if (itemsToAdd == 0 && serials.isNotEmpty) itemsToAdd = serials.length; // Fallback if quantity is 0 but serials expected

            for (int i = 0; i < itemsToAdd; i++) {
              serialized.add({
                'productName': productName,
                'partNumber': partNumber,
                // Show found serial if available, otherwise null
                'serialNumber': (i < serialsFound.length) ? serialsFound[i] : null,
                // Store original expected serial for display if needed
                'originalSerialNumber': (i < serials.length) ? serials[i] : null,
                'scanned': wasDelivered, // ✅ Use loaded status (true if 'Livré')
                'type': 'serialized',
                'productId': productId, // ✅ ADDED
              });
            }
          }
        }

        setState(() {
          _livraisonDoc = doc;
          // ✅ Set the completed flag
          _isLivraisonCompleted = isCompleted;
          _serializedItems = serialized;
          _bulkItems = bulk;
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
      debugPrint("Error loading livraison details: $e"); // Added for debugging
    }
  }

  // --- Scan/Mark Logic ---
  void _scanSerializedItem(Map<String, dynamic> item) async {
    // ✅ Prevent scanning if completed
    if (_isLivraisonCompleted) return;

    String? scannedCode;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              ScannerPage(onScan: (code) => scannedCode = code)),
    );
    final code = scannedCode?.trim();
    if (code == null || code.isEmpty) return;
    setState(() {
      // Update the serialNumber field which is displayed
      item['serialNumber'] = code;
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
    // ✅ Prevent marking if completed
    if (_isLivraisonCompleted) return;
    setState(() {
      item['delivered'] = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
        Text('✓ ${item['quantity']} x ${item['productName']} marqué comme livré'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _verifySingleFromBulk(Map<String, dynamic> item) async {
    // ✅ Prevent verifying if completed
    if (_isLivraisonCompleted) return;
    String? scannedCode;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              ScannerPage(onScan: (code) => scannedCode = code)),
    );
    final code = scannedCode?.trim();
    if (code == null || code.isEmpty) return;
    setState(() {
      item['delivered'] = true; // Mark as delivered upon verification
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Lot vérifié et marqué comme livré'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // --- Signature Upload Logic ---
  Future<String?> _uploadSignature() async {
    // Should not be called if completed, but check anyway
    if (_isLivraisonCompleted || _signatureController.isEmpty) return null;
    final Uint8List? data = await _signatureController.toPngBytes();
    if (data == null) return null;

    try {
      final b2Credentials = await _getB2UploadCredentials();
      if (b2Credentials == null) {
        throw Exception('Impossible de récupérer les accès B2 pour la signature.');
      }
      final fileName =
          'livraison_signatures/${widget.livraisonId}/${DateTime.now().toIso8601String()}.png';
      const mimeType = 'image/png';
      final uploadedFileMap =
      await _uploadBytesToB2(data, fileName, mimeType, b2Credentials);

      if (uploadedFileMap != null && uploadedFileMap['url'] != null) {
        return uploadedFileMap['url'];
      } else {
        throw Exception('Échec de l\'upload de la signature sur B2.');
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'upload de la signature sur B2: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur upload signature: $e'),
              backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  // --- ✅ CHANGED: Completion Logic (Switched to Transaction) ---
  Future<void> _completeLivraison() async {
    // ✅ Prevent completion if already completed
    if (_isLivraisonCompleted) return;

    if (!_proofFormKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez entrer le nom du réceptionnaire.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    // Check if signature is empty
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez obtenir la signature du client.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (_livraisonDoc == null) return;
    setState(() => _isCompleting = true);

    // Get current user for the audit log
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur: Utilisateur non connecté.')),
      );
      setState(() => _isCompleting = false);
      return;
    }

    String? signatureUrl;
    try {
      // --- 1. Upload Signature FIRST ---
      signatureUrl = await _uploadSignature();
      // Ensure signature uploaded successfully
      if (signatureUrl == null) {
        throw Exception('Échec de l\'upload de la signature.');
      }

      final livraisonData = _livraisonDoc!.data() as Map<String, dynamic>;
      final clientId = livraisonData['clientId'];
      final storeId = livraisonData['storeId'];
      final bonLivraisonCode = livraisonData['bonLivraisonCode'] ?? 'N/A';
      if (storeId == null || storeId.isEmpty) {
        throw Exception(
            'Impossible de sauvegarder l\'historique: Magasin non spécifié.');
      }

      // Get original products list to preserve original serial numbers
      final List originalProducts = livraisonData['products'] as List? ?? [];

      // --- 2. Run Firestore Transaction ---
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final livraisonRef = FirebaseFirestore.instance
            .collection('livraisons')
            .doc(widget.livraisonId);

        // --- 2a. Group all delivered products by their ID ---
        final Map<String, int> productQuantityChanges = {};
        final Map<String, Map<String, dynamic>> productDetails = {};

        // Group serialized items
        for (final item in _serializedItems) {
          final productId = item['productId'] as String?;
          // Check if item was scanned OR if it has a serial number (manually entered/generated)
          if ((item['scanned'] == true || item['serialNumber'] != null) && productId != null) {
            productQuantityChanges[productId] = (productQuantityChanges[productId] ?? 0) + 1;
            productDetails.putIfAbsent(productId, () => {
              'name': item['productName'],
              'ref': item['partNumber'], // 'partNumber' holds the reference
            });
          }
        }

        // Group bulk items
        for (final item in _bulkItems) {
          final productId = item['productId'] as String?;
          if (item['delivered'] == true && productId != null) {
            productQuantityChanges[productId] = (productQuantityChanges[productId] ?? 0) + (item['quantity'] as int);
            productDetails.putIfAbsent(productId, () => {
              'name': item['productName'],
              'ref': item['partNumber'], // 'partNumber' holds the reference
            });
          }
        }

        // --- 2b. Read, Log, and Update Stock for EACH product ---
        for (final productId in productQuantityChanges.keys) {
          final int quantityChange = productQuantityChanges[productId]!; // e.g., 5
          final details = productDetails[productId]!;

          // Define references
          final productDocRef = FirebaseFirestore.instance.collection('produits').doc(productId);
          final ledgerDocRef = FirebaseFirestore.instance.collection('stock_movements').doc();

          // **READ (This is why we need a transaction)**
          final productSnapshot = await transaction.get(productDocRef);
          if (!productSnapshot.exists) {
            throw Exception('Produit ${details['name']} (ID: $productId) non trouvé.');
          }
          final int oldQuantity = (productSnapshot.data()?['quantiteEnStock'] ?? 0) as int;
          final int newQuantity = oldQuantity - quantityChange;

          // **WRITE 1: Update Product Stock (Atomic)**
          transaction.update(productDocRef, {
            // Use FieldValue.increment for atomic subtraction
            'quantiteEnStock': FieldValue.increment(-quantityChange)
          });

          // **WRITE 2: Create Stock Movement Ledger**
          transaction.set(ledgerDocRef, {
            'productId': productId,
            'productRef': details['ref'] ?? 'N/A',
            'productName': details['name'] ?? 'Nom inconnu',
            'quantityChange': -quantityChange, // Save as negative
            'oldQuantity': oldQuantity,
            'newQuantity': newQuantity,
            'type': 'LIVRAISON', // New type
            'notes': 'Sortie pour Bon de Livraison: $bonLivraisonCode',
            'userId': currentUser.uid,
            'userDisplayName': currentUser.displayName ?? currentUser.email,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        // --- 2c. Prepare final product list for livraison doc ---
        // (This logic is from your original function, now inside the transaction)
        final Map<String, Map<String, dynamic>> groupedProducts = {};
        for (final item in _serializedItems) {
          final key = item['partNumber'] ?? item['productName'];
          // Use a stricter check to only include items confirmed delivered/scanned/generated
          if (item['scanned'] != true && item['serialNumber'] == null) continue;

          if (!groupedProducts.containsKey(key)) {
            final originalProduct = originalProducts.firstWhere(
                    (p) => (p['partNumber'] ?? p['productName']) == key,
                orElse: () => null);
            groupedProducts[key] = {
              'productName': item['productName'],
              'partNumber': item['partNumber'],
              'quantity': 0,
              'productId': item['productId'], // ✅ Pass productId
              'serialNumbers': originalProduct?['serialNumbers'] as List? ?? [],
              'serialNumbersFound': [],
            };
          }
          groupedProducts[key]!['quantity'] =
              (groupedProducts[key]!['quantity'] as int) + 1;
          if (item['serialNumber'] != null) {
            (groupedProducts[key]!['serialNumbersFound'] as List)
                .add(item['serialNumber']);
          }
        }
        for (final item in _bulkItems) {
          // Only include bulk items confirmed delivered
          if (item['delivered'] != true) continue;

          final key = item['partNumber'] ?? item['productName'];
          final originalProduct = originalProducts.firstWhere(
                  (p) => (p['partNumber'] ?? p['productName']) == key,
              orElse: () => null);
          if (!groupedProducts.containsKey(key)) {
            groupedProducts[key] = {
              'productName': item['productName'],
              'partNumber': item['partNumber'],
              'quantity': item['quantity'],
              'productId': item['productId'], // ✅ Pass productId
              'serialNumbers': originalProduct?['serialNumbers'] as List? ?? [],
              'serialNumbersFound': [],
            };
          } else {
            groupedProducts[key]!['quantity'] = (groupedProducts[key]!['quantity'] as int) + (item['quantity'] as int);
          }
        }
        groupedProducts.values.forEach((productData) {
          if (productData['serialNumbersFound'] is List) {
            productData['serialNumbersFound'] = (productData['serialNumbersFound'] as List)
                .where((sn) => sn != null)
                .toSet()
                .toList();
          }
        });
        final List<Map<String, dynamic>> updatedProductsList =
        List<Map<String, dynamic>>.from(groupedProducts.values);

        // --- 2d. Update Livraison Document ---
        transaction.update(livraisonRef, {
          'status': 'Livré',
          'completedAt': FieldValue.serverTimestamp(),
          'signatureUrl': signatureUrl,
          'products': updatedProductsList, // Save products with found serials
          'recipientName': _recipientNameController.text.trim(),
          'recipientPhone': _recipientPhoneController.text.trim(),
          'recipientEmail': _recipientEmailController.text.trim(),
        });

        // --- 2e. Update materiel_installe ---
        final materielCollectionRef = FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .collection('stores')
            .doc(storeId)
            .collection('materiel_installe');

        for (final productGroup in updatedProductsList) {
          final serialsFound = productGroup['serialNumbersFound'] as List? ?? [];
          if (serialsFound.isNotEmpty) {
            for (final sn in serialsFound) {
              // Note: We cannot query inside a transaction.
              // We will just set the doc using the SN as the ID.
              // This is "upsert" behavior (create or overwrite).
              final newMaterielDoc = materielCollectionRef.doc(sn); // Use SN as doc ID
              transaction.set(newMaterielDoc, {
                'productName': productGroup['productName'],
                'partNumber': productGroup['partNumber'],
                'serialNumber': sn,
                'installationDate': FieldValue.serverTimestamp(),
                'livraisonId': widget.livraisonId,
              });
            }
          }
        }
      }); // --- End of Transaction ---

      // --- 3. Log Activity and Pop Screen (AFTER transaction) ---
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
          SnackBar(content: Text('Erreur lors de la complétion: $e')),
        );
      }
      debugPrint("Error completing livraison: $e"); // Added for debugging
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  // ✅ --- START: B2 UPLOAD & FILE LOGIC (REFACTORED) ---

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
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': mimeType ?? 'b2/x-auto',
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
        final downloadUrl =
            (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
        return {'url': downloadUrl, 'fileName': fileName}; // Return map
      } else {
        debugPrint('Failed to upload to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file to B2: $e');
      return null;
    }
  }

  Future<Map<String, String>?> _uploadFileToB2(
      PlatformFile file, Map<String, dynamic> b2Creds) async {
    try {
      final fileBytes = file.bytes;
      if (fileBytes == null) {
        debugPrint('File bytes are null for ${file.name}');
        return null;
      }
      final fileName = file.name;

      String? mimeType;
      if (fileName.toLowerCase().endsWith('.jpg') ||
          fileName.toLowerCase().endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (fileName.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (fileName.toLowerCase().endsWith('.pdf')) {
        mimeType = 'application/pdf';
      } else if (fileName.toLowerCase().endsWith('.mp4')) {
        mimeType = 'video/mp4';
      } else if (fileName.toLowerCase().endsWith('.mov')) {
        mimeType = 'video/quicktime';
      }

      return await _uploadBytesToB2(fileBytes, fileName, mimeType, b2Creds);
    } catch (e) {
      debugPrint('Error preparing file for B2 upload: $e');
      return null;
    }
  }

  Future<void> _pickMediaFiles() async {
    // ✅ Prevent picking if completed
    if (_isLivraisonCompleted) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media, // Allows images and videos
      allowMultiple: true,
      withData: true, // Needed for B2
    );
    if (result != null) {
      setState(() {
        _pickedMediaFiles.addAll(result.files);
      });
    }
  }

  Future<void> _uploadAndSaveMedia() async {
    // ✅ Prevent uploading if completed
    if (_isLivraisonCompleted || _pickedMediaFiles.isEmpty) return;
    setState(() => _isUploadingMedia = true);

    try {
      final b2Credentials = await _getB2UploadCredentials();
      if (b2Credentials == null) {
        throw Exception('Impossible de récupérer les accès B2.');
      }

      List<Map<String, dynamic>> mediaList = List<Map<String, dynamic>>.from(
          _existingMedia.map((e) => e as Map<String, dynamic>));

      for (final file in _pickedMediaFiles) {
        final uploadedFileMap = await _uploadFileToB2(file, b2Credentials);
        if (uploadedFileMap != null) {
          mediaList.add(uploadedFileMap);
        }
      }

      await FirebaseFirestore.instance
          .collection('livraisons')
          .doc(widget.livraisonId)
          .update({'deliveryMedia': mediaList});

      setState(() {
        _existingMedia = mediaList;
        _pickedMediaFiles.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fichiers uploadés!'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur upload: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _openFile(String? urlString, String? fileName) async {
    if (urlString == null ||
        urlString.isEmpty ||
        fileName == null ||
        fileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun fichier à afficher.')),
      );
      return;
    }
    final extension = path.extension(fileName).toLowerCase();
    final uri = Uri.parse(urlString);

    // Combine all image URLs for the gallery
    final List<String> imageUrls = _existingMedia
        .where((m) {
      final fname = m['fileName'] as String?;
      if (fname == null) return false;
      final ext = path.extension(fname).toLowerCase();
      return ['.jpg', '.jpeg', '.png'].contains(ext);
    })
        .map((m) => m['url'] as String)
        .toList();

    // Find the index of the currently tapped image
    int initialImageIndex = imageUrls.indexOf(urlString);
    if (initialImageIndex == -1) initialImageIndex = 0; // Fallback


    if (['.mp4', '.mov', '.avi'].contains(extension)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(videoUrl: urlString),
        ),
      );
    } else if (['.jpg', '.jpeg', '.png'].contains(extension)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageGalleryPage(
            imageUrls: imageUrls, // Pass all image URLs
            initialIndex: initialImageIndex, // Pass the correct starting index
          ),
        ),
      );
    } else if (extension == '.pdf') {
      setState(() => _isLoading = true); // Use _isLoading for consistency
      try {
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfViewerPage(
                  pdfBytes: response.bodyBytes,
                  title: fileName,
                ),
              ),
            );
          }
        } else {
          throw Exception('Impossible de télécharger le PDF.');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur ouverture PDF: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Type de fichier non supporté: $extension')),
      );
    }
  }

  IconData _getFileIcon(String? fileName) {
    if (fileName == null) return Icons.attach_file;
    final extension = path.extension(fileName).toLowerCase();
    if (['.jpg', '.jpeg', '.png'].contains(extension)) {
      return Icons.image;
    } else if (extension == '.pdf') {
      return Icons.picture_as_pdf;
    } else if (['.mp4', '.mov', '.avi'].contains(extension)) {
      return Icons.videocam;
    }
    return Icons.description;
  }
  // ✅ --- END: B2 UPLOAD & FILE LOGIC ---

  // ✅ NEW WIDGET: Builds an editable product item for serialized products
  Widget _buildEditableSerializedItem(Map<String, dynamic> item, int index) {
    bool isScanned = item['scanned'] ?? false;

    // Use a unique key to ensure TextFormField re-renders correctly when the item data changes
    final Key itemKey = ValueKey('item_${widget.livraisonId}_$index');

    // Create a controller to hold and manage the dynamic value
    final TextEditingController snController =
    TextEditingController(text: item['serialNumber'] ?? '');

    // A simple onChanged to keep the map updated if the user types manually
    void updateItem(String value) {
      item['serialNumber'] = value;
      // If user manually enters a value, mark it as 'scanned'
      if (value.isNotEmpty) {
        item['scanned'] = true;
      } else {
        item['scanned'] = false;
      }
    }

    // Since this widget will be rebuilt by setState, the controller is recreated
    // correctly reflecting the current state of item['serialNumber'].

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Card(
        key: itemKey, // Apply the key
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
                        color: isScanned ? Colors.green.shade900 : Colors.black87,
                      ),
                    ),
                  ),
                  if (isScanned)
                    const Icon(Icons.check_circle, color: Colors.green, size: 24)
                  else if (!_isLivraisonCompleted)
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      color: Colors.blue,
                      tooltip: 'Scanner',
                      onPressed: () => _scanSerializedItem(item),
                    ),
                ],
              ),
              Text('Réf: ${item['partNumber'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade700)),
              if (item['originalSerialNumber'] != null)
                Text('N/S Attendu: ${item['originalSerialNumber']}', style: TextStyle(color: Colors.orange.shade700)),
              const SizedBox(height: 10),

              // --- Editable Serial Number Field (Generation button removed) ---
              TextFormField(
                controller: snController,
                enabled: !_isLivraisonCompleted, // Disable editing if completed
                decoration: InputDecoration(
                  labelText: 'Numéro de Série Scanné/Saisi', // MODIFIED TEXT
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  // REMOVED: suffixIcon (Generation Button)
                ),
                onChanged: updateItem, // Use the update function
                validator: (value) {
                  // Ensure a value is present if not completed
                  if (!_isLivraisonCompleted && (value == null || value.isEmpty)) {
                    // MODIFIED TEXT
                    return 'Veuillez scanner ou entrer un numéro de série.';
                  }
                  return null;
                },
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
      return Scaffold(
        appBar: AppBar(title: const Text('Chargement Détails...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_livraisonDoc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: const Center(child: Text('Impossible de charger les détails de la livraison.')),
      );
    }


    final data = _livraisonDoc!.data() as Map<String, dynamic>; // Now safe to assume not null
    final int totalSerializedItems = _serializedItems.length;
    final int totalSerializedScanned =
        _serializedItems.where((item) => item['scanned'] == true).length;
    final int totalBulkItems = _bulkItems.length;
    final int totalBulkDelivered =
        _bulkItems.where((item) => item['delivered'] == true).length;

    // ✅ CHANGED: This logic now points to the new 'externalBons' list
    final List bonFiles = data['externalBons'] as List? ?? [];
    final String? fileUrl = bonFiles.isNotEmpty ? bonFiles.first['url'] as String? : null;
    final String? fileName = bonFiles.isNotEmpty ? bonFiles.first['name'] as String? : null;
    final String? signatureImageUrl = data['signatureUrl'] as String?; // ✅ Get signature URL


    return Scaffold(
      appBar: AppBar(
        title: Text(data['bonLivraisonCode'] ?? 'Détails de la Livraison'),
        // ✅ Add indicator if completed
        actions: [
          if (_isLivraisonCompleted)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Chip(
                label: Text('Terminé', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.green,
                avatar: Icon(Icons.check_circle, color: Colors.white, size: 18),
              ),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.business, color: Colors.blueGrey),
                title: Text(data['clientName'] ?? 'Client Inconnu', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    'Magasin: ${data['storeName'] ?? 'N/A'}\nAdresse: ${data['deliveryAddress'] ?? 'N/A'}'),
              ),
            ),

            // ✅ CHANGED: This section now shows the *first* bon file, if any
            if (fileUrl != null && fileUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Fichier Attaché (Bon)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                color: Colors.blue.shade50,
                child: ListTile(
                  leading: Icon(_getFileIcon(fileName), color: Colors.blue.shade700),
                  title: Text(fileName ?? 'Bon de Livraison'),
                  subtitle: const Text('Appuyez pour ouvrir'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openFile(fileUrl, fileName),
                ),
              ),
            ],
            const SizedBox(height: 16),

            if (_serializedItems.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Produits avec N/S ($totalSerializedScanned/$totalSerializedItems)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ✅ MODIFIED: Use the new builder with Card per item
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _serializedItems.length,
                itemBuilder: (context, index) {
                  final item = _serializedItems[index];
                  return _buildEditableSerializedItem(item, index);
                },
              ),
              const SizedBox(height: 24),
            ],


            if (_bulkItems.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.inventory, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Produits Cons ($totalBulkDelivered/$totalBulkItems)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                color: Colors.green.shade50,
                child: ListView.separated( // Use ListView.separated
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _bulkItems.length,
                  separatorBuilder: (_, __) => Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final item = _bulkItems[index];
                    bool isDelivered = item['delivered'] ?? false;
                    return ListTile(
                      leading: isDelivered
                          ? const Icon(Icons.check_circle,
                          color: Colors.green, size: 30)
                          : const Icon(Icons.inventory_2_outlined,
                          color: Colors.grey, size: 30),
                      title: Text(
                        item['productName'] ?? 'Produit Inconnu',
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
                      trailing: !isDelivered && !_isLivraisonCompleted
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
                            onPressed: () =>
                                _markBulkItemDelivered(item),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Livré'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      )
                          : (isDelivered ? const Icon(Icons.check,
                          color: Colors.green, size: 28) : null),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],


            const Divider(height: 32),

            Text('Preuve de Livraison',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _proofFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Photos / Vidéos',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          if (!_isLivraisonCompleted)
                            OutlinedButton.icon(
                              onPressed: _pickMediaFiles,
                              icon:
                              const Icon(Icons.add_a_photo_outlined, size: 18),
                              label: const Text('Ajouter'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: const BorderSide(color: Colors.blue),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildMediaThumbnails(_isLivraisonCompleted),
                      if (!_isLivraisonCompleted && _pickedMediaFiles.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isUploadingMedia
                                ? null
                                : _uploadAndSaveMedia,
                            icon: _isUploadingMedia
                                ? Container(
                              width: 20,
                              height: 20,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                                : const Icon(Icons.upload),
                            label: Text(
                                'Uploader (${_pickedMediaFiles.length}) Fichier(s)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                      const Divider(height: 24),
                      const Text('Détails du Réceptionnaire',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextFormField(
                        enabled: !_isLivraisonCompleted,
                        controller: _recipientNameController,
                        decoration: InputDecoration(
                          labelText: 'Nom Complet *',
                          prefixIcon: const Icon(Icons.person_outline),
                          fillColor: _isLivraisonCompleted ? Colors.grey.shade200 : null,
                          filled: _isLivraisonCompleted,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (value) {
                          if (!_isLivraisonCompleted && (value == null || value.trim().isEmpty)) {
                            return 'Le nom est requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        enabled: !_isLivraisonCompleted,
                        controller: _recipientPhoneController,
                        decoration: InputDecoration(
                          labelText: 'Numéro de Téléphone (Optionnel)',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          fillColor: _isLivraisonCompleted ? Colors.grey.shade200 : null,
                          filled: _isLivraisonCompleted,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        enabled: !_isLivraisonCompleted,
                        controller: _recipientEmailController,
                        decoration: InputDecoration(
                          labelText: 'Email (Optionnel)',
                          prefixIcon: const Icon(Icons.email_outlined),
                          fillColor: _isLivraisonCompleted ? Colors.grey.shade200 : null,
                          filled: _isLivraisonCompleted,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Signature du Client',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          if (!_isLivraisonCompleted)
                            TextButton(
                              child: const Text('Effacer'),
                              onPressed: _signatureController.isEmpty ? null : () => _signatureController.clear(),
                            )
                        ],
                      ),
                      // ✅ Conditionally show Signature pad or saved Image
                      _isLivraisonCompleted
                          ? (signatureImageUrl != null
                          ? Container( // Display the saved signature image
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4), // Add border radius
                          color: Colors.grey.shade100, // Background color
                        ),
                        child: ClipRRect( // Clip the image to the border radius
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            signatureImageUrl,
                            fit: BoxFit.contain, // Or BoxFit.fill
                            loadingBuilder: (context, child, progress) {
                              return progress == null
                                  ? child
                                  : Center(child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                    : null,
                              ));
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(child: Icon(Icons.error_outline, color: Colors.red, size: 40));
                            },
                          ),
                        ),
                      )
                          : Container( // Placeholder if URL missing but completed
                        height: 150,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.grey.shade200),
                        child: const Center(child: Text('Signature non disponible', style: TextStyle(color: Colors.grey))),
                      )
                      )
                          : Container( // Show editable signature pad if NOT completed
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4), // Add border radius
                        ),
                        child: ClipRRect( // Clip the signature pad
                          borderRadius: BorderRadius.circular(4),
                          child: Signature(
                            controller: _signatureController,
                            backgroundColor: Colors.grey[200]!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 32),

            if (!_isLivraisonCompleted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isCompleting || !_allCompleted || _isUploadingMedia) // Removed signature check here, added validation earlier
                      ? null
                      : _completeLivraison,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Confirmer la Livraison'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // ✅ --- START: THUMBNAIL WIDGETS (Added isReadOnly parameter) ---

  Widget _buildMediaThumbnails([bool isReadOnly = false]) { // Add parameter
    final allMedia = [
      ..._existingMedia.map((media) => {'isPicked': false, 'data': media}),
      // Only show newly picked files if not read-only
      if (!isReadOnly) ..._pickedMediaFiles.map((file) => {'isPicked': true, 'data': file})
    ];

    if (allMedia.isEmpty) {
      return const Center(
          child: Text('Aucune photo ou vidéo ajoutée.',
              style: TextStyle(color: Colors.grey)));
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: allMedia.map((media) {
        if (media['isPicked'] as bool) {
          // Pass read-only flag to disable remove button
          return _buildPickedFileThumbnail(media['data'] as PlatformFile, isReadOnly);
        } else {
          return _buildExistingMediaThumbnail(
              media['data'] as Map<String, dynamic>);
        }
      }).toList(),
    );
  }

  Widget _buildExistingMediaThumbnail(Map<String, dynamic> media) {
    final url = media['url'] as String?;
    final fileName = media['fileName'] as String?;
    final icon = _getFileIcon(fileName);

    return InkWell(
      onTap: () => _openFile(url, fileName),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect( // Clip content
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (icon == Icons.image)
                Image.network(
                  url!,
                  fit: BoxFit.cover, width: 80, height: 80,
                  loadingBuilder: (context, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: 40, color: Colors.grey.shade700),
                )
              else if (icon == Icons.videocam)
                _buildVideoThumbnailFromUrl(url) // Use helper for URL thumbs
              else
                Icon(icon, size: 40, color: Colors.grey.shade700),
              if (icon == Icons.videocam)
                Icon(Icons.play_circle_fill, color: Colors.white70, size: 30),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildVideoThumbnailFromUrl(String? url) {
    // Placeholder - Actual URL thumbnail generation might need more work
    return Icon(Icons.videocam, size: 40, color: Colors.grey.shade700);
  }


  Widget _buildPickedFileThumbnail(PlatformFile file, [bool isReadOnly = false]) { // Add parameter
    final fileName = file.name;
    final icon = _getFileIcon(fileName);

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue),
      ),
      child: ClipRRect( // Clip content
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (icon == Icons.image && file.bytes != null)
              Image.memory(file.bytes!,
                  fit: BoxFit.cover, width: 80, height: 80)
            else if (icon == Icons.videocam)
              _buildVideoThumbnail(file) // Assumes file.path is available
            else
              Icon(icon, size: 40, color: Colors.blue.shade700),
            // Show add icon only if not read-only
            if (!isReadOnly)
              Positioned(
                top: 2, // Adjusted position
                right: 2, // Adjusted position
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8), // Slightly transparent
                    shape: BoxShape.circle, // Make it circular
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 14), // Smaller icon
                ),
              ),
            // Show remove button only if not read-only
            if (!isReadOnly)
              Positioned(
                bottom: -12, // Adjusted position
                right: -12, // Adjusted position
                child: Material( // Wrap IconButton in Material for ink splash
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(Icons.remove_circle),
                    color: Colors.red.withOpacity(0.9), // Slightly transparent
                    iconSize: 22, // Slightly larger icon
                    tooltip: 'Supprimer',
                    padding: EdgeInsets.zero, // Remove padding
                    constraints: BoxConstraints(), // Remove constraints
                    onPressed: () {
                      setState(() {
                        _pickedMediaFiles.remove(file);
                      });
                    },
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(PlatformFile file) {
    if (file.path == null) {
      // Show placeholder if path isn't available
      return Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.videocam, size: 40, color: Colors.blue.shade700),
          Icon(Icons.play_circle_fill, color: Colors.black45, size: 30),
        ],
      );
    }
    return FutureBuilder<Uint8List?>(
      future: VideoThumbnail.thumbnailData(
        video: file.path!,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 120, // Increased size for better quality if needed
        quality: 50,    // Increased quality
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snapshot.hasError) {
          debugPrint("Error generating video thumbnail: ${snapshot.error}");
          return Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.videocam_off, size: 40, color: Colors.red.shade700),
              Icon(Icons.error_outline, color: Colors.black45, size: 30),
            ],
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              Image.memory(snapshot.data!, fit: BoxFit.cover),
              Icon(Icons.play_circle_fill, color: Colors.white.withOpacity(0.7), size: 30), // Adjusted opacity
            ],
          );
        }
        // Fallback if data is null for some reason
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.videocam, size: 40, color: Colors.blue.shade700),
            Icon(Icons.play_circle_fill, color: Colors.black45, size: 30),
          ],
        );
      },
    );
  }
// ✅ --- END: THUMBNAIL WIDGETS ---
}
// lib/screens/administration/livraison_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:boitex_info_app/screens/widgets/scanner_page.dart';
import 'package:signature/signature.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

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

  List<dynamic> _existingMedia = []; // From Firestore
  List<PlatformFile> _pickedMediaFiles = []; // Newly picked
  bool _isUploadingMedia = false;
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';

  // ✅ ADDED: Controllers for recipient details
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _recipientEmailController = TextEditingController();

  bool get _allCompleted {
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

        // ✅ ADDED: Load recipient details if they exist
        _recipientNameController.text = data['recipientName'] ?? '';
        _recipientPhoneController.text = data['recipientPhone'] ?? '';
        _recipientEmailController.text = data['recipientEmail'] ?? '';

        final List<Map<String, dynamic>> serialized = [];
        final List<Map<String, dynamic>> bulk = [];

        for (final product in products) {
          final int quantity = product['quantity'] ?? 0;
          final String productName = product['productName'] ?? 'N/A';
          final String? partNumber = product['partNumber'] as String?;
          final List serials = product['serialNumbers'] as List? ?? [];

          if (quantity > 5 && serials.isEmpty) {
            bulk.add({
              'productName': productName,
              'partNumber': partNumber,
              'quantity': quantity,
              'delivered': false,
              'type': 'bulk',
            });
          } else {
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
    }
  }

  // --- Scan/Mark Logic (No Changes) ---
  void _scanSerializedItem(Map<String, dynamic> item) async {
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
        content:
        Text('✓ ${item['quantity']} x ${item['productName']} marqué comme livré'),
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
          builder: (context) =>
              ScannerPage(onScan: (code) => scannedCode = code)),
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

  // --- Signature Logic (No Changes) ---
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

  // --- Completion Logic ---
  Future<void> _completeLivraison() async {
    // ✅ ADDED: Validate recipient name
    if (!_proofFormKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez entrer le nom du réceptionnaire.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    if (_livraisonDoc == null) return;
    setState(() => _isCompleting = true);

    try {
      final signatureUrl = await _uploadSignature();
      final livraisonData = _livraisonDoc!.data() as Map<String, dynamic>;
      final clientId = livraisonData['clientId'];
      final storeId = livraisonData['storeId'];
      if (storeId == null || storeId.isEmpty) {
        throw Exception(
            'Impossible de sauvegarder l\'historique: Magasin non spécifié.');
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
        groupedProducts[key]!['quantity'] =
            (groupedProducts[key]!['quantity'] as int) + 1;
        if (item['serialNumber'] != null) {
          (groupedProducts[key]!['serialNumbers'] as List)
              .add(item['serialNumber']);
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
      final livraisonRef = FirebaseFirestore.instance
          .collection('livraisons')
          .doc(widget.livraisonId);

      // ✅ ADDED: Include recipient details in the update
      batch.update(livraisonRef, {
        'status': 'Livré',
        'completedAt': FieldValue.serverTimestamp(),
        'signatureUrl': signatureUrl,
        'products': updatedProductsList,
        'recipientName': _recipientNameController.text.trim(),
        'recipientPhone': _recipientPhoneController.text.trim(),
        'recipientEmail': _recipientEmailController.text.trim(),
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

  // ✅ --- START: B2 UPLOAD & FILE LOGIC (No Changes from previous) ---

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

  Future<Map<String, String>?> _uploadFileToB2(
      PlatformFile file, Map<String, dynamic> b2Creds) async {
    try {
      final fileBytes = file.bytes;
      if (fileBytes == null) {
        debugPrint('File bytes are null for ${file.name}');
        return null;
      }
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
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

  Future<void> _pickMediaFiles() async {
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
    if (_pickedMediaFiles.isEmpty) return;
    setState(() => _isUploadingMedia = true);

    try {
      final b2Credentials = await _getB2UploadCredentials();
      if (b2Credentials == null) {
        throw Exception('Impossible de récupérer les accès B2.');
      }

      // Get current list of media from state
      List<Map<String, dynamic>> mediaList =
      List<Map<String, dynamic>>.from(
          _existingMedia.map((e) => e as Map<String, dynamic>));

      for (final file in _pickedMediaFiles) {
        final uploadedFileMap = await _uploadFileToB2(file, b2Credentials);
        if (uploadedFileMap != null) {
          mediaList.add(uploadedFileMap);
        }
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('livraisons')
          .doc(widget.livraisonId)
          .update({'deliveryMedia': mediaList});

      // Update local state and clear picked files
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
            imageUrls: [urlString],
            initialIndex: 0,
          ),
        ),
      );
    } else if (extension == '.pdf') {
      setState(() => _isCompleting = true); // Show loading indicator
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
        if (mounted) setState(() => _isCompleting = false); // Hide loading
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

    final String? fileUrl = data['externalBonUrl'] as String?;
    final String? fileName = data['externalBonFileName'] as String?;

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

            if (fileUrl != null && fileUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Fichier Attaché',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.blue.shade50,
                child: ListTile(
                  leading: Icon(_getFileIcon(fileName), color: Colors.blue),
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
                          ? const Icon(Icons.check_circle,
                          color: Colors.green, size: 30)
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
                          ? const Icon(Icons.check_circle,
                          color: Colors.green, size: 30)
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
                            onPressed: () =>
                                _markBulkItemDelivered(item),
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
                          : const Icon(Icons.check,
                          color: Colors.green, size: 28),
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
                // ✅ ADDED Form widget
                child: Form(
                  key: _proofFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Media Upload Section (No Changes)---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Photos / Vidéos',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          OutlinedButton.icon(
                            onPressed: _pickMediaFiles,
                            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                            label: const Text('Ajouter'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildMediaThumbnails(),
                      if (_pickedMediaFiles.isNotEmpty) ...[
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
                            ),
                          ),
                        ),
                      ],
                      const Divider(height: 24),
                      // ✅ --- START: ADDED RECIPIENT DETAILS FIELDS ---
                      const Text('Détails du Réceptionnaire',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _recipientNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom Complet *',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le nom est requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _recipientPhoneController,
                        decoration: const InputDecoration(
                          labelText: 'Numéro de Téléphone (Optionnel)',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _recipientEmailController,
                        decoration: const InputDecoration(
                          labelText: 'Email (Optionnel)',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      // ✅ --- END: ADDED RECIPIENT DETAILS FIELDS ---
                      const Divider(height: 24),
                      // --- Signature Section (No Changes) ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Signature du Client',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          TextButton(
                            child: const Text('Effacer'),
                            onPressed: () => _signatureController.clear(),
                          )
                        ],
                      ),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400)),
                        child: Signature(
                          controller: _signatureController,
                          backgroundColor: Colors.grey[200]!,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isCompleting || !_allCompleted || _isUploadingMedia)
                    ? null
                    : _completeLivraison,
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

  // ✅ --- START: THUMBNAIL WIDGETS (No Changes) ---

  Widget _buildMediaThumbnails() {
    final allMedia = [
      ..._existingMedia.map((media) => {'isPicked': false, 'data': media}),
      ..._pickedMediaFiles
          .map((file) => {'isPicked': true, 'data': file})
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
          return _buildPickedFileThumbnail(media['data'] as PlatformFile);
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
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (icon == Icons.image)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(url!,
                    fit: BoxFit.cover, width: 80, height: 80),
              )
            else
              Icon(icon, size: 40, color: Colors.grey.shade700),
            if (icon == Icons.videocam)
              Icon(Icons.play_circle_fill, color: Colors.white70, size: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPickedFileThumbnail(PlatformFile file) {
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (icon == Icons.image && file.bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(file.bytes!,
                  fit: BoxFit.cover, width: 80, height: 80),
            )
          else if (icon == Icons.videocam)
            _buildVideoThumbnail(file)
          else
            Icon(icon, size: 40, color: Colors.blue.shade700),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 12),
            ),
          ),
          Positioned(
            bottom: -10,
            right: -10,
            child: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
              onPressed: () {
                setState(() {
                  _pickedMediaFiles.remove(file);
                });
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildVideoThumbnail(PlatformFile file) {
    if (file.path == null) {
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
        maxWidth: 80,
        quality: 30,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(strokeWidth: 2);
        }
        if (snapshot.hasData && snapshot.data != null) {
          return Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(snapshot.data!, fit: BoxFit.cover)),
              Icon(Icons.play_circle_fill, color: Colors.white70, size: 30),
            ],
          );
        }
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
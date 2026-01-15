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
import 'package:google_fonts/google_fonts.dart';

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

  // ✅ Controllers
  final Map<int, TextEditingController> _pickingControllers = {};
  final Map<int, FocusNode> _pickingFocusNodes = {};

  // ✅ State
  int? _selectedPickingIndex;
  StreamSubscription? _zebraSubscription;

  String _status = '';
  bool _isLoading = true;
  bool _isCompleting = false;
  bool _isLivraisonCompleted = false;
  String _loadingStatus = '';

  List<dynamic> _existingMedia = [];
  List<PlatformFile> _pickedMediaFiles = [];
  bool _isUploadingMedia = false;
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl';

  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _recipientEmailController = TextEditingController();

  double? _storeLat;
  double? _storeLng;
  bool _isLoadingGps = false;
  bool _isGeneratingPdf = false;

  bool get _isPickingMode => _status == 'À Préparer';

  // ✅ Colors for the "High Quality" Vibe
  final Color _primaryBlue = const Color(0xFF2962FF); // Premium Blue
  final Color _accentGreen = const Color(0xFF00E676); // Neon Green
  final Color _bgLight = const Color(0xFFF4F6F9); // Clean Grey/White

  // ✅ UPDATED: Validation logic for delivery phase
  bool get _allCompleted {
    if (_isLivraisonCompleted) return true;
    if (_serializedItems.isEmpty && _bulkItems.isEmpty) return false;

    // Technician must check (delivered=true) all items
    final serializedDone = _serializedItems.isEmpty ||
        _serializedItems.every((item) => item['delivered'] == true);

    final bulkDone = _bulkItems.isEmpty ||
        _bulkItems.every((item) => item['delivered'] == true);

    return serializedDone && bulkDone;
  }

  bool get _allPicked {
    if (_pickingItems.isEmpty) return false;
    return _pickingItems.every((item) {
      final int qty = item['quantity'] as int? ?? 0;
      final bool isBulk = item['isBulk'] == true;
      if (isBulk) {
        final int picked = item['pickedQuantity'] as int? ?? 0;
        return picked >= qty;
      } else {
        final List serials = item['serialNumbers'] as List? ?? [];
        return serials.length >= qty;
      }
    });
  }

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 4,
    penColor: const Color(0xFF2962FF),
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _loadLivraisonDetails();

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

  Future<void> _fetchStoreCoordinates(String clientId, String storeId) async {
    setState(() => _isLoadingGps = true);
    try {
      final storeDoc = await FirebaseFirestore.instance.collection('clients').doc(clientId).collection('stores').doc(storeId).get();
      if (storeDoc.exists) {
        final storeData = storeDoc.data();
        if (storeData != null && storeData['latitude'] != null && storeData['longitude'] != null) {
          setState(() {
            _storeLat = (storeData['latitude'] as num).toDouble();
            _storeLng = (storeData['longitude'] as num).toDouble();
          });
        }
      }
    } catch (e) { debugPrint("Error GPS: $e"); } finally { if (mounted) setState(() => _isLoadingGps = false); }
  }

  Future<void> _launchMaps() async {
    if (_storeLat == null || _storeLng == null) return;
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$_storeLat,$_storeLng");
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _loadLivraisonDetails() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('livraisons').doc(widget.livraisonId).get();
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
          pickingList = List<Map<String, dynamic>>.from(rawProducts.map((p) {
            final map = Map<String, dynamic>.from(p);
            // ✅ FORCE DEFAULT: If 'isBulk' is not set, default to TRUE (Manual Mode)
            if (!map.containsKey('isBulk')) {
              map['isBulk'] = true;
            }
            return map;
          }));
          if (pickingList.isNotEmpty) _selectedPickingIndex = 0;
        } else {
          // ✅ DELIVERY PHASE LOGIC
          for (final product in rawProducts) {
            int quantity = product['quantity'] is int ? product['quantity'] : int.tryParse(product['quantity'].toString()) ?? 0;
            // ✅ Retrieve Picked Quantity
            int pickedQuantity = product['pickedQuantity'] is int ? product['pickedQuantity'] : int.tryParse(product['pickedQuantity'].toString()) ?? 0;

            final String productName = product['productName'] ?? 'N/A';
            final String? partNumber = product['partNumber'];
            final String? productId = product['productId'];
            final List serials = product['serialNumbers'] as List? ?? [];
            final List serialsFound = product['serialNumbersFound'] as List? ?? [];

            // Determine if it's bulk or serialized logic
            bool isBulkItem = (quantity > 50) || (quantity > 5 && serials.isEmpty && serialsFound.isEmpty) || product['isBulk'] == true;

            // ✅ If no serials were picked, default pickedQuantity to number of serials if available
            if (pickedQuantity == 0 && serials.isNotEmpty) {
              pickedQuantity = serials.length;
            }

            if (isBulkItem) {
              String key = productId ?? productName;
              if (bulkMap.containsKey(key)) {
                bulkMap[key]!['quantity'] = (bulkMap[key]!['quantity'] as int) + quantity;
                bulkMap[key]!['pickedQuantity'] = (bulkMap[key]!['pickedQuantity'] as int) + pickedQuantity;
              } else {
                bulkMap[key] = {
                  'productName': productName,
                  'partNumber': partNumber,
                  'quantity': quantity,
                  'pickedQuantity': pickedQuantity, // ✅ Added
                  'delivered': isCompleted,
                  'type': 'bulk',
                  'productId': productId,
                };
              }
            } else {
              // Serialized: Create an entry for each picked item
              int itemsToAdd = serials.isNotEmpty ? serials.length : quantity;
              // Use pickedQuantity if serials are empty but manual picking happened
              if (serials.isEmpty && pickedQuantity > 0) itemsToAdd = pickedQuantity;

              for (int i = 0; i < itemsToAdd; i++) {
                serializedList.add({
                  'productName': productName,
                  'partNumber': partNumber,
                  'serialNumber': (i < serialsFound.length) ? serialsFound[i] : (i < serials.length ? serials[i] : null),
                  'originalSerialNumber': (i < serials.length) ? serials[i] : null,
                  'delivered': isCompleted, // ✅ Replaced 'scanned' with 'delivered'
                  'type': 'serialized',
                  'productId': productId,
                  'quantity': 1,
                  'pickedQuantity': 1,
                });
              }
            }
          }
        }
        setState(() {
          _livraisonDoc = doc; _isLivraisonCompleted = isCompleted; _pickingItems = pickingList;
          _serializedItems = serializedList; _bulkItems = bulkMap.values.toList();
          _existingMedia = deliveryMedia; _isLoading = false;
        });
      } else { setState(() => _isLoading = false); }
    } catch (e) { setState(() => _isLoading = false); }
  }

  Future<void> _generateAndOpenPdf() async {
    if (_livraisonDoc == null) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final data = _livraisonDoc!.data() as Map<String, dynamic>;
      final clientId = data['clientId'];
      final bonCode = data['bonLivraisonCode'] ?? 'BL';
      final clientDoc = await FirebaseFirestore.instance.collection('clients').doc(clientId).get();
      final clientData = clientDoc.data() ?? {};
      List<ProductSelection> pdfProducts = [];
      if (_status == 'À Préparer') {
        pdfProducts = _pickingItems.map((item) => ProductSelection.fromJson(item)).toList();
      } else {
        final Map<String, Map<String, dynamic>> groupedMap = {};
        for (var item in _serializedItems) {
          final key = item['partNumber'] ?? item['productName'];
          if (!groupedMap.containsKey(key)) {
            groupedMap[key] = {'productId': item['productId'], 'productName': item['productName'], 'partNumber': item['partNumber'], 'marque': item['marque'] ?? 'N/A', 'quantity': 0, 'serialNumbers': <String>[]};
          }
          groupedMap[key]!['quantity'] = (groupedMap[key]!['quantity'] as int) + 1;
          final sn = item['serialNumber'] ?? item['originalSerialNumber'];
          if (sn != null) (groupedMap[key]!['serialNumbers'] as List<String>).add(sn);
        }
        for (var item in _bulkItems) {
          final key = item['partNumber'] ?? item['productName'];
          if (!groupedMap.containsKey(key)) {
            groupedMap[key] = {'productId': item['productId'], 'productName': item['productName'], 'partNumber': item['partNumber'], 'marque': item['marque'] ?? 'N/A', 'quantity': 0, 'serialNumbers': <String>[]};
          }
          groupedMap[key]!['quantity'] = (groupedMap[key]!['quantity'] as int) + (item['quantity'] as int);
        }
        pdfProducts = groupedMap.values.map((map) => ProductSelection.fromJson(map)).toList();
      }
      Uint8List? signatureBytes;
      if (data['signatureUrl'] != null) {
        final resp = await http.get(Uri.parse(data['signatureUrl']));
        if (resp.statusCode == 200) signatureBytes = resp.bodyBytes;
      }
      final pdfBytes = await LivraisonPdfService().generateLivraisonPdf(livraisonData: data, products: pdfProducts, clientData: clientData, docId: widget.livraisonId, signatureBytes: signatureBytes);
      if (mounted) {
        if (kIsWeb) {
          await FileSaver.instance.saveFile(name: bonCode.replaceAll('/', '-'), bytes: pdfBytes, ext: 'pdf', mimeType: MimeType.pdf);
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => PdfViewerPage(pdfBytes: pdfBytes, title: "$bonCode.pdf")));
        }
      }
    } catch (e) { debugPrint("PDF Error: $e"); } finally { if (mounted) setState(() => _isGeneratingPdf = false); }
  }

  void _toggleBulkMode(int index) {
    setState(() {
      final isBulk = _pickingItems[index]['isBulk'] == true;
      _pickingItems[index]['isBulk'] = !isBulk;
      if (!isBulk && _pickingItems[index]['pickedQuantity'] == null) {
        final List serials = _pickingItems[index]['serialNumbers'] ?? [];
        _pickingItems[index]['pickedQuantity'] = serials.length;
      }
    });
    _savePickingState();
  }

  // ✅ New Helper: Validate Full Quantity instantly
  void _validateFullQuantity(int index) {
    final item = _pickingItems[index];
    final int quantity = item['quantity'] ?? 0;
    setState(() => _pickingItems[index]['pickedQuantity'] = quantity);
    _savePickingState();
  }

  void _showBulkQuantityDialog(int index) {
    final item = _pickingItems[index];
    final int current = item['pickedQuantity'] as int? ?? 0;
    final int max = item['quantity'] as int? ?? 0;
    final TextEditingController qtyCtrl = TextEditingController(text: current.toString());
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Définir la Quantité"),
      content: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(labelText: "Quantité", border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
        ElevatedButton(onPressed: () {
          int? val = int.tryParse(qtyCtrl.text);
          if (val != null) {
            if (val > max) val = max; if (val < 0) val = 0;
            setState(() => _pickingItems[index]['pickedQuantity'] = val);
            _savePickingState();
          }
          Navigator.pop(context);
        }, child: const Text("Valider"))
      ],
    ));
  }

  void _processInputScan(int index, String code) {
    if (code.trim().isEmpty) return;
    final item = _pickingItems[index];
    final String? partNumber = item['partNumber'];
    final int quantity = item['quantity'] ?? 0;
    final bool isBulk = item['isBulk'] == true;

    if (isBulk) {
      int picked = item['pickedQuantity'] as int? ?? 0;
      if (picked >= quantity) return;
      if (partNumber != null && code.trim().toUpperCase() != partNumber.trim().toUpperCase()) return;
      setState(() => _pickingItems[index]['pickedQuantity'] = picked + 1);
      _savePickingState();
    } else {
      List<String> currentSerials = List<String>.from(item['serialNumbers'] ?? []);
      if (currentSerials.length >= quantity) return;
      if (partNumber != null && code.trim().toUpperCase() == partNumber.trim().toUpperCase()) return;
      if (currentSerials.contains(code.trim())) return;
      setState(() { currentSerials.add(code.trim()); _pickingItems[index]['serialNumbers'] = currentSerials; });
      _savePickingState();
    }
    _pickingControllers[index]?.clear();
    _pickingFocusNodes[index]?.requestFocus();
  }

  Future<void> _handlePickingScan(int index) async {
    setState(() => _selectedPickingIndex = index);
    String? scannedSN;
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (context) => ScannerPage(onScan: (code) => scannedSN = code)));
    if (scannedSN != null) _processInputScan(index, scannedSN!);
  }

  Future<void> _savePickingState() async {
    try { await FirebaseFirestore.instance.collection('livraisons').doc(widget.livraisonId).update({'products': _pickingItems}); } catch (e) { debugPrint("Error saving: $e"); }
  }

  Future<void> _validatePreparation() async {
    if (!_allPicked) return;
    setState(() => _isCompleting = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    try {
      final bonLivraisonCode = _livraisonDoc?.get('bonLivraisonCode') ?? 'N/A';
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final livraisonRef = FirebaseFirestore.instance.collection('livraisons').doc(widget.livraisonId);
        List<Map<String, dynamic>> ops = [];
        for (final item in _pickingItems) {
          if (item['productId'] != null) {
            final ref = FirebaseFirestore.instance.collection('produits').doc(item['productId']);
            final snap = await transaction.get(ref);
            if (snap.exists) ops.add({'ref': ref, 'snap': snap, 'item': item});
          }
        }
        for (final op in ops) {
          final int qty = op['item']['quantity'] ?? 0;
          transaction.update(op['ref'], {'quantiteEnStock': FieldValue.increment(-qty)});
          final ledgerRef = FirebaseFirestore.instance.collection('stock_movements').doc();
          transaction.set(ledgerRef, {
            'productId': op['item']['productId'], 'productName': op['item']['productName'],
            'quantityChange': -qty, 'type': 'PREPARATION', 'notes': 'Sortie $bonLivraisonCode',
            'timestamp': FieldValue.serverTimestamp()
          });
        }
        transaction.update(livraisonRef, {'status': 'En Cours de Livraison', 'preparedAt': FieldValue.serverTimestamp(), 'products': _pickingItems});
      });
      if (mounted) _loadLivraisonDetails();
    } catch (e) { debugPrint("Error: $e"); } finally { if (mounted) setState(() => _isCompleting = false); }
  }

  // ✅ REMOVED: _scanSerializedItem is no longer needed in new workflow
  // Technician just checks the item off.

  Future<String?> _uploadSignature() async {
    if (_isLivraisonCompleted || _signatureController.isEmpty) return null;
    final data = await _signatureController.toPngBytes();
    if (data == null) return null;
    try {
      final creds = await _getB2UploadCredentials();
      if (creds == null) return null;
      final fileName = 'livraison_signatures/${widget.livraisonId}/${DateTime.now().millisecondsSinceEpoch}.png';
      final res = await _uploadBytesToB2(data, fileName, 'image/png', creds);
      return res?['url'];
    } catch (e) { return null; }
  }

  Future<void> _completeLivraison() async {
    if (_isLivraisonCompleted) return;
    // ✅ VALIDATION: Ensure all items (bulk and serialized) are marked as delivered
    if (!_allCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez valider tous les produits avant de confirmer.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (_proofFormKey.currentState != null && !_proofFormKey.currentState!.validate()) return;
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La signature est obligatoire.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isCompleting = true);
    try {
      String? sigUrl = await _uploadSignature();
      await FirebaseFirestore.instance.collection('livraisons').doc(widget.livraisonId).update({
        'status': 'Livré', 'completedAt': FieldValue.serverTimestamp(), 'signatureUrl': sigUrl,
        'recipientName': _recipientNameController.text, 'recipientPhone': _recipientPhoneController.text,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) { debugPrint("Error: $e"); } finally { if (mounted) setState(() => _isCompleting = false); }
  }

  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response = await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) {} return null;
  }

  Future<Map<String, String>?> _uploadBytesToB2(Uint8List bytes, String name, String mime, Map<String, dynamic> creds) async {
    try {
      final sha1Hash = sha1.convert(bytes).toString();
      final resp = await http.post(Uri.parse(creds['uploadUrl']), headers: {
        'Authorization': creds['authorizationToken'], 'X-Bz-File-Name': Uri.encodeComponent(name),
        'Content-Type': mime, 'X-Bz-Content-Sha1': sha1Hash, 'Content-Length': bytes.length.toString()
      }, body: bytes);
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        return {'url': creds['downloadUrlPrefix'] + Uri.encodeComponent(body['fileName']), 'fileName': name};
      }
    } catch (e) {} return null;
  }

  // ===============================================================
  // 🎨 NEW HIGH-QUALITY UI WIDGETS
  // ===============================================================

  Widget _buildStatusTimeline() {
    int currentStep = 0;
    if (_status == 'En Cours de Livraison') currentStep = 1;
    if (_status == 'Livré') currentStep = 2;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTimelineStep(0, "Préparation", Icons.inventory_2, currentStep >= 0),
          _buildTimelineLine(currentStep >= 1),
          _buildTimelineStep(1, "En Route", Icons.local_shipping, currentStep >= 1),
          _buildTimelineLine(currentStep >= 2),
          _buildTimelineStep(2, "Livré", Icons.check_circle, currentStep >= 2),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(int stepIndex, String label, IconData icon, bool isActive) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? _primaryBlue : Colors.grey.shade300,
            boxShadow: isActive ? [BoxShadow(color: _primaryBlue.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)] : [],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? _primaryBlue : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20), // Align with circle center
        color: isActive ? _primaryBlue : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildWaybillCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          // Header of Card (Like a ticket)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryBlue.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("DESTINATAIRE", style: GoogleFonts.poppins(fontSize: 10, letterSpacing: 1.5, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(data['clientName'] ?? 'Client Inconnu', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.map, color: Colors.blueAccent),
                    onPressed: _launchMaps,
                    tooltip: "Ouvrir GPS",
                  ),
                )
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data['deliveryAddress'] ?? 'Adresse non spécifiée',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(top: 20, left: 4, right: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade700, Colors.deepPurple.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text("Livraison Externe", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                if (data['externalCarrierName'] != null)
                  Chip(
                    label: Text(data['externalCarrierName'], style: GoogleFonts.poppins(color: Colors.purple.shade900, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  )
              ],
            ),
            const SizedBox(height: 20),
            _buildWhiteInfoRow(Icons.person, data['externalClientName'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildWhiteInfoRow(Icons.phone, data['externalClientPhone'] ?? 'N/A', isLink: true),
            const SizedBox(height: 8),
            _buildWhiteInfoRow(Icons.location_on, data['externalClientAddress'] ?? 'N/A'),

            if (data['codAmount'] != null && (data['codAmount'] as num) > 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.payments, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "À ENCAISSER: ${data['codAmount']} DZD",
                      style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteInfoRow(IconData icon, String text, {bool isLink = false}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: isLink ? () => launchUrl(Uri.parse("tel:$text")) : null,
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                decoration: isLink ? TextDecoration.underline : null,
                decorationColor: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernProductCard(Map<String, dynamic> item, int index, {required bool isPicking}) {
    final int qty = item['quantity'] ?? 0;
    // ✅ ADDED: Picked Quantity Display
    final int pickedQty = item['pickedQuantity'] as int? ?? (item['quantity'] ?? 0);

    final bool isBulk = item['isBulk'] == true;
    int pickedCount = 0;
    bool isDone = false;

    if (isPicking) {
      pickedCount = isBulk ? (item['pickedQuantity'] as int? ?? 0) : (item['serialNumbers'] as List?)?.length ?? 0;
      isDone = pickedCount >= qty;
    } else {
      // ✅ CHANGED: Logic for Delivery Phase - Manual Check
      isDone = item['delivered'] == true;
    }

    final bool isSelected = _selectedPickingIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected ? Border.all(color: _primaryBlue, width: 2) : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: isDone ? _accentGreen.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Status Bar
            if (isDone)
              Container(height: 4, width: double.infinity, color: _accentGreen),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDone ? _accentGreen.withOpacity(0.1) : _primaryBlue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isBulk ? Icons.grain : Icons.qr_code_2,
                          color: isDone ? Colors.green : _primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['productName'] ?? 'Produit',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Réf: ${item['partNumber'] ?? 'N/A'}',
                              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                            ),
                            // ✅ ADDED: Quantity Information for Technician
                            if (!isPicking)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  // CHANGED: Only show quantity for delivery phase as requested
                                  'Quantité: $qty',
                                  style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isPicking)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "$pickedCount/$qty",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDone ? Colors.green : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // ✅ NEW: TOGGLE BUTTON FOR MODE SWITCHING
                            InkWell(
                              onTap: () => _toggleBulkMode(index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isBulk ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isBulk ? Colors.orange : Colors.blue, width: 1),
                                ),
                                child: Text(
                                  isBulk ? "MODE QUANTITÉ" : "MODE SCAN", // Toggle label
                                  style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: isBulk ? Colors.orange[800] : Colors.blue[800],
                                      fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                            )
                          ],
                        )
                      else
                      // Simple Check Icon for delivery phase status
                        Icon(isDone ? Icons.check_circle : Icons.circle_outlined, color: isDone ? Colors.green : Colors.grey.shade300)
                    ],
                  ),

                  // Actions & Inputs Area (PICKING PHASE ONLY)
                  if (isSelected && !isDone && isPicking) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    if (isBulk)
                    // ✅ MODE VRAC (MANUAL)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // ✏️ PENCIL BUTTON (Edit Quantity)
                          Column(
                            children: [
                              IconButton.filledTonal(
                                onPressed: () => _showBulkQuantityDialog(index),
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                style: IconButton.styleFrom(backgroundColor: Colors.blue.shade50),
                              ),
                              Text("Saisir", style: GoogleFonts.poppins(fontSize: 10, color: Colors.blue))
                            ],
                          ),

                          // 📦 Quantity Indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                            child: Text("VRAC", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey)),
                          ),

                          // ✅ CHECK BUTTON (Full Validate)
                          Column(
                            children: [
                              IconButton.filledTonal(
                                onPressed: () => _validateFullQuantity(index),
                                icon: const Icon(Icons.check, color: Colors.green),
                                style: IconButton.styleFrom(backgroundColor: Colors.green.shade50),
                              ),
                              Text("Tout", style: GoogleFonts.poppins(fontSize: 10, color: Colors.green))
                            ],
                          ),
                        ],
                      )
                    else
                    // 📸 MODE SCAN (Original)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pickingControllers[index],
                              focusNode: _pickingFocusNodes[index],
                              decoration: InputDecoration(
                                hintText: "Scanner N° Série...",
                                prefixIcon: const Icon(Icons.qr_code_scanner),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                              onSubmitted: (val) => _processInputScan(index, val),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FloatingActionButton.small(
                            heroTag: "cam_$index",
                            backgroundColor: _primaryBlue,
                            onPressed: () => _handlePickingScan(index),
                            child: const Icon(Icons.camera_alt, color: Colors.white),
                          )
                        ],
                      )
                  ],

                  // DELIVERY MODE INPUTS (TECHNICIAN)
                  if (!isPicking && !isDone) ...[
                    const SizedBox(height: 12),
                    // ✅ CHANGED: Removed Scanner Button, Replaced with "Confirm" Button for all types
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text("Confirmer Réception"),
                        onPressed: () => setState(() => item['delivered'] = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _primaryBlue,
                          side: BorderSide(color: _primaryBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    )
                  ],

                  // SERIAL LIST
                  if (!isBulk && (item['serialNumbers'] as List? ?? []).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: (item['serialNumbers'] as List).map<Widget>((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                          child: Text(s, style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w600)), // ✅ FIXED HERE
                        )).toList(),
                      ),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: _bgLight, body: Center(child: CircularProgressIndicator(color: _primaryBlue)));
    }
    if (_livraisonDoc == null) {
      return const Scaffold(body: Center(child: Text("Erreur de chargement")));
    }

    final data = _livraisonDoc!.data() as Map<String, dynamic>;

    return Scaffold(
      backgroundColor: _bgLight,
      extendBody: true, // For floating effect if needed
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          data['bonLivraisonCode'] ?? 'Détails',
          style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_isGeneratingPdf)
            Padding(padding: const EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _primaryBlue, strokeWidth: 2)))
          else
            IconButton(
              icon: Icon(Icons.picture_as_pdf_outlined, color: _primaryBlue),
              onPressed: _generateAndOpenPdf,
            ),
        ],
      ),
      bottomNavigationBar: (!_isLivraisonCompleted && !_isLoading) ? _buildStickyFooter() : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120), // Spacing for footer
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusTimeline(),
            _buildWaybillCard(data),

            if (data['deliveryMethod'] == 'Livraison Externe')
              _buildLogisticsCard(data),

            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _isPickingMode ? "LISTE DE PRÉPARATION" : "LISTE DE LIVRAISON",
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _isPickingMode
                  ? ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pickingItems.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () { if (_selectedPickingIndex != index) setState(() => _selectedPickingIndex = index); },
                    child: _buildModernProductCard(_pickingItems[index], index, isPicking: true),
                  );
                },
              )
                  : Column(
                children: [
                  if (_serializedItems.isNotEmpty) ...[
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: Text("Produits Sérialisés", style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                    ..._serializedItems.map((item) => _buildModernProductCard(item, 0, isPicking: false)).toList(),
                  ],
                  if (_bulkItems.isNotEmpty) ...[
                    Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text("Produits Vrac", style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                    ..._bulkItems.map((item) => _buildModernProductCard(item, 0, isPicking: false)).toList(),
                  ],
                  // SIGNATURE SECTION FOR DELIVERY
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Form(
                      key: _proofFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Preuve de Livraison", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _recipientNameController,
                            decoration: InputDecoration(
                              labelText: 'Nom du Réceptionnaire',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true, fillColor: Colors.grey.shade50,
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 180,
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12), color: Colors.grey.shade50),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Signature(controller: _signatureController, backgroundColor: Colors.transparent),
                            ),
                          ),
                          Center(
                            child: TextButton(
                              onPressed: () => _signatureController.clear(),
                              child: const Text("Effacer Signature"),
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewPadding.bottom + 20),
      child: SafeArea(
        top: false,
        child: _isCompleting
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 16),
            Text("Traitement en cours...", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600)),
          ],
        )
            : SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (_isPickingMode && !_allPicked) ? null : (_isPickingMode ? _validatePreparation : _completeLivraison),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isPickingMode ? Colors.orange.shade800 : _primaryBlue,
              elevation: 8,
              shadowColor: (_isPickingMode ? Colors.orange : _primaryBlue).withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              _isPickingMode ? "VALIDER PRÉPARATION" : "CONFIRMER LIVRAISON",
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
            ),
          ),
        ),
      ),
    );
  }
}
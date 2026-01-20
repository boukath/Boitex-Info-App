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

// ✅ STOCK SERVICE (Added for future logic)
import 'package:boitex_info_app/services/stock_service.dart';

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

  // ✅ NEW: Map to track SPLITS (Accepted vs Rejected per item)
  // Key: ProductId or Name
  // Value: { 'accepted': int, 'rejected': int, 'reason': String, 'note': String }
  final Map<String, Map<String, dynamic>> _itemSplits = {};

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

  List<dynamic> _existingMedia = [];
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

  final Color _primaryBlue = const Color(0xFF2962FF);
  final Color _accentGreen = const Color(0xFF00E676);
  final Color _bgLight = const Color(0xFFF4F6F9);

  // ✅ Helper to check if all items are picked (Preparation Phase)
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
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$_storeLat,$_storeLng?q=$_storeLat,$_storeLng");
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

            // ✅ RESTORE PARTIAL DELIVERY STATE
            // If we are in 'Livraison Partielle', we need to check which specific serials/quantities were already delivered
            final List deliveredSerials = product['deliveredSerials'] as List? ?? [];
            final int deliveredQuantity = product['deliveredQuantity'] as int? ?? 0;

            final String productName = product['productName'] ?? 'N/A';
            final String? partNumber = product['partNumber'];
            final String? productId = product['productId'];
            final List serials = product['serialNumbers'] as List? ?? [];
            final List serialsFound = product['serialNumbersFound'] as List? ?? [];

            // Determine if it's bulk or serialized logic
            bool isBulkItem = (quantity > 50) || (quantity > 5 && serials.isEmpty && serialsFound.isEmpty) || product['isBulk'] == true;

            if (pickedQuantity == 0 && serials.isNotEmpty) {
              pickedQuantity = serials.length;
            }

            if (isBulkItem) {
              String key = productId ?? productName;

              // ✅ FIX 1: UPDATE BULK ITEM LOGIC
              // Check if completed OR partial to show delivered quantity instead of ordered quantity
              if (!_itemSplits.containsKey(key)) {
                bool isPartialOrComplete = isCompleted || _status == 'Livraison Partielle';
                _itemSplits[key] = {
                  'accepted': isPartialOrComplete ? deliveredQuantity : quantity,
                  'rejected': isPartialOrComplete ? (quantity - deliveredQuantity) : 0,
                  'reason': 'N/A',
                  'note': ''
                };
              }

              if (bulkMap.containsKey(key)) {
                bulkMap[key]!['quantity'] = (bulkMap[key]!['quantity'] as int) + quantity;
                bulkMap[key]!['pickedQuantity'] = (bulkMap[key]!['pickedQuantity'] as int) + pickedQuantity;
                // Accumulate delivered quantity for bulk logic
              } else {
                bulkMap[key] = {
                  'productName': productName,
                  'partNumber': partNumber,
                  'quantity': quantity,
                  'pickedQuantity': pickedQuantity,
                  'delivered': isCompleted || (deliveredQuantity >= quantity), // Auto-check if full quantity delivered
                  'type': 'bulk',
                  'isBulk': true, // ✅ FIXED: Explicitly set isBulk to true for display logic
                  'productId': productId,
                  'deliveredQuantity': deliveredQuantity, // Track for saving
                };
              }
            } else {
              // Serialized: Create an entry for each picked item
              int itemsToAdd = serials.isNotEmpty ? serials.length : quantity;
              if (serials.isEmpty && pickedQuantity > 0) itemsToAdd = pickedQuantity;

              for (int i = 0; i < itemsToAdd; i++) {
                final serialNumber = (i < serialsFound.length) ? serialsFound[i] : (i < serials.length ? serials[i] : null);

                // ✅ FIX 2: UPDATE SERIALIZED ITEM LOGIC
                // Check if specific serial was delivered in partial status
                bool wasDelivered = isCompleted;
                if (!wasDelivered && _status == 'Livraison Partielle' && serialNumber != null) {
                  wasDelivered = deliveredSerials.contains(serialNumber);
                }

                serializedList.add({
                  'productName': productName,
                  'partNumber': partNumber,
                  'serialNumber': serialNumber,
                  'originalSerialNumber': (i < serials.length) ? serials[i] : null,
                  'delivered': wasDelivered,
                  'type': 'serialized',
                  'isBulk': false, // ✅ FIXED: Explicitly set isBulk to false for display logic
                  'productId': productId,
                  'quantity': 1,
                  'pickedQuantity': 1,
                  'parentProductIndex': rawProducts.indexOf(product), // Track parent to update later
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
        // Logic to reconstruct PDF items based on what is CURRENTLY showing (Delivery Note)
        final Map<String, Map<String, dynamic>> groupedMap = {};
        for (var item in _serializedItems) {
          final key = item['partNumber'] ?? item['productName'];
          if (!groupedMap.containsKey(key)) {
            groupedMap[key] = {'productId': item['productId'], 'productName': item['productName'], 'partNumber': item['partNumber'], 'marque': item['marque'] ?? 'N/A', 'quantity': 0, 'serialNumbers': <String>[]};
          }
          // Only add if accepted
          if (item['delivered'] == true) {
            groupedMap[key]!['quantity'] = (groupedMap[key]!['quantity'] as int) + 1;
            final sn = item['serialNumber'] ?? item['originalSerialNumber'];
            if (sn != null) (groupedMap[key]!['serialNumbers'] as List<String>).add(sn);
          }
        }
        for (var item in _bulkItems) {
          final key = item['partNumber'] ?? item['productName'];
          final mapKey = item['productId'] ?? item['productName'];
          if (!groupedMap.containsKey(key)) {
            groupedMap[key] = {'productId': item['productId'], 'productName': item['productName'], 'partNumber': item['partNumber'], 'marque': item['marque'] ?? 'N/A', 'quantity': 0, 'serialNumbers': <String>[]};
          }

          // ✅ PDF GENERATION: Use the Split Accepted Quantity
          int quantityToPrint = item['quantity'];
          if (_itemSplits.containsKey(mapKey)) {
            quantityToPrint = _itemSplits[mapKey]!['accepted'];
          } else if (item['delivered'] != true) {
            quantityToPrint = 0; // If unchecked and no split, it's 0
          }

          if (quantityToPrint > 0) {
            groupedMap[key]!['quantity'] = (groupedMap[key]!['quantity'] as int) + quantityToPrint;
          }
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

  // ✅ SIMPLIFIED DIALOG: "Silent Edit" (Only Quantity)
  // No logic checks here. Just captures the new number. Logic happens at the end.
  void _showDeliveryQuantityDialog(String key, int maxQty, int currentQty) {
    final TextEditingController qtyCtrl = TextEditingController(text: currentQty.toString());

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Quantité Reçue"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Commande Initiale: $maxQty", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: "Quantité Acceptée",
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.edit)
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
              ElevatedButton(
                onPressed: () {
                  int? inputVal = int.tryParse(qtyCtrl.text);
                  if (inputVal != null) {
                    // ✅ FIX: Use a definite int type for math operations
                    int safeVal = inputVal;
                    if (safeVal > maxQty) safeVal = maxQty;
                    if (safeVal < 0) safeVal = 0;

                    // Silent Save: Just update state, no questions asked.
                    setState(() {
                      _itemSplits[key] = {
                        'accepted': safeVal,
                        'rejected': maxQty - safeVal, // Now safe (int - int)
                        'reason': 'N/A', // Will be filled in "Batch Resolution"
                        'note': ''
                      };
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text("Valider"),
              )
            ],
          );
        }
    );
  }

  // ✅ NEW HELPER: Calculate Discrepancies
  List<Map<String, dynamic>> _calculateDiscrepancies() {
    List<Map<String, dynamic>> problems = [];

    // 1. Check Bulk Items
    for (var item in _bulkItems) {
      final key = item['productId'] ?? item['productName'];
      int ordered = item['quantity'] ?? 0;
      int accepted = ordered;
      bool isChecked = item['delivered'] == true;

      // Has user edited quantity?
      if (_itemSplits.containsKey(key)) {
        accepted = _itemSplits[key]!['accepted'];
      } else if (!isChecked) {
        // Unchecked = 0 Accepted
        accepted = 0;
      }

      if (accepted < ordered) {
        problems.add({
          'key': key,
          'name': item['productName'],
          'ordered': ordered,
          'accepted': accepted,
          'missing': ordered - accepted,
          'productId': item['productId'],
          'type': 'bulk'
        });
      }
    }

    // 2. Check Serialized Items (Simplified: Group by product for easier reasoning)
    // If a serialized item is unchecked, it counts as missing
    Map<String, int> serializedMissingCounts = {};
    Map<String, String> serializedNames = {};

    for (var item in _serializedItems) {
      if (item['delivered'] != true) {
        final key = item['productId'] ?? item['productName'];
        serializedMissingCounts[key] = (serializedMissingCounts[key] ?? 0) + 1;
        serializedNames[key] = item['productName'];
      }
    }

    serializedMissingCounts.forEach((key, count) {
      problems.add({
        'key': key,
        'name': serializedNames[key],
        'ordered': count, // In this context "ordered" is just the missing batch size for display
        'accepted': 0, // These are fully missing lines
        'missing': count,
        'productId': key, // ID is key
        'type': 'serialized'
      });
    });

    return problems;
  }

  // ✅ NEW DIALOG: "Batch Resolution Dashboard" (The One Pop-up)
  Future<void> _showBatchResolutionDialog(List<Map<String, dynamic>> problems) async {
    // Local state controller for the dialog
    final Map<String, String> reasons = {}; // key -> reason
    final Map<String, String> notes = {};   // key -> note

    bool allResolved() {
      // Check if every problem has a selected reason
      return problems.every((p) => reasons.containsKey(p['key']) && reasons[p['key']] != null);
    }

    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Row(
                    children: [
                      const Icon(Icons.assignment_late, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text("Rapport d'Anomalies"),
                    ],
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: problems.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (context, index) {
                        final problem = problems[index];
                        final String key = problem['key'];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                problem['name'],
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                      "-${problem['missing']}",
                                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Non Livré / Manquant",
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(),
                                labelText: "Motif",
                              ),
                              items: ["Produit Endommagé", "Refus Client", "Produit Manquant", "Erreur Commande"]
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: (val) {
                                setDialogState(() {
                                  reasons[key] = val!;
                                });
                              },
                            ),
                            if (reasons.containsKey(key))
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: TextField(
                                  decoration: const InputDecoration(
                                      isDense: true,
                                      labelText: "Note (Facultatif)",
                                      border: OutlineInputBorder()
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                  onChanged: (val) => notes[key] = val,
                                ),
                              )
                          ],
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Annuler", style: TextStyle(color: Colors.grey))
                    ),
                    ElevatedButton(
                      onPressed: allResolved() ? () {
                        // SAVE DECISIONS TO MAIN STATE
                        setState(() {
                          for (var p in problems) {
                            String k = p['key'];
                            // Update _itemSplits with the FINAL reason
                            _itemSplits[k] = {
                              'accepted': p['accepted'],
                              'rejected': p['missing'],
                              'reason': reasons[k],
                              'note': notes[k] ?? ''
                            };
                          }
                        });
                        Navigator.pop(context, true); // Signal Success
                      } : null, // Disable until valid
                      style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue),
                      child: const Text("CONFIRMER TOUT"),
                    )
                  ],
                );
              }
          );
        }
    ).then((result) {
      if (result == true) {
        // If confirmed, proceed to final save
        _finalizeFullDeliveryWithSplits();
      }
    });
  }

  // ✅ MAIN ACTION: Complete Delivery
  Future<void> _completeLivraison() async {
    if (_isLivraisonCompleted) return;

    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La signature est obligatoire.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (_proofFormKey.currentState != null && !_proofFormKey.currentState!.validate()) return;

    // 1. CALCULATE DISCREPANCIES (Silent Audit)
    final problems = _calculateDiscrepancies();

    if (problems.isNotEmpty) {
      // ⚠️ Found issues? Show the Batch Resolution Dashboard
      await _showBatchResolutionDialog(problems);
    } else {
      // ✅ Clean delivery? Save immediately (Happy Path)
      await _finalizeFullDeliveryWithSplits();
    }
  }

  // ✅ LOGIC: Finalize with In-Line Splits
  // This is now the ONLY save function. It handles both full and partial because
  // the Batch Dialog has already filled _itemSplits with the reasons.
  Future<void> _finalizeFullDeliveryWithSplits() async {
    setState(() => _isCompleting = true);

    // Determine status: If any item was rejected, it's technically "Partiel" or "Livré avec réserves"
    // For simplicity, we can check if _itemSplits has any rejections
    bool hasRejections = _itemSplits.values.any((v) => (v['rejected'] ?? 0) > 0);
    String finalStatus = hasRejections ? "Livraison Partielle" : "Livré";

    try {
      String? sigUrl = await _uploadSignature();
      final user = FirebaseAuth.instance.currentUser;

      final doc = await FirebaseFirestore.instance.collection('livraisons').doc(widget.livraisonId).get();
      List<dynamic> currentProducts = List.from(doc.get('products') ?? []);
      List<dynamic> updatedProducts = [];
      List<Map<String, dynamic>> newEvents = [];

      // ✅ NEW: COLLECT ACCEPTED ITEMS FOR STOCK DEDUCTION
      List<Map<String, dynamic>> acceptedItemsForStock = [];

      for (var product in currentProducts) {
        Map<String, dynamic> p = Map<String, dynamic>.from(product);
        final key = p['productId'] ?? p['productName'];
        int deliveredQuantity = 0;

        // Logic to sync with _itemSplits
        if (_itemSplits.containsKey(key)) {
          // Apply Split Data
          int accepted = _itemSplits[key]!['accepted'];
          int rejected = _itemSplits[key]!['rejected'];
          String reason = _itemSplits[key]!['reason'] ?? 'Autre';
          String note = _itemSplits[key]!['note'] ?? '';

          p['deliveredQuantity'] = accepted;
          deliveredQuantity = accepted;

          // HANDLE STOCK RETURN LOGIC (BROKEN ONLY)
          // ⚠️ CHANGED: No more 'restockFromPartialDelivery' because stock wasn't deducted yet.
          // Only 'moveToBrokenStock' applies if item is damaged, effectively moving it from Healthy -> Defective.
          if (rejected > 0 && p['productId'] != null) {
            if (reason == "Produit Endommagé") {
              // Moves from Healthy -> Defective
              await StockService().moveToBrokenStock(
                  p['productId'], rejected, productName: p['productName'], deliveryId: widget.livraisonId, reason: "$reason $note"
              );
            }
            // If reason is "Refus Client" (non-broken) or "Erreur Commande",
            // we simply DO NOTHING to the stock. It stays in stock naturally because we won't deduct it below.

            // Log Event
            newEvents.add({
              'event': 'item_rejected',
              'product': p['productName'],
              'qty': rejected,
              'reason': reason,
              'note': note,
              'timestamp': Timestamp.now()
            });
          }
        } else {
          // If not in splits, it means it was fully accepted (Happy Path Logic)
          p['deliveredQuantity'] = p['quantity'];
          deliveredQuantity = p['quantity'];
        }

        if (p['serialNumbers'] != null && (p['serialNumbers'] as List).isNotEmpty) {
          int qty = p['deliveredQuantity'] ?? 0;
          List<String> sns = List<String>.from(p['serialNumbers']);
          p['deliveredSerials'] = sns.take(qty).toList();
        }

        updatedProducts.add(p);

        // ✅ PREPARE FOR STOCK DEDUCTION
        if (deliveredQuantity > 0 && p['productId'] != null) {
          acceptedItemsForStock.add({
            'productId': p['productId'],
            'productName': p['productName'],
            'deliveredQuantity': deliveredQuantity
          });
        }
      }

      // ✅ EXECUTE STOCK DEDUCTION (The New "Exit Point")
      if (acceptedItemsForStock.isNotEmpty) {
        await StockService().confirmDeliveryStockOut(
            deliveryId: widget.livraisonId,
            products: acceptedItemsForStock
        );
      }

      // Prepare Update Data
      Map<String, dynamic> updateData = {
        'status': finalStatus,
        'completedAt': FieldValue.serverTimestamp(),
        'signatureUrl': sigUrl,
        'recipientName': _recipientNameController.text,
        'recipientPhone': _recipientPhoneController.text,
        'products': updatedProducts,
      };

      if (hasRejections) {
        updateData['lastPartialDeliveryAt'] = FieldValue.serverTimestamp();
      }

      // Update Firestore
      await FirebaseFirestore.instance.collection('livraisons').doc(widget.livraisonId).update(updateData);

      // Add Events if any
      if (newEvents.isNotEmpty) {
        await FirebaseFirestore.instance.collection('livraisons').doc(widget.livraisonId).update({
          'deliveryEvents': FieldValue.arrayUnion(newEvents)
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(hasRejections ? "Livraison partielle enregistrée avec succès." : "Livraison terminée avec succès."),
          backgroundColor: hasRejections ? Colors.orange : Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
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
    // ⚠️ CHANGED: No stock transaction here anymore!
    // Just update status and picked items.
    try {
      final livraisonRef = FirebaseFirestore.instance.collection('livraisons').doc(widget.livraisonId);
      await livraisonRef.update({
        'status': 'En Cours de Livraison',
        'preparedAt': FieldValue.serverTimestamp(),
        'products': _pickingItems
      });
      if (mounted) _loadLivraisonDetails();
    } catch (e) { debugPrint("Error: $e"); } finally { if (mounted) setState(() => _isCompleting = false); }
  }

  Future<String?> _uploadSignature() async {
    if (_signatureController.isEmpty) return null;
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
  // 🎨 UI WIDGETS
  // ===============================================================

  Widget _buildStatusTimeline() {
    int currentStep = 0;
    if (_status == 'En Cours de Livraison') currentStep = 1;
    if (_status == 'Livraison Partielle') currentStep = 1;
    if (_status == 'Livré') currentStep = 2;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTimelineStep(0, "Préparation", Icons.inventory_2, currentStep >= 0),
          _buildTimelineLine(currentStep >= 1),
          _buildTimelineStep(1, _status == 'Livraison Partielle' ? "Partiel" : "En Route",
              _status == 'Livraison Partielle' ? Icons.warning_amber : Icons.local_shipping, currentStep >= 1,
              isWarning: _status == 'Livraison Partielle'),
          _buildTimelineLine(currentStep >= 2),
          _buildTimelineStep(2, "Livré", Icons.check_circle, currentStep >= 2),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(int stepIndex, String label, IconData icon, bool isActive, {bool isWarning = false}) {
    Color color = isActive ? (isWarning ? Colors.orange : _primaryBlue) : Colors.grey.shade300;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)] : [],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? (isWarning ? Colors.orange : _primaryBlue) : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
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

    // ✅ DELIVERY: Read from _itemSplits if available, else default to Qty
    int deliveredDisplayQty = qty;
    bool hasDiscrepancy = false;

    if (!isPicking) {
      final key = item['productId'] ?? item['productName'];
      if (_itemSplits.containsKey(key)) {
        deliveredDisplayQty = _itemSplits[key]!['accepted'] ?? qty;
        hasDiscrepancy = deliveredDisplayQty < qty;
      }
    }

    // Status logic
    bool isDone = false;
    int pickedCount = 0;
    if (isPicking) {
      pickedCount = (item['isBulk'] == true) ? (item['pickedQuantity'] as int? ?? 0) : (item['serialNumbers'] as List?)?.length ?? 0;
      isDone = pickedCount >= qty;
    } else {
      isDone = item['delivered'] == true;
    }

    final bool isSelected = _selectedPickingIndex == index;
    final bool isBulk = item['isBulk'] == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: hasDiscrepancy ? Colors.orange.shade50 : Colors.white, // ✅ AMBER BG FOR DISCREPANCY
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: _primaryBlue, width: 2)
            : (hasDiscrepancy ? Border.all(color: Colors.orange.shade300) : Border.all(color: Colors.transparent)),
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
            if (isDone)
              Container(height: 4, width: double.infinity, color: hasDiscrepancy ? Colors.orange : _accentGreen),

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
                          color: isDone ? (hasDiscrepancy ? Colors.orange.withOpacity(0.1) : _accentGreen.withOpacity(0.1)) : _primaryBlue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isBulk ? Icons.grain : Icons.qr_code_2,
                          color: isDone ? (hasDiscrepancy ? Colors.orange : Colors.green) : _primaryBlue,
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
                            if (!isPicking)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: isBulk
                                    ? Row(
                                  children: [
                                    Text('Cmd: $qty', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    SizedBox(width: 8),
                                    Text('Accepté: $deliveredDisplayQty', style: TextStyle(
                                        color: hasDiscrepancy ? Colors.deepOrange : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                  ],
                                )
                                    : Text(
                                  'SN: ${item['serialNumber'] ?? 'N/A'}',
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
                                  isBulk ? "MODE QUANTITÉ" : "MODE SCAN",
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
                      // ✅ DELIVERY MODE ACTIONS
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Allow edit for both Bulk and Serialized (if serialized is rejected)
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blueGrey, size: 20),
                              onPressed: () {
                                final key = item['productId'] ?? item['productName'];
                                // For serialized, maxQty is 1. For bulk, it's qty.
                                _showDeliveryQuantityDialog(key, qty, deliveredDisplayQty);
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                  isDone ? Icons.check_box : Icons.check_box_outline_blank,
                                  color: isDone ? Colors.green : Colors.grey
                              ),
                              onPressed: () {
                                setState(() {
                                  item['delivered'] = !isDone;
                                });
                              },
                            ),
                          ],
                        )
                    ],
                  ),

                  // Actions & Inputs Area (PICKING PHASE ONLY)
                  if (isSelected && !isDone && isPicking) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    if (isBulk)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                            child: Text("VRAC", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey)),
                          ),
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
                          child: Text(s, style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w600)),
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
      extendBody: true,
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
        padding: const EdgeInsets.only(bottom: 120),
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
            // ✅ Removed blocking logic to allow partial submission
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
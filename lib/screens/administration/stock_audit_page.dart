// lib/screens/administration/stock_audit_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for HapticFeedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:boitex_info_app/services/stock_audit_pdf_service.dart';
import 'package:boitex_info_app/services/stock_audit_csv_service.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_saver/file_saver.dart';

import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';
// ✅ IMPORT LIVRAISON DETAILS PAGE
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';

class StockAuditPage extends StatefulWidget {
  const StockAuditPage({super.key});

  @override
  State<StockAuditPage> createState() => _StockAuditPageState();
}

class _StockAuditPageState extends State<StockAuditPage>
    with TickerProviderStateMixin {

  // Date States
  DateTime? _startDate;
  DateTime? _endDate;

  // FILTER STATE VARIABLES
  final _searchKeywordController = TextEditingController();
  String _filterProduct = '';
  String _filterClient = '';
  String _filterStore = '';
  String _filterSupplier = '';
  String _filterUser = '';

  // Autocomplete Options
  List<String> _productOptions = [];
  List<String> _clientOptions = [];
  List<String> _storeOptions = [];
  List<String> _supplierOptions = [];
  List<String> _userOptions = [];

  // Query State
  bool _isLoading = false;
  bool _isExportingPdf = false;
  bool _isExportingCsv = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _movements = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredMovements = [];

  Map<String, String> _userNamesMap = {};

  // Store the FULL product data to access 'marque' (Fournisseur)
  Map<String, Map<String, dynamic>> _fullProductCatalog = {};

  // Animation Controllers for smooth transitions
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _searchKeywordController.addListener(_applyClientFilters);
    _fetchAutocompleteOptions();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _searchKeywordController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // ⚙️ LOGIC & DATA FETCHING
  // ===========================================================================

  Future<void> _fetchAutocompleteOptions() async {
    try {
      final db = FirebaseFirestore.instance;

      final productsSnap = await db.collection('produits').get();
      _productOptions = productsSnap.docs.map((d) {
        final data = d.data();
        return "${data['name'] ?? data['productName'] ?? ''} ${data['reference'] ?? ''}".trim();
      }).where((s) => s.isNotEmpty).toSet().toList()..sort();

      final clientsSnap = await db.collection('clients').get();
      final Set<String> clientSet = {};
      final Set<String> storeSet = {};

      for (var doc in clientsSnap.docs) {
        final data = doc.data();

        final cName = (data['name'] ?? data['nom'] ?? data['clientName'] ?? '').toString().trim();
        if (cName.isNotEmpty) clientSet.add(cName);

        if (data['brands'] is List) {
          for (var brand in data['brands']) {
            final bName = brand.toString().trim();
            if (bName.isNotEmpty) storeSet.add(bName);
          }
        }
      }

      final storesSnap = await db.collection('stores').get();
      for (var doc in storesSnap.docs) {
        final data = doc.data();
        final sName = (data['name'] ?? data['nom'] ?? data['storeName'] ?? '').toString().trim();
        if (sName.isNotEmpty) storeSet.add(sName);
      }

      _clientOptions = clientSet.toList()..sort();
      _storeOptions = storeSet.toList()..sort();

      final supplierSnap = await db.collection('marque').get();
      _supplierOptions = supplierSnap.docs.map((d) {
        final data = d.data();
        return (data['name'] ?? data['nom'] ?? data['marque'] ?? '').toString().trim();
      }).where((s) => s.isNotEmpty).toSet().toList()..sort();

      final usersSnap = await db.collection('users').get();
      _userOptions = usersSnap.docs.map((d) {
        final data = d.data();
        return (data['fullName'] ?? data['name'] ?? '').toString().trim();
      }).where((s) => s.isNotEmpty).toSet().toList()..sort();

      if (mounted) setState(() {});
    } catch (e) {
      print("Error fetching autocomplete options: $e");
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchProductCatalog() async {
    final snapshot = await FirebaseFirestore.instance.collection('produits').get();
    final Map<String, Map<String, dynamic>> catalog = {};
    for (var doc in snapshot.docs) {
      catalog[doc.id] = doc.data();
    }
    return catalog;
  }

  Future<void> _runQuery() async {
    if (_isLoading) return;
    if (_startDate == null && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner au moins une date.')));
      return;
    }

    setState(() {
      _isLoading = true;
      _movements = [];
      _filteredMovements = [];
      _userNamesMap = {};
      _fullProductCatalog = {};
    });

    try {
      final catalogFuture = _fetchProductCatalog();
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('stock_movements').orderBy('timestamp', descending: true);

      if (_startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: _startDate);
      }
      if (_endDate != null) {
        final inclusiveEndDate = _endDate!.add(const Duration(days: 1));
        query = query.where('timestamp', isLessThanOrEqualTo: inclusiveEndDate);
      }

      final snapshot = await query.get();
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> movements = snapshot.docs;

      Map<String, String> fetchedNames = {};
      if (movements.isNotEmpty) {
        final Set<String> userIds = movements.map((doc) => (doc.data()['userId'] ?? '').toString()).where((id) => id.isNotEmpty).toSet();

        if (userIds.isNotEmpty) {
          final List<String> userIdList = userIds.toList();
          for (int i = 0; i < userIdList.length; i += 30) {
            final batch = userIdList.skip(i).take(30).toList();
            if (batch.isEmpty) continue;
            final userSnapshot = await FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: batch).get();
            for (final userDoc in userSnapshot.docs) {
              fetchedNames[userDoc.id] = userDoc.data()?['fullName'] ?? 'Utilisateur Inconnu';
            }
          }
        }
      }

      final fullCatalog = await catalogFuture;

      setState(() {
        _movements = movements;
        _userNamesMap = fetchedNames;
        _fullProductCatalog = fullCatalog;
        _applyClientFilters();
      });

      if (_movements.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun mouvement trouvé pour cette période.')));
      } else {
        _scaleController..reset()..forward();
      }
    } catch (e) {
      print("Error running query: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _applyClientFilters() {
    final searchKeyword = _searchKeywordController.text.toLowerCase().trim();

    List<QueryDocumentSnapshot<Map<String, dynamic>>> results = List.from(_movements);

    results = results.where((doc) {
      final data = doc.data();

      final String productId = (data['productId'] ?? '').toString();
      final Map<String, dynamic> productDoc = _fullProductCatalog[productId] ?? {};

      final String productName = (data['productName'] ?? productDoc['name'] ?? productDoc['productName'] ?? '').toString().toLowerCase();
      final String productRef = (data['productRef'] ?? productDoc['reference'] ?? '').toString().toLowerCase();
      final String supplier = (productDoc['marque'] ?? productDoc['fournisseur'] ?? data['supplier'] ?? '').toString().toLowerCase();

      final String userId = (data['userId'] ?? '').toString();
      final String user = (_userNamesMap[userId] ?? data['user'] ?? '').toString().toLowerCase();

      final String clientName = (data['clientName'] ?? data['client'] ?? '').toString().toLowerCase();
      final String storeName = (data['storeName'] ?? data['store'] ?? data['magasin'] ?? '').toString().toLowerCase();
      final String notes = (data['notes'] ?? data['reason'] ?? '').toString().toLowerCase();

      final String productSearchText = "$productName $productRef $notes";
      final String clientSearchText = "$clientName $storeName $notes";
      final String storeSearchText = "$storeName $clientName $notes";
      final String supplierSearchText = "$supplier $notes";

      bool matchesKeywords(String text, String query) {
        if (query.isEmpty) return true;
        final keywords = query.toLowerCase().trim().split(' ');
        for (final kw in keywords) {
          if (kw.isNotEmpty && !text.contains(kw)) return false;
        }
        return true;
      }

      if (!matchesKeywords(productSearchText, _filterProduct)) return false;
      if (!matchesKeywords(clientSearchText, _filterClient)) return false;
      if (!matchesKeywords(storeSearchText, _filterStore)) return false;
      if (!matchesKeywords(supplierSearchText, _filterSupplier)) return false;
      if (!matchesKeywords(user, _filterUser)) return false;

      final String globalSearchText = "$productSearchText $clientSearchText $supplierSearchText $user";
      if (searchKeyword.isNotEmpty && !matchesKeywords(globalSearchText, searchKeyword)) {
        return false;
      }

      return true;
    }).toList();

    setState(() { _filteredMovements = results; });
  }

  Map<String, String> get _simpleProductCatalogForPdf {
    return _fullProductCatalog.map((k, v) => MapEntry(k, (v['reference'] ?? '').toString()));
  }

  // ✅ NEW: NAVIGATION LOGIC TO LIVRAISON DETAILS
  Future<void> _handleBLNavigation(Map<String, dynamic> data) async {
    // 1. Easiest Route: If deliveryId is explicitly saved in the stock movement
    String? deliveryId = data['deliveryId'] ?? data['livraisonId'];

    if (deliveryId != null && deliveryId.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => LivraisonDetailsPage(livraisonId: deliveryId),
      ));
      return;
    }

    // 2. Fallback Route: Try to extract BL code from notes (e.g., "Sortie BL-95/2026" or "BL 95")
    final notes = (data['notes'] ?? '').toString();
    // Regex matches "BL-123/2026", "BL 123", "BL123"
    final RegExp blRegExp = RegExp(r'BL\s*-?\s*\d+(/\d+)?', caseSensitive: false);
    final match = blRegExp.firstMatch(notes);

    if (match != null) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

      try {
        // Normalize the string to match database standard (e.g. "BL-95/2026")
        String blCode = match.group(0)!.toUpperCase().replaceAll(' ', '');
        if (!blCode.contains('-')) {
          blCode = blCode.replaceFirst('BL', 'BL-');
        }

        final snap = await FirebaseFirestore.instance
            .collection('livraisons')
            .where('bonLivraisonCode', isEqualTo: blCode)
            .limit(1)
            .get();

        Navigator.pop(context); // close dialog

        if (snap.docs.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => LivraisonDetailsPage(livraisonId: snap.docs.first.id),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de trouver ce Bon de Livraison.')));
        }
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun code BL valide trouvé dans les notes.')));
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime initial = (isStartDate ? _startDate : _endDate) ?? DateTime.now();
    final DateTime first = DateTime(2020);
    final DateTime last = DateTime.now().add(const Duration(days: 1));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue.shade700),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _exportToPdf() async {
    if (_isExportingPdf || _isExportingCsv || _filteredMovements.isEmpty) return;
    setState(() { _isExportingPdf = true; });

    try {
      final pdfService = StockAuditPdfService();
      final Uint8List pdfData = await pdfService.generateAuditPdf(
        _filteredMovements,
        _startDate,
        _endDate,
        _userNamesMap,
        _simpleProductCatalogForPdf,
        "Audit Global des Mouvements",
      );

      final String fileName = 'audit_rapport_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        await FileSaver.instance.saveFile(name: fileName, bytes: pdfData, mimeType: MimeType.pdf);
      } else {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => PdfViewerPage(pdfBytes: pdfData, title: fileName)));
      }
    } catch (e) {
      print("Error exporting PDF: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la création du PDF: $e')));
    } finally {
      if (mounted) setState(() { _isExportingPdf = false; });
    }
  }

  Future<void> _exportToCsv() async {
    if (_isExportingPdf || _isExportingCsv || _filteredMovements.isEmpty) return;
    setState(() { _isExportingCsv = true; });

    try {
      final csvService = StockAuditCsvService();
      final String csvData = await csvService.generateAuditCsv(_filteredMovements, _userNamesMap);
      final String fileName = 'audit_mouvements_${DateTime.now().millisecondsSinceEpoch}.csv';

      if (kIsWeb) {
        final bytes = utf8.encode(csvData);
        await FileSaver.instance.saveFile(name: fileName, bytes: bytes, mimeType: MimeType.csv);
      } else {
        final Directory tempDir = await getTemporaryDirectory();
        final String filePath = '${tempDir.path}/$fileName';
        final File file = File(filePath);
        await file.writeAsString(csvData, encoding: utf8);
        final xFile = XFile(filePath, mimeType: 'text/csv', name: fileName);
        await Share.shareXFiles([xFile], subject: 'Export Audit Mouvements de Stock');
      }
    } catch (e) {
      print("Error exporting CSV: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la création du CSV: $e')));
    } finally {
      if (mounted) setState(() { _isExportingCsv = false; });
    }
  }

  // ===========================================================================
  // 💎 PREMIUM UI BUILDER
  // ===========================================================================

  bool get _hasActiveFilters => _filterProduct.isNotEmpty || _filterClient.isNotEmpty || _filterStore.isNotEmpty || _filterSupplier.isNotEmpty || _filterUser.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text("Audit des Mouvements", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildPremiumFilterSection(),

                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
                    ),
                  )
                else
                  Expanded(
                    child: _buildResultsList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    final productCtrl = TextEditingController(text: _filterProduct);
    final clientCtrl = TextEditingController(text: _filterClient);
    final storeCtrl = TextEditingController(text: _filterStore);
    final supplierCtrl = TextEditingController(text: _filterSupplier);
    final userCtrl = TextEditingController(text: _filterUser);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 40, spreadRadius: 0, offset: Offset(0, -10))]
              ),
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48, height: 5,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Filtres Intelligents", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Colors.black87)),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _filterProduct = ''; _filterClient = ''; _filterStore = '';
                              _filterSupplier = ''; _filterUser = '';
                              _applyClientFilters();
                            });
                            Navigator.pop(context);
                          },
                          child: Text("Réinitialiser", style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSmartFilterField("Produit (Nom ou Réf)", Icons.inventory_2_rounded, productCtrl, _productOptions),
                    _buildSmartFilterField("Fournisseur (Marque)", Icons.local_shipping_rounded, supplierCtrl, _supplierOptions),
                    _buildSmartFilterField("Technicien / Utilisateur", Icons.person_rounded, userCtrl, _userOptions),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text("Client et Magasin recherchent uniquement dans les notes", style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                          ),
                        ],
                      ),
                    ),
                    _buildSmartFilterField("Client", Icons.business_rounded, clientCtrl, _clientOptions),
                    _buildSmartFilterField("Magasin (Brand)", Icons.storefront_rounded, storeCtrl, _storeOptions),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          setState(() {
                            _filterProduct = productCtrl.text.trim();
                            _filterClient = clientCtrl.text.trim();
                            _filterStore = storeCtrl.text.trim();
                            _filterSupplier = supplierCtrl.text.trim();
                            _filterUser = userCtrl.text.trim();
                            _applyClientFilters();
                          });
                          Navigator.pop(context);
                        },
                        child: Text("Appliquer les Filtres", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmartFilterField(String label, IconData icon, TextEditingController controller, List<String> options) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: controller.text),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<String>.empty();
          }
          return options.where((String option) {
            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
          });
        },
        onSelected: (String selection) {
          controller.text = selection;
        },
        fieldViewBuilder: (context, fieldTextEditingController, focusNode, onFieldSubmitted) {
          fieldTextEditingController.addListener(() {
            controller.text = fieldTextEditingController.text;
          });

          return TextField(
            controller: fieldTextEditingController,
            focusNode: focusNode,
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 22),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8.0,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: 220,
                    maxWidth: MediaQuery.of(context).size.width > 800 ? 750 : MediaQuery.of(context).size.width - 48
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade100))
                        ),
                        child: Text(option, style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumFilterSection() {
    final DateFormat formatter = DateFormat('dd MMM yyyy', 'fr_FR');
    final bool canExport = !_isLoading && !_isExportingPdf && !_isExportingCsv && _filteredMovements.isNotEmpty;
    final bool canFilter = !_isLoading && !_isExportingPdf && !_isExportingCsv;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))
          ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      children: [
                        Icon(Icons.date_range_rounded, size: 18, color: Colors.blue.shade600),
                        const SizedBox(width: 12),
                        Text(_startDate == null ? 'Date de début' : formatter.format(_startDate!), style: GoogleFonts.poppins(fontSize: 14, color: _startDate == null ? Colors.grey.shade500 : Colors.black87, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      children: [
                        Icon(Icons.date_range_rounded, size: 18, color: Colors.blue.shade600),
                        const SizedBox(width: 12),
                        Text(_endDate == null ? 'Date de fin' : formatter.format(_endDate!), style: GoogleFonts.poppins(fontSize: 14, color: _endDate == null ? Colors.grey.shade500 : Colors.black87, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchKeywordController,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Recherche globale (Notes, Produit...)',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _showFilterDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _hasActiveFilters ? Colors.blue.shade700 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _hasActiveFilters ? Colors.blue.shade700 : Colors.grey.shade200),
                  ),
                  child: Icon(
                    _hasActiveFilters ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                    color: _hasActiveFilters ? Colors.white : Colors.grey.shade600,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_download_rounded, size: 20),
                  label: Text('Charger les données', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  onPressed: canFilter ? _runQuery : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isExportingPdf
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text('PDF', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  onPressed: canExport ? _exportToPdf : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isExportingCsv
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.table_chart_rounded, size: 18),
                  label: Text('CSV', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  onPressed: canExport ? _exportToCsv : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_filteredMovements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
              child: Icon(Icons.analytics_outlined, size: 64, color: Colors.blue.shade100),
            ),
            const SizedBox(height: 24),
            Text('Aucun mouvement à afficher.', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _filteredMovements.length,
      itemBuilder: (context, index) {
        final doc = _filteredMovements[index];
        final data = doc.data();

        final int change = ((data['quantityChange'] ?? 0) as num).toInt();
        final bool isPositive = change > 0;
        final Color themeColor = isPositive ? const Color(0xFF00B074) : const Color(0xFFFF5C5C);
        final Color themeBgColor = isPositive ? const Color(0xFFE5F7F1) : const Color(0xFFFFEEEE);
        final String changeSign = isPositive ? '+' : '';

        final Timestamp? ts = data['timestamp'];
        final String formattedDate = ts != null ? DateFormat('dd MMM yy • HH:mm', 'fr_FR').format(ts.toDate()) : 'Date inconnue';

        // Supplier Fetching
        final String productId = (data['productId'] ?? '').toString();
        final Map<String, dynamic> productDoc = _fullProductCatalog[productId] ?? {};
        final String supplierName = (productDoc['marque'] ?? productDoc['fournisseur'] ?? data['supplier'] ?? '').toString();

        // ✅ CHECK IF THIS ITEM IS A DELIVERY (BL)
        final String notesStr = (data['notes'] ?? '').toString().toLowerCase();
        final bool isBL = notesStr.contains('bl') || notesStr.contains('livraison') || data.containsKey('deliveryId') || data.containsKey('livraisonId');

        return SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: themeBgColor, borderRadius: BorderRadius.circular(12)),
                        child: Icon(isPositive ? Icons.south_west_rounded : Icons.north_east_rounded, color: themeColor, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['productName'] ?? 'Produit inconnu',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87, letterSpacing: -0.3),
                            ),
                            const SizedBox(height: 2),
                            Text('Réf: ${data['productRef'] ?? 'N/A'}', style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
                        child: Text('$changeSign$change', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 18, color: themeColor)),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, thickness: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPremiumStatChip('Stock Avant', (data['oldQuantity'] ?? 0).toString()),
                      Icon(Icons.arrow_forward_rounded, color: Colors.grey.shade300, size: 20),
                      _buildPremiumStatChip('Stock Après', (data['newQuantity'] ?? 0).toString()),
                    ],
                  ),
                  if (data['notes'] != null && (data['notes'] as String).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        (data['notes'] as String),
                        style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildMetaChip(Icons.person_rounded, _userNamesMap[data['userId']] ?? 'Utilisateur inconnu'),
                      _buildMetaChip(Icons.access_time_filled_rounded, formattedDate),
                      if (supplierName.isNotEmpty)
                        _buildMetaChip(Icons.local_shipping_rounded, supplierName),

                      // ✅ NEW: ACTION CHIP FOR BL NAVIGATION
                      if (isBL)
                        _buildActionChip(Icons.remove_red_eye_rounded, "Voir le BL", () => _handleBLNavigation(data)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumStatChip(String label, String value) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87)),
      ],
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ✅ CUSTOM CLICKABLE CHIP FOR BL
  Widget _buildActionChip(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade200)
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.blue.shade700),
            const SizedBox(width: 6),
            Text(text, style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
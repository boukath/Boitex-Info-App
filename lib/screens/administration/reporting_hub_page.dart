// lib/screens/administration/reporting_hub_page.dart

import 'dart:io';
import 'dart:convert'; // ✅ Needed for Base64 decoding
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'; // ✅ Cloud Functions
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;

// ✅ IMPORTS
import 'package:boitex_info_app/screens/administration/widgets/report_selectors.dart';
import 'package:boitex_info_app/services/stock_audit_pdf_service.dart';
import 'package:boitex_info_app/services/inventory_pdf_service.dart';
import 'package:boitex_info_app/services/livraison_pdf_service.dart';
import 'package:boitex_info_app/services/client_report_service.dart';
import 'package:boitex_info_app/services/client_report_pdf_service.dart';
// Note: Local PDF services for Intervention/Installation are removed
// because we use Cloud Functions for them now.
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';

class ReportingHubPage extends StatefulWidget {
  const ReportingHubPage({super.key});

  @override
  State<ReportingHubPage> createState() => _ReportingHubPageState();
}

class _ReportingHubPageState extends State<ReportingHubPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- GLOBAL UI STATE ---
  bool _isLoading = false;

  // --- STATE FOR STOCK TAB ---
  DateTime? _stockStartDate;
  DateTime? _stockEndDate;
  String _selectedMovementType = 'ALL'; // Options: 'ALL', 'ENTRY', 'EXIT'
  final StockAuditPdfService _stockAuditService = StockAuditPdfService();

  // --- STATE FOR INVENTORY TAB ---
  String _inventoryFilterType = 'global';
  String? _selectedFilterValue;
  List<String> _extractedBrands = [];
  List<String> _extractedCategories = [];

  // --- STATE FOR LOGISTICS TAB ---
  final LivraisonPdfService _livraisonPdfService = LivraisonPdfService();
  String _logisticsSearchType = 'recent';
  TextEditingController _logisticsSearchController = TextEditingController();
  List<DocumentSnapshot> _logisticsResults = [];
  DateTime? _logisticsStartDate;
  DateTime? _logisticsEndDate;

  // --- STATE FOR COMMERCIAL TAB ---
  final ClientReportService _clientReportService = ClientReportService();
  final ClientReportPdfService _clientReportPdfService = ClientReportPdfService();
  DateTime? _commercialStartDate;
  DateTime? _commercialEndDate;
  String? _selectedClientId;
  String? _selectedClientName;
  List<Map<String, String>> _clientsList = [];

  // --- STATE FOR TECHNICAL TAB (INTERVENTION) ---
  DateTime? _technicalStartDate;
  DateTime? _technicalEndDate;
  String _technicalSearchType = 'recent';
  TextEditingController _technicalSearchController = TextEditingController();
  List<DocumentSnapshot> _technicalResults = [];

  // --- STATE FOR TECHNICAL TAB (INSTALLATION) ---
  DateTime? _installationStartDate;
  DateTime? _installationEndDate;
  String _installationSearchType = 'recent';
  TextEditingController _installationSearchController = TextEditingController();
  List<DocumentSnapshot> _installationResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    // Default dates
    _stockStartDate = startOfMonth;
    _stockEndDate = now;

    _logisticsStartDate = startOfMonth;
    _logisticsEndDate = now;

    _commercialStartDate = startOfMonth;
    _commercialEndDate = now;

    _technicalStartDate = startOfMonth;
    _technicalEndDate = now;

    _installationStartDate = startOfMonth;
    _installationEndDate = now;

    // Load Data
    _extractFilterDataFromProducts();
    _fetchRecentDeliveries();
    _fetchClients();
    _fetchRecentInterventions();
    _fetchRecentInstallations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logisticsSearchController.dispose();
    _technicalSearchController.dispose();
    _installationSearchController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 🧹 DATA SANITIZER (Only needed if sending full objects, usually not needed for ID calls)
  // ===========================================================================
  dynamic _sanitizeForJson(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitizeForJson(v)));
    } else if (value is List) {
      return value.map((v) => _sanitizeForJson(v)).toList();
    }
    return value;
  }

  // ===========================================================================
  // 🛠 TECHNICAL LOGIC (INTERVENTION) - ✅ FIXED TO USE CLOUD FUNCTION
  // ===========================================================================

  Future<void> _fetchRecentInterventions() async {
    setState(() => _isLoading = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('interventions')
          .where('status', whereIn: ['Terminé', 'Clôturé']) // ✅ ONLY COMPLETED
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      setState(() => _technicalResults = query.docs);
    } catch (e) {
      debugPrint("Error fetching recent interventions: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchInterventions() async {
    setState(() => _isLoading = true);
    _technicalResults.clear();

    try {
      String rawSearch = _technicalSearchController.text.trim();
      String searchLower = rawSearch.toLowerCase();

      Query baseQuery = FirebaseFirestore.instance
          .collection('interventions')
          .where('status', whereIn: ['Terminé', 'Clôturé']) // ✅ ONLY COMPLETED
          .orderBy('createdAt', descending: true);

      if (_technicalSearchType == 'date' && _technicalStartDate != null && _technicalEndDate != null) {
        final endOfDay = _technicalEndDate!.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        final snapshot = await baseQuery
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_technicalStartDate!))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get();
        setState(() => _technicalResults = snapshot.docs);
        setState(() => _isLoading = false);
        return;
      }

      final snapshot = await baseQuery.limit(100).get();

      List<DocumentSnapshot> filteredList = [];

      if (_technicalSearchType == 'code') {
        filteredList = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final code = (data['interventionCode'] ?? '').toString().toLowerCase();
          return code.contains(searchLower);
        }).toList();
      }
      else if (_technicalSearchType == 'client') {
        filteredList = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['clientName'] ?? '').toString().toLowerCase();
          return name.contains(searchLower);
        }).toList();
      }
      else if (_technicalSearchType == 'tech') {
        filteredList = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final tech = (data['createdByName'] ?? '').toString().toLowerCase();
          return tech.contains(searchLower);
        }).toList();
      } else {
        filteredList = snapshot.docs;
      }

      if (filteredList.isEmpty) {
        _showSnack("Aucun résultat trouvé.");
      }

      setState(() => _technicalResults = filteredList);

    } catch (e) {
      _showError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// ☁️ CALLS THE CLOUD FUNCTION 'exportInterventionPdf' (FIXED)
  Future<void> _reprintIntervention(DocumentSnapshot doc) async {
    setState(() => _isLoading = true);
    try {
      final rawData = doc.data() as Map<String, dynamic>;

      // ✅ 1. Use 'europe-west1' region
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

      // ✅ 2. Call 'exportInterventionPdf'
      final callable = functions.httpsCallable('exportInterventionPdf');

      // ✅ 3. Send only 'interventionId'
      final result = await callable.call({
        'interventionId': doc.id,
      });

      // 4. Decode Response
      final data = result.data as Map<dynamic, dynamic>;
      final String base64Pdf = data['pdfBase64'];

      if (base64Pdf.isEmpty) throw Exception("PDF vide retourné par le serveur.");

      final Uint8List pdfBytes = base64Decode(base64Pdf);

      // 5. View PDF
      final String fileName = rawData['interventionCode']?.toString().replaceAll('/', '-') ?? 'Intervention';
      _previewOrDownloadPdf(pdfBytes, "$fileName.pdf");

    } catch (e) {
      debugPrint("Cloud Function Error: $e");
      if (e is FirebaseFunctionsException) {
        _showSnack("Erreur Serveur: ${e.message} (${e.code})");
      } else {
        _showSnack("Erreur: ${e.toString()}");
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectTechnicalDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _technicalStartDate != null && _technicalEndDate != null
          ? DateTimeRange(start: _technicalStartDate!, end: _technicalEndDate!)
          : null,
      builder: (context, child) => _datePickerTheme(child),
    );

    if (picked != null) {
      setState(() {
        _technicalStartDate = picked.start;
        _technicalEndDate = picked.end;
      });
    }
  }

  // ===========================================================================
  // 🛠 TECHNICAL LOGIC (INSTALLATION - CLOUD FUNCTION)
  // ===========================================================================

  Future<void> _fetchRecentInstallations() async {
    setState(() => _isLoading = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('installations')
          .where('status', isEqualTo: 'Terminée') // ✅ ONLY COMPLETED INSTALLATIONS
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      setState(() => _installationResults = query.docs);
    } catch (e) {
      debugPrint("Error fetching recent installations: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchInstallations() async {
    setState(() => _isLoading = true);
    _installationResults.clear();

    try {
      String rawSearch = _installationSearchController.text.trim();
      String searchLower = rawSearch.toLowerCase();

      Query baseQuery = FirebaseFirestore.instance
          .collection('installations')
          .where('status', isEqualTo: 'Terminée') // ✅ ONLY COMPLETED INSTALLATIONS
          .orderBy('createdAt', descending: true);

      if (_installationSearchType == 'date' && _installationStartDate != null && _installationEndDate != null) {
        final endOfDay = _installationEndDate!.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        final snapshot = await baseQuery
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_installationStartDate!))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get();
        setState(() => _installationResults = snapshot.docs);
        setState(() => _isLoading = false);
        return;
      }

      final snapshot = await baseQuery.limit(100).get();
      List<DocumentSnapshot> filteredList = [];

      if (_installationSearchType == 'code') {
        filteredList = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final code = (data['installationCode'] ?? '').toString().toLowerCase();
          return code.contains(searchLower);
        }).toList();
      }
      else if (_installationSearchType == 'client') {
        filteredList = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['clientName'] ?? '').toString().toLowerCase();
          return name.contains(searchLower);
        }).toList();
      } else {
        filteredList = snapshot.docs;
      }

      if (filteredList.isEmpty) {
        _showSnack("Aucune installation trouvée.");
      }

      setState(() => _installationResults = filteredList);

    } catch (e) {
      _showError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// ☁️ CALLS THE CLOUD FUNCTION 'getInstallationPdf'
  Future<void> _reprintInstallation(DocumentSnapshot doc) async {
    setState(() => _isLoading = true);
    try {
      final rawData = doc.data() as Map<String, dynamic>;

      // ✅ 1. Region: europe-west1
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

      // ✅ 2. Function: getInstallationPdf
      final callable = functions.httpsCallable('getInstallationPdf');

      // ✅ 3. Param: installationId
      final result = await callable.call({
        'installationId': doc.id,
      });

      // 4. Decode
      final data = result.data as Map<dynamic, dynamic>;
      final String base64Pdf = data['pdfBase64'];
      final String filename = data['filename'] ?? 'Installation.pdf';

      if (base64Pdf.isEmpty) throw Exception("PDF vide retourné par le serveur.");

      final Uint8List pdfBytes = base64Decode(base64Pdf);

      // 5. View
      _previewOrDownloadPdf(pdfBytes, filename);

    } catch (e) {
      debugPrint("Cloud Function Error: $e");
      if (e is FirebaseFunctionsException) {
        _showSnack("Erreur Serveur: ${e.message} (${e.code})");
      } else {
        _showSnack("Erreur: ${e.toString()}");
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectInstallationDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _installationStartDate != null && _installationEndDate != null
          ? DateTimeRange(start: _installationStartDate!, end: _installationEndDate!)
          : null,
      builder: (context, child) => _datePickerTheme(child),
    );

    if (picked != null) {
      setState(() {
        _installationStartDate = picked.start;
        _installationEndDate = picked.end;
      });
    }
  }

  // ===========================================================================
  // 👥 COMMERCIAL LOGIC
  // ===========================================================================

  Future<void> _fetchClients() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('clients').orderBy('name').get();
      if (mounted) {
        setState(() {
          _clientsList = snapshot.docs.map((doc) => {
            'id': doc.id,
            'name': (doc.data()['name'] ?? 'Client Inconnu').toString(),
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching clients: $e");
    }
  }

  Future<void> _selectCommercialDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _commercialStartDate != null && _commercialEndDate != null
          ? DateTimeRange(start: _commercialStartDate!, end: _commercialEndDate!)
          : null,
      builder: (context, child) => _datePickerTheme(child),
    );

    if (picked != null) {
      setState(() {
        _commercialStartDate = picked.start;
        _commercialEndDate = picked.end;
      });
    }
  }

  Future<void> _generateClientReport() async {
    if (_commercialStartDate == null || _commercialEndDate == null) {
      _showSnack("Veuillez sélectionner une période.");
      return;
    }
    if (_selectedClientId == null) {
      _showSnack("Veuillez sélectionner un client.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final reportData = await _clientReportService.fetchReportData(
        clientId: _selectedClientId!,
        clientName: _selectedClientName ?? 'Client',
        dateRange: DateTimeRange(start: _commercialStartDate!, end: _commercialEndDate!),
      );

      final pdfBytes = await _clientReportPdfService.generateReport(reportData);

      final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final safeClient = _selectedClientName?.replaceAll(' ', '_') ?? 'Client';
      await _previewOrDownloadPdf(pdfBytes, "Rapport_${safeClient}_$dateStr.pdf");

    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // 📦 STOCK & INVENTORY LOGIC
  // ===========================================================================

  Future<void> _extractFilterDataFromProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('produits').get();
      final Set<String> brands = {};
      final Set<String> categories = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['marque'] != null && data['marque'].toString().trim().isNotEmpty) {
          brands.add(data['marque'].toString().trim());
        }
        if (data['mainCategory'] != null && data['mainCategory'].toString().trim().isNotEmpty) {
          categories.add(data['mainCategory'].toString().trim());
        }
      }

      if (mounted) {
        setState(() {
          _extractedBrands = brands.toList()..sort();
          _extractedCategories = categories.toList()..sort();
        });
      }
    } catch (e) { debugPrint("Error extracting filter data: $e"); }
  }

  Future<void> _selectStockDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _stockStartDate != null && _stockEndDate != null
          ? DateTimeRange(start: _stockStartDate!, end: _stockEndDate!)
          : null,
      builder: (context, child) => _datePickerTheme(child),
    );

    if (picked != null) {
      setState(() {
        _stockStartDate = picked.start;
        _stockEndDate = picked.end;
      });
    }
  }

  Widget _buildMovementFilterSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment<String>(
            value: 'ALL',
            label: Text('Tout'),
            icon: Icon(Icons.list_alt),
          ),
          ButtonSegment<String>(
            value: 'ENTRY',
            label: Text('Entrées'),
            icon: Icon(Icons.arrow_downward, color: Colors.green),
          ),
          ButtonSegment<String>(
            value: 'EXIT',
            label: Text('Sorties'),
            icon: Icon(Icons.arrow_upward, color: Colors.red),
          ),
        ],
        selected: {_selectedMovementType},
        onSelectionChanged: (Set<String> newSelection) {
          setState(() {
            _selectedMovementType = newSelection.first;
          });
        },
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Future<void> _generateStockAudit() async {
    if (_stockStartDate == null || _stockEndDate == null) return;
    setState(() => _isLoading = true);
    try {
      final endOfDay = _stockEndDate!.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));

      final QuerySnapshot movementsSnapshot = await FirebaseFirestore.instance
          .collection('stock_movements')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(_stockStartDate!))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp', descending: true)
          .get();

      // ✅ FILTER LOGIC HERE
      List<QueryDocumentSnapshot> docs = movementsSnapshot.docs;
      // ✅ DEFINE TITLE BASED ON FILTER
      String pdfTitle = "Audit Global des Mouvements";

      if (_selectedMovementType == 'ENTRY') {
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // ✅ FIX: Safe casting to prevent 'double is not int' error
          final int q = (data['quantityChange'] is int)
              ? (data['quantityChange'] as int)
              : ((data['quantityChange'] as num?)?.toInt() ?? 0);
          return q > 0;
        }).toList();
        pdfTitle = "Rapport des Entrées de Stock";
      } else if (_selectedMovementType == 'EXIT') {
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // ✅ FIX: Safe casting to prevent 'double is not int' error
          final int q = (data['quantityChange'] is int)
              ? (data['quantityChange'] as int)
              : ((data['quantityChange'] as num?)?.toInt() ?? 0);
          return q < 0;
        }).toList();
        pdfTitle = "Rapport des Sorties de Stock";
      }

      if (docs.isEmpty) {
        _showSnack('Aucune donnée trouvée pour cette période et ce filtre.');
        return;
      }

      final Map<String, String> productCatalog = await _fetchProductCatalog();
      final Map<String, String> userNamesMap = {};

      final pdfBytes = await _stockAuditService.generateAuditPdf(
          docs,
          _stockStartDate,
          _stockEndDate,
          userNamesMap,
          productCatalog,
          pdfTitle // ✅ PASSING THE TITLE (6th Argument)
      );

      await _previewOrDownloadPdf(pdfBytes, "Audit_Stock_${_selectedMovementType}_${_stockStartDate?.month}_${_stockStartDate?.year}");
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateInventoryReport() async {
    if ((_inventoryFilterType == 'brand' || _inventoryFilterType == 'category' || _inventoryFilterType == 'status') &&
        _selectedFilterValue == null) {
      _showSnack("Veuillez sélectionner une option.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('produits').orderBy('nom').get();
      List<DocumentSnapshot> filteredDocs = snapshot.docs;
      String reportTitle = "État du Stock Global";
      String reportFilterDesc = "Filtre: Tout le stock";

      if (_inventoryFilterType == 'brand') {
        filteredDocs = filteredDocs.where((doc) {
          // ✅ FIX: Safe Access to Data
          final data = doc.data() as Map<String, dynamic>;
          return (data['marque'] ?? '') == _selectedFilterValue;
        }).toList();
        reportTitle = "Inventaire par Marque";
        reportFilterDesc = "Marque: $_selectedFilterValue";

      } else if (_inventoryFilterType == 'category') {
        filteredDocs = filteredDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['mainCategory'] ?? '') == _selectedFilterValue;
        }).toList();
        reportTitle = "Inventaire par Catégorie";
        reportFilterDesc = "Catégorie: $_selectedFilterValue";

      } else if (_inventoryFilterType == 'status') {
        if (_selectedFilterValue == 'Rupture (0)') {
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['quantiteEnStock'] ?? 0) <= 0;
          }).toList();
          reportTitle = "Rapport de Rupture";
        } else if (_selectedFilterValue == 'Stock Faible (<5)') {
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final q = data['quantiteEnStock'] ?? 0;
            return q > 0 && q < 5;
          }).toList();
          reportTitle = "Rapport Stock Critique";
        } else if (_selectedFilterValue == 'En Stock (>0)') {
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['quantiteEnStock'] ?? 0) > 0;
          }).toList();
          reportTitle = "Produits Disponibles";
        }
        reportFilterDesc = "Statut: $_selectedFilterValue";
      }

      if (filteredDocs.isEmpty) {
        _showSnack('Aucun produit ne correspond à ces critères.');
        return;
      }

      final pdfBytes = await InventoryPdfService.generateInventoryPdf(filteredDocs, reportTitle, reportFilterDesc);
      final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final safeFilter = _selectedFilterValue?.replaceAll(' ', '_') ?? 'Global';
      await _previewOrDownloadPdf(pdfBytes, "Inventaire_${safeFilter}_$dateStr");

    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // 🚚 LOGISTICS LOGIC
  // ===========================================================================

  Future<void> _fetchRecentDeliveries() async {
    setState(() => _isLoading = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('livraisons')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      setState(() => _logisticsResults = query.docs);
    } catch (e) {
      debugPrint("Error fetching recent deliveries: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchDeliveries() async {
    setState(() => _isLoading = true);
    _logisticsResults.clear();

    try {
      String rawSearch = _logisticsSearchController.text.trim();
      String searchLower = rawSearch.toLowerCase();

      Query baseQuery = FirebaseFirestore.instance
          .collection('livraisons')
          .orderBy('createdAt', descending: true);

      if (_logisticsSearchType == 'date' && _logisticsStartDate != null && _logisticsEndDate != null) {
        final endOfDay = _logisticsEndDate!.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        final snapshot = await baseQuery
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_logisticsStartDate!))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get();
        setState(() => _logisticsResults = snapshot.docs);
        setState(() => _isLoading = false);
        return;
      }

      final snapshot = await baseQuery.limit(100).get();

      List<DocumentSnapshot> filteredList = [];

      if (_logisticsSearchType == 'code') {
        filteredList = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final code = (data['bonLivraisonCode'] ?? '').toString().toLowerCase();
          return code.contains(searchLower);
        }).toList();
      }
      else if (_logisticsSearchType == 'client') {
        filteredList = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['clientName'] ?? '').toString().toLowerCase();
          return name.contains(searchLower);
        }).toList();
      }
      else if (_logisticsSearchType == 'store') {
        filteredList = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['storeName'] ?? '').toString().toLowerCase();
          return name.contains(searchLower);
        }).toList();
      } else {
        filteredList = snapshot.docs;
      }

      if (filteredList.isEmpty) {
        _showSnack("Aucun résultat trouvé dans les 100 dernières livraisons.");
      }

      setState(() => _logisticsResults = filteredList);

    } catch (e) {
      _showError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reprintDelivery(DocumentSnapshot doc) async {
    setState(() => _isLoading = true);
    try {
      final data = doc.data() as Map<String, dynamic>;

      Map<String, dynamic> clientData = {};
      if (data['clientId'] != null) {
        final clientDoc = await FirebaseFirestore.instance.collection('clients').doc(data['clientId']).get();
        if (clientDoc.exists) {
          clientData = clientDoc.data() as Map<String, dynamic>;
        }
      }

      List<ProductSelection> products = [];
      if (data['products'] != null) {
        products = (data['products'] as List).map<ProductSelection>((item) {
          return ProductSelection(
            productId: item['id'] ?? item['productId'] ?? '',
            productName: item['name'] ?? item['productName'] ?? 'Inconnu',
            partNumber: item['reference'] ?? item['partNumber'] ?? '',
            marque: item['marque'] ?? 'N/A',
            quantity: item['quantity'] ?? 0,
            serialNumbers: item['serialNumbers'] != null
                ? List<String>.from(item['serialNumbers'])
                : [],
          );
        }).toList();
      }

      Uint8List? signatureBytes;
      if (data['signatureUrl'] != null && data['signatureUrl'].toString().isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(data['signatureUrl']));
          if (response.statusCode == 200) signatureBytes = response.bodyBytes;
        } catch (e) { debugPrint("Sig error: $e"); }
      }

      final pdfBytes = await _livraisonPdfService.generateLivraisonPdf(
        livraisonData: data,
        clientData: clientData,
        products: products,
        docId: data['bonLivraisonCode'] ?? data['id'] ?? 'BL',
        signatureBytes: signatureBytes,
      );

      _previewOrDownloadPdf(pdfBytes, "${data['bonLivraisonCode'] ?? 'BL'}.pdf");

    } catch (e) {
      _showError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectLogisticsDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _logisticsStartDate != null && _logisticsEndDate != null
          ? DateTimeRange(start: _logisticsStartDate!, end: _logisticsEndDate!)
          : null,
      builder: (context, child) => _datePickerTheme(child),
    );

    if (picked != null) {
      setState(() {
        _logisticsStartDate = picked.start;
        _logisticsEndDate = picked.end;
      });
    }
  }

  // ===========================================================================
  // 🖥 UI BUILDERS
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Centre d'Édition"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: "STOCKS", icon: Icon(Icons.inventory_2_outlined)),
            Tab(text: "TECHNIQUE", icon: Icon(Icons.build_outlined)),
            Tab(text: "LOGISTIQUE", icon: Icon(Icons.local_shipping_outlined)),
            Tab(text: "COMMERCIAL", icon: Icon(Icons.business_center_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStockSection(),
          _buildTechnicalSection(),
          _buildLogisticsSection(),
          _buildCommercialSection(),
        ],
      ),
    );
  }

  // ✅ TECHNICAL SECTION UI (UPDATED WITH INSTALLATIONS)
  Widget _buildTechnicalSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. INTERVENTIONS CARD
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderIcon("Rapports d'Intervention", Icons.handyman_outlined),
                const SizedBox(height: 15),

                // Search Type
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Rechercher par :"),
                  value: _technicalSearchType,
                  items: const [
                    DropdownMenuItem(value: 'recent', child: Text("🕒 Dernières Interventions")),
                    DropdownMenuItem(value: 'code', child: Text("🔢 Code (ex: INT-23...)")),
                    DropdownMenuItem(value: 'client', child: Text("👤 Client")),
                    DropdownMenuItem(value: 'tech', child: Text("👨‍🔧 Technicien")),
                    DropdownMenuItem(value: 'date', child: Text("📅 Par Période")),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _technicalSearchType = val!;
                      _technicalResults.clear();
                      if (val == 'recent') _fetchRecentInterventions();
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Dynamic Input
                if (_technicalSearchType != 'recent' && _technicalSearchType != 'date')
                  TextField(
                    controller: _technicalSearchController,
                    decoration: _inputDecoration("Entrez votre recherche..."),
                    onSubmitted: (_) => _searchInterventions(),
                  ),

                if (_technicalSearchType == 'date')
                  ReportDateSelector(
                      startDate: _technicalStartDate,
                      endDate: _technicalEndDate,
                      onSelectDateRange: _selectTechnicalDateRange
                  ),

                if (_technicalSearchType != 'recent') ...[
                  const SizedBox(height: 15),
                  _buildActionButton(
                    label: "RECHERCHER",
                    icon: Icons.search_rounded,
                    onTap: _searchInterventions,
                    color: Colors.blueGrey.shade700,
                  ),
                ]
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Interventions Results
          if (_technicalResults.isNotEmpty) ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _technicalResults.length,
              itemBuilder: (context, index) {
                final doc = _technicalResults[index];
                final data = doc.data() as Map<String, dynamic>;
                final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                // ✅ Prioritize Store Name > Client Name
                final String displayName = (data['storeName'] != null && data['storeName'].toString().isNotEmpty)
                    ? data['storeName']
                    : (data['clientName'] ?? 'Client Inconnu');

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: Icon(Icons.build, color: Colors.orange.shade800),
                    ),
                    title: Text(data['interventionCode'] ?? 'Code Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(DateFormat('dd/MM/yyyy').format(date), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      tooltip: "Générer PDF",
                      onPressed: () => _reprintIntervention(doc),
                    ),
                  ),
                );
              },
            ),
          ] else if (_isLoading && _technicalSearchType != 'recent') ...[
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          ],

          const SizedBox(height: 30),

          // 2. INSTALLATIONS CARD (✅ NEW)
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderIcon("Rapports d'Installation", Icons.settings_input_component_outlined),
                const SizedBox(height: 15),

                // Search Type
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Rechercher par :"),
                  value: _installationSearchType,
                  items: const [
                    DropdownMenuItem(value: 'recent', child: Text("🕒 Dernières Installations")),
                    DropdownMenuItem(value: 'code', child: Text("🔢 Code (ex: INST-23...)")),
                    DropdownMenuItem(value: 'client', child: Text("👤 Client")),
                    DropdownMenuItem(value: 'date', child: Text("📅 Par Période")),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _installationSearchType = val!;
                      _installationResults.clear();
                      if (val == 'recent') _fetchRecentInstallations();
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Dynamic Input
                if (_installationSearchType != 'recent' && _installationSearchType != 'date')
                  TextField(
                    controller: _installationSearchController,
                    decoration: _inputDecoration("Entrez votre recherche..."),
                    onSubmitted: (_) => _searchInstallations(),
                  ),

                if (_installationSearchType == 'date')
                  ReportDateSelector(
                      startDate: _installationStartDate,
                      endDate: _installationEndDate,
                      onSelectDateRange: _selectInstallationDateRange
                  ),

                if (_installationSearchType != 'recent') ...[
                  const SizedBox(height: 15),
                  _buildActionButton(
                    label: "RECHERCHER",
                    icon: Icons.search_rounded,
                    onTap: _searchInstallations,
                    color: Colors.teal.shade700,
                  ),
                ]
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Installation Results
          if (_installationResults.isNotEmpty) ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _installationResults.length,
              itemBuilder: (context, index) {
                final doc = _installationResults[index];
                final data = doc.data() as Map<String, dynamic>;
                final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                // ✅ Prioritize Store Name > Client Name
                final String displayName = (data['storeName'] != null && data['storeName'].toString().isNotEmpty)
                    ? data['storeName']
                    : (data['clientName'] ?? 'Client Inconnu');

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade100,
                      child: Icon(Icons.settings, color: Colors.teal.shade800),
                    ),
                    title: Text(data['installationCode'] ?? 'Code Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(DateFormat('dd/MM/yyyy').format(date), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      tooltip: "Générer PDF",
                      onPressed: () => _reprintInstallation(doc),
                    ),
                  ),
                );
              },
            ),
          ] else if (_isLoading && _installationSearchType != 'recent') ...[
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          ],
        ],
      ),
    );
  }

  // ✅ COMMERCIAL SECTION UI
  Widget _buildCommercialSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderIcon("Rapport Client Global", Icons.pie_chart_rounded),
                const SizedBox(height: 8),
                const Text(
                  "Générez un rapport complet incluant les interventions, l'état des équipements et les statistiques par magasin pour un client donné.",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // 1. Client Selector
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Sélectionner le Client"),
                  value: _selectedClientId,
                  hint: const Text("Choisir un client..."),
                  items: _clientsList.map((client) {
                    return DropdownMenuItem<String>(
                      value: client['id'],
                      child: Text(client['name']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedClientId = val;
                      _selectedClientName = _clientsList.firstWhere((c) => c['id'] == val)['name'];
                    });
                  },
                ),

                const SizedBox(height: 15),

                // 2. Date Range
                ReportDateSelector(
                    startDate: _commercialStartDate,
                    endDate: _commercialEndDate,
                    onSelectDateRange: _selectCommercialDateRange
                ),

                const SizedBox(height: 24),

                // 3. Generate Button
                _buildActionButton(
                  label: "GÉNÉRER LE RAPPORT CLIENT",
                  icon: Icons.picture_as_pdf_rounded,
                  onTap: _generateClientReport,
                  color: Colors.indigo.shade600,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderIcon("Audit & Mouvements", Icons.history_edu),
                const SizedBox(height: 15),

                // ✅ NEW SELECTOR
                _buildMovementFilterSelector(),

                const SizedBox(height: 8),

                ReportDateSelector(
                  startDate: _stockStartDate,
                  endDate: _stockEndDate,
                  onSelectDateRange: _selectStockDateRange,
                ),
                const SizedBox(height: 15),
                _buildActionButton(
                  label: "GÉNÉRER JOURNAL D'AUDIT",
                  icon: Icons.print,
                  onTap: _generateStockAudit,
                  color: const Color(0xFF1E3A8A),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderIcon("État du Stock", Icons.analytics_outlined),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Filtrer par :"),
                  value: _inventoryFilterType,
                  items: const [
                    DropdownMenuItem(value: 'global', child: Text("Tout le Stock (Global)")),
                    DropdownMenuItem(value: 'brand', child: Text("Par Marque")),
                    DropdownMenuItem(value: 'category', child: Text("Par Catégorie (Main)")),
                    DropdownMenuItem(value: 'status', child: Text("Par Statut")),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _inventoryFilterType = val!;
                      _selectedFilterValue = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_inventoryFilterType == 'brand')
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration("Sélectionner la Marque"),
                    value: _selectedFilterValue,
                    hint: const Text("Choisir une marque..."),
                    items: _extractedBrands.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setState(() => _selectedFilterValue = val),
                  ),
                if (_inventoryFilterType == 'category')
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration("Sélectionner la Catégorie"),
                    value: _selectedFilterValue,
                    hint: const Text("Choisir une catégorie..."),
                    items: _extractedCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setState(() => _selectedFilterValue = val),
                  ),
                if (_inventoryFilterType == 'status')
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration("Sélectionner le Statut"),
                    value: _selectedFilterValue,
                    items: const [
                      DropdownMenuItem(value: 'Rupture (0)', child: Text("🔴 En Rupture (0)")),
                      DropdownMenuItem(value: 'Stock Faible (<5)', child: Text("🟠 Stock Faible (< 5)")),
                      DropdownMenuItem(value: 'En Stock (>0)', child: Text("🟢 Disponible (> 0)")),
                    ],
                    onChanged: (val) => setState(() => _selectedFilterValue = val),
                  ),
                const SizedBox(height: 20),
                _buildActionButton(
                  label: "GÉNÉRER L'INVENTAIRE",
                  icon: Icons.picture_as_pdf_rounded,
                  onTap: _generateInventoryReport,
                  color: Colors.teal.shade700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderIcon("Recherche Bons de Livraison", Icons.search),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Méthode de recherche"),
                  value: _logisticsSearchType,
                  items: const [
                    DropdownMenuItem(value: 'recent', child: Text("🕒 Dernières livraisons")),
                    DropdownMenuItem(value: 'code', child: Text("🔢 Par Code BL (ex: BL-40...)")),
                    DropdownMenuItem(value: 'client', child: Text("👤 Par Client")),
                    DropdownMenuItem(value: 'store', child: Text("🏢 Par Magasin")),
                    DropdownMenuItem(value: 'date', child: Text("📅 Par Période")),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _logisticsSearchType = val!;
                      _logisticsResults.clear();
                      if (val == 'recent') _fetchRecentDeliveries();
                    });
                  },
                ),
                const SizedBox(height: 12),

                if (_logisticsSearchType != 'recent' && _logisticsSearchType != 'date')
                  TextField(
                    controller: _logisticsSearchController,
                    decoration: _inputDecoration("Entrez votre recherche..."),
                    onSubmitted: (_) => _searchDeliveries(),
                  ),

                if (_logisticsSearchType == 'date')
                  ReportDateSelector(
                      startDate: _logisticsStartDate,
                      endDate: _logisticsEndDate,
                      onSelectDateRange: _selectLogisticsDateRange
                  ),

                if (_logisticsSearchType != 'recent') ...[
                  const SizedBox(height: 15),
                  _buildActionButton(
                    label: "RECHERCHER",
                    icon: Icons.search_rounded,
                    onTap: _searchDeliveries,
                    color: Colors.indigo,
                  ),
                ]
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_logisticsResults.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text("Aucun résultat", style: TextStyle(color: Colors.grey.shade500)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _logisticsResults.length,
              itemBuilder: (context, index) {
                final doc = _logisticsResults[index];
                final data = doc.data() as Map<String, dynamic>;
                final date = (data['createdAt'] as Timestamp?)?.toDate()
                    ?? (data['completedAt'] as Timestamp?)?.toDate()
                    ?? DateTime.now();

                final String displayName = (data['storeName'] != null && data['storeName'].toString().isNotEmpty)
                    ? data['storeName']
                    : (data['clientName'] ?? 'Client Inconnu');

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(Icons.local_shipping, color: Colors.blue.shade800),
                    ),
                    title: Text(data['bonLivraisonCode'] ?? 'BL Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(DateFormat('dd/MM/yyyy HH:mm').format(date), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      tooltip: "Générer PDF",
                      onPressed: () => _reprintDelivery(doc),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Theme _datePickerTheme(Widget? child) {
    return Theme(
      data: ThemeData.light().copyWith(
        primaryColor: const Color(0xFF1E3A8A),
        colorScheme: const ColorScheme.light(primary: Color(0xFF1E3A8A)),
      ),
      child: child!,
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHeaderIcon(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: const Color(0xFF1E3A8A)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87))),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required VoidCallback onTap, required Color color}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onTap,
        icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Future<void> _previewOrDownloadPdf(Uint8List pdfBytes, String fileName) async {
    if (!mounted) return;
    if (kIsWeb) {
      await FileSaver.instance.saveFile(name: fileName, bytes: pdfBytes, ext: 'pdf', mimeType: MimeType.pdf);
      if (mounted) _showSnack("Téléchargement commencé ! 📥", isError: false);
    } else if (Platform.isAndroid || Platform.isIOS) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => PdfViewerPage(pdfBytes: pdfBytes, title: fileName)));
    } else {
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes, name: '$fileName.pdf');
    }
  }

  Future<Map<String, String>> _fetchProductCatalog() async {
    final Map<String, String> catalog = {};
    try {
      final snapshot = await FirebaseFirestore.instance.collection('produits').get();
      for (var doc in snapshot.docs) {
        catalog[doc.id] = doc.data()['reference'] ?? doc.data()['nom'] ?? 'Inconnu';
      }
    } catch (e) { /* ignore */ }
    return catalog;
  }

  void _showSnack(String msg, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700),
      );
    }
  }

  void _showError(dynamic e) {
    debugPrint("Error: $e");
    _showSnack('Erreur: $e');
  }

  Widget _buildPlaceholderTab(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(title, style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
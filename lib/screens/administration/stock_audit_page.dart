// lib/screens/administration/stock_audit_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for HapticFeedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:boitex_info_app/services/stock_audit_pdf_service.dart';
import 'package:boitex_info_app/services/stock_audit_csv_service.dart';
import 'package:pdf/pdf.dart';
// ⛔️ REMOVED: printing.dart (no longer needed for this page)
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ FOR WEB CHECK
import 'package:file_saver/file_saver.dart'; // ✅ ADDED FOR WEB DOWNLOAD

// ✅ --- ADDED: Import for the in-app PDF viewer ---
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';
// ✅ --- END OF IMPORTS ---

class StockAuditPage extends StatefulWidget {
  const StockAuditPage({super.key});

  @override
  State<StockAuditPage> createState() => _StockAuditPageState();
}

class _StockAuditPageState extends State<StockAuditPage>
    with TickerProviderStateMixin {
  // Filter States
  DateTime? _startDate;
  DateTime? _endDate;
  final _productSearchController = TextEditingController();
  final _userSearchController = TextEditingController();

  // Query State
  bool _isLoading = false;
  bool _isExportingPdf = false;
  bool _isExportingCsv = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _movements = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredMovements = [];

  // ✅ --- NEW: User name lookup map ---
  Map<String, String> _userNamesMap = {};
  // ✅ --- END NEW ---

  // Animation Controllers for smooth transitions
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Add listeners for client-side filtering
    _productSearchController.addListener(_applyClientFilters);
    _userSearchController.addListener(_applyClientFilters);

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
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _productSearchController.dispose();
    _userSearchController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// Runs the main query against Firestore based on the date range
  Future<void> _runQuery() async {
    if (_isLoading) return;

    if (_startDate == null && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez sélectionner au moins une date.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _movements = [];
      _filteredMovements = [];
      _userNamesMap = {}; // Clear old names
    });

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('stock_movements')
          .orderBy('timestamp', descending: true);

      // Apply date filters
      if (_startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: _startDate);
      }
      if (_endDate != null) {
        final inclusiveEndDate = _endDate!.add(const Duration(days: 1));
        query = query.where('timestamp', isLessThanOrEqualTo: inclusiveEndDate);
      }

      final snapshot = await query.get();
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> movements =
          snapshot.docs;

      // ✅ --- NEW: Fetch User Names ---
      Map<String, String> fetchedNames = {};
      if (movements.isNotEmpty) {
        // 1. Get all unique user IDs from the movements
        final Set<String> userIds = movements
            .map((doc) => (doc.data()['userId'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet();

        // 2. Fetch user documents in batches (Firestore 'whereIn' is limited to 30 items)
        if (userIds.isNotEmpty) {
          final List<String> userIdList = userIds.toList();
          for (int i = 0; i < userIdList.length; i += 30) {
            final batch = userIdList.skip(i).take(30).toList();
            if (batch.isEmpty) continue;

            final userSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: batch)
                .get();

            // 3. Populate the name map
            for (final userDoc in userSnapshot.docs) {
              fetchedNames[userDoc.id] =
                  userDoc.data()?['fullName'] ?? 'Utilisateur Inconnu';
            }
          }
        }
      }
      // ✅ --- END: Fetch User Names ---

      setState(() {
        _movements = movements;
        _userNamesMap = fetchedNames; // Store the map
        _applyClientFilters(); // Apply text filters to the new results
      });

      if (_movements.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Aucun mouvement trouvé pour cette période.')),
        );
      } else {
        _scaleController
          ..reset()
          ..forward();
      }
    } catch (e) {
      print("Error running query: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Applies client-side filters for product and user
  void _applyClientFilters() {
    final productQuery = _productSearchController.text.toLowerCase().trim();
    final userQuery = _userSearchController.text.toLowerCase().trim();

    List<QueryDocumentSnapshot<Map<String, dynamic>>> results =
    List.from(_movements);

    if (productQuery.isNotEmpty) {
      results = results.where((doc) {
        final data = doc.data();
        final name = (data['productName'] ?? '').toString().toLowerCase();
        final ref = (data['productRef'] ?? '').toString().toLowerCase();
        return name.contains(productQuery) || ref.contains(productQuery);
      }).toList();
    }

    if (userQuery.isNotEmpty) {
      results = results.where((doc) {
        final data = doc.data();
        // ✅ --- UPDATED: Filter using the name map ---
        final String userId = (data['userId'] ?? '').toString();
        final String user = (_userNamesMap[userId] ?? '').toLowerCase();
        // ✅ --- END UPDATED ---
        return user.contains(userQuery);
      }).toList();
    }

    setState(() {
      _filteredMovements = results;
    });
  }

  /// Date Picker Logic
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    // ... (This function remains unchanged)
    final DateTime initial =
        (isStartDate ? _startDate : _endDate) ?? DateTime.now();
    final DateTime first = DateTime(2020);
    final DateTime last = DateTime.now().add(const Duration(days: 1));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
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

  // ✅ --- START: UPDATED PDF Export Function ---
  /// PDF Export Function
  Future<void> _exportToPdf() async {
    if (_isExportingPdf || _isExportingCsv || _filteredMovements.isEmpty) return;

    setState(() {
      _isExportingPdf = true;
    });

    try {
      // 1. Generate the PDF data (same for both platforms)
      final pdfService = StockAuditPdfService();
      final Uint8List pdfData = await pdfService.generateAuditPdf(
        _filteredMovements,
        _startDate,
        _endDate,
        _userNamesMap, // Pass the map
      );

      final String fileName =
          'audit_rapport_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        // --- WEB LOGIC (Direct Download) ---
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: pdfData,
          mimeType: MimeType.pdf,
        );
      } else {
        // --- ✅ MODIFIED: MOBILE LOGIC (Open In-App PDF Viewer) ---
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfViewerPage(
              pdfBytes: pdfData,
              title: fileName,
            ),
          ),
        );
      }
    } catch (e) {
      print("Error exporting PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la création du PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
        });
      }
    }
  }
  // ✅ --- END: UPDATED PDF Export Function ---

  // ✅ --- START: UPDATED CSV Export Function ---
  /// CSV Export Function
  Future<void> _exportToCsv() async {
    if (_isExportingPdf || _isExportingCsv || _filteredMovements.isEmpty) return;

    setState(() {
      _isExportingCsv = true;
    });

    try {
      // 1. Generate CSV String (same for both platforms)
      final csvService = StockAuditCsvService();
      final String csvData = await csvService.generateAuditCsv(
        _filteredMovements,
        _userNamesMap, // Pass the map
      );

      final String fileName =
          'audit_mouvements_${DateTime.now().millisecondsSinceEpoch}.csv';

      if (kIsWeb) {
        // --- WEB LOGIC (Direct Download) ---

        // 2. (Web) Convert the String to bytes (Uint8List)
        final bytes = utf8.encode(csvData);

        // 3. (Web) Use file_saver to trigger a direct browser download
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: bytes,
          mimeType: MimeType.csv,
        );
      } else {
        // --- ANDROID LOGIC (Open With / Share) ---

        // 2. (Mobile) Get temp directory
        final Directory tempDir = await getTemporaryDirectory();
        final String filePath = '${tempDir.path}/$fileName';

        // 3. (Mobile) Write file
        final File file = File(filePath);
        await file.writeAsString(csvData, encoding: utf8);

        // 4. (Mobile) Share file
        final xFile = XFile(
          filePath,
          mimeType: 'text/csv',
          name: fileName,
        );

        await Share.shareXFiles(
          [xFile],
          subject: 'Export Audit Mouvements de Stock',
        );
      }
    } catch (e) {
      print("Error exporting CSV: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la création du CSV: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingCsv = false;
        });
      }
    }
  }
  // ✅ --- END: UPDATED CSV Export Function ---

  @override
  Widget build(BuildContext context) {
    // ... (build method remains unchanged)
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebOrTablet = screenWidth > 600;
    final paddingHorizontal = isWebOrTablet ? 32.0 : 16.0;

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue, // Default for neutral audit theme
          brightness: Brightness.light,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            "Audit Mouvements Stock",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade600,
                  Colors.blue.shade400,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade50,
                Colors.white,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      paddingHorizontal, 100, paddingHorizontal, 16),
                  sliver: SliverToBoxAdapter(
                    child: _buildFilterSection(isWebOrTablet),
                  ),
                ),
                // --- LOADING INDICATOR ---
                if (_isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                    ),
                  ),
                // --- RESULTS LIST ---
                SliverFillRemaining(
                  child: _buildResultsList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(bool isWideScreen) {
    // ... (This function remains unchanged, the logic for canExport/canFilter already works)
    final DateFormat formatter = DateFormat('dd/MM/yyyy');

    final bool isExporting = _isExportingPdf || _isExportingCsv;
    final bool canExport =
        !_isLoading && !isExporting && _filteredMovements.isNotEmpty;
    final bool canFilter = !_isLoading && !isExporting;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(isWideScreen ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade600,
                  Colors.blue.shade400,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Filtres d\'Audit',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          // Date Pickers
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context, true),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date de début',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.calendar_today),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    child: Text(
                      _startDate == null
                          ? 'Aucune date'
                          : formatter.format(_startDate!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context, false),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date de fin',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.calendar_today),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    child: Text(
                      _endDate == null
                          ? 'Aucune date'
                          : formatter.format(_endDate!),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Text Search Filters
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _productSearchController,
                  decoration: InputDecoration(
                    labelText: 'Filtrer par produit/référence...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _userSearchController,
                  decoration: InputDecoration(
                    labelText: 'Filtrer par utilisateur...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person_search),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isLoading
                  ? Container(
                width: 20,
                height: 20,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.filter_list_alt),
              label: const Text('Appliquer les Filtres'),
              onPressed: canFilter ? _runQuery : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          // Export Buttons
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isExportingPdf
                      ? Container(
                    width: 20,
                    height: 20,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Export PDF'),
                  onPressed: canExport ? _exportToPdf : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isExportingCsv
                      ? Container(
                    width: 20,
                    height: 20,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.table_chart_outlined),
                  label: const Text('Export CSV'),
                  onPressed: canExport ? _exportToCsv : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_filteredMovements.isEmpty && !_isLoading) {
      // ... (This widget remains unchanged)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Veuillez appliquer des filtres pour voir les mouvements.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredMovements.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final doc = _filteredMovements[index];
        final data = doc.data();

        final int change = ((data['quantityChange'] ?? 0) as num).toInt();
        final Color changeColor =
        change > 0 ? Colors.green.shade600 : Colors.red.shade600;
        final String changeSign = change > 0 ? '+' : '';
        final Timestamp? ts = data['timestamp'];
        final String formattedDate = ts != null
            ? DateFormat('dd/MM/yyyy à HH:mm').format(ts.toDate())
            : 'Date inconnue';

        return SlideTransition(
          position: _slideAnimation,
          child: Card(
            elevation: 4,
            shadowColor: changeColor.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ... (Product/Quantity Row - unchanged)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          data['productName'] ?? 'Produit inconnu',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: changeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$changeSign$change',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: changeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Réf: ${data['productRef'] ?? 'N/A'}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Divider(height: 20),
                  // ... (Before/After Row - unchanged)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatChip(
                          'Avant', (data['oldQuantity'] ?? 0).toString()),
                      Icon(
                        change > 0 ? Icons.trending_up : Icons.trending_down,
                        color: changeColor,
                        size: 24,
                      ),
                      _buildStatChip(
                          'Après', (data['newQuantity'] ?? 0).toString()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ... (Notes - unchanged)
                  if (data['notes'] != null &&
                      (data['notes'] as String).isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        'Notes: ${(data['notes'] as String)}',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // ✅ --- START: UPDATED User/Date Row ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          // Use the map to find the name, fallback to 'Inconnu'
                          _userNamesMap[data['userId']] ?? 'Utilisateur inconnu',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  // ✅ --- END: UPDATED User/Date Row ---
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(String label, String value) {
    // ... (This function remains unchanged)
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
// lib/screens/administration/inventory_report_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for HapticFeedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data'; // ✅ ADDED FOR WEB EXPORT
import 'dart:convert'; // ✅ ADDED TO FIX 'utf8' ERROR
// We can re-use the MainCategory from stock_page.dart
import 'package:boitex_info_app/screens/administration/stock_page.dart';
// ✅ --- ADD THESE IMPORTS ---
import 'package:boitex_info_app/services/inventory_pdf_service.dart';
import 'package:boitex_info_app/services/inventory_csv_service.dart';
// ⛔️ REMOVED: printing.dart (no longer used by mobile)
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ ADDED FOR WEB CHECK
import 'package:file_saver/file_saver.dart'; // ✅ ADDED FOR WEB DOWNLOAD

// ✅ --- RE-ADD THESE IMPORTS FOR MOBILE SHARING ---
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// ✅ --- END OF IMPORTS ---

// ✅ --- NEW IMPORTS FOR IN-APP VIEWERS ---
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';
import 'package:boitex_info_app/widgets/csv_viewer_page.dart';
// ✅ --- END OF IMPORTS ---

// --- ✨ NEW BRIGHT THEME COLORS ✨ ---
class ReportTheme {
  static const Color background = Color(0xFFF8FAFC); // Light Gray
  static const Color card = Colors.white;
  static const Color surface = Color(0xFFF1F5F9); // Light Gray for inputs
  static const Color primary = Color(0xFF0EA5E9); // Default Blue
  static const Color accentGreen = Color(0xFF16A34A);
  static const Color accentRed = Color(0xFFDC2626);
  static const Color accentOrange = Color(0xFFEA580C);
  static const Color text = Color(0xFF0F172A); // Deep Navy Blue
  static const Color textSecondary = Color(0xFF64748B); // Medium Gray
}
// --- ✨ END OF THEME ✨ ---

class InventoryReportPage extends StatefulWidget {
  const InventoryReportPage({super.key});

  @override
  State<InventoryReportPage> createState() => _InventoryReportPageState();
}

class _InventoryReportPageState extends State<InventoryReportPage>
    with TickerProviderStateMixin {
  // Filter States
  MainCategory? _selectedMainCategory;
  String? _selectedSubCategory;
  String _stockFilter = 'Tous'; // 'Tous', 'En Stock', 'En Rupture'

  // Data States
  List<String> _subCategories = [];
  bool _isFetchingSubCategories = false;
  bool _isLoadingReport = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _products = [];
  bool _isExporting = false; // To show loading spinner on buttons

  // Animation Controllers for smooth transitions
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<MainCategory> _mainCategories = [
    MainCategory(
        name: 'Antivol',
        icon: Icons.shield_rounded,
        color: const Color(0xFF667EEA)),
    MainCategory(
        name: 'TPV',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFFEC4899)),
    MainCategory(
        name: 'Compteur Client',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF10B981)),
  ];

  @override
  void initState() {
    super.initState();
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
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// ✅ NEW: Helper to abbreviate large stock quantities for display (keeps full ints for exports/filters)
  String _formatStockDisplay(int quantity) {
    if (quantity >= 1000000) {
      return NumberFormat('#,##0.0', 'fr_FR').format(quantity / 1000000) + 'M';
    } else if (quantity >= 1000) {
      return NumberFormat('#,##0', 'fr_FR').format(quantity / 1000) + 'K';
    } else {
      return quantity.toString();
    }
  }

  /// Fetches the unique list of sub-categories for the selected main category
  Future<void> _fetchSubCategories(String mainCategory) async {
    if (_isFetchingSubCategories) return;

    setState(() {
      _isFetchingSubCategories = true;
      _selectedSubCategory = null; // Reset sub-category
      _subCategories = [];
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('mainCategory', isEqualTo: mainCategory)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _isFetchingSubCategories = false;
        });
        return;
      }

      // Use a Set to get unique category names
      final Set<String> categories = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('categorie') && data['categorie'] != null) {
          categories.add(data['categorie'] as String);
        }
      }

      final List<String> sortedList = categories.toList()..sort();

      setState(() {
        _subCategories = sortedList;
        _isFetchingSubCategories = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print("Error fetching sub-categories: $e");
      setState(() {
        _isFetchingSubCategories = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
              Text('Erreur lors du chargement des sous-catégories: $e')),
        );
      }
    }
  }

  /// Runs the main query to generate the report data
  Future<void> _runReport() async {
    setState(() {
      _isLoadingReport = true;
      _products = [];
    });

    try {
      Query<Map<String, dynamic>> query =
      FirebaseFirestore.instance.collection('produits');

      // 1. Filter by Main Category (required)
      if (_selectedMainCategory != null) {
        query =
            query.where('mainCategory', isEqualTo: _selectedMainCategory!.name);
      } else {
        // We require a main category to be selected
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Veuillez sélectionner une catégorie principale.')),
          );
        }
        setState(() {
          _isLoadingReport = false;
        });
        return;
      }

      // 2. Filter by Sub-Category (optional)
      if (_selectedSubCategory != null) {
        query = query.where('categorie', isEqualTo: _selectedSubCategory);
      }

      // 3. Filter by Stock Level (client-side)
      final snapshot = await query.orderBy('nom').get();
      List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredProducts =
          snapshot.docs;

      // Apply stock filter on the client side
      if (_stockFilter == 'En Stock') {
        filteredProducts = filteredProducts.where((doc) {
          final data = doc.data();
          final quantity = (data['quantiteEnStock'] ?? 0) as num;
          return quantity > 0;
        }).toList();
      } else if (_stockFilter == 'En Rupture') {
        filteredProducts = filteredProducts.where((doc) {
          final data = doc.data();
          final quantity = (data['quantiteEnStock'] ?? 0) as num;
          return quantity <= 0;
        }).toList();
      }

      setState(() {
        _products = filteredProducts;
        _isLoadingReport = false;
      });

      if (_products.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Aucun produit trouvé pour ces filtres.')),
          );
        }
      } else {
        _scaleController
          ..reset()
          ..forward(); // Animate list entrance
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error running report: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la génération: $e')),
        );
      }
      setState(() {
        _isLoadingReport = false;
      });
    }
  }

  // ✅ --- START: PDF EXPORT FUNCTION (MOBILE + WEB) ---
  void _generatePdf() async {
    if (_isExporting || _products.isEmpty) return;

    setState(() => _isExporting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final title = 'Rapport d\'Inventaire: ${_selectedMainCategory!.name}';
      final filters =
          'Filtres: ${_selectedSubCategory ?? 'Toutes sous-catégories'} | Statut: $_stockFilter';

      // Service expects List<DocumentSnapshot<Object?>>
      final List<DocumentSnapshot<Object?>> exportDocs =
      _products.cast<DocumentSnapshot<Object?>>();

      final pdfData = await InventoryPdfService.generateInventoryPdf(
        exportDocs,
        title,
        filters,
      );

      final String fileName =
          'Rapport_Inventaire_${_selectedMainCategory!.name.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';

      if (kIsWeb) {
        // --- WEB LOGIC (Direct Download) ---
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: pdfData,
          mimeType: MimeType.pdf,
        );
      } else {
        // --- MOBILE LOGIC (Open In-App PDF Viewer) ---
        if (!mounted) return; // Check if the widget is still in the tree
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
      // ignore: avoid_print
      print("Error generating PDF: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erreur lors de la création du PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
  // ✅ --- END: PDF EXPORT FUNCTION ---

  // ✅ --- START: CSV EXPORT FUNCTION (MOBILE + WEB) ---
  void _generateCsv() async {
    if (_isExporting || _products.isEmpty) return;

    setState(() => _isExporting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Service expects List<DocumentSnapshot<Object?>>
      final List<DocumentSnapshot<Object?>> exportDocs =
      _products.cast<DocumentSnapshot<Object?>>();

      // 1. Generate the CSV String
      final csvData = InventoryCsvService.generateInventoryCsv(exportDocs);

      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final categoryName = _selectedMainCategory!.name.replaceAll(' ', '_');
      final fileName = 'Inventaire_${categoryName}_$date.csv';

      if (kIsWeb) {
        // --- WEB LOGIC (Direct Download) ---
        final Uint8List bytes =
        utf8.encode(csvData); // 'utf8' is from dart:convert
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: bytes,
          mimeType: MimeType.csv,
        );
      } else {
        // --- MOBILE LOGIC (Show options dialog) ---

        // 1. Save the file to a temporary directory
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/$fileName';
        final file = File(path);
        await file.writeAsString(csvData, encoding: utf8);

        // 2. Show a dialog with options
        if (!mounted) return;

        // Find the button's position for iPad
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        final sharePosition = renderBox != null
            ? renderBox.localToGlobal(Offset.zero) & renderBox.size
            : Rect.fromCenter(
          center: Offset(MediaQuery.of(context).size.width / 2,
              MediaQuery.of(context).size.height / 2),
          width: 0,
          height: 0,
        );

        await showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (builderContext) {
            return Container(
              margin: const EdgeInsets.all(12).copyWith(
                  bottom: MediaQuery.of(builderContext).padding.bottom + 12),
              decoration: BoxDecoration(
                color: ReportTheme.card,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SafeArea(
                child: Wrap(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Exporter CSV',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    ListTile(
                      leading:
                      Icon(Icons.visibility, color: ReportTheme.primary),
                      title: const Text('Prévisualiser le CSV'),
                      onTap: () {
                        Navigator.of(builderContext).pop(); // Close bottom sheet
                        Navigator.of(context).push(
                          // Use main context
                          MaterialPageRoute(
                            builder: (context) => CsvViewerPage(
                              csvData: csvData,
                              title: fileName,
                              fieldDelimiter: ';', // Match your service
                            ),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading:
                      Icon(Icons.share, color: ReportTheme.accentGreen),
                      title: const Text('Partager / Enregistrer'),
                      onTap: () async {
                        Navigator.of(builderContext).pop(); // Close bottom sheet
                        await Share.shareXFiles(
                          [XFile(path, mimeType: 'text/csv')],
                          subject:
                          'Rapport d\'Inventaire - ${_selectedMainCategory!.name}',
                          sharePositionOrigin: sharePosition,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error generating CSV: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erreur lors de la création du CSV: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
  // ✅ --- END: CSV EXPORT FUNCTION ---

  @override
  Widget build(BuildContext context) {
    // Responsive design for phone and web
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebOrTablet = screenWidth > 600;
    final isWideWeb = screenWidth > 1200; // ✅ NEW: For extra-wide web layouts
    final paddingHorizontal = isWebOrTablet ? 32.0 : 16.0;

    // --- ✨ NEW BRIGHT THEME LOGIC ✨ ---
    final Color accentColor =
        _selectedMainCategory?.color ?? ReportTheme.primary;

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light, // Set theme to light
        scaffoldBackgroundColor: ReportTheme.background,
        primaryColor: accentColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.light,
          background: ReportTheme.background,
          surface: ReportTheme.card,
          primary: accentColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle:
          SystemUiOverlayStyle.dark, // Dark icons for light bg
          iconTheme: IconThemeData(color: ReportTheme.text),
          titleTextStyle: TextStyle(
            color: ReportTheme.text,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: ReportTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: ReportTheme.surface,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentColor, width: 2),
          ),
          labelStyle: const TextStyle(color: ReportTheme.textSecondary),
          hintStyle: const TextStyle(color: ReportTheme.textSecondary),
        ),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: ReportTheme.text,
          displayColor: ReportTheme.text,
        ),
        iconTheme: const IconThemeData(color: ReportTheme.textSecondary),
        dividerTheme:
        DividerThemeData(color: ReportTheme.surface, thickness: 1),
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Rapport d'Inventaire"),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.8),
                  Colors.white.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    paddingHorizontal,
                    kToolbarHeight +
                        MediaQuery.of(context).padding.top +
                        20, // Padded below app bar
                    paddingHorizontal,
                    16),
                sliver: SliverToBoxAdapter(
                  child: _buildFilterSection(
                      isWebOrTablet, isWideWeb, accentColor),
                ),
              ),
              // --- LOADING INDICATOR ---
              if (_isLoadingReport)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                  ),
                ),
              // --- RESULTS LIST ---
              // Add padding for the floating buttons
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: 120, // Space for the bottom bar
                  left: paddingHorizontal,
                  right: paddingHorizontal,
                ),
                sliver: _buildResultsList(),
              ),
            ],
          ),
        ),
        // --- ✨ NEW 2026 BOTTOM EXPORT BAR (SYMMETRICAL) ✨ ---
        bottomNavigationBar: _products.isNotEmpty
            ? _buildBottomExportBar(accentColor)
            : null,
      ),
    );
  }

  // --- ✨ NEW 2026 SYMMETRICAL BOTTOM BAR ✨ ---
  Widget _buildBottomExportBar(Color accentColor) {
    return ScaleTransition(
      scale: _scaleController,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: ReportTheme.card,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ],
          border: Border(
            top: BorderSide(color: ReportTheme.surface, width: 1),
          ),
        ),
        child: Row(
          children: [
            // --- CSV BUTTON ---
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _generateCsv,
                icon: _isExporting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.table_rows_outlined),
                label: const Text('Export CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ReportTheme.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // --- PDF BUTTON ---
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _generatePdf,
                icon: _isExporting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ReportTheme.accentRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ✨ NEW 2026 BRIGHT FILTER SECTION (FULL OVERFLOW FIXED) ✨ ---
  Widget _buildFilterSection(
      bool isWebOrTablet, bool isWideWeb, Color accentColor) {
    // ✅ FIXED: Local screenWidth declaration to avoid getter error
    final screenWidth = MediaQuery.of(context).size.width;

    // ✅ IMPROVED: Horizontal scroll only for web, with constrained width
    final Widget filterContent = SizedBox(
      width: screenWidth, // Full available width
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
                  accentColor,
                  accentColor.withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Text(
              'Filtres de Rapport',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          // Main Category Selection (Ultra-Responsive)
          isWideWeb
              ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _mainCategories.map((category) {
              final isSelected =
                  _selectedMainCategory?.name == category.name;
              return Flexible(
                flex: 1, // ✅ EQUAL FLEX FOR EVEN SPACING
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(category.icon,
                          color: isSelected
                              ? Colors.white
                              : category.color,
                          size: 16), // ✅ FURTHER REDUCED
                      const SizedBox(width: 4), // ✅ TIGHTER
                      Flexible(
                        child: Text(
                          category.name,
                          style: TextStyle(
                              fontSize: 11), // ✅ SMALLER FONT
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedMainCategory = category;
                        _selectedSubCategory = null;
                        _subCategories = [];
                      });
                      _fetchSubCategories(category.name);
                    }
                  },
                  selectedColor: category.color,
                  backgroundColor: ReportTheme.surface,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : ReportTheme.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 11, // ✅ SMALLER FONT
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? category.color
                          : Colors.transparent,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4), // ✅ EVEN TIGHTER
                ),
              );
            }).toList(),
          )
              : Wrap(
            spacing: 4.0, // ✅ TIGHTER FROM 6
            runSpacing: 4.0, // ✅ TIGHTER FROM 6
            alignment: WrapAlignment.center,
            children: _mainCategories.map((category) {
              final isSelected =
                  _selectedMainCategory?.name == category.name;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(category.icon,
                        color: isSelected
                            ? Colors.white
                            : category.color,
                        size: 16), // ✅ FURTHER REDUCED
                    const SizedBox(width: 4), // ✅ TIGHTER
                    Flexible(
                      child: Text(
                        category.name,
                        style: TextStyle(
                            fontSize: 11), // ✅ SMALLER FONT
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedMainCategory = category;
                      _selectedSubCategory = null;
                      _subCategories = [];
                    });
                    _fetchSubCategories(category.name);
                  }
                },
                selectedColor: category.color,
                backgroundColor: ReportTheme.surface,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : ReportTheme.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 11, // ✅ SMALLER FONT
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? category.color
                        : Colors.transparent,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4), // ✅ EVEN TIGHTER
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // Sub Category Dropdown
          if (_selectedMainCategory != null)
            DropdownButtonFormField<String>(
              value: _selectedSubCategory,
              hint: const Text('Sélectionner Sous-Catégorie (Optionnel)'),
              isExpanded: true,
              dropdownColor: ReportTheme.card,
              decoration: InputDecoration(
                labelText: 'Sous-Catégorie',
                prefixIcon: Icon(
                  Icons.subdirectory_arrow_right,
                  color: accentColor,
                ),
                suffixIcon: _isFetchingSubCategories
                    ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : null,
              ),
              items: _subCategories
                  .map<DropdownMenuItem<String>>(
                    (category) => DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                ),
              )
                  .toList(),
              onChanged: _isFetchingSubCategories
                  ? null
                  : (String? newValue) {
                setState(() {
                  _selectedSubCategory = newValue;
                });
              },
            ),
          const SizedBox(height: 16),

          // ✅ --- STOCK FILTER: ULTRA-RESPONSIVE ---
          isWideWeb
              ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStockFilterChip('Tous', accentColor),
              const SizedBox(width: 4), // ✅ TIGHTER
              _buildStockFilterChip('En Stock', accentColor),
              const SizedBox(width: 4), // ✅ TIGHTER
              _buildStockFilterChip('En Rupture', accentColor),
            ],
          )
              : Wrap(
            spacing: 4.0, // ✅ TIGHTER
            runSpacing: 4.0, // ✅ TIGHTER
            alignment: WrapAlignment.center,
            children: [
              _buildStockFilterChip('Tous', accentColor),
              _buildStockFilterChip('En Stock', accentColor),
              _buildStockFilterChip('En Rupture', accentColor),
            ],
          ),

          const SizedBox(height: 24),
          // Generate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isLoadingReport
                  ? Container(
                width: 20,
                height: 20,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.query_stats_rounded),
              label: const Text('Générer le Rapport'),
              onPressed: _isLoadingReport || _selectedMainCategory == null
                  ? null
                  : _runReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
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
        ],
      ),
    );

    // ✅ FIXED: Conditional horizontal scroll only for web, wrapped in Padding
    return Container(
      padding: EdgeInsets.all(isWebOrTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: ReportTheme.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
        border: Border.all(color: ReportTheme.surface),
      ),
      child: isWebOrTablet
          ? SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: 16.0), // ✅ MINIMAL HORIZONTAL PAD
        child: filterContent,
      )
          : filterContent,
    );
  }

  // ✅ HELPER: Stock Filter Chip (Reusable, Overflow-Proof)
  Widget _buildStockFilterChip(String label, Color accentColor) {
    final isSelected = _stockFilter == label;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(fontSize: 11), // ✅ SMALLER FONT
        overflow: TextOverflow.ellipsis,
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _stockFilter = label);
        }
      },
      selectedColor: accentColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : ReportTheme.text,
        fontWeight: FontWeight.bold,
        fontSize: 11, // ✅ SMALLER FONT
      ),
      backgroundColor: ReportTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? accentColor : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // ✅ TIGHTER
    );
  }

  // --- ✨ NEW 2026 BRIGHT RESULTS LIST (OVERFLOW FULLY RESOLVED) ✨ ---
  Widget _buildResultsList() {
    if (_products.isEmpty && !_isLoadingReport) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 80,
                color: ReportTheme.surface,
              ),
              const SizedBox(height: 16),
              const Text(
                'Les résultats du rapport apparaîtront ici.',
                style: TextStyle(fontSize: 16, color: ReportTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverList.separated(
      itemCount: _products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final Map<String, dynamic> productData = _products[index].data();
        final num stockQuantityNum =
        (productData['quantiteEnStock'] ?? 0) as num;
        final int stockQuantity = stockQuantityNum.toInt();

        // Determine stock color and icon
        Color stockColor;
        IconData stockIcon;
        String stockLabel;

        if (stockQuantity > 5) {
          stockColor = ReportTheme.accentGreen;
          stockIcon = Icons.check_circle_rounded;
          stockLabel = 'En Stock';
        } else if (stockQuantity > 0) {
          stockColor = ReportTheme.accentOrange;
          stockIcon = Icons.warning_rounded;
          stockLabel = 'Stock Faible';
        } else {
          stockColor = ReportTheme.accentRed;
          stockIcon = Icons.error_rounded;
          stockLabel = 'En Rupture';
        }

        return SlideTransition(
          position: _slideAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: ReportTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ReportTheme.surface),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8), // ✅ REDUCED VERTICAL
              leading: ConstrainedBox(
                // ✅ NEW: CONSTRAIN LEADING WIDTH
                constraints:
                const BoxConstraints(maxWidth: 50), // ✅ TIGHT BOUND
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatStockDisplay(
                          stockQuantity), // ✅ ABBREVIATED FOR LONG NUMBERS
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: stockColor,
                        fontSize: 20, // ✅ REDUCED FROM 24
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Text(
                      'Stock',
                      style: TextStyle(
                        color: ReportTheme.textSecondary,
                        fontSize: 10, // ✅ REDUCED FROM 12
                      ),
                      textAlign: TextAlign.center,
                    )
                  ],
                ),
              ),
              title: Flexible(
                // ✅ WRAP FOR RESPONSIVE
                child: Text(
                  productData['nom'] ?? 'Nom inconnu',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: ReportTheme.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2, // ✅ ALLOW SLIGHT MULTI-LINE FOR LONG NAMES
                ),
              ),
              subtitle: Flexible(
                // ✅ WRAP FOR RESPONSIVE (NOW ONLY REFERENCE)
                child: Padding(
                  padding: const EdgeInsets.only(top: 2.0), // ✅ TIGHTER SPACING
                  child: Text(
                    'Réf: ${productData['reference'] ?? 'N/A'}',
                    style: TextStyle(
                      color: ReportTheme.textSecondary,
                      fontSize: 11, // ✅ REDUCED FONT
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              trailing: ConstrainedBox(
                // ✅ CONSTRAIN WIDTH TO PREVENT EXPANSION
                constraints:
                const BoxConstraints(maxWidth: 120), // ✅ FIXED MAX WIDTH
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: stockColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(stockIcon, color: stockColor, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          stockLabel,
                          style: TextStyle(
                            color: stockColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11, // ✅ REDUCED FONT
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
              },
            ),
          ),
        );
      },
    );
  }
}
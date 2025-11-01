// lib/screens/administration/inventory_report_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for HapticFeedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:intl/intl.dart';
// We can re-use the MainCategory from stock_page.dart
import 'package:boitex_info_app/screens/administration/stock_page.dart';
// ✅ --- ADD THESE IMPORTS ---
import 'package:boitex_info_app/services/inventory_pdf_service.dart';
import 'package:boitex_info_app/services/inventory_csv_service.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// ✅ --- END OF IMPORTS ---

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

  // ✅ --- THIS IS THE CORRECTED LIST ---
  // This list now matches your stock_page.dart and product_catalog_page.dart
  final List<MainCategory> _mainCategories = [
    MainCategory(name: 'Antivol', icon: Icons.shield_rounded, color: const Color(0xFF667EEA)),
    MainCategory(name: 'TPV', icon: Icons.point_of_sale_rounded, color: const Color(0xFFEC4899)),
    MainCategory(name: 'Compteur Client', icon: Icons.people_alt_rounded, color: const Color(0xFF10B981)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des sous-catégories: $e')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez sélectionner une catégorie principale.')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun produit trouvé pour ces filtres.')),
        );
      } else {
        _scaleController
          ..reset()
          ..forward(); // Animate list entrance
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error running report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la génération: $e')),
      );
      setState(() {
        _isLoadingReport = false;
      });
    }
  }

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

      await Printing.layoutPdf(onLayout: (format) => pdfData);
    } catch (e) {
      // ignore: avoid_print
      print("Error generating PDF: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erreur lors de la création du PDF: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _generateCsv() async {
    if (_isExporting || _products.isEmpty) return;

    setState(() => _isExporting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Service expects List<DocumentSnapshot<Object?>>
      final List<DocumentSnapshot<Object?>> exportDocs =
      _products.cast<DocumentSnapshot<Object?>>();

      final csvData = InventoryCsvService.generateInventoryCsv(exportDocs);

      final tempDir = await getTemporaryDirectory();
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final categoryName = _selectedMainCategory!.name.replaceAll(' ', '_');
      final path = '${tempDir.path}/Inventaire_${categoryName}_$date.csv';

      final file = File(path);
      await file.writeAsString(csvData, encoding: const SystemEncoding());

      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/csv')],
        subject: 'Rapport d\'Inventaire - ${_selectedMainCategory!.name}',
      );
    } catch (e) {
      // ignore: avoid_print
      print("Error generating CSV: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erreur lors de la création du CSV: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive design for phone and web
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebOrTablet = screenWidth > 600;
    final paddingHorizontal = isWebOrTablet ? 32.0 : 16.0;

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _selectedMainCategory?.color ?? Colors.blue,
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
            "Rapport d'Inventaire",
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
                  _selectedMainCategory?.color ?? Colors.blue,
                  (_selectedMainCategory?.color ?? Colors.blue).withOpacity(0.8),
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
                if (_isLoadingReport)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
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
        // --- ACTION BUTTONS ---
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _products.isNotEmpty
            ? AnimatedBuilder(
          animation: _scaleController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleController.value,
              child: FloatingActionButton.extended(
                heroTag: "pdf",
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                icon: _isExporting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.picture_as_pdf),
                label: const Text('PDF'),
                onPressed: _isExporting ? null : _generatePdf,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
        )
            : null,
        bottomNavigationBar: _products.isNotEmpty
            ? Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedBuilder(
                    animation: _scaleController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleController.value,
                        child: ElevatedButton.icon(
                          icon: _isExporting
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                              : const Icon(Icons.table_rows_outlined),
                          label: const Text('CSV'),
                          onPressed: _isExporting ? null : _generateCsv,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        )
            : null,
      ),
    );
  }

  Widget _buildFilterSection(bool isWideScreen) {
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
                  _selectedMainCategory?.color ?? Colors.grey.shade300,
                  (_selectedMainCategory?.color ?? Colors.grey.shade300)
                      .withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 20),
          // Main Category Selection - Use Chips for colorful, elegant selection
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _mainCategories.map((category) {
              final isSelected = _selectedMainCategory?.name == category.name;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(category.icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(category.name),
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
                backgroundColor: category.color.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? category.color : Colors.grey.shade300,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Sub Category Dropdown
          if (_selectedMainCategory != null)
            DropdownButtonFormField<String>(
              value: _selectedSubCategory,
              hint: const Text('Sélectionner Sous-Catégorie (Optionnel)'),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Sous-Catégorie',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: _selectedMainCategory!.color.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: _selectedMainCategory!.color.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  BorderSide(color: _selectedMainCategory!.color, width: 2),
                ),
                prefixIcon: Icon(
                  Icons.subdirectory_arrow_right,
                  color: _selectedMainCategory!.color,
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
          // Stock Filter - Use Segmented Button for modern look
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: 'Tous', label: Text('Tous')),
              ButtonSegment<String>(value: 'En Stock', label: Text('En Stock')),
              ButtonSegment<String>(
                  value: 'En Rupture', label: Text('En Rupture')),
            ],
            selected: {_stockFilter},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _stockFilter = newSelection.first;
              });
            },
            style: SegmentedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Generate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.query_stats),
              label: const Text('Générer le Rapport'),
              onPressed: _isLoadingReport ? null : _runReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedMainCategory?.color ?? Colors.blue,
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
  }

  Widget _buildResultsList() {
    if (_products.isEmpty && !_isLoadingReport) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Veuillez sélectionner vos filtres et générer le rapport.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final Map<String, dynamic> productData = _products[index].data();
        final num stockQuantityNum = (productData['quantiteEnStock'] ?? 0) as num;
        final int stockQuantity = stockQuantityNum.toInt();

        // Determine stock color and icon
        Color stockColor;
        IconData stockIcon;
        if (stockQuantity > 5) {
          stockColor = Colors.green.shade600;
          stockIcon = Icons.check_circle;
        } else if (stockQuantity > 0) {
          stockColor = Colors.orange.shade600;
          stockIcon = Icons.warning_amber;
        } else {
          stockColor = Colors.red.shade600;
          stockIcon = Icons.error;
        }

        return SlideTransition(
          position: _slideAnimation,
          child: Card(
            elevation: 4,
            shadowColor: stockColor.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: stockColor.withOpacity(0.1),
                child: Icon(
                  stockIcon,
                  color: stockColor,
                  size: 24,
                ),
              ),
              title: Text(
                productData['nom'] ?? 'Nom inconnu',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Référence: ${productData['reference'] ?? 'N/A'}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  if (productData['categorie'] != null)
                    Text(
                      'Catégorie: ${productData['categorie']}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory,
                    color: stockColor,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stockQuantity.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: stockColor,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              onTap: () {
                // Add ripple effect or navigation if needed
                HapticFeedback.lightImpact();
              },
            ),
          ),
        );
      },
    );
  }
}

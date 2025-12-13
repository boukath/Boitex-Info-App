// lib/screens/administration/product_catalog_page.dart

import 'dart:async'; // ✅ ADDED: For Timer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ ADDED: For Hardware Keys
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ ADDED: For Database Search
import 'package:boitex_info_app/screens/administration/add_product_page.dart';
import 'package:boitex_info_app/screens/administration/category_list_page.dart';
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';
import 'package:boitex_info_app/screens/administration/product_details_page.dart'; // ✅ ADDED: To open details

// Helper class to hold style info for our main sections
class MainCategory {
  final String name;
  final IconData icon;
  final Color color;

  MainCategory({required this.name, required this.icon, required this.color});
}

class ProductCatalogPage extends StatefulWidget {
  const ProductCatalogPage({super.key});

  @override
  State<ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _ProductCatalogPageState extends State<ProductCatalogPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // 🔥 1. ZEBRA/YOKOSCAN VARIABLES
  final StringBuffer _keyBuffer = StringBuffer();
  Timer? _bufferTimer;

  final List<MainCategory> _allCategories = [
    MainCategory(name: 'Antivol', icon: Icons.shield_rounded, color: const Color(0xFF667EEA)),
    MainCategory(name: 'TPV', icon: Icons.point_of_sale_rounded, color: const Color(0xFFEC4899)),
    MainCategory(name: 'Compteur Client', icon: Icons.people_alt_rounded, color: const Color(0xFF10B981)),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _bufferTimer?.cancel(); // ✅ Clean up timer
    super.dispose();
  }

  // 🔥 2. HARDWARE KEY LISTENER (Engine B)
  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final String? character = event.character;

    // Detect "Enter" key (Scan complete)
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_keyBuffer.isNotEmpty) {
        String scanData = _keyBuffer.toString().trim();
        _keyBuffer.clear();
        print("CATALOG SCAN DETECTED: $scanData");
        _handleScannedBarcode(scanData); // 🔥 Trigger Search
      }
      return;
    }

    // Accumulate characters
    if (character != null && character.isNotEmpty) {
      _keyBuffer.write(character);
      // Reset timer: if no key for 200ms, clear buffer
      _bufferTimer?.cancel();
      _bufferTimer = Timer(const Duration(milliseconds: 200), () {
        _keyBuffer.clear();
      });
    }
  }

  // 🔥 3. SEARCH & NAVIGATE LOGIC
  Future<void> _handleScannedBarcode(String scannedCode) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Search in Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('reference', isEqualTo: scannedCode)
          .limit(1)
          .get();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (querySnapshot.docs.isNotEmpty) {
        // ✅ FOUND: Navigate directly to details
        final productDoc = querySnapshot.docs.first;
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProductDetailsPage(productDoc: productDoc),
            ),
          );
        }
      } else {
        // ❌ NOT FOUND
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Aucun produit trouvé pour : $scannedCode'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      // Error handling
      if (mounted) Navigator.of(context).pop(); // Ensure loading is closed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la recherche: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🛡️ WRAP SCAFFOLD IN FOCUS TO CATCH HARDWARE SCANNER INPUT
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _onKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.purple.shade50,
                Colors.pink.shade50,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildCategoryList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddProductPage()),
              );
            },
            tooltip: 'Ajouter un produit',
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: const Icon(Icons.add_rounded, size: 32),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Produits',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // ✨ SEARCH BUTTON - Opens Global Product Search
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.white, size: 26),
              tooltip: 'Recherche globale',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GlobalProductSearchPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _allCategories.length,
      itemBuilder: (context, index) {
        final mainCategory = _allCategories[index];
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 100)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: mainCategory.color.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CategoryListPage(
                        mainCategory: mainCategory.name,
                        mainCategoryColor: mainCategory.color,
                        mainCategoryIcon: mainCategory.icon,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              mainCategory.color,
                              mainCategory.color.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: mainCategory.color.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          mainCategory.icon,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mainCategory.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Voir les produits',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: mainCategory.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 18,
                          color: mainCategory.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
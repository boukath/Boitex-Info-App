// lib/screens/administration/stock_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/stock_category_list_page.dart';
import 'package:boitex_info_app/screens/administration/add_requisition_page.dart';
import 'package:boitex_info_app/screens/administration/product_scanner_page.dart';
import 'package:boitex_info_app/screens/administration/antivol_config/antivol_main_page.dart';
import 'package:boitex_info_app/screens/administration/product_list_page.dart';

// Helper class to hold style info for our main sections
class MainCategory {
  final String name;
  final IconData icon;
  final Color color;
  MainCategory({required this.name, required this.icon, required this.color});
}

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ NEW: Search across ALL products in Firestore
  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final queryLower = query.toLowerCase();

      // Search in product names and references
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .get();

      final results = snapshot.docs.where((doc) {
        final data = doc.data();
        final productName = (data['nom'] ?? '').toString().toLowerCase();
        final reference = (data['reference'] ?? '').toString().toLowerCase();
        final category = (data['categorie'] ?? '').toString().toLowerCase();

        return productName.contains(queryLower) ||
            reference.contains(queryLower) ||
            category.contains(queryLower);
      }).toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de recherche: $e')),
        );
      }
    }
  }

  Future<void> _scanProduct(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final String? scannedCode = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProductScannerPage()),
    );

    if (scannedCode == null || scannedCode.isEmpty) {
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('reference', isEqualTo: scannedCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final productData = querySnapshot.docs.first.data();
        final productName = productData['nom'] ?? 'Nom inconnu';
        final stockQuantity = productData['quantiteEnStock'] ?? 0;

        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(productName),
            content: Text(
              'Quantité en stock: $stockQuantity',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Produit non trouvé'),
            content: Text('Aucun produit trouvé pour le code: $scannedCode'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la recherche du produit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<MainCategory> mainCategories = [
      MainCategory(name: 'Antivol', icon: Icons.shield_outlined, color: Colors.blue),
      MainCategory(name: 'TPV', icon: Icons.point_of_sale_outlined, color: Colors.purple),
      MainCategory(name: 'Compteur Client', icon: Icons.people_alt_outlined, color: Colors.teal),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock par Section'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scanner un produit',
            onPressed: () => _scanProduct(context),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Configuration Antivol',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AntivolMainPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Search bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un produit, référence ou catégorie...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _searchResults = [];
                    });
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _searchProducts(value);
              },
            ),
          ),

          // ✅ Show search results OR main categories
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults()
                : _buildMainCategories(mainCategories),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddRequisitionPage()),
          );
        },
        label: const Text('Demande d\'Achat'),
        icon: const Icon(Icons.add_shopping_cart),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Aucun produit trouvé',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            Text(
              'pour "$_searchQuery"',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final doc = _searchResults[index];
        final data = doc.data() as Map<String, dynamic>;
        final productName = data['nom'] ?? 'Sans nom';
        final reference = data['reference'] ?? 'N/A';
        final stock = data['quantiteEnStock'] ?? 0;
        final mainCategory = data['mainCategory'] ?? 'N/A';
        final category = data['categorie'] ?? 'N/A';

        // Determine color based on main category
        Color categoryColor = Colors.grey;
        if (mainCategory == 'Antivol') {
          categoryColor = Colors.blue;
        } else if (mainCategory == 'TPV') {
          categoryColor = Colors.purple;
        } else if (mainCategory == 'Compteur Client') {
          categoryColor = Colors.teal;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: categoryColor.withOpacity(0.1),
              child: Icon(Icons.inventory_2, color: categoryColor),
            ),
            title: Text(
              productName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Référence: $reference', style: const TextStyle(fontSize: 12)),
                Text('$mainCategory > $category',
                  style: TextStyle(fontSize: 11, color: categoryColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: stock > 0 ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$stock',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
            onTap: () {
              // Navigate to product details (optional)
              // You can add navigation to product details page here
            },
          ),
        );
      },
    );
  }

  Widget _buildMainCategories(List<MainCategory> mainCategories) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
      itemCount: mainCategories.length,
      itemBuilder: (context, index) {
        final mainCategory = mainCategories[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: mainCategory.color.withOpacity(0.1),
              child: Icon(mainCategory.icon, color: mainCategory.color),
            ),
            title: Text(
              mainCategory.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => StockCategoryListPage(
                    mainCategory: mainCategory.name,
                    mainCategoryColor: mainCategory.color,
                    mainCategoryIcon: mainCategory.icon,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

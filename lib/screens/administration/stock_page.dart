// lib/screens/administration/stock_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ ADDED
import 'package:boitex_info_app/screens/administration/stock_category_list_page.dart';
import 'package:boitex_info_app/screens/administration/add_requisition_page.dart';
import 'package:boitex_info_app/screens/administration/product_scanner_page.dart'; // ✅ ADDED
// ✅ 1. NOUVEL IMPORT pour la page de configuration
import 'package:boitex_info_app/screens/administration/antivol_config/antivol_main_page.dart';

// Helper class to hold style info for our main sections
class MainCategory {
  final String name;
  final IconData icon;
  final Color color;

  MainCategory({required this.name, required this.icon, required this.color});
}

class StockPage extends StatelessWidget {
  const StockPage({super.key});

  // ✅ ADDED: Function to handle the scan button press
  Future<void> _scanProduct(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Navigate to the scanner page and wait for a result
    final String? scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ProductScannerPage()),
    );

    if (scannedCode == null || scannedCode.isEmpty) {
      return; // User canceled the scan
    }

    try {
      // Search for the product in Firestore using the 'reference' field
      final querySnapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('reference', isEqualTo: scannedCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final productData = querySnapshot.docs.first.data();
        final productName = productData['nom'] ?? 'Nom inconnu';
        final stockQuantity = productData['quantiteEnStock'] ?? 0;

        // Show the result in a success dialog
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
        // Show a "not found" dialog
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
      // Show an error message if something goes wrong
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
        // ✅ MODIFIÉ: Liste des actions
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scanner un produit',
            onPressed: () => _scanProduct(context),
          ),
          // ✅ 2. BOUTON AJOUTÉ
          IconButton(
            icon: const Icon(Icons.tune_rounded), // Icône 'tune' pour la configuration
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
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 80), // Padding for FAB
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
              title: Text(mainCategory.name, style: const TextStyle(fontWeight: FontWeight.bold)),
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
}
// lib/screens/administration/product_catalog_page.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/screens/administration/add_product_page.dart';
import 'package:boitex_info_app/screens/administration/category_list_page.dart';

// Helper class to hold style info for our main sections
class MainCategory {
  final String name;
  final IconData icon;
  final Color color;

  MainCategory({required this.name, required this.icon, required this.color});
}

class ProductCatalogPage extends StatelessWidget {
  const ProductCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ CHANGED: We now have a fixed list of main categories
    final List<MainCategory> mainCategories = [
      MainCategory(name: 'Antivol', icon: Icons.shield_outlined, color: Colors.blue),
      MainCategory(name: 'TPV', icon: Icons.point_of_sale_outlined, color: Colors.purple),
      MainCategory(name: 'Compteur Client', icon: Icons.people_alt_outlined, color: Colors.teal),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue des Produits'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
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
                // ✅ CHANGED: Navigate to our new category list page
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
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddProductPage()),
          );
        },
        tooltip: 'Ajouter un produit',
        child: const Icon(Icons.add),
      ),
    );
  }
}
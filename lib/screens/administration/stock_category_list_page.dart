// lib/screens/administration/stock_category_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/product_stock_list_page.dart';

class StockCategoryListPage extends StatelessWidget {
  final String mainCategory;
  final Color mainCategoryColor;
  final IconData mainCategoryIcon;

  const StockCategoryListPage({
    super.key,
    required this.mainCategory,
    required this.mainCategoryColor,
    required this.mainCategoryIcon,
  });

  Future<List<String>> _fetchSubCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('produits')
        .where('mainCategory', isEqualTo: mainCategory)
        .get();

    if (snapshot.docs.isEmpty) {
      return [];
    }

    final categories = <String>{};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('categorie')) {
        categories.add(data['categorie'] as String);
      }
    }

    final sortedList = categories.toList();
    sortedList.sort();
    return sortedList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stock - $mainCategory'),
        backgroundColor: mainCategoryColor,
      ),
      body: FutureBuilder<List<String>>(
        future: _fetchSubCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune catégorie trouvée dans cette section.'));
          }

          final categories = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final categoryName = categories[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: mainCategoryColor.withOpacity(0.1),
                    child: Icon(mainCategoryIcon, color: mainCategoryColor),
                  ),
                  title: Text(categoryName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // This is the key difference: navigates to the STOCK list page
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProductStockListPage(
                          category: categoryName,
                          categoryColor: mainCategoryColor,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
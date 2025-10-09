import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/product_details_page.dart';


class ProductListPage extends StatelessWidget {
  final String category;
  // **NEW**: Added categoryColor to accept the theme color
  final Color categoryColor;

  const ProductListPage({
    super.key,
    required this.category,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('produits')
            .where('categorie', isEqualTo: category)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucun produit trouvé dans cette catégorie.'));
          }

          final productDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            itemCount: productDocs.length,
            itemBuilder: (context, index) {
              final productDoc = productDocs[index];
              final productData = productDoc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  // **NEW**: Added a styled leading icon
                  leading: CircleAvatar(
                    backgroundColor: categoryColor.withOpacity(0.1),
                    child: Icon(Icons.inventory_2_outlined, color: categoryColor),
                  ),
                  title: Text(productData['nom'] ?? 'Nom inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Marque: ${productData['marque'] ?? 'N/A'}\nRéférence: ${productData['reference'] ?? 'N/A'}'),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProductDetailsPage(productDoc: productDoc),
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
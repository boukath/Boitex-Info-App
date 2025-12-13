import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/product_details_page.dart';

class ProductListPage extends StatelessWidget {
  final String category;
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
        backgroundColor: categoryColor,
        foregroundColor: Colors.white,
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

              // ✅ EXTRACT IMAGE URLS
              final List<dynamic>? images = productData['imageUrls'];
              final String? firstImageUrl = (images != null && images.isNotEmpty)
                  ? images.first.toString()
                  : null;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  // ✅ UPDATED LEADING WIDGET
                  leading: SizedBox(
                    width: 60,
                    height: 60,
                    child: firstImageUrl != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        firstImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback if image fails to load
                          return _buildFallbackIcon();
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                            ),
                          );
                        },
                      ),
                    )
                        : _buildFallbackIcon(), // No image available
                  ),
                  title: Text(
                      productData['nom'] ?? 'Nom inconnu',
                      style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  subtitle: Text(
                      'Marque: ${productData['marque'] ?? 'N/A'}\nRéférence: ${productData['reference'] ?? 'N/A'}'
                  ),
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

  // ✅ HELPER WIDGET FOR FALLBACK ICON
  Widget _buildFallbackIcon() {
    return Container(
      decoration: BoxDecoration(
        color: categoryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(Icons.inventory_2_outlined, color: categoryColor),
      ),
    );
  }
}
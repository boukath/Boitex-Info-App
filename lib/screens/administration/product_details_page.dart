import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/add_product_page.dart';

class ProductDetailsPage extends StatelessWidget {
  final DocumentSnapshot productDoc;

  const ProductDetailsPage({super.key, required this.productDoc});

  @override
  Widget build(BuildContext context) {
    final data = productDoc.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: Text(data['nom'] ?? 'Détails du Produit'),
        // **NEW**: Add Edit and Delete buttons to the AppBar
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: () {
              // Navigate to the form in "Edit Mode"
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddProductPage(productDoc: productDoc),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Supprimer',
            onPressed: () {
              // Show a confirmation dialog before deleting
              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Confirmer la Suppression'),
                    content: const Text('Êtes-vous sûr de vouloir supprimer ce produit ? Cette action est irréversible.'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Annuler'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                      TextButton(
                        child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                        onPressed: () async {
                          try {
                            await FirebaseFirestore.instance.collection('produits').doc(productDoc.id).delete();
                            Navigator.of(dialogContext).pop(); // Close dialog
                            Navigator.of(context).pop(); // Go back from details page
                          } catch (e) {
                            print("Error deleting product: $e");
                            Navigator.of(dialogContext).pop();
                          }
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const SizedBox(height: 8),
          Text(data['nom'] ?? 'Nom non disponible', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Chip(label: Text('Catégorie: ${data['categorie'] ?? 'N/A'}')),
          const SizedBox(height: 24),
          _buildDetailRow('Marque:', data['marque'] ?? 'N/A'),
          _buildDetailRow('Référence:', data['reference'] ?? 'N/A'),
          _buildDetailRow('Origine:', data['origine'] ?? 'N/A'),
          const Divider(height: 32),
          Text('Description', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(data['description'] ?? 'Aucune description.'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
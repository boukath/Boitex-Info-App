// lib/screens/administration/antivol_config/config_details_page.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/models/antivol_system.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigDetailsPage extends StatelessWidget {
  final String systemName;
  final AntivolConfiguration configuration;

  const ConfigDetailsPage({
    super.key,
    required this.systemName,
    required this.configuration,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(configuration.name), // ex: "Dual"
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              systemName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Configuration: ${configuration.name}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.blue.shade700, // Couleur pour le nom de la config
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Composants Requis:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // ✅ Construit la liste des produits avec leur stock
            _buildComponentList(),

            // ✅ Affiche la description (notes)
            if (configuration.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Notes de Configuration:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        configuration.description,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Construit la liste des composants en allant chercher les infos de stock
  Widget _buildComponentList() {
    final components = configuration.components;

    if (components.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('Aucun composant défini pour cette configuration.')),
      );
    }

    return ListView.builder(
      shrinkWrap: true, // Important dans un SingleChildScrollView
      physics: const NeverScrollableScrollPhysics(), // La page est déjà scrollable
      itemCount: components.length,
      itemBuilder: (context, index) {
        final component = components[index];

        // Crée une référence au document produit
        // IMPORTANT: Assurez-vous que votre collection de produits s'appelle 'produits'
        final productRef = FirebaseFirestore.instance.doc(component.productRef);

        return FutureBuilder<DocumentSnapshot>(
          future: productRef.get(),
          builder: (context, snapshot) {
            // --- État de chargement ---
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text('Chargement...'),
                  subtitle: Text('Vérification du stock...'),
                  trailing: CircularProgressIndicator(),
                ),
              );
            }

            // --- État d'erreur (ex: produit non trouvé) ---
            if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.red.shade50,
                child: ListTile(
                  title: const Text('Produit non trouvé', style: TextStyle(color: Colors.red)),
                  subtitle: Text('Référence: ${component.productRef}', style: const TextStyle(color: Colors.red)),
                  trailing: const Icon(Icons.error_outline, color: Colors.red),
                ),
              );
            }

            // --- État de succès ---
            final productData = snapshot.data!.data() as Map<String, dynamic>;
            final productName = productData['nom'] ?? 'Nom inconnu';
            // IMPORTANT: Assurez-vous que le champ de stock s'appelle 'quantiteEnStock'
            final stockQuantity = (productData['quantiteEnStock'] as num? ?? 0).toInt();

            final requiredQuantity = component.quantity;
            final hasEnoughStock = stockQuantity >= requiredQuantity;

            final Color stockColor = hasEnoughStock
                ? Colors.green.shade700
                : (stockQuantity > 0 ? Colors.orange.shade700 : Colors.red.shade700);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                title: Text(
                  productName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text('Requis: $requiredQuantity'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'En Stock: $stockQuantity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: stockColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      hasEnoughStock ? Icons.check_circle : Icons.warning_rounded,
                      color: stockColor,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
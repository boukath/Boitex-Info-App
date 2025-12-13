// lib/screens/administration/antivol_config/config_options_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ✅ 1. Import du modèle
import 'package:boitex_info_app/models/antivol_system.dart';
// ✅ 2. Import de la page suivante
import 'package:boitex_info_app/screens/administration/antivol_config/config_details_page.dart';

// ✅ 3. Converti en StatefulWidget pour gérer l'état de chargement et de stock
class ConfigOptionsPage extends StatefulWidget {
  final AntivolSystem system;

  const ConfigOptionsPage({
    super.key,
    required this.system,
  });

  @override
  State<ConfigOptionsPage> createState() => _ConfigOptionsPageState();
}

class _ConfigOptionsPageState extends State<ConfigOptionsPage> {
  // ✅ 4. Future pour contenir les statuts de stock (ex: {"Dual": true, "Split": false})
  late Future<Map<String, bool>> _availabilityFuture;

  @override
  void initState() {
    super.initState();
    // ✅ 5. Lancer la vérification du stock au démarrage de la page
    _availabilityFuture = _checkAllConfigurationsAvailability();
  }

  /// Vérifie le stock pour chaque composant d'une configuration.
  Future<bool> _isConfigurationInStock(AntivolConfiguration config) async {
    if (config.components.isEmpty) {
      return true; // S'il n'y a pas de composants, c'est "en stock"
    }

    try {
      for (final component in config.components) {
        final productRef = FirebaseFirestore.instance.doc(component.productRef);
        final productDoc = await productRef.get();

        if (!productDoc.exists) {
          return false; // Le produit n'existe pas
        }

        final productData = productDoc.data() as Map<String, dynamic>;
        final stockQuantity = (productData['quantiteEnStock'] as num? ?? 0).toInt();

        if (stockQuantity < component.quantity) {
          return false; // Pas assez de stock pour ce composant
        }
      }
      return true; // Tous les composants sont en stock
    } catch (e) {
      print("Erreur vérification stock pour ${config.name}: $e");
      return false; // Erreur, marquer comme non disponible
    }
  }

  /// Boucle sur toutes les configurations et vérifie leur disponibilité.
  Future<Map<String, bool>> _checkAllConfigurationsAvailability() async {
    final availabilityMap = <String, bool>{};

    for (final config in widget.system.configurations) {
      availabilityMap[config.name] = await _isConfigurationInStock(config);
    }

    return availabilityMap;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.system.systemName), // ex: "UP6"
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Système: ${widget.system.systemName}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Fournisseur: ${widget.system.supplier}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sélectionner une configuration:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // ✅ 6. Utiliser un FutureBuilder pour afficher la liste après vérification
            Expanded(
              child: FutureBuilder<Map<String, bool>>(
                future: _availabilityFuture,
                builder: (context, snapshot) {
                  // --- État de chargement ---
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Vérification des stocks...',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  // --- État d'erreur ---
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Erreur de vérification du stock: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  // --- État de succès ---
                  final availabilityMap = snapshot.data ?? {};
                  final configurations = widget.system.configurations;

                  if (configurations.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'Aucune configuration n\'a été définie pour ce système.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  // --- Construire la liste avec les statuts ---
                  return ListView.builder(
                    itemCount: configurations.length,
                    itemBuilder: (context, index) {
                      final config = configurations[index];
                      // Obtenir le statut de stock (par défaut 'false' si non trouvé)
                      final bool isInStock = availabilityMap[config.name] ?? false;
                      final Color statusColor = isInStock ? Colors.green.shade700 : Colors.red.shade700;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: ElevatedButton(
                          onPressed: () {
                            // Naviguer vers la page de détails finale
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ConfigDetailsPage(
                                  systemName: widget.system.systemName,
                                  configuration: config,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // ✅ 7. Ajouter l'icône de statut
                              Icon(
                                isInStock ? Icons.check_circle_rounded : Icons.warning_rounded,
                                color: statusColor,
                              ),
                              Text(
                                config.name, // ex: "Dual"
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isInStock ? 'En Stock' : 'Stock faible',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
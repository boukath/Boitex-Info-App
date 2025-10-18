// lib/screens/administration/antivol_config/config_options_page.dart

import 'package:flutter/material.dart';
// ✅ 1. Import du modèle
import 'package:boitex_info_app/models/antivol_system.dart';
// ✅ 2. Import de la page suivante
import 'package:boitex_info_app/screens/administration/antivol_config/config_details_page.dart';

class ConfigOptionsPage extends StatelessWidget {
  final AntivolSystem system;

  const ConfigOptionsPage({
    super.key,
    required this.system,
  });

  @override
  Widget build(BuildContext context) {
    // Extrait la liste des configurations de l'objet système
    final configurations = system.configurations;

    return Scaffold(
      appBar: AppBar(
        title: Text(system.systemName), // ex: "UP6"
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Système: ${system.systemName}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Fournisseur: ${system.supplier}',
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

            // Construit la liste des boutons de configuration
            if (configurations.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Aucune configuration n\'a été définie pour ce système.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: configurations.length,
                  itemBuilder: (context, index) {
                    final config = configurations[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: ElevatedButton(
                        onPressed: () {
                          // Naviguer vers la page de détails finale
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ConfigDetailsPage(
                                systemName: system.systemName,
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
                            Text(
                              config.name, // ex: "Dual"
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                          ],
                        ),
                      ),
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
// lib/screens/administration/antivol_config/system_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ✅ 1. Import du modèle de données
import 'package:boitex_info_app/models/antivol_system.dart';
// ✅ 2. Import de la page suivante
import 'package:boitex_info_app/screens/administration/antivol_config/config_options_page.dart';

class SystemListPage extends StatefulWidget {
  final String technology;
  final String supplier;

  const SystemListPage({
    super.key,
    required this.technology,
    required this.supplier,
  });

  @override
  State<SystemListPage> createState() => _SystemListPageState();
}

class _SystemListPageState extends State<SystemListPage> {
  late Future<List<AntivolSystem>> _systemsFuture;

  @override
  void initState() {
    super.initState();
    _systemsFuture = _fetchSystems();
  }

  /// Récupère les systèmes pour le fournisseur et la technologie sélectionnés.
  Future<List<AntivolSystem>> _fetchSystems() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('antivolSystems')
          .where('technology', isEqualTo: widget.technology)
          .where('supplier', isEqualTo: widget.supplier)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return []; // Aucun système trouvé
      }

      // Convertit les documents en objets AntivolSystem
      final systems = querySnapshot.docs
          .map((doc) => AntivolSystem.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      // Trie les systèmes par nom
      systems.sort((a, b) => a.systemName.compareTo(b.systemName));

      return systems;
    } catch (e) {
      print("Erreur lors de la récupération des systèmes: $e");
      throw Exception('Impossible de charger les systèmes');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplier), // ex: "Sensormatic"
      ),
      body: FutureBuilder<List<AntivolSystem>>(
        future: _systemsFuture,
        builder: (context, snapshot) {
          // 1. État de chargement
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. État d'erreur
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // 3. État sans données
          final systems = snapshot.data;
          if (systems == null || systems.isEmpty) {
            return Center(
              child: Text(
                'Aucun système trouvé pour ${widget.supplier}.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // 4. État de succès: Afficher la liste
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: systems.length,
            itemBuilder: (context, index) {
              final system = systems[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.display_settings_rounded),
                  ),
                  title: Text(
                    system.systemName, // ex: "UP6"
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Naviguer vers la page des options de configuration
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ConfigOptionsPage(
                          system: system, // Passer l'objet système complet
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
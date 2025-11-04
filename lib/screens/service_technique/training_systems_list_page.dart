// lib/screens/service_technique/training_systems_list_page.dart

// ✅ 1. NOUVEL IMPORT AJOUTÉ
import 'package:boitex_info_app/screens/service_technique/training_system_detail_page.dart';

import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TrainingSystemsListPage extends StatefulWidget {
  final String categoryName;
  final String categoryId; // <-- ID de la catégorie parente

  const TrainingSystemsListPage({
    super.key,
    required this.categoryName,
    required this.categoryId, // <-- Requis maintenant
  });

  @override
  State<TrainingSystemsListPage> createState() =>
      _TrainingSystemsListPageState();
}

class _TrainingSystemsListPageState extends State<TrainingSystemsListPage> {
  bool _isManager = false;
  final TextEditingController _systemNameController = TextEditingController();
  late final CollectionReference _systemsCollection;

  @override
  void initState() {
    super.initState();
    // Définit le chemin de la sous-collection en utilisant l'ID de la catégorie
    _systemsCollection = FirebaseFirestore.instance
        .collection('training_categories')
        .doc(widget.categoryId)
        .collection('training_systems');

    _fetchUserRole();
  }

  @override
  void dispose() {
    _systemNameController.dispose();
    super.dispose();
  }

  /// Récupère le rôle de l'utilisateur et vérifie s'il est un manager
  Future<void> _fetchUserRole() async {
    final role = await UserRoles.getCurrentUserRole();
    if (mounted) {
      setState(() {
        _isManager = _checkIsManager(role);
      });
    }
  }

  /// Vérifie si le rôle est un rôle de manager
  bool _checkIsManager(String? role) {
    if (role == null) return false;
    final managerRoles = <String>{
      UserRoles.pdg,
      UserRoles.admin,
      UserRoles.responsableAdministratif,
      UserRoles.responsableCommercial,
      UserRoles.responsableTechnique,
      UserRoles.responsableIT,
      UserRoles.chefDeProjet,
    };
    return managerRoles.contains(role);
  }

  /// Affiche la boîte de dialogue pour ajouter un nouveau système
  void _showAddSystemDialog() {
    _systemNameController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouveau Système'),
          content: TextField(
            controller: _systemNameController,
            decoration: const InputDecoration(
              labelText: 'Nom du système',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Ajouter'),
              onPressed: () {
                final name = _systemNameController.text.trim();
                if (name.isNotEmpty) {
                  _addSystem(name);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Ajoute le nouveau système à la sous-collection Firestore
  Future<void> _addSystem(String name) async {
    try {
      await _systemsCollection.add({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  /// Affiche la confirmation de suppression
  void _showDeleteConfirmDialog(String docId, String systemName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer le Système'),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer le système "$systemName" ?'),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer'),
              onPressed: () {
                _deleteSystem(docId);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  /// Supprime le système de Firestore
  Future<void> _deleteSystem(String docId) async {
    try {
      await _systemsCollection.doc(docId).delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName), // Titre dynamique (ex: "Antivol")
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      // Affiche le bouton "Ajouter" (+) uniquement pour les managers
      floatingActionButton: _isManager
          ? FloatingActionButton(
        onPressed: _showAddSystemDialog,
        child: const Icon(Icons.add),
        tooltip: 'Ajouter un système',
      )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        // Lit le flux de données depuis la sous-collection
        stream: _systemsCollection.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Erreur de chargement des systèmes.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child:
                Text('Aucun système trouvé pour ${widget.categoryName}.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final systemName = data['name'] ?? 'Sans nom';

              return ListTile(
                title: Text(systemName),
                // ✅ 2. LOGIQUE 'ONTAP' MISE À JOUR
                onTap: () {
                  // Naviguer vers la page de détails du système
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TrainingSystemDetailPage(
                        // Nous passons tous les IDs et noms nécessaires
                        categoryId: widget.categoryId,
                        systemId: doc.id,
                        systemName: systemName,
                      ),
                    ),
                  );
                },
                // Affiche le bouton de suppression uniquement pour les managers
                trailing: _isManager
                    ? IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red),
                  tooltip: 'Supprimer le système',
                  onPressed: () {
                    _showDeleteConfirmDialog(doc.id, systemName);
                  },
                )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
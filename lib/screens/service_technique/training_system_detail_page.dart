// lib/screens/service_technique/training_system_detail_page.dart

// ✅ 1. AJOUTER LE NOUVEL IMPORT
import 'package:boitex_info_app/screens/service_technique/training_document_list_page.dart';

import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TrainingSystemDetailPage extends StatefulWidget {
  final String categoryId;
  final String systemId;
  final String systemName;

  const TrainingSystemDetailPage({
    super.key,
    required this.categoryId,
    required this.systemId,
    required this.systemName,
  });

  @override
  State<TrainingSystemDetailPage> createState() =>
      _TrainingSystemDetailPageState();
}

class _TrainingSystemDetailPageState extends State<TrainingSystemDetailPage> {
  bool _isManager = false;
  // ✅ 2. Renommé pour plus de clarté
  final TextEditingController _subSystemNameController =
  TextEditingController();
  late final CollectionReference _subSystemsCollection; // ✅ 3. Collection Renommée

  @override
  void initState() {
    super.initState();
    // ✅ 4. Changement du chemin de la collection
    _subSystemsCollection = FirebaseFirestore.instance
        .collection('training_categories')
        .doc(widget.categoryId)
        .collection('training_systems')
        .doc(widget.systemId)
        .collection('training_sub_systems'); // <-- NOUVEAU NIVEAU

    _fetchUserRole();
  }

  @override
  void dispose() {
    _subSystemNameController.dispose(); // ✅ 5. Renommé
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

  // ✅ 6. Fonction renommée et mise à jour
  /// Affiche la boîte de dialogue pour ajouter un nouveau SOUS-SYSTÈME
  void _showAddSubSystemDialog() {
    _subSystemNameController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouveau Sous-Système'),
          content: TextField(
            controller: _subSystemNameController,
            decoration: const InputDecoration(
              labelText: 'Nom (ex: Synergy, Advantage...)',
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
                final name = _subSystemNameController.text.trim();
                if (name.isNotEmpty) {
                  _addSubSystem(name);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  // ✅ 7. Fonction renommée
  /// Ajoute le nouveau sous-système à Firestore
  Future<void> _addSubSystem(String name) async {
    try {
      await _subSystemsCollection.add({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  // ✅ 8. Fonction renommée
  /// Affiche la confirmation de suppression
  void _showDeleteConfirmDialog(String docId, String subSystemName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer le Sous-Système'),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer "$subSystemName" ?'),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer'),
              onPressed: () {
                _deleteSubSystem(docId);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  // ✅ 9. Fonction renommée
  /// Supprime le sous-système de Firestore
  Future<void> _deleteSubSystem(String docId) async {
    try {
      await _subSystemsCollection.doc(docId).delete();
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
        title: Text(widget.systemName), // Titre (ex: "Sensormatic")
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      // ✅ 10. Bouton mis à jour
      floatingActionButton: _isManager
          ? FloatingActionButton(
        onPressed: _showAddSubSystemDialog,
        child: const Icon(Icons.add_box_outlined), // Icône différente
        tooltip: 'Ajouter un sous-système',
      )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        // ✅ 11. Stream mis à jour
        stream: _subSystemsCollection.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Erreur de chargement des sous-systèmes.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Text(
                    'Aucun sous-système trouvé pour ${widget.systemName}.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final subSystemName = data['name'] ?? 'Sans nom';

              return ListTile(
                leading: const Icon(Icons.category_rounded,
                    color: Colors.blueAccent), // Icône changée
                title: Text(subSystemName),

                // ✅ 12. Navigation mise à jour
                onTap: () {
                  // Naviguer vers la page finale des documents
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TrainingDocumentListPage(
                        categoryId: widget.categoryId,
                        systemId: widget.systemId,
                        subSystemId: doc.id,
                        subSystemName: subSystemName,
                      ),
                    ),
                  );
                },
                trailing: _isManager
                    ? IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red),
                  tooltip: 'Supprimer le sous-système',
                  onPressed: () {
                    _showDeleteConfirmDialog(doc.id, subSystemName);
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
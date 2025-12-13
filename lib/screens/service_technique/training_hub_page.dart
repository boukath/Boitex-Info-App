// ✅ 1. NOUVEL IMPORT AJOUTÉ
import 'package:boitex_info_app/screens/service_technique/training_systems_list_page.dart';

import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TrainingHubPage extends StatefulWidget {
  const TrainingHubPage({super.key});

  @override
  State<TrainingHubPage> createState() => _TrainingHubPageState();
}

class _TrainingHubPageState extends State<TrainingHubPage> {
  bool _isManager = false;
  final TextEditingController _categoryNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
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
  /// (Basé sur la logique de votre 'administration_dashboard_page.dart')
  bool _checkIsManager(String? role) {
    if (role == null) return false;
    // Ces rôles peuvent voir les cartes de gestion
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

  /// Affiche la boîte de dialogue pour ajouter une nouvelle catégorie
  void _showAddCategoryDialog() {
    _categoryNameController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouvelle Catégorie'),
          content: TextField(
            controller: _categoryNameController,
            decoration: const InputDecoration(
              labelText: 'Nom de la catégorie',
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
                final name = _categoryNameController.text.trim();
                if (name.isNotEmpty) {
                  _addCategory(name);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Ajoute la nouvelle catégorie à Firestore
  Future<void> _addCategory(String name) async {
    try {
      await FirebaseFirestore.instance.collection('training_categories').add({
        'name': name,
        'iconName': 'default', // Icône par défaut
        'colorHex': '#808080', // Couleur par défaut
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  /// Affiche la confirmation de suppression
  void _showDeleteConfirmDialog(String docId, String categoryName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la Catégorie'),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer la catégorie "$categoryName" ?'),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer'),
              onPressed: () {
                _deleteCategory(docId);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  /// Supprime la catégorie de Firestore
  Future<void> _deleteCategory(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('training_categories')
          .doc(docId)
          .delete();
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
        title: const Text('Centre de Formation'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (_isManager)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Ajouter une catégorie',
              onPressed: _showAddCategoryDialog,
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Lit le flux de données depuis la collection Firestore
        stream: FirebaseFirestore.instance
            .collection('training_categories')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Erreur de chargement des catégories.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucune catégorie trouvée.'));
          }

          final docs = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 cartes par ligne
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 1.1, // Ajuste la hauteur des cartes
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final category = _TrainingCategory(
                docId: doc.id,
                name: data['name'] ?? 'Sans nom',
                icon: _getIconFromName(data['iconName'] ?? 'default'),
                color: _getColorFromHex(data['colorHex'] ?? '#808080'),
              );

              return _CategoryCard(
                category: category,
                isManager: _isManager,
                // ✅ 2. LOGIQUE 'ONTAP' MISE À JOUR
                onTap: () {
                  // Naviguer vers la page de liste des systèmes
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TrainingSystemsListPage(
                        categoryName: category.name,
                        categoryId: category.docId,
                      ),
                    ),
                  );
                  // ❌ Ancien SnackBar supprimé
                },
                onDelete: () {
                  _showDeleteConfirmDialog(category.docId, category.name);
                },
              );
            },
          );
        },
      ),
    );
  }
}

// Un widget privé pour les données de catégorie
class _TrainingCategory {
  final String docId;
  final String name;
  final IconData icon;
  final Color color;

  const _TrainingCategory({
    required this.docId,
    required this.name,
    required this.icon,
    required this.color,
  });
}

// Un widget privé pour la carte de catégorie
class _CategoryCard extends StatelessWidget {
  final _TrainingCategory category;
  final bool isManager;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.isManager,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // La carte principale
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(category.icon, size: 32, color: category.color),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Le bouton de suppression (visible uniquement par le manager)
        if (isManager)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
              tooltip: 'Supprimer la catégorie',
              onPressed: onDelete,
              splashRadius: 20,
            ),
          ),
      ],
    );
  }
}

// --- Petits utilitaires ---

/// Fait correspondre un nom d'icône (String) à une IconData réelle
IconData _getIconFromName(String iconName) {
  switch (iconName) {
    case 'shield_rounded':
      return Icons.shield_rounded;
    case 'videocam_rounded':
      return Icons.videocam_rounded;
    case 'sensor_door_rounded':
      return Icons.sensor_door_rounded;
    default:
      return Icons.widgets_rounded; // Icône par défaut
  }
}

/// Convertit une chaîne hexadécimale (ex: "#FF0000") en un objet Color
Color _getColorFromHex(String hexColor) {
  hexColor = hexColor.toUpperCase().replaceAll('#', '');
  if (hexColor.length == 6) {
    hexColor = 'FF$hexColor'; // Ajoute l'opacité complète
  }
  try {
    return Color(int.parse(hexColor, radix: 16));
  } catch (e) {
    return Colors.grey; // Couleur par défaut en cas d'erreur
  }
}
// lib/screens/administration/project_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/project_details_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart'; // ✅ AJOUTÉ: Import pour la gestion des rôles

class ProjectListPage extends StatefulWidget {
  final String userRole;
  final String serviceType;

  const ProjectListPage({
    super.key,
    required this.userRole,
    required this.serviceType,
  });

  @override
  State<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends State<ProjectListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _canDelete = false; // ✅ AJOUTÉ: État pour la permission de suppression

  // ✅ NEW: This list is now our single source of truth for the pipeline.
  // It defines the title and the statuses for each tab.
  final List<Map<String, dynamic>> _pipelineStages = [
    {
      'title': 'Nouvelles',
      'statuses': ['Nouvelle Demande']
    },
    {
      'title': 'Éval. Terminée',
      'statuses': ['Évaluation Technique Terminé', 'Évaluation IT Terminé']
    },
    // "Devis Envoyé" removed here
    {
      'title': 'Finalisation',
      'statuses': ['Finalisation de la Commande']
    },
    {
      'title': 'À Planifier',
      'statuses': ['À Planifier']
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: _pipelineStages.length, vsync: this);
    _checkUserPermissions(); // ✅ AJOUTÉ: Vérification des permissions au démarrage
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ NOUVEAU: Vérification de la permission de suppression (réservée aux managers)
  Future<void> _checkUserPermissions() async {
    // Utilise la vérification d'accès complet existante
    final canDelete = await RolePermissions.canCurrentUserDeleteLivraison();
    if (mounted) {
      setState(() {
        _canDelete = canDelete;
      }
      );
    }
  }

  // ✅ NOUVEAU: Fonction de suppression avec dialogue de confirmation
  /// Affiche une boîte de dialogue de confirmation et supprime le projet si confirmé.
  Future<void> _deleteProject(String projectId, String clientName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer définitivement le projet pour "$clientName"? Cette action est irréversible et supprime toutes les données associées.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Projet supprimé pour "$clientName".'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Erreur lors de la suppression du projet: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur de suppression: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Projets ${widget.serviceType}'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          // ✅ MODIFIED: The tabs are now built dynamically from our list
          tabs: _pipelineStages.map((stage) {
            // We use our new badge-aware widget for each tab
            return _ProjectPipelineTab(
              serviceType: widget.serviceType,
              tabTitle: stage['title'] as String,
              statuses: stage['statuses'] as List<String>,
            );
          }).toList(),
        ),
      ),
      // ✅ MODIFIED: Passing state and callback to _ProjectListStream
      body: TabBarView(
        controller: _tabController,
        children: _pipelineStages.map((stage) {
          // We re-use the same list widget for each tab's content
          return _ProjectListStream(
            userRole: widget.userRole,
            serviceType: widget.serviceType,
            statuses: stage['statuses'] as List<String>,
            emptyMessage: 'Aucun projet dans "${stage['title']}".',
            canDelete: _canDelete, // ✅ PASSAGE DE L'ÉTAT
            onDelete: _deleteProject, // ✅ PASSAGE DU CALLBACK
          );
        }).toList(),
      ),
    );
  }
}

// ✅ --- NEW WIDGET ---
// This widget is responsible for building a single tab and
// fetching its own count to display a badge.
class _ProjectPipelineTab extends StatelessWidget {
  final String serviceType;
  final String tabTitle;
  final List<String> statuses;

  const _ProjectPipelineTab({
    required this.serviceType,
    required this.tabTitle,
    required this.statuses,
  });

  @override
  Widget build(BuildContext context) {
    // We use a StreamBuilder to listen for the count
    return StreamBuilder<int>(
      // ✅ This query is very efficient. .map((s) => s.size)
      // gets ONLY the count, not all the documents.
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where('serviceType', isEqualTo: serviceType)
          .where('status', whereIn: statuses)
          .snapshots()
          .map((snapshot) => snapshot.size),
      builder: (context, snapshot) {
        final int count = snapshot.data ?? 0;

        // If count is 0, just show the text
        if (count == 0) {
          return Tab(text: tabTitle);
        }

        // If count > 0, show the text + badge
        return Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(tabTitle),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.red, // Badge color
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ✅ --- This is the same list widget from before, now updated ---
// It displays the actual list of projects for a given tab.
class _ProjectListStream extends StatelessWidget {
  final String userRole;
  final String serviceType;
  final List<String> statuses;
  final String emptyMessage;
  final bool canDelete; // ✅ NOUVEAU: Permission de suppression
  final Function(String, String) onDelete; // ✅ NOUVEAU: Callback de suppression

  const _ProjectListStream({
    required this.userRole,
    required this.serviceType,
    required this.statuses,
    required this.emptyMessage,
    required this.canDelete, // ✅ AJOUTÉ AU CONSTRUCTEUR
    required this.onDelete, // ✅ AJOUTÉ AU CONSTRUCTEUR
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Nouvelle Demande':
        return Colors.blue;
      case 'Évaluation Technique Terminé':
      case 'Évaluation IT Terminé':
        return Colors.orange;
      case 'Devis Envoyé':
        return Colors.purple;
      case 'Finalisation de la Commande':
        return Colors.teal;
      case 'À Planifier':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where('serviceType', isEqualTo: serviceType)
          .where('status', whereIn: statuses)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Une erreur est survenue.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text(emptyMessage));
        }

        final projectDocs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: projectDocs.length,
          itemBuilder: (context, index) {
            final projectDoc = projectDocs[index];
            final projectData = projectDoc.data() as Map<String, dynamic>;
            final String projectId = projectDoc.id; // ✅ Récupération de l'ID
            final createdAt = (projectData['createdAt'] as Timestamp).toDate();

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProjectDetailsPage(
                          projectId: projectDoc.id, userRole: userRole),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  projectData['clientName'] ?? 'Nom inconnu',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${projectData['storeName'] ?? 'Magasin inconnu'} - ${projectData['storeLocation'] ?? 'Lieu inconnu'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // ✅ MODIFIÉ: Ajout d'un Row pour le Chip et le bouton de menu
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text(
                                  projectData['status'] ?? 'Inconnu',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                backgroundColor:
                                _getStatusColor(projectData['status'] ?? ''),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              // ✅ NOUVEAU: PopupMenuButton pour la suppression
                              if (canDelete)
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      // Appel du callback de suppression passé par le parent
                                      onDelete(projectId, projectData['clientName'] ?? 'Projet Inconnu');
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('Supprimer', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Demande: ${projectData['initialRequest'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                projectData['createdByName'] ?? 'N/A',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy').format(createdAt),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
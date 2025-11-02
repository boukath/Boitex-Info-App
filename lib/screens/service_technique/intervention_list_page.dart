// lib/screens/service_technique/intervention_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:boitex_info_app/screens/service_technique/add_intervention_page.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';

// ✅ MODIFIÉ: Converti en StatefulWidget pour gérer l'état de la permission de suppression
class InterventionListPage extends StatefulWidget {
  final String userRole;
  final String serviceType;

  const InterventionListPage({
    super.key,
    required this.userRole,
    required this.serviceType,
  });

  @override
  State<InterventionListPage> createState() => _InterventionListPageState();
}

class _InterventionListPageState extends State<InterventionListPage> {
  // ✅ AJOUTÉ: État pour la permission de suppression
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _checkUserPermissions();
  }

  // ✅ AJOUTÉ: Vérification asynchrone des permissions
  Future<void> _checkUserPermissions() async {
    final canDelete = await RolePermissions.canCurrentUserDeleteIntervention();
    if (mounted) {
      setState(() {
        _canDelete = canDelete;
      });
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'En cours':
        return Colors.orange.shade700;
      case 'Nouveau':
        return Colors.blue.shade700;
      case 'Terminé':
        return Colors.green.shade700;
      case 'En attente':
        return Colors.purple.shade700;
      default:
        return Colors.grey;
    }
  }

  Widget _getPriorityFlag(String? priority) {
    Color flagColor = Colors.grey;
    switch (priority) {
      case 'Haute':
        flagColor = Colors.red.shade700;
        break;
      case 'Moyenne':
        flagColor = Colors.orange.shade700;
        break;
      case 'Basse':
        flagColor = Colors.blue.shade700;
        break;
      default:
        flagColor = Colors.grey;
    }
    return Container(
      width: 10,
      height: double.infinity,
      color: flagColor,
    );
  }

  // ✅ AJOUTÉ: Logique de suppression
  /// Affiche une boîte de dialogue de confirmation et supprime l'intervention si confirmé.
  Future<void> _deleteIntervention(String interventionId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer définitivement l\'intervention pour "$title"? Cette action est irréversible.'),
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
            .collection('interventions')
            .doc(interventionId)
            .delete();

        // Afficher la confirmation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Intervention supprimée: "$title".'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Gérer l'erreur de suppression
        debugPrint('Erreur lors de la suppression de l\'intervention: $e');
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
    // MODIFIÉ: Utilise widget.serviceType et widget.userRole
    final serviceType = widget.serviceType;
    final userRole = widget.userRole;

    // Determine the query based on serviceType
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('interventions')
        .where('serviceType', isEqualTo: serviceType)
    // ✅ FIX: Filter to show ONLY truly active/pending statuses.
        .where('status', whereIn: ['Nouveau', 'En cours', 'En attente'])
        .orderBy('status', descending: true)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text('Interventions - $serviceType'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Aucune intervention en cours ou nouvelle.'),
            );
          }

          final interventions = snapshot.data!.docs;

          return ListView.builder(
            itemCount: interventions.length,
            itemBuilder: (context, index) {
              final interventionDoc = interventions[index];
              final interventionData = interventionDoc.data();
              final String docId = interventionDoc.id;
              final String storeName = interventionData['storeName'] ?? 'Magasin Inconnu';

              final DateTime? createdAt = (interventionData['createdAt'] as Timestamp?)?.toDate();
              final String formattedDate = createdAt != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt)
                  : 'Date inconnue';
              final String priority = interventionData['priority'] ?? 'Basse';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                elevation: 2,
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      _getPriorityFlag(priority), // Flag color on the left
                      Expanded(
                        child: ListTile(
                          // ✅ MODIFIED: Adjusted padding to try and restore original layout
                          contentPadding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0, right: 0),
                          title: Text(
                            storeName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column( // Wrapped subtitle content in a Column to manage flow
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Client: ${interventionData['clientName'] ?? 'Client Inconnu'}'),
                              // ✅ REMOVED: The creator text line is gone.
                              Text('Créée le: $formattedDate'),
                            ],
                          ),
                          // The 'isThreeLine' property is kept, which now refers to:
                          // 1. Title (Store Name)
                          // 2. Subtitle Line 1 (Client Name)
                          // 3. Subtitle Line 2 (Date)
                          isThreeLine: true,
                          // ✅ MODIFIED: Use Row to combine Chip and Menu Button
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text(
                                  (interventionData['status'] as String?) ?? 'Inconnu',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: _getStatusColor(interventionData['status'] as String?),
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              ),
                              // ✅ PopupMenuButton for deletion
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _deleteIntervention(docId, storeName);
                                  }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  if (_canDelete) // Affiche seulement si la permission est activée
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('Supprimer', style: TextStyle(color: Colors.red)),
                                    ),
                                ],
                                // Affiche l'icône de menu seulement si l'utilisateur a la permission de supprimer
                                icon: _canDelete ? const Icon(Icons.more_vert) : null,
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                // QueryDocumentSnapshot<Map<String, dynamic>> is a DocumentSnapshot<Map<String, dynamic>>
                                builder: (context) => InterventionDetailsPage(interventionDoc: interventionDoc),
                              ),
                            );
                          },
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
      floatingActionButton: RolePermissions.canAddIntervention(userRole)
          ? FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => AddInterventionPage(serviceType: serviceType)),
          );
        },
        tooltip: "Nouvelle Demande D'intervention",
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}
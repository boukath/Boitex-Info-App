// lib/screens/service_technique/intervention_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/service_technique/add_intervention_page.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
// ✅ 1. IMPORT THE TIMEAGO PACKAGE
import 'package:timeago/timeago.dart' as timeago;

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
  State createState() => _InterventionListPageState();
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
      case 'Nouvelle Demande': // ✅ ADDED TO MATCH CREATION STATUS
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

    // Return a rounded container for a more modern look
    return Container(
      width: 10,
      decoration: BoxDecoration(
        color: flagColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer',
                  style: TextStyle(color: Colors.white)),
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
    // ✅ FIXED QUERY: Filter to include 'Nouvelle Demande' from the creation page
        .where('status',
        whereIn: ['Nouvelle Demande', 'Nouveau', 'En cours', 'En attente'])
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
            padding: const EdgeInsets.only(bottom: 80), // Space for FAB
            itemCount: interventions.length,
            itemBuilder: (context, index) {
              final interventionDoc = interventions[index];
              final interventionData = interventionDoc.data();
              final String docId = interventionDoc.id;

              // --- Data extraction ---
              final String storeName =
                  interventionData['storeName'] ?? 'Magasin Inconnu';
              final String clientName =
                  interventionData['clientName'] ?? 'Client Inconnu';
              final String interventionCode =
                  interventionData['interventionCode'] ?? 'INT-XX/XXXX';
              final String status = interventionData['status'] ?? 'Inconnu';
              final DateTime? createdAt =
              (interventionData['createdAt'] as Timestamp?)?.toDate();
              final String timeAgoDate = createdAt != null
                  ? timeago.format(createdAt, locale: 'fr') // Use timeago
                  : 'Date inconnue';
              final String priority = interventionData['priority'] ?? 'Basse';

              // ✅ --- NEW CARD LAYOUT ---
              // This layout replaces the ListTile to fix the overflow
              // and implements the new design.
              return Card(
                margin:
                const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.hardEdge, // Ensures priority flag clips
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _getPriorityFlag(priority), // Flag color on the left

                      // Main content area
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => InterventionDetailsPage(
                                    interventionDoc: interventionDoc),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Row: Code and Status
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        interventionCode,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.deepPurple.shade700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: Text(
                                        status,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                      backgroundColor: _getStatusColor(status),
                                      padding: const EdgeInsets.all(0),
                                      labelPadding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Store Name
                                Text(
                                  storeName,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),

                                // Client Name
                                Row(
                                  children: [
                                    Icon(Icons.business,
                                        size: 14,
                                        color: Colors.grey.shade700),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Client: $clientName',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade800),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Date
                                Row(
                                  children: [
                                    Icon(Icons.access_time,
                                        size: 14,
                                        color: Colors.grey.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Créée $timeAgoDate',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade800,
                                          fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // More Icon (for delete)
                      if (_canDelete)
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') {
                              _deleteIntervention(docId, storeName);
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                          <PopupMenuItem<String>>[
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('Supprimer',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          icon: Icon(Icons.more_vert,
                              color: Colors.grey.shade600),
                        ),
                      // Add padding if delete is not available, to keep UI balanced
                      if (!_canDelete) const SizedBox(width: 12),
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
            MaterialPageRoute(
                builder: (context) =>
                    AddInterventionPage(serviceType: serviceType)),
          );
        },
        tooltip: "Nouvelle Demande D'intervention",
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}
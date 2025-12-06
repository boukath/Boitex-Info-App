import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/service_technique/add_intervention_page.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
// ✅ CHANGED: Import the specific Clients History Page instead of General History
import 'package:boitex_info_app/screens/service_technique/intervention_history_clients_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:timeago/timeago.dart' as timeago;

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
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _checkUserPermissions();
  }

  Future<void> _checkUserPermissions() async {
    final canDelete = await RolePermissions.canCurrentUserDeleteIntervention();
    if (mounted) {
      setState(() {
        _canDelete = canDelete;
      });
    }
  }

  // --- ⚡️ NEW: QUICK UPDATE DIALOG (Instagram/Status Style) ---
  Future<void> _showQuickUpdateDialog(String docId, String? currentNote) async {
    final TextEditingController noteController = TextEditingController(text: currentNote);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.flash_on, color: Colors.amber),
            SizedBox(width: 8),
            Text("Flash Info"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Ajoutez une note rapide pour expliquer la situation actuelle (ex: Client en vacances, Pièce commandée...)",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "La situation actuelle...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 16),
            label: const Text("Publier le statut"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (noteController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('interventions')
                    .doc(docId)
                    .update({
                  'lastFollowUpNote': noteController.text.trim(),
                  'lastFollowUpDate': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
              }
            },
          )
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'En cours':
        return Colors.orange.shade700;
      case 'Nouveau':
      case 'Nouvelle Demande':
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
      decoration: BoxDecoration(
        color: flagColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
    );
  }

  Future<void> _deleteIntervention(String interventionId, String title) async {
    // ... existing delete logic ...
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
              child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('interventions').doc(interventionId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceType = widget.serviceType;
    final userRole = widget.userRole;

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('interventions')
        .where('serviceType', isEqualTo: serviceType)
        .where('status', whereIn: ['Nouvelle Demande', 'Nouveau', 'En cours', 'En attente'])
        .orderBy('status', descending: true)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text('Interventions - $serviceType'),
        // ✅ HISTORY ACTION BUTTON
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: "Historique Clients",
            onPressed: () {
              // ✅ CHANGED: Navigates directly to Clients History Page
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => InterventionHistoryClientsPage(
                    serviceType: serviceType,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucune intervention en cours.'));
          }

          final interventions = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: interventions.length,
            itemBuilder: (context, index) {
              final interventionDoc = interventions[index];
              final interventionData = interventionDoc.data();
              final String docId = interventionDoc.id;

              final String storeName = interventionData['storeName'] ?? 'Magasin Inconnu';
              final String clientName = interventionData['clientName'] ?? 'Client Inconnu';
              final String interventionCode = interventionData['interventionCode'] ?? 'INT-XX';
              final String status = interventionData['status'] ?? 'Inconnu';
              final DateTime? createdAt = (interventionData['createdAt'] as Timestamp?)?.toDate();
              final String timeAgoDate = createdAt != null ? timeago.format(createdAt, locale: 'fr') : 'N/A';
              final String priority = interventionData['priority'] ?? 'Basse';

              // --- ⚡️ FLASH NOTE DATA ---
              final String? flashNote = interventionData['lastFollowUpNote'];
              final DateTime? flashDate = (interventionData['lastFollowUpDate'] as Timestamp?)?.toDate();

              // Calculate freshness (Green if < 24h, Red if > 3 days)
              Color flashColor = Colors.blueGrey;
              String timeAgoFlash = '';
              if (flashDate != null) {
                timeAgoFlash = timeago.format(flashDate, locale: 'fr');
                final diff = DateTime.now().difference(flashDate);
                if (diff.inHours < 24) {
                  flashColor = Colors.green.shade600; // Fresh
                } else if (diff.inDays > 3) {
                  flashColor = Colors.red.shade400; // Old
                }
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  // ⚡️ LONG PRESS TO ADD FLASH NOTE
                  onLongPress: () => _showQuickUpdateDialog(docId, flashNote),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => InterventionDetailsPage(interventionDoc: interventionDoc),
                      ),
                    );
                  },
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _getPriorityFlag(priority),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // HEADER
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    Chip(
                                      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      backgroundColor: _getStatusColor(status),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(storeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                Text('Client: $clientName', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),

                                const SizedBox(height: 8),

                                // --- ⚡️ THE GLANCE SECTION (Flash Note) ---
                                if (flashNote != null && flashNote.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: flashColor.withOpacity(0.08),
                                      border: Border(left: BorderSide(color: flashColor, width: 3)),
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.info_outline, size: 14, color: flashColor),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                flashNote,
                                                style: const TextStyle(
                                                    fontStyle: FontStyle.italic,
                                                    fontSize: 13,
                                                    color: Colors.black87,
                                                    height: 1.2
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Mise à jour $timeAgoFlash",
                                          style: TextStyle(fontSize: 10, color: flashColor, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                // Placeholder hint for Technicians (Optional)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Créée $timeAgoDate',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // DELETE MENU (Existing)
                        if (_canDelete)
                          PopupMenuButton<String>(
                            onSelected: (value) { if (value == 'delete') _deleteIntervention(docId, storeName); },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Supprimer')]),
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
      ),
      floatingActionButton: RolePermissions.canAddIntervention(userRole)
          ? FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => AddInterventionPage(serviceType: serviceType))),
        tooltip: "Nouvelle Demande",
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}
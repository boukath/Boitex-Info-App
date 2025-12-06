// lib/screens/service_technique/installation_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

// Import for the edit page
import 'package:boitex_info_app/screens/service_technique/add_installation_page.dart';
// ✅ ADDED: Import for Installation History Page
import 'package:boitex_info_app/screens/service_technique/installation_history_list_page.dart';

class InstallationListPage extends StatelessWidget {
  final String userRole;
  final String serviceType;

  const InstallationListPage({
    super.key,
    required this.userRole,
    required this.serviceType,
  });

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'En Cours':
        return Colors.orange.shade700;
      case 'À Planifier':
        return Colors.blue.shade700;
      case 'Planifiée':
        return Colors.purple.shade700;
      default:
        return Colors.grey;
    }
  }

  // Navigate to Details (Read-only / Execution View)
  void _navigateToDetails(BuildContext context, DocumentSnapshot doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstallationDetailsPage(
          installationDoc: doc,
          userRole: userRole,
        ),
      ),
    );
  }

  // Navigate to Edit (Modify Data)
  void _navigateToEdit(BuildContext context, DocumentSnapshot doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddInstallationPage(
          userRole: userRole,
          serviceType: serviceType,
          installationToEdit: doc, // Pass the existing doc to enable Edit Mode
        ),
      ),
    );
  }

  // ✅ NEW: Delete Confirmation Logic
  Future<void> _confirmDelete(BuildContext context, String docId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'installation ?'),
        content: const Text(
            'Cette action est irréversible. Voulez-vous vraiment supprimer cette installation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('installations')
            .doc(docId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Installation supprimée avec succès.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check edit permission
    final bool canEdit = RolePermissions.canScheduleInstallation(userRole);

    return Scaffold(
      appBar: AppBar(
        title: Text('Installations $serviceType'),
        // ✅ ADDED: History Action Button
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: "Historique Installations",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => InstallationHistoryListPage(
                    serviceType: serviceType,
                    userRole: userRole,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('installations')
            .where('serviceType', isEqualTo: serviceType)
            .where('status', whereIn: ['À Planifier', 'Planifiée', 'En Cours'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.router_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune installation active',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Les installations terminées sont dans l\'historique',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          final installations = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: installations.length,
            itemBuilder: (context, index) {
              final doc = installations[index];
              final data = doc.data() as Map<String, dynamic>;

              final installationCode = data['installationCode'] ?? 'N/A';
              final clientName = data['clientName'] ?? 'Client inconnu';
              final storeName = data['storeName'] ?? 'Magasin inconnu';
              final status = data['status'] ?? 'À Planifier';

              final DateTime? installationDate =
              (data['installationDate'] as Timestamp?)?.toDate();
              final String dateDisplay;
              if (installationDate != null) {
                dateDisplay =
                    DateFormat('dd/MM/yyyy', 'fr_FR').format(installationDate);
              } else {
                dateDisplay = 'Non planifiée';
              }

              return Slidable(
                key: ValueKey(doc.id),
                endActionPane: canEdit
                    ? ActionPane(
                  motion: const StretchMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (ctx) => _navigateToEdit(context, doc),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      icon: Icons.edit,
                      label: 'Modifier',
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // Optional: Add Delete to slide as well
                    SlidableAction(
                      onPressed: (ctx) => _confirmDelete(context, doc.id),
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Supprimer',
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ],
                )
                    : null,
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _navigateToDetails(context, doc),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // LEFT: Icon + Code + Date
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.router_outlined,
                                        color: Colors.blue.shade700,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            installationCode,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            dateDisplay,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: installationDate != null
                                                  ? Colors.grey.shade600
                                                  : Colors.blue.shade700,
                                              fontWeight: installationDate != null
                                                  ? FontWeight.normal
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // RIGHT: Status Badge + 3-Dot Menu
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      status,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),

                                  // ✅ UPDATED MENU
                                  if (canEdit) ...[
                                    const SizedBox(width: 4),
                                    PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.more_vert,
                                          color: Colors.grey),
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _navigateToEdit(context, doc);
                                        } else if (value == 'delete') {
                                          // Trigger Delete
                                          _confirmDelete(context, doc.id);
                                        }
                                      },
                                      itemBuilder: (BuildContext context) =>
                                      <PopupMenuEntry<String>>[
                                        const PopupMenuItem<String>(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit,
                                                  color: Colors.blueGrey),
                                              SizedBox(width: 10),
                                              Text('Modifier tout'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        // ✅ DELETE OPTION ADDED HERE
                                        const PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline,
                                                  color: Colors.red),
                                              SizedBox(width: 10),
                                              Text(
                                                'Supprimer',
                                                style: TextStyle(
                                                    color: Colors.red),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // Client & Store Info
                          Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  clientName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.store_outlined,
                                  size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  storeName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddInstallationPage(
                userRole: userRole,
                serviceType: serviceType,
                // No installationToEdit passed here = Create Mode
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle'),
        backgroundColor: Colors.green,
      )
          : null,
    );
  }
}
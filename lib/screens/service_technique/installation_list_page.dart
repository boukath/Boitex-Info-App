// lib/screens/service_technique/installation_list_page.dart
// UPDATED: Filters out 'Terminée' installations (they go to history)
// ADDED: Slidable action to edit installations
// ADDED: FloatingActionButton to create new installations

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

// ✅ 1. ADD IMPORT for the new page
import 'package:boitex_info_app/screens/service_technique/add_installation_page.dart';

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

  // Helper method for navigation
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

  @override
  Widget build(BuildContext context) {
    // Check edit permission
    final bool canEdit = RolePermissions.canScheduleInstallation(userRole);

    return Scaffold(
      appBar: AppBar(
        title: Text('Installations $serviceType'),
      ),
      // -----------------------------------------------------------------
      // VVV THIS IS THE MODIFIED BODY VVV
      // -----------------------------------------------------------------
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

              // This logic for date display is from our previous change
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
                      onPressed: (ctx) => _navigateToDetails(context, doc),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      icon: Icons.edit_calendar_outlined,
                      label: 'Modifier',
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
                          // Installation Code & Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Installation Code & Date
                              Row(
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
                                  Column(
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
                                        dateDisplay, // Date logic
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
                                ],
                              ),

                              // Status Badge
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
      // -----------------------------------------------------------------
      // VVV THIS IS THE NEW FLOATING ACTION BUTTON VVV
      // -----------------------------------------------------------------
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddInstallationPage(
                userRole: userRole,
                serviceType: serviceType,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle'),
        backgroundColor: Colors.green, // Match your theme
      )
          : null, // Hide button if user has no permission
    );
  }
}
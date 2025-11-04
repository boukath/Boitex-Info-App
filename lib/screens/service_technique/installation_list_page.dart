// lib/screens/service_technique/installation_list_page.dart
// UPDATED: Filters out 'Terminée' installations (they go to history)
// ADDED: Slidable action to edit installations

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
// ✅ 1. ADD THIS IMPORT for the Slidable widget
import 'package:flutter_slidable/flutter_slidable.dart';

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

  // ✅ 2. ADD HELPER METHOD for navigation
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
    // ✅ 3. CHECK EDIT PERMISSION (we'll use this in the builder)
    final bool canEdit = RolePermissions.canScheduleInstallation(userRole);

    return Scaffold(
      appBar: AppBar(
        title: Text('Installations $serviceType'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ... (your stream query is correct)
        stream: FirebaseFirestore.instance
            .collection('installations')
            .where('serviceType', isEqualTo: serviceType)
            .where('status', whereIn: ['À Planifier', 'Planifiée', 'En Cours'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // ... (your loading, error, and empty states are correct)
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

              // -----------------------------------------------------------------
              // VVV THIS IS THE MODIFIED WIDGET VVV
              // -----------------------------------------------------------------

              // ✅ 4. WRAP THE CARD WITH A SLIDABLE WIDGET
              return Slidable(
                key: ValueKey(doc.id),
                // Show edit action only if user has permission
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
                    // Use the helper method for navigation
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
              // -----------------------------------------------------------------
              // ^^^ THIS IS THE MODIFIED WIDGET ^^^
              // -----------------------------------------------------------------
            },
          );
        },
      ),
    );
  }
}
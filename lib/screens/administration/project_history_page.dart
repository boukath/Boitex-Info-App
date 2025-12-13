// lib/screens/administration/project_history_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/project_details_page.dart';

class ProjectHistoryPage extends StatelessWidget {
  final String userRole;
  final String serviceType;

  const ProjectHistoryPage({
    super.key,
    required this.userRole,
    required this.serviceType,
  });

  // Helper function to color-code the status chips
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Transféré à l\'Installation':
        return Colors.green;
      case 'Refusé':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique $serviceType'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ This query fetches ONLY the "Archived" statuses
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where('serviceType', isEqualTo: serviceType)
            .where('status', whereIn: [
          'Transféré à l\'Installation',
          'Refusé',
        ])
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
            return const Center(child: Text('Aucun projet dans l\'historique.'));
          }

          final projectDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: projectDocs.length,
            itemBuilder: (context, index) {
              final projectDoc = projectDocs[index];
              final projectData = projectDoc.data() as Map<String, dynamic>;
              final createdAt =
              (projectData['createdAt'] as Timestamp).toDate();

              // Re-using the same beautiful card layout
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                            Chip(
                              label: Text(
                                projectData['status'] ?? 'Inconnu',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                              backgroundColor:
                              _getStatusColor(projectData['status'] ?? ''),
                              padding:
                              const EdgeInsets.symmetric(horizontal: 8),
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
      ),
    );
  }
}
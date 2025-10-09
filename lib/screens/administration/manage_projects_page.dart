// lib/screens/administration/manage_projects_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/project_details_page.dart';

class ManageProjectsPage extends StatelessWidget {
  final String userRole;

  const ManageProjectsPage({super.key, required this.userRole});

  // MODIFIED: Added a helper function to color-code the status chips
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Nouvelle Demande':
        return Colors.blue;
      case 'Évaluation Technique Terminé':
        return Colors.orange;
      case 'Devis Envoyé':
        return Colors.purple;
      case 'Bon de Commande Reçu':
        return Colors.green;
      case 'Refusé':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer les Projets'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('projects').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucun projet trouvé.'));
          }

          final projectDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: projectDocs.length,
            itemBuilder: (context, index) {
              final projectDoc = projectDocs[index];
              final projectData = projectDoc.data() as Map<String, dynamic>;
              final createdAt = (projectData['createdAt'] as Timestamp).toDate();

              // MODIFIED: Replaced ListTile with a more robust custom layout
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProjectDetailsPage(projectId: projectDoc.id, userRole: userRole),
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
                              child: Text(
                                projectData['clientName'] ?? 'Nom inconnu',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            Chip(
                              label: Text(
                                projectData['status'] ?? 'Inconnu',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              backgroundColor: _getStatusColor(projectData['status'] ?? ''),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  projectData['createdByName'] ?? 'N/A',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy').format(createdAt),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
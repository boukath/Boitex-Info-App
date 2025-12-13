// lib/screens/administration/replacement_requests_hub_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/replacement_request_details_page.dart';

class ReplacementRequestsHubPage extends StatelessWidget {
  // MODIFIED: Add constructor parameters
  final String pageTitle;
  final String? filterStatus;

  const ReplacementRequestsHubPage({
    super.key,
    required this.pageTitle,
    this.filterStatus,
  });

  Widget _getStatusChip(String status) {
    Color color;
    switch (status) {
      case "En attente d'action":
        color = Colors.red;
        break;
      case 'Devis envoyé':
        color = Colors.blue;
        break;
      case 'Approuvé - Produit en stock':
        color = Colors.orange;
        break;
      case 'Approuvé - Bon de commande reçu':
      case 'Approuvé - Confirmation téléphonique':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    // MODIFIED: Build the query dynamically
    Query query = FirebaseFirestore.instance
        .collection('replacementRequests')
        .orderBy('createdAt', descending: true);

    if (filterStatus != null) {
      query = query.where('requestStatus', isEqualTo: filterStatus);
    }

    return Scaffold(
      appBar: AppBar(
        // MODIFIED: Use the dynamic page title
        title: Text(pageTitle),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // MODIFIED: Use the dynamic query
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucune demande de remplacement.'));
          }

          final requestDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: requestDocs.length,
            itemBuilder: (context, index) {
              final requestDoc = requestDocs[index];
              final requestData = requestDoc.data() as Map<String, dynamic>;
              final createdAt = (requestData['createdAt'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ReplacementRequestDetailsPage(requestId: requestDoc.id),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          foregroundColor: Colors.red,
                          child: const Icon(Icons.sync_problem_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(requestData['replacementRequestCode'] ?? requestData['savCode'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                'Client: ${requestData['clientName'] ?? ''}',
                                style: TextStyle(color: Colors.grey.shade700),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Produit: ${requestData['productName'] ?? ''}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _getStatusChip(requestData['requestStatus'] ?? ''),
                            const SizedBox(height: 8),
                            Text(DateFormat('dd/MM/yy').format(createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
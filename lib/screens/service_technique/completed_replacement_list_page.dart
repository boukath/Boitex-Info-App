// lib/screens/service_technique/completed_replacement_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/replacement_request_details_page.dart';

class CompletedReplacementListPage extends StatelessWidget {
  // ✅ ADDED: Accept the serviceType
  final String serviceType;

  const CompletedReplacementListPage({super.key, required this.serviceType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique Remplacements - $serviceType'),
        backgroundColor: Colors.red,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('replacementRequests')
        // ✅ ADDED: Filter by serviceType
            .where('serviceType', isEqualTo: serviceType)
            .where('requestStatus', isEqualTo: 'Remplacement Effectué')
            .orderBy('completedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // ... The rest of the file is the same
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
                  Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun remplacement terminé',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final doc = requests[index];
              final data = doc.data() as Map<String, dynamic>;

              final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
              final formattedDate = completedAt != null
                  ? DateFormat('dd MMM yyyy', 'fr_FR').format(completedAt)
                  : 'Date inconnue';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.withOpacity(0.1),
                    child: const Icon(Icons.check_circle, color: Colors.grey),
                  ),
                  title: Text(
                    data['replacementRequestCode'] ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Client: ${data['clientName'] ?? 'N/A'}\nProduit: ${data['productName'] ?? 'N/A'}',
                  ),
                  trailing: Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReplacementRequestDetailsPage(requestId: doc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
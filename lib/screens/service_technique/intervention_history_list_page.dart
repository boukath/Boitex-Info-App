// lib/screens/service_technique/intervention_history_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';

class InterventionHistoryListPage extends StatelessWidget {
  // ✅ ADDED: Accept the serviceType
  final String serviceType;

  const InterventionHistoryListPage({super.key, required this.serviceType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Interventions'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('interventions')
        // ✅ ADDED: The filter for serviceType
            .where('serviceType', isEqualTo: serviceType)
            .where('status', isEqualTo: 'Clôturé')
            .orderBy('closedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // ... The rest of the file remains the same ...
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucune intervention clôturée trouvée.'));
          }

          final interventionDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: interventionDocs.length,
            itemBuilder: (context, index) {
              final interventionDoc = interventionDocs[index];
              final data = interventionDoc.data() as Map<String, dynamic>;

              final closedDate = (data['closedAt'] as Timestamp?)?.toDate();
              final billingStatus = data['billingStatus'] ?? 'N/A';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16.0),
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withOpacity(0.1),
                    child: const Icon(Icons.check_circle, color: Colors.green),
                  ),
                  title: Text(
                    '${data['storeName']} - ${data['storeLocation']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Clôturée le: ${closedDate != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(closedDate) : 'N/A'}\nStatut: $billingStatus',
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => InterventionDetailsPage(interventionDoc: interventionDoc),
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
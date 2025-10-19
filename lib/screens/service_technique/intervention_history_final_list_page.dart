// lib/screens/service_technique/intervention_history_final_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';

class InterventionHistoryFinalListPage extends StatelessWidget {
  final String serviceType;
  final String clientName;
  final String storeName;
  final String locationName;

  const InterventionHistoryFinalListPage({
    super.key,
    required this.serviceType,
    required this.clientName,
    required this.storeName,
    required this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(locationName),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>( // typed stream
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('serviceType', isEqualTo: serviceType)
            .where('status', isEqualTo: 'Clôturé')
            .where('clientName', isEqualTo: clientName)
            .where('storeName', isEqualTo: storeName)
            .where('storeLocation', isEqualTo: locationName)
            .orderBy('closedAt', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucune intervention trouvée pour cet emplacement.'));
          }

          final interventionDocs = snapshot.data!.docs; // List<QueryDocumentSnapshot<Map<String, dynamic>>>
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: interventionDocs.length,
            itemBuilder: (context, index) {
              final interventionDoc = interventionDocs[index];
              final data = interventionDoc.data();

              final DateTime? closedDate = (data['closedAt'] as Timestamp?)?.toDate();
              final String billingStatus = (data['billingStatus'] as String?) ?? 'N/A';

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
                    'Clôturée le: ${closedDate != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(closedDate) : 'N/A'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Statut: $billingStatus'),
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

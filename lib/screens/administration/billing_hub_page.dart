import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/billing_decision_page.dart';

class BillingHubPage extends StatelessWidget {
  const BillingHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturation en Attente'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('status', isEqualTo: 'Terminé')
            .orderBy('interventionDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucune intervention en attente de facturation.'));
          }

          final interventionDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: interventionDocs.length,
            itemBuilder: (context, index) {
              final doc = interventionDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final interventionDate = (data['interventionDate'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.receipt_long_outlined),
                  ),
                  title: Text(data['interventionCode'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${data['clientName'] ?? ''}\n${data['storeName'] ?? ''}',
                  ),
                  trailing: Text(DateFormat('dd/MM/yy').format(interventionDate)),
                  // **MODIFIED**: Added navigation
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => BillingDecisionPage(interventionDoc: doc)),
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
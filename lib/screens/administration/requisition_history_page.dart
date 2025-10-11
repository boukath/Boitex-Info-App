// lib/screens/administration/requisition_history_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';

class RequisitionHistoryPage extends StatelessWidget {
  const RequisitionHistoryPage({super.key});

  Widget _getStatusChip(String status) {
    Color color;
    switch (status) {
      case 'Reçue':
        color = Colors.green;
        break;
      case 'Reçue avec Écarts':
        color = Colors.orange;
        break;
      case 'Refusée':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Achats'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requisitions')
            .where('status', whereIn: ['Reçue', 'Reçue avec Écarts', 'Refusée'])
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
            return const Center(child: Text('Aucun historique d\'achat trouvé.'));
          }

          final requisitionDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: requisitionDocs.length,
            itemBuilder: (context, index) {
              final reqDoc = requisitionDocs[index];
              final reqData = reqDoc.data() as Map<String, dynamic>;
              final createdAt = (reqData['createdAt'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                child: ListTile(
                  title: Text(
                    reqData['requisitionCode'] ?? 'Demande',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Demandé par: ${reqData['requestedBy'] ?? ''}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(DateFormat('dd/MM/yy').format(createdAt)),
                      const SizedBox(height: 4),
                      _getStatusChip(reqData['status']),
                    ],
                  ),
                  onTap: () {
                    // Assuming you have a userRole available here.
                    // For simplicity, I'm passing 'Admin' but you might need to get the actual user role.
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RequisitionDetailsPage(
                          requisitionId: reqDoc.id,
                          userRole: 'Admin',
                        ),
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
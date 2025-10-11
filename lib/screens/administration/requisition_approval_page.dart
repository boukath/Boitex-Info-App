// lib/screens/administration/requisition_approval_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';

class RequisitionApprovalPage extends StatelessWidget {
  final String userRole;
  const RequisitionApprovalPage({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approbations Requises'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requisitions')
            .where('status', isEqualTo: "En attente d'approbation")
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucune demande en attente d\'approbation.'));
          }

          final requisitionDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: requisitionDocs.length,
            itemBuilder: (context, index) {
              final reqDoc = requisitionDocs[index];
              final reqData = reqDoc.data() as Map<String, dynamic>;
              final createdAt = (reqData['createdAt'] as Timestamp).toDate();
              final items = reqData['items'] as List<dynamic>? ?? [];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.inventory),
                  ),
                  title: Text(
                      reqData['requisitionCode'] ?? 'Demandé par: ${reqData['requestedBy'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  subtitle: Text('${items.length} article(s)'),
                  trailing: Text(DateFormat('dd/MM/yy').format(createdAt)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RequisitionDetailsPage(
                          requisitionId: reqDoc.id,
                          userRole: userRole,
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
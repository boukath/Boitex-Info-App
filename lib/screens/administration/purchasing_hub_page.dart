// lib/screens/administration/purchasing_hub_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';

class PurchasingHubPage extends StatelessWidget {
  final String userRole;

  const PurchasingHubPage({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commandes à Passer')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requisitions')
            .where(
          'status',
          whereIn: <String>[
            'Approuvée',  // PDG has approved but not yet ordered
            'Commandée',  // PDG has clicked “Confirmer commande”
          ],
        )
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Aucune commande à passer.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data()! as Map<String, dynamic>;
              final createdAt = (data['createdAt'] as Timestamp).toDate();
              final items = (data['items'] as List<dynamic>?) ?? [];

              return Card(
                margin:
                const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.shopping_cart_checkout),
                  ),
                  title: Text(
                    'Demandé par : ${data['requestedBy'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${items.length} article(s) à commander'),
                  trailing: Text(DateFormat('dd/MM/yy').format(createdAt)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RequisitionDetailsPage(
                          requisitionId: doc.id,
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

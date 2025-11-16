// lib/screens/service_technique/intervention_history_stores_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_history_locations_page.dart';

// ✅ MODIFIED: Converted back to a StatelessWidget
class InterventionHistoryStoresPage extends StatelessWidget {
  final String serviceType;
  final String clientName;

  const InterventionHistoryStoresPage({
    super.key,
    required this.serviceType,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(clientName),
      ),
      // ✅ REMOVED: The Column and TextField are gone
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('serviceType', isEqualTo: serviceType)
            .where('status', whereIn: ['Terminé', 'Clôturé'])
            .where('clientName', isEqualTo: clientName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('Aucun magasin trouvé pour ce client.'));
          }

          // ✅ REVERTED: No more filtering, just gets the full list
          final storeNames = snapshot.data!.docs
              .map((doc) =>
          (doc.data() as Map<String, dynamic>)['storeName']
          as String? ??
              'Magasin non spécifié')
              .toSet()
              .toList();

          storeNames.sort();

          return ListView.builder(
            itemCount: storeNames.length,
            itemBuilder: (context, index) {
              final storeName = storeNames[index];
              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ListTile(
                  leading: const Icon(Icons.store, color: Colors.teal),
                  title: Text(storeName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InterventionHistoryLocationsPage(
                          serviceType: serviceType,
                          clientName: clientName,
                          storeName: storeName,
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
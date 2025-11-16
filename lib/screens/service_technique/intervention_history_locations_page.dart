// lib/screens/service_technique/intervention_history_locations_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_history_final_list_page.dart';

// ✅ MODIFIED: Converted back to a StatelessWidget
class InterventionHistoryLocationsPage extends StatelessWidget {
  final String serviceType;
  final String clientName;
  final String storeName;

  const InterventionHistoryLocationsPage({
    super.key,
    required this.serviceType,
    required this.clientName,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(storeName),
      ),
      // ✅ REMOVED: The Column and TextField are gone
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('serviceType', isEqualTo: serviceType)
            .where('status', whereIn: ['Terminé', 'Clôturé'])
            .where('clientName', isEqualTo: clientName)
            .where('storeName', isEqualTo: storeName)
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
                child: Text('Aucun emplacement trouvé pour ce magasin.'));
          }

          // ✅ REVERTED: No more filtering, just gets the full list
          final locationNames = snapshot.data!.docs
              .map((doc) =>
          (doc.data()
          as Map<String, dynamic>)['storeLocation'] as String? ??
              'Emplacement non spécifié')
              .toSet()
              .toList();

          locationNames.sort();

          return ListView.builder(
            itemCount: locationNames.length,
            itemBuilder: (context, index) {
              final locationName = locationNames[index];
              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ListTile(
                  leading:
                  const Icon(Icons.location_on, color: Colors.orange),
                  title: Text(locationName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InterventionHistoryFinalListPage(
                          serviceType: serviceType,
                          clientName: clientName,
                          storeName: storeName,
                          locationName: locationName,
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
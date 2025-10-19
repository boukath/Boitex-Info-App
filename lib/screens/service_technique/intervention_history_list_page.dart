// lib/screens/service_technique/intervention_history_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';

class InterventionHistoryListPage extends StatelessWidget {
  final String serviceType;

  const InterventionHistoryListPage({super.key, required this.serviceType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Interventions'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('serviceType', isEqualTo: serviceType)
            .where('status', isEqualTo: 'Clôturé')
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
            return const Center(child: Text('Aucune intervention clôturée trouvée.'));
          }

          final docs = snapshot.data!.docs; // List<QueryDocumentSnapshot<Map<String, dynamic>>>
          final grouped = _groupInterventions(docs);

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final clientName = grouped.keys.elementAt(index);
              final stores = grouped[clientName]!;
              return _buildClientTile(context, clientName, stores);
            },
          );
        },
      ),
    );
  }

  // client -> store -> location -> list of docs
  Map<String, Map<String, Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>>> _groupInterventions(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final Map<String, Map<String, Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>>> grouped = {};

    for (final doc in docs) {
      final data = doc.data();
      final String clientName = (data['clientName'] as String?) ?? 'Client non spécifié';
      final String storeName = (data['storeName'] as String?) ?? 'Magasin non spécifié';
      final String locationName = (data['storeLocation'] as String?) ?? 'Emplacement non spécifié';

      grouped.putIfAbsent(clientName, () => {});
      grouped[clientName]!.putIfAbsent(storeName, () => {});
      grouped[clientName]![storeName]!.putIfAbsent(locationName, () => []);
      grouped[clientName]![storeName]![locationName]!.add(doc);
    }

    return grouped;
  }

  Widget _buildClientTile(
      BuildContext context,
      String clientName,
      Map<String, Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>> stores,
      ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.business, color: Colors.blueGrey),
        title: Text(
          clientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: stores.keys.map((storeName) {
          final locations = stores[storeName]!;
          return _buildStoreTile(context, storeName, locations);
        }).toList(),
      ),
    );
  }

  Widget _buildStoreTile(
      BuildContext context,
      String storeName,
      Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> locations,
      ) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: ExpansionTile(
        leading: const Icon(Icons.store, color: Colors.teal),
        title: Text(storeName),
        children: locations.keys.map((locationName) {
          final interventions = locations[locationName]!;
          return _buildLocationTile(context, locationName, interventions);
        }).toList(),
      ),
    );
  }

  Widget _buildLocationTile(
      BuildContext context,
      String locationName,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> interventions,
      ) {
    return Padding(
      padding: const EdgeInsets.only(left: 32.0),
      child: ExpansionTile(
        leading: const Icon(Icons.location_on, color: Colors.orange),
        title: Text(locationName),
        children: interventions
            .map((interventionDoc) => _buildInterventionTile(context, interventionDoc))
            .toList(),
      ),
    );
  }

  Widget _buildInterventionTile(
      BuildContext context,
      DocumentSnapshot<Map<String, dynamic>> interventionDoc,
      ) {
    final data = interventionDoc.data() ?? {};
    final DateTime? closedDate = (data['closedAt'] as Timestamp?)?.toDate();
    final String billingStatus = (data['billingStatus'] as String?) ?? 'N/A';

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 48.0, right: 16.0),
      leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
      title: Text(
        'Clôturée le: ${closedDate != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(closedDate) : 'N/A'}',
      ),
      subtitle: Text('Statut: $billingStatus'),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => InterventionDetailsPage(interventionDoc: interventionDoc),
          ),
        );
      },
    );
  }
}

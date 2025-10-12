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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('serviceType', isEqualTo: serviceType)
            .where('status', isEqualTo: 'Clôturé')
            .orderBy('closedAt', descending: true)
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
                child: Text('Aucune intervention clôturée trouvée.'));
          }

          final interventionDocs = snapshot.data!.docs;
          final groupedInterventions =
          _groupInterventions(interventionDocs);

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: groupedInterventions.keys.length,
            itemBuilder: (context, index) {
              final clientName = groupedInterventions.keys.elementAt(index);
              final stores = groupedInterventions[clientName]!;
              return _buildClientTile(context, clientName, stores);
            },
          );
        },
      ),
    );
  }

  Map<String, Map<String, Map<String, List<DocumentSnapshot>>>>
  _groupInterventions(List<DocumentSnapshot> docs) {
    final Map<String, Map<String, Map<String, List<DocumentSnapshot>>>>
    grouped = {};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final clientName = data['clientName'] ?? 'Client non spécifié';
      final storeName = data['storeName'] ?? 'Magasin non spécifié';
      final storeLocation =
          data['storeLocation'] ?? 'Emplacement non spécifié';

      grouped
          .putIfAbsent(clientName, () => {})
          .putIfAbsent(storeName, () => {})
          .putIfAbsent(storeLocation, () => [])
          .add(doc);
    }

    return grouped;
  }

  Widget _buildClientTile(BuildContext context, String clientName,
      Map<String, Map<String, List<DocumentSnapshot>>> stores) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.business, color: Colors.blueGrey),
        title: Text(clientName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        children: stores.keys.map((storeName) {
          final locations = stores[storeName]!;
          return _buildStoreTile(context, storeName, locations);
        }).toList(),
      ),
    );
  }

  Widget _buildStoreTile(BuildContext context, String storeName,
      Map<String, List<DocumentSnapshot>> locations) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: ExpansionTile(
        leading: const Icon(Icons.store, color: Colors.teal),
        title: Text(storeName),
        children: locations.keys.map((locationName) {
          final interventions = locations[locationName]!;
          return _buildLocationTile(
              context, locationName, interventions);
        }).toList(),
      ),
    );
  }

  Widget _buildLocationTile(BuildContext context, String locationName,
      List<DocumentSnapshot> interventions) {
    return Padding(
      padding: const EdgeInsets.only(left: 32.0),
      child: ExpansionTile(
        leading: const Icon(Icons.location_on, color: Colors.orange),
        title: Text(locationName),
        children: interventions.map((interventionDoc) {
          return _buildInterventionTile(context, interventionDoc);
        }).toList(),
      ),
    );
  }

  Widget _buildInterventionTile(
      BuildContext context, DocumentSnapshot interventionDoc) {
    final data = interventionDoc.data() as Map<String, dynamic>;
    final closedDate = (data['closedAt'] as Timestamp?)?.toDate();
    final billingStatus = data['billingStatus'] ?? 'N/A';

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
            builder: (context) =>
                InterventionDetailsPage(interventionDoc: interventionDoc),
          ),
        );
      },
    );
  }
}
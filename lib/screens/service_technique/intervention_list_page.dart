// lib/screens/service_technique/intervention_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:boitex_info_app/screens/service_technique/add_intervention_page.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';

class InterventionListPage extends StatelessWidget {
  final String userRole;
  final String serviceType;

  const InterventionListPage({
    super.key,
    required this.userRole,
    required this.serviceType,
  });

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'En cours':
        return Colors.orange.shade700;
      case 'Nouveau':
        return Colors.blue.shade700;
      case 'Terminé':
        return Colors.green.shade700;
      case 'En attente':
        return Colors.purple.shade700;
      default:
        return Colors.grey;
    }
  }

  Widget _getPriorityFlag(String? priority) {
    Color flagColor = Colors.grey;
    switch (priority) {
      case 'Haute':
        flagColor = Colors.red;
        break;
      case 'Moyenne':
        flagColor = Colors.orange;
        break;
      case 'Basse':
        flagColor = Colors.green;
        break;
    }
    return Icon(Icons.flag, color: flagColor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Interventions $serviceType'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>( // typed snapshot
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('serviceType', isEqualTo: serviceType)
            .where('status', whereIn: ['Nouveau', 'En cours', 'En attente'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucune intervention active trouvée.'));
          }

          final interventionDocs = snapshot.data!.docs; // List<QueryDocumentSnapshot<Map<String, dynamic>>>
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: interventionDocs.length,
            itemBuilder: (context, index) {
              final interventionDoc = interventionDocs[index]; // typed document
              final Map<String, dynamic> interventionData = interventionDoc.data();

              final Timestamp ts = interventionData['createdAt'] as Timestamp;
              final DateTime createdAt = ts.toDate();
              final String creatorName = (interventionData['createdByName'] as String?) ?? 'Inconnu';

              return Card(
                elevation: 2.0,
                margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                child: ListTile(
                  leading: _getPriorityFlag(interventionData['priority'] as String?),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                  title: Text(
                    '${interventionData['storeName']} - ${interventionData['storeLocation']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Client: ${interventionData['clientName']}\n'
                        '${DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR').format(createdAt)}\n'
                        'Créé par: $creatorName',
                  ),
                  isThreeLine: true,
                  trailing: Chip(
                    label: Text(
                      (interventionData['status'] as String?) ?? 'Inconnu',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: _getStatusColor(interventionData['status'] as String?),
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        // QueryDocumentSnapshot<Map<String, dynamic>> is a DocumentSnapshot<Map<String, dynamic>>
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
      floatingActionButton: RolePermissions.canAddIntervention(userRole)
          ? FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => AddInterventionPage(serviceType: serviceType)),
          );
        },
        tooltip: "Nouvelle Demande D'intervention",
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}

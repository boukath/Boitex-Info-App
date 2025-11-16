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
        // ✅ 1. QUERY CHANGE: Now fetches both 'Terminé' and 'Clôturé'
            .where('status', whereIn: ['Terminé', 'Clôturé'])
            .where('clientName', isEqualTo: clientName)
            .where('storeName', isEqualTo: storeName)
            .where('storeLocation', isEqualTo: locationName)
        // ✅ 2. QUERY CHANGE: Sort by status first, then by date
            .orderBy('status') // Groups 'Clôturé' then 'Terminé' (alphabetical)
            .orderBy('closedAt', descending: true) // Sorts within those groups
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

          final interventionDocs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: interventionDocs.length,
            itemBuilder: (context, index) {
              final interventionDoc = interventionDocs[index];
              final data = interventionDoc.data();

              // ✅ 3. UI LOGIC: Get the status to decide the UI
              final String status = data['status'] ?? 'N/A';

              // Define UI variables based on status
              final IconData iconData;
              final Color iconColor;
              final String titleText;
              final String subtitleText;

              if (status == 'Clôturé') {
                // --- UI for "Clôturé" (Green Icon) ---
                final DateTime? closedDate = (data['closedAt'] as Timestamp?)?.toDate();
                final String billingStatus = (data['billingStatus'] as String?) ?? 'N/A';

                iconData = Icons.check_circle;
                iconColor = Colors.green;
                titleText = 'Clôturée le: ${closedDate != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(closedDate) : 'N/A'}';
                subtitleText = 'Statut: $billingStatus';
              } else {
                // --- UI for "Terminé" (Yellow Icon) ---
                // Use 'completedAt' as 'closedAt' might be null
                final DateTime? completedDate = (data['completedAt'] as Timestamp?)?.toDate();

                iconData = Icons.pending_actions; // Yellow "pending" icon
                iconColor = Colors.orange;
                titleText = 'Terminée le: ${completedDate != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(completedDate) : 'N/A'}';
                subtitleText = 'Statut: En attente de facturation'; // Clear message
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16.0),
                  // ✅ 4. UI LOGIC: Use dynamic icon and color
                  leading: CircleAvatar(
                    backgroundColor: iconColor.withOpacity(0.1),
                    child: Icon(iconData, color: iconColor),
                  ),
                  // ✅ 5. UI LOGIC: Use dynamic titles
                  title: Text(
                    titleText,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(subtitleText),
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
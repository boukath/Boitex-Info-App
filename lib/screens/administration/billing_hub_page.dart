// lib/screens/administration/billing_hub_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/billing_decision_page.dart';
import 'package:boitex_info_app/screens/administration/sav_billing_decision_page.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';

// ✅ FIXED: Converted to StatefulWidget to allow refreshing the list
class BillingHubPage extends StatefulWidget {
  const BillingHubPage({super.key});

  @override
  State<BillingHubPage> createState() => _BillingHubPageState();
}

class _BillingHubPageState extends State<BillingHubPage> {
  // ✅ FIXED: Replaced StreamBuilder with a Future to correctly combine two separate queries.
  Future<List<DocumentSnapshot>> _fetchPendingItems() async {
    final interventionsFuture = FirebaseFirestore.instance
        .collection('interventions')
        .where('status', isEqualTo: 'Terminé')
        .get();

    final savTicketsFuture = FirebaseFirestore.instance
        .collection('sav_tickets')
        .where('status', isEqualTo: 'Terminé')
        .get();

    final results = await Future.wait([interventionsFuture, savTicketsFuture]);

    final allDocs = [...results[0].docs, ...results[1].docs];

    // Sort all documents by their creation date, descending.
    allDocs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aDate = (aData['createdAt'] as Timestamp? ??
          aData['interventionDate'] as Timestamp)
          .toDate();
      final bDate = (bData['createdAt'] as Timestamp? ??
          bData['interventionDate'] as Timestamp)
          .toDate();
      return bDate.compareTo(aDate);
    });

    return allDocs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturation en Attente'),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _fetchPendingItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text('Aucun dossier en attente de facturation.'));
          }

          final allDocs = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: allDocs.length,
            itemBuilder: (context, index) {
              final doc = allDocs[index];
              final data = doc.data() as Map<String, dynamic>;

              final bool isIntervention = data.containsKey('interventionCode');

              if (isIntervention) {
                return _buildInterventionTile(context, doc);
              } else {
                return _buildSavTicketTile(context, doc);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildInterventionTile(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['interventionDate'] as Timestamp).toDate();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          child: Icon(Icons.construction_outlined),
        ),
        title: Text(data['interventionCode'] ?? 'Intervention',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${data['clientName'] ?? ''}\n${data['storeName'] ?? ''}',
        ),
        trailing: Text(DateFormat('dd/MM/yy').format(date)),
        onTap: () {
          Navigator.of(context)
              .push(
            MaterialPageRoute(
                builder: (context) =>
                    BillingDecisionPage(interventionDoc: doc)),
          )
              .then((_) => setState(() {})); // Refresh the list on return
        },
      ),
    );
  }

  Widget _buildSavTicketTile(BuildContext context, DocumentSnapshot doc) {
    final ticket =
    SavTicket.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          child: Icon(Icons.support_agent_outlined),
        ),
        title: Text(ticket.savCode,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${ticket.clientName}\n${ticket.productName}',
        ),
        trailing: Text(DateFormat('dd/MM/yy').format(ticket.createdAt)),
        onTap: () {
          Navigator.of(context)
              .push(
            MaterialPageRoute(
                builder: (context) => SavBillingDecisionPage(ticket: ticket)),
          )
              .then((_) => setState(() {})); // Refresh the list on return
        },
      ),
    );
  }
}
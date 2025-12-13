// lib/screens/administration/billing_hub_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/billing_decision_page.dart';

// ✅ FIXED: Converted to StatefulWidget to allow refreshing the list
class BillingHubPage extends StatefulWidget {
  const BillingHubPage({super.key});

  @override
  State<BillingHubPage> createState() => _BillingHubPageState();
}

class _BillingHubPageState extends State<BillingHubPage> {
  // ✅ FIXED: Replaced StreamBuilder with a Future to correctly combine two separate queries.
  Future<List<DocumentSnapshot>> _fetchPendingItems() async {
    final interventionsSnapshot = await FirebaseFirestore.instance
        .collection('interventions')
        .where('status', isEqualTo: 'Terminé')
        .get();

    final allDocs = interventionsSnapshot.docs;

    // ✅ FIXED: Sort by date. Handle potential nulls in 'interventionDate' or 'createdAt'.
    allDocs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>?;
      final bData = b.data() as Map<String, dynamic>?;

      // Helper to get a date, checking multiple possible fields
      DateTime? getDate(Map<String, dynamic>? data) {
        if (data == null) return null;
        final ts = (data['interventionDate'] ?? data['createdAt'] ?? data['updatedAt']) as Timestamp?;
        return ts?.toDate();
      }

      final aDate = getDate(aData) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = getDate(bData) ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate); // Sort descending (newest first)
    });

    return allDocs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dossiers à Facturer"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // ✅ FIXED: Refresh the FutureBuilder
              setState(() {});
            },
          ),
        ],
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _fetchPendingItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erreur: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "Aucun dossier en attente de facturation.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final items = snapshot.data!;

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final doc = items[index];
              final data = doc.data() as Map<String, dynamic>?; // Safe cast

              // ✅ FIXED: Check for null data
              if (data == null) {
                return Card(
                  color: Colors.red.shade100,
                  child: ListTile(
                    leading: const Icon(Icons.error, color: Colors.red),
                    title: Text("Erreur de données pour doc ID: ${doc.id}"),
                    subtitle: const Text("Ce document est peut-être corrompu."),
                  ),
                );
              }

              // Determine if it's an intervention (SAV removed)
              if (data.containsKey('serviceType')) {
                // This is an Intervention
                return _buildInterventionTile(context, doc);
              }

              // Fallback for an unknown document type
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.help),
                  title: Text("Document inconnu: ${doc.id}"),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInterventionTile(BuildContext context, DocumentSnapshot doc) {
    // ✅ FIX: Apply null-safety to all data access
    final data = doc.data() as Map<String, dynamic>?;

    // Safety check: If data is null, return an error tile.
    if (data == null) {
      return Card(
        color: Colors.red.shade100,
        child: ListTile(
          leading: const Icon(Icons.error, color: Colors.red),
          title: Text("Erreur de données pour Intervention ID: ${doc.id}"),
        ),
      );
    }

    final clientName = data['clientName'] as String? ?? 'Client N/A';
    final serviceType = data['serviceType'] as String? ?? 'Service N/A';

    // ✅ FIX: Safely get and format the date
    final dateRaw = (data['interventionDate'] ?? data['createdAt']) as Timestamp?;
    final String dateFormatted;
    if (dateRaw != null) {
      dateFormatted = DateFormat('dd/MM/yy').format(dateRaw.toDate());
    } else {
      dateFormatted = 'Date N/A';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: serviceType == 'Service IT' ? Colors.green : Colors.blue,
          foregroundColor: Colors.white,
          child: Icon(serviceType == 'Service IT' ? Icons.computer : Icons.construction),
        ),
        title: Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(serviceType),
        trailing: Text(dateFormatted), // Use the safe, formatted string
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
}
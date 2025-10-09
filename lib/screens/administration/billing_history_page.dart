// lib/screens/administration/billing_history_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
// ADDED: Import for launching URLs
import 'package:url_launcher/url_launcher.dart';

class BillingHistoryPage extends StatelessWidget {
  const BillingHistoryPage({super.key});

  Future<void> _launchURL(BuildContext context, String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir le lien: $urlString')),
        );
      }
    }
  }

  void _navigateToDetails(BuildContext context, String? interventionId) async {
    if (interventionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID de l\'intervention manquant.'))
      );
      return;
    }
    try {
      final interventionDoc = await FirebaseFirestore.instance
          .collection('interventions')
          .doc(interventionId)
          .get();

      if (context.mounted && interventionDoc.exists) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => InterventionDetailsPage(interventionDoc: interventionDoc),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible de trouver l\'intervention.'))
        );
      }
    } catch (e) {
      print('Error fetching intervention: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique de Facturation"),
        backgroundColor: const Color(0xFFF8F8FA),
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      backgroundColor: const Color(0xFFF8F8FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('global_activity_log')
            .where('category', isEqualTo: 'Facturation')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Aucune activité de facturation enregistrée.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text("Erreur de chargement de l'historique."),
            );
          }

          final logs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index].data() as Map<String, dynamic>;

              final timestamp = log['timestamp'] as Timestamp?;
              final formattedDate = timestamp != null
                  ? DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(timestamp.toDate())
                  : 'Date inconnue';

              final storeName = log['storeName'] ?? log['interventionCode'] ?? 'N/A';
              final storeLocation = log['storeLocation'] ?? '';
              final userName = log['userName'] ?? 'Utilisateur inconnu';
              final interventionId = log['interventionId'] as String?;
              final invoiceUrl = log['invoiceUrl'] as String?; // Get the invoice URL

              return Card(
                elevation: 1.0,
                margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                child: ListTile(
                  onTap: () => _navigateToDetails(context, interventionId),
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.withOpacity(0.1),
                    child: const Icon(Icons.receipt_long, color: Colors.teal),
                  ),
                  title: Text(
                    '$storeName - $storeLocation',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${log['message']}\nPar: $userName\n$formattedDate",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  isThreeLine: true,
                  // MODIFIED: The trailing widget is now dynamic
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Conditionally show the invoice button
                      if (invoiceUrl != null)
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          color: Colors.green,
                          tooltip: 'Voir la facture',
                          onPressed: () => _launchURL(context, invoiceUrl),
                        ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
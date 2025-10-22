// lib/screens/administration/billing_history_page.dart
// ✅ MODIFIED TO SHOW ALL HISTORY IN ONE PAGE

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class BillingHistoryPage extends StatelessWidget {
  // We keep these optional filters. If they are passed, they will work.
  // If not (our new flow), the page will just show everything.
  final String? clientNameFilter;
  final String? storeNameFilter;
  final String? storeLocationFilter;

  const BillingHistoryPage({
    super.key,
    this.clientNameFilter,
    this.storeNameFilter,
    this.storeLocationFilter,
  });

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
          const SnackBar(content: Text('ID de l\'intervention manquant.')));
      return;
    }
    try {
      final interventionDoc = await FirebaseFirestore.instance
          .collection('interventions')
          .doc(interventionId)
          .get();

      if (interventionDoc.exists && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InterventionDetailsPage(
              interventionDoc: interventionDoc,
            ),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Intervention non trouvée ou supprimée.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur lors de la récupération de l\'intervention: $e')));
      }
    }
  }

  // ✅ MODIFIED: Simplified title functions
  // We check if any filter is active. If so, show "Filtre Appliqué".
  // Otherwise, show "Historique Facturation".
  String _buildTitle() {
    if (clientNameFilter != null || storeNameFilter != null || storeLocationFilter != null) {
      return storeLocationFilter ?? storeNameFilter ?? clientNameFilter ?? 'Filtre Appliqué';
    }
    return 'Historique Facturation';
  }

  // ✅ MODIFIED: Show filter details or a general subtitle.
  String _buildSubtitle() {
    if (storeLocationFilter != null && storeNameFilter != null) {
      return '$storeNameFilter ($clientNameFilter)';
    }
    if (storeNameFilter != null) {
      return clientNameFilter ?? '';
    }
    if (clientNameFilter != null) {
      return 'Filtre: $clientNameFilter';
    }
    return 'Toutes les transactions'; // New default subtitle
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('global_activity_log')
        .where('category', whereIn: ['Intervention Facturée', 'Intervention Clôturée Sans Facture', 'Facturation']) // ✅ MODIFIED: Use 'category' for reliability
        .orderBy('timestamp', descending: true);

    // This filter logic is still 100% valid.
    // If filters are null, it just skips them.
    if (clientNameFilter != null && clientNameFilter!.isNotEmpty) {
      query = query.where('clientName', isEqualTo: clientNameFilter);
    }
    if (storeNameFilter != null && storeNameFilter!.isNotEmpty) {
      query = query.where('storeName', isEqualTo: storeNameFilter);
    }
    if (storeLocationFilter != null && storeLocationFilter!.isNotEmpty) {
      if (storeLocationFilter == "Emplacement non spécifié") {
        query = query.where('storeLocation', isNull: true);
      } else {
        query = query.where('storeLocation', isEqualTo: storeLocationFilter);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.0,
        foregroundColor: const Color(0xFF1E1E2A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _buildTitle(), // Uses our new title logic
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            if (_buildSubtitle().isNotEmpty)
              Text(
                _buildSubtitle(), // Uses our new subtitle logic
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("Firestore Error: ${snapshot.error}");
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Text(
                  'Aucun historique de facturation trouvé.', // Simplified message
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ));
          }

          final logs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index].data() as Map<String, dynamic>;
              final timestamp = log['timestamp'] as Timestamp?;
              final formattedDate = timestamp != null
                  ? DateFormat('dd/MM/yyyy HH:mm', 'fr_FR')
                  .format(timestamp.toDate())
                  : 'Date inconnue';
              
              // ✅ MODIFIED: Get all relevant data
              final userName = log['userName'] ?? 'Utilisateur inconnu';
              final clientName = log['clientName'] ?? 'Client inconnu';
              final storeName = log['storeName'] ?? 'Magasin inconnu';
              // final storeLocation = log['storeLocation'] ?? 'Lieu inconnu'; // Not used, but here if you need it
              final interventionId = log['interventionId'] ?? log['relatedId'] as String?; // Check both fields
              final invoiceUrl = log['invoiceUrl'] as String?;
              final message = log['message'] ?? 'Action inconnue';

              // ✅ MODIFIED: Determine title and subtitle
              // New logic: Title is the client, subtitle has store and message.
              final String displayTitle = clientName;
              final String displaySubtitle = "$storeName\n$message\nPar: $userName - $formattedDate";

              return Card(
                elevation: 2.0,
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  onTap: () => _navigateToDetails(context, interventionId),
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.withOpacity(0.1),
                    child: const Icon(Icons.receipt_long, color: Colors.deepPurple),
                  ),
                  title: Text(
                    displayTitle, // ✅ Now shows Client Name
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    displaySubtitle, // ✅ Now shows Store, Message, User, and Date
                    style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  isThreeLine: true, // Keep this as true
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (invoiceUrl != null)
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          color: Colors.green.shade600,
                          tooltip: 'Voir la facture',
                          onPressed: () => _launchURL(context, invoiceUrl),
                          splashRadius: 20,
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
// lib/screens/administration/billing_history_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class BillingHistoryPage extends StatelessWidget {
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

  String _buildTitle() {
    if (storeLocationFilter != null && storeLocationFilter != "Emplacement non spécifié") {
      return storeLocationFilter!;
    }
    if (storeLocationFilter == "Emplacement non spécifié" && storeNameFilter != null) {
      return storeNameFilter!; // Show store name if location is unspecified
    }
    if (storeNameFilter != null) {
      return storeNameFilter!;
    }
    if (clientNameFilter != null) {
      return clientNameFilter!;
    }
    return 'Historique Facturation';
  }

  String _buildSubtitle() {
    if (storeLocationFilter != null && storeNameFilter != null) {
      // Show store(client) if location is specific, or just client if location unspecified
      return storeLocationFilter != "Emplacement non spécifié"
          ? '$storeNameFilter ($clientNameFilter)'
          : clientNameFilter ?? '';
    }
    if (storeNameFilter != null) {
      return clientNameFilter ?? '';
    }
    return 'Tous'; // More concise default
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('global_activity_log')
    // --- MODIFIED: Use whereIn for type ---
        .where('type', whereIn: ['Facturation', 'Intervention Facturée'])
    // --- END MODIFIED ---
        .orderBy('timestamp', descending: true);

    // Apply filters conditionally
    if (clientNameFilter != null && clientNameFilter!.isNotEmpty) {
      query = query.where('clientName', isEqualTo: clientNameFilter);
    }
    if (storeNameFilter != null && storeNameFilter!.isNotEmpty) {
      query = query.where('storeName', isEqualTo: storeNameFilter);
    }
    if (storeLocationFilter != null && storeLocationFilter!.isNotEmpty) {
      if (storeLocationFilter == "Emplacement non spécifié") {
        // Query for null or potentially empty string if that's how you store it
        query = query.where('storeLocation', isNull: true);
        // or query = query.where('storeLocation', isEqualTo: '');
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
              _buildTitle(),
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            if (_buildSubtitle().isNotEmpty)
              Text(
                _buildSubtitle(),
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
                  'Aucun historique trouvé pour les filtres sélectionnés.',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  textAlign: TextAlign.center, // Center text
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
              final userName = log['userName'] ?? 'Utilisateur inconnu';
              // Fallbacks added just in case, though filters should ensure they exist
              final storeName = log['storeName'] ?? storeNameFilter ?? 'Magasin inconnu';
              final storeLocation = log['storeLocation'] ?? storeLocationFilter ?? 'Lieu inconnu';
              final interventionId = log['relatedId'] as String?;
              final invoiceUrl = log['invoiceUrl'] as String?;

              // Determine the title based on context
              String displayTitle = storeName;
              // Only add location if we aren't already filtered to a specific location
              if (storeLocationFilter == null && storeLocation.isNotEmpty && storeLocation != "Emplacement non spécifié") {
                displayTitle += ' - $storeLocation';
              } else if (storeLocationFilter == "Emplacement non spécifié") {
                // Optionally indicate if the location was specifically unknown
                // displayTitle += ' (Lieu inconnu)';
              }


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
                    displayTitle, // Use the dynamically determined title
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    "${log['message'] ?? 'Action inconnue'}\nPar: $userName\n$formattedDate",
                    style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  isThreeLine: true,
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
// lib/screens/administration/billing_history_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Make sure this import path is correct for your project
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class BillingHistoryPage extends StatefulWidget {
  // These filters are no longer used by this query,
  // but we keep them so the constructor doesn't break other pages.
  final String? clientNameFilter;
  final String? storeNameFilter;
  final String? storeLocationFilter;

  const BillingHistoryPage({
    super.key,
    this.clientNameFilter,
    this.storeNameFilter,
    this.storeLocationFilter,
  });

  @override
  State<BillingHistoryPage> createState() => _BillingHistoryPageState();
}

class _BillingHistoryPageState extends State<BillingHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    // ✅ --- THIS IS THE FIX ---
    // Query the 'global_activity_log' collection
    // Filter by the 'Facturation' category
    // Order by timestamp
    Query query = FirebaseFirestore.instance
        .collection('global_activity_log')
        .where('category', isEqualTo: 'Facturation')
        .orderBy('timestamp', descending: true);
    // ✅ --- END OF FIX ---

    // We no longer apply the widget filters, as this page is for ALL history
    // and the search bar will handle filtering.

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 1,
        title: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Rechercher par client, magasin, date...',
              hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                },
              )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20.0),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // This will show if you need a Firestore index
            return Center(child: Text("Erreur: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "Aucune décision de facturation trouvée.",
                style: GoogleFonts.poppins(),
              ),
            );
          }

          final allDocs = snapshot.data!.docs;

          // The local search logic will now filter the full list
          final filteredDocs = allDocs.where((doc) {
            if (_searchQuery.isEmpty) {
              return true;
            }

            final data = doc.data() as Map<String, dynamic>;
            final clientName = (data['clientName'] as String? ?? '').toLowerCase();
            final storeName = (data['storeName'] as String? ?? '').toLowerCase();

            final timestamp = data['timestamp'] as Timestamp?;
            String formattedDate = '';
            if (timestamp != null) {
              formattedDate = DateFormat('dd/MM/yyyy', 'fr_FR').format(timestamp.toDate());
            }

            return clientName.contains(_searchQuery) ||
                storeName.contains(_searchQuery) ||
                formattedDate.contains(_searchQuery);

          }).toList();

          if (filteredDocs.isEmpty) {
            return Center(
              child: Text(
                "Aucun résultat pour '$_searchQuery'",
                style: GoogleFonts.poppins(),
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;

              // ✅ Map fields from 'global_activity_log'
              final message = data['message'] as String? ?? '';
              final interventionId = data['interventionId'] as String? ?? '';
              final clientName = data['clientName'] as String? ?? 'Client inconnu';
              final storeName = data['storeName'] as String? ?? 'Magasin inconnu';
              // ✅ 'madeBy' in the old code is 'userName' in the log
              final madeBy = data['userName'] as String? ?? 'Inconnu';
              final invoiceUrl = data['invoiceUrl'] as String?;

              final timestamp = data['timestamp'] as Timestamp?;
              final date = timestamp != null
                  ? DateFormat('dd MMM yyyy à HH:mm', 'fr_FR')
                  .format(timestamp.toDate())
                  : 'Date inconnue';

              String displayTitle = clientName;
              String displaySubtitle = '$storeName\n$madeBy - $date';
              if (message.isNotEmpty) {
                // Use the log message to show the decision
                displaySubtitle = '$storeName - $message\n$madeBy - $date';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  // ✅ --- FIX FOR NAVIGATION ---
                  // We can't navigate to InterventionDetailsPage with just the log entry.
                  // We need to fetch the intervention document first.
                  // For now, let's disable tap to prevent crashes.
                  // We can add this back later.
                  onTap: () {
                    // TODO: To navigate, we must fetch the intervention doc first
                    // using the 'interventionId'
                    if (interventionId.isNotEmpty) {
                      print('Intervention ID: $interventionId');
                      // We can implement the navigation in the next step
                    }
                  },
                  // ✅ --- END OF FIX ---
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.withOpacity(0.1),
                    child: const Icon(Icons.receipt_long,
                        color: Colors.deepPurple),
                  ),
                  title: Text(
                    displayTitle,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    displaySubtitle,
                    style: GoogleFonts.poppins(
                        color: Colors.grey.shade600, fontSize: 12),
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
                      // Only show chevron if tappable
                      if (interventionId.isNotEmpty)
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
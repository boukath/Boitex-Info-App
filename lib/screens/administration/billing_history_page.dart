// lib/screens/administration/billing_history_page.dart
import 'package:boitex_info_app/models/sav_ticket.dart'; // ✅ ADDED SavTicket model import
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
// ✅ ADDED SAV Ticket Details Page import
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class BillingHistoryPage extends StatefulWidget {
  // Filters might need reconsideration if combining data sources extensively
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

  // Helper to launch URLs safely (Unchanged)
  Future<void> _launchURL(BuildContext context, String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun fichier joint.'), backgroundColor: Colors.orange),
      );
      return;
    }
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir le lien: $urlString'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ NEW: Function to fetch COMBINED history data
  Future<List<Map<String, dynamic>>> _fetchCombinedBillingHistory() async {
    // Query 1: Activity Log for Interventions
    final activityLogFuture = FirebaseFirestore.instance
        .collection('global_activity_log')
    // ✅ FIX: Use 'whereIn' to find the new "Facturation" category
    // AND the two old categories you were using before.
        .where('category', whereIn: [
      'Facturation',
      'Intervention Facturée',
      'Intervention Clôturée Sans Facture'
    ])
        .orderBy('timestamp', descending: true)
        .get();

    // Query 2: SAV Tickets with billing status
    final savTicketsFuture = FirebaseFirestore.instance
        .collection('sav_tickets')
    // ✅ FIX: Use 'whereIn' to find the status you are writing
    // ('Approuvé - Prêt pour retour') AND the one you are querying ('Retourné')
    // This makes the query robust for old and new data.
        .where('status', whereIn: ['Retourné', 'Approuvé - Prêt pour retour'])
        .where('billingStatus', isNotEqualTo: null) // Ensure billing decision was made
        .orderBy('createdAt', descending: true) // Sort SAV tickets by creation date
        .get();


    // Wait for both queries
    final results = await Future.wait([activityLogFuture, savTicketsFuture]);
    final activityLogDocs = results[0].docs;
    final savTicketDocs = results[1].docs;

    final combinedList = <Map<String, dynamic>>[];

    // Add intervention logs
    combinedList.addAll(activityLogDocs.map((doc) {
      final data = doc.data();
      // Use activity log timestamp for sorting intervention entries
      final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      return {
        'type': 'intervention_log', // Identify the source
        'data': data,
        'id': doc.id,
        'date': date,
      };
    }));

    // Add SAV tickets
    combinedList.addAll(savTicketDocs.map((doc) {
      final data = doc.data();
      // Use SAV ticket creation date for sorting SAV entries
      final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      return {
        'type': 'sav_ticket', // Identify the source
        'data': data,
        'id': doc.id,
        'date': date,
      };
    }));

    // Sort the combined list by date, most recent first
    combinedList.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return combinedList;
  }


  @override
  Widget build(BuildContext context) {
    // Note: The direct Firestore query is replaced by the FutureBuilder below

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 1,
        title: Container( // Search Bar (Unchanged)
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Rechercher (Client, Magasin, Code...)', // Updated hint
              hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                onPressed: () { _searchController.clear(); },
                splashRadius: 20,
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
      // ✅ CHANGED: Use FutureBuilder to handle combined data fetch
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchCombinedBillingHistory(), // Call the new fetch function
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('Error fetching combined history: ${snapshot.error}');
            return Center(child: Text("Erreur: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data == null || snapshot.data!.isEmpty) {
            return Center(
              child: Text("Aucune décision de facturation trouvée.", style: GoogleFonts.poppins()),
            );
          }

          final allItems = snapshot.data!;

          // Filter the combined list based on search query
          final filteredItems = allItems.where((item) {
            if (_searchQuery.isEmpty) return true;

            final data = item['data'] as Map<String, dynamic>;
            final type = item['type'] as String;
            final date = item['date'] as DateTime?;
            String formattedDate = date != null ? DateFormat('dd/MM/yyyy', 'fr_FR').format(date) : '';

            bool clientMatch = (data['clientName']?.toString().toLowerCase() ?? '').contains(_searchQuery);
            bool storeMatch = (data['storeName']?.toString().toLowerCase() ?? '').contains(_searchQuery);
            bool dateMatch = formattedDate.contains(_searchQuery);
            bool codeMatch = false;
            bool decisionMatch = false;

            if (type == 'intervention_log') {
              // interventionId might be useful if searching by code
              codeMatch = (data['interventionId']?.toString().toLowerCase() ?? '').contains(_searchQuery);
              // Search within the message for decision text
              decisionMatch = (data['message']?.toString().toLowerCase() ?? '').contains(_searchQuery);
            } else if (type == 'sav_ticket') {
              codeMatch = (data['savCode']?.toString().toLowerCase() ?? '').contains(_searchQuery);
              decisionMatch = (data['billingStatus']?.toString().toLowerCase() ?? '').contains(_searchQuery);
              // Also search product name for SAV
              bool productMatch = (data['productName']?.toString().toLowerCase() ?? '').contains(_searchQuery);
              return clientMatch || storeMatch || dateMatch || codeMatch || decisionMatch || productMatch;
            }

            return clientMatch || storeMatch || dateMatch || codeMatch || decisionMatch;

          }).toList();

          if (filteredItems.isEmpty) {
            return Center(
              child: Text("Aucun résultat pour '$_searchQuery'", style: GoogleFonts.poppins()),
            );
          }

          // Build the list using the filtered items
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              final data = item['data'] as Map<String, dynamic>;
              final type = item['type'] as String;
              final docId = item['id'] as String; // Original document ID

              // ✅ Call the appropriate tile builder based on type
              if (type == 'intervention_log') {
                return _buildInterventionLogTile(context, data, docId); // Use log tile builder
              } else if (type == 'sav_ticket') {
                // Safely create SavTicket object
                try {
                  final ticket = SavTicket.fromFirestore(_MockDocumentSnapshot(docId, data));
                  return _buildSavTicketHistoryTile(context, ticket); // Use SAV tile builder
                } catch (e) {
                  print("Error parsing SAV ticket $docId for display: $e");
                  // Return an error tile if parsing fails
                  return Card(
                    color: Colors.red.shade100,
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      title: Text("Erreur: Impossible de charger SAV $docId"),
                      subtitle: Text(e.toString()),
                    ),
                  );
                }
              } else {
                return const SizedBox.shrink(); // Should not happen
              }
            },
          );
        },
      ),
    );
  }

  // ✅ --- Builder for Intervention LOG Tile (Based on your original logic) ---
  Widget _buildInterventionLogTile(BuildContext context, Map<String, dynamic> data, String logDocId) {
    // Extract fields from 'global_activity_log' data
    final message = data['message'] as String? ?? '';
    final interventionId = data['interventionId'] as String? ?? ''; // ID of the related intervention
    final clientName = data['clientName'] as String? ?? 'Client inconnu';
    final storeName = data['storeName'] as String? ?? 'Magasin inconnu';
    final madeBy = data['userName'] as String? ?? 'Inconnu'; // User who made the decision
    final invoiceUrl = data['invoiceUrl'] as String?; // Invoice URL from the log

    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('dd MMM yyyy à HH:mm', 'fr_FR').format(timestamp.toDate())
        : 'Date inconnue';

    // Construct display strings
    String displayTitle = clientName; // Or intervention ID if useful: data['interventionCode'] ?? clientName;
    String displaySubtitle = '$storeName\n$madeBy - $date';
    if (message.isNotEmpty) {
      // Enhance subtitle with the decision message from the log
      displaySubtitle = '$storeName - $message\n$madeBy - $date';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: interventionId.isNotEmpty ? () async {
          // --- Navigation Logic for Interventions ---
          // Fetch the full intervention document before navigating
          try {
            final interventionSnapshot = await FirebaseFirestore.instance
                .collection('interventions')
                .doc(interventionId)
                .get();
            if (interventionSnapshot.exists && context.mounted) {
              Navigator.of(context).push(MaterialPageRoute(
                // Ensure InterventionDetailsPage expects a DocumentSnapshot
                builder: (context) => InterventionDetailsPage(interventionDoc: interventionSnapshot),
              ));
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Intervention associée introuvable.'), backgroundColor: Colors.orange),
              );
            }
          } catch (e) {
            print("Error fetching intervention $interventionId: $e");
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur chargement intervention: ${e.toString()}'), backgroundColor: Colors.red),
              );
            }
          }
        } : null, // Disable tap if no interventionId
        leading: CircleAvatar( // Intervention icon
          backgroundColor: Colors.deepPurple.withOpacity(0.1),
          child: const Icon(Icons.receipt_long, color: Colors.deepPurple),
        ),
        title: Text(
          displayTitle,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          displaySubtitle,
          style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (invoiceUrl != null && invoiceUrl.isNotEmpty) // Check URL validity
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                color: Colors.green.shade600,
                tooltip: 'Voir la facture',
                onPressed: () => _launchURL(context, invoiceUrl),
                splashRadius: 20,
              ),
            if (interventionId.isNotEmpty) // Show chevron only if navigation is possible
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
  // ✅ --- END of Intervention Log Tile Builder ---


  // ✅ --- Builder for SAV Ticket History Tile ---
  Widget _buildSavTicketHistoryTile(BuildContext context, SavTicket ticket) {
    final displayTitle = '${ticket.savCode} - ${ticket.clientName}';
    final displaySubtitle = 'Produit: ${ticket.productName}\nDécision: ${ticket.billingStatus ?? 'N/A'} (${DateFormat('dd/MM/yy').format(ticket.createdAt)})';
    final invoiceUrl = ticket.invoiceUrl;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          // Navigate to SAV Ticket Details Page
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => SavTicketDetailsPage(ticket: ticket),
          ));
        },
        leading: CircleAvatar( // SAV icon
          backgroundColor: Colors.orange.withOpacity(0.1),
          child: const Icon(Icons.support_agent, color: Colors.orange),
        ),
        title: Text(
          displayTitle,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          displaySubtitle,
          style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (invoiceUrl != null && invoiceUrl.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                color: Colors.green.shade600,
                tooltip: 'Voir la facture (SAV)',
                onPressed: () => _launchURL(context, invoiceUrl),
                splashRadius: 20,
              ),
            const Icon(Icons.chevron_right, color: Colors.grey), // Always show for SAV details
          ],
        ),
      ),
    );
  }
// ✅ --- END of SAV Tile Builder ---

}


// ✅ ADDED: Helper class to mock DocumentSnapshot for SavTicket.fromFirestore
// (Same as before, needed to adapt data from .get() to the factory method)
class _MockDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> _data;

  _MockDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic get(Object field) => _data[field];

  @override
  bool get exists => true; // Assume exists since we got it from a query result

  @override
  SnapshotMetadata get metadata => throw UnimplementedError("Metadata not implemented for mock snapshot");

  @override
  DocumentReference<Map<String, dynamic>> get reference => throw UnimplementedError("Reference not implemented for mock snapshot");

  @override
  operator [](Object field) => _data[field];
}
// lib/screens/administration/billing_filtered_list_page.dart

import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class BillingFilteredListPage extends StatefulWidget {
  final String type; // 'intervention' or 'sav'
  final String billingStatus; // 'Facturé' or 'Sans Facture'
  final String title;
  // ✅ ADDED: Optional serviceType parameter
  final String? serviceType;

  const BillingFilteredListPage({
    super.key,
    required this.type,
    required this.billingStatus,
    required this.title,
    this.serviceType, // Make it optional
  });

  @override
  State<BillingFilteredListPage> createState() =>
      _BillingFilteredListPageState();
}

class _BillingFilteredListPageState extends State<BillingFilteredListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Future<List<DocumentSnapshot>> _historyFuture;

  @override
  void initState() {
    super.initState();
    // Fetch data when the page loads
    _historyFuture = _fetchFilteredHistory();

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

  // --- Helper to launch URLs safely ---
  Future<void> _launchURL(BuildContext context, String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aucun fichier joint.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Impossible d\'ouvrir le lien: $urlString'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- UPDATED: Function to fetch filtered history data ---
  Future<List<DocumentSnapshot>> _fetchFilteredHistory() async {
    Query query;

    if (widget.type == 'intervention') {
      // ✅ Start building the intervention query
      query = FirebaseFirestore.instance
          .collection('interventions')
          .where('status', isEqualTo: 'Clôturé')
          .where('billingStatus', isEqualTo: widget.billingStatus);

      // ✅ ADDED: Conditionally add the serviceType filter
      if (widget.serviceType != null) {
        query = query.where('serviceType', isEqualTo: widget.serviceType);
      }

      // Add ordering at the end
      query = query.orderBy('closedAt', descending: true);

    } else {
      // This is the query for SAV tickets (remains unchanged)
      query = FirebaseFirestore.instance
          .collection('sav_tickets')
          .where('status', whereIn: ['Retourné', 'Approuvé - Prêt pour retour'])
          .where('billingStatus', isEqualTo: widget.billingStatus)
          .orderBy('createdAt', descending: true);
    }

    final querySnapshot = await query.get();
    return querySnapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 1,
        // Use the title passed from the previous page
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(fontSize: 16), // Adjust size if needed
          overflow: TextOverflow.ellipsis,
        ),
        // Search bar can be added back here if needed, or kept simple
        actions: [
          // Optional: Add search icon button here to reveal search bar?
        ],
      ),
      body: Column( // Wrap FutureBuilder in Column to add search bar
        children: [
          // --- Search Bar ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              height: 45, // Slightly taller for better touch target
              child: TextField(
                controller: _searchController,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Rechercher (Client, Magasin, Code...)',
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15), // Added horizontal padding
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0), // More rounded
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder( // Consistent border styling
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder( // Highlight on focus
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor),
                  ),
                ),
              ),
            ),
          ),
          // --- List Content ---
          Expanded( // Make the FutureBuilder take remaining space
            child: FutureBuilder<List<DocumentSnapshot>>(
              future: _historyFuture, // Call the fetch function
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('Error fetching filtered history: ${snapshot.error}');
                  return Center(child: Text("Erreur: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data == null || snapshot.data!.isEmpty) {
                  // Provide more context in the empty message
                  String emptyMessage = "Aucun dossier ${widget.billingStatus.toLowerCase()} trouvé";
                  if (widget.serviceType != null) {
                    emptyMessage += " pour ${widget.serviceType}";
                  }
                  emptyMessage += ".";
                  return Center(
                    child: Text(emptyMessage, style: GoogleFonts.poppins()),
                  );
                }

                final allItems = snapshot.data!;

                // --- Apply search filter ---
                final filteredItems = allItems.where((doc) {
                  if (_searchQuery.isEmpty) return true;

                  final data = doc.data() as Map<String, dynamic>;

                  bool clientMatch = (data['clientName']?.toString().toLowerCase() ?? '')
                      .contains(_searchQuery);
                  bool storeMatch = (data['storeName']?.toString().toLowerCase() ?? '')
                      .contains(_searchQuery);
                  // Added serviceType to search if applicable
                  bool serviceMatch = widget.type == 'intervention' && (data['serviceType']?.toString().toLowerCase() ?? '').contains(_searchQuery);

                  if (widget.type == 'intervention') {
                    bool codeMatch = (data['interventionCode']?.toString().toLowerCase() ?? '')
                        .contains(_searchQuery);
                    return clientMatch || storeMatch || codeMatch || serviceMatch;
                  } else { // SAV
                    bool codeMatch = (data['savCode']?.toString().toLowerCase() ?? '')
                        .contains(_searchQuery);
                    bool productMatch =
                    (data['productName']?.toString().toLowerCase() ?? '')
                        .contains(_searchQuery);
                    return clientMatch || storeMatch || codeMatch || productMatch;
                  }
                }).toList();

                if (filteredItems.isEmpty) {
                  return Center(
                    child: Text(
                      "Aucun résultat pour '$_searchQuery'",
                      style: GoogleFonts.poppins(),
                    ),
                  );
                }

                // --- Build the list ---
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 0, bottom: 8.0), // Removed top padding
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final doc = filteredItems[index];

                    // Call the correct tile builder based on the type
                    if (widget.type == 'intervention') {
                      return _buildInterventionTile(context, doc);
                    } else {
                      // We can safely cast here
                      final ticket = SavTicket.fromFirestore(
                          doc as DocumentSnapshot<Map<String, dynamic>>);
                      return _buildSavTicketTile(context, ticket);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  // --- Builder for Intervention Tile (from 'interventions' collection) ---
  Widget _buildInterventionTile(
      BuildContext context, DocumentSnapshot interventionDoc) {
    // Cast data safely
    final data = interventionDoc.data() as Map<String, dynamic>? ?? {};

    final clientName = data['clientName'] as String? ?? 'Client inconnu';
    final storeName = data['storeName'] as String? ?? 'Magasin inconnu';
    final invoiceUrl = data['invoiceUrl'] as String?;
    final code = data['interventionCode'] as String? ?? 'N/A';
    final serviceTypeDisplay = data['serviceType'] as String? ?? 'Service N/A'; // Get service type for display

    final timestamp = data['closedAt'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('dd/MM/yyyy', 'fr_FR').format(timestamp.toDate())
        : 'Date inconnue';

    String displayTitle = '$code - $clientName';
    // Include service type in subtitle
    String displaySubtitle = '$storeName ($serviceTypeDisplay)\nClôturé le: $date';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          // Navigate to Intervention Details
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) =>
                InterventionDetailsPage(
                    interventionDoc: interventionDoc
                    as DocumentSnapshot<Map<String, dynamic>>),
          ));
        },
        leading: CircleAvatar(
          // Dynamically set color based on serviceType
          backgroundColor: (serviceTypeDisplay == 'Service IT' ? Colors.green : Colors.deepPurple).withOpacity(0.1),
          child: Icon(
            serviceTypeDisplay == 'Service IT' ? Icons.computer_outlined : Icons.receipt_long, // Dynamic icon
            color: serviceTypeDisplay == 'Service IT' ? Colors.green : Colors.deepPurple,
          ),
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
                tooltip: 'Voir la facture',
                onPressed: () => _launchURL(context, invoiceUrl),
                splashRadius: 20,
              ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // --- Builder for SAV Ticket History Tile ---
  Widget _buildSavTicketTile(BuildContext context, SavTicket ticket) {
    final displayTitle = '${ticket.savCode} - ${ticket.clientName}';
    final displaySubtitle =
        'Produit: ${ticket.productName}\nRetourné le: ${DateFormat('dd/MM/yy', 'fr_FR').format(ticket.createdAt)}';
    final invoiceUrl = ticket.invoiceUrl;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          // Navigate to SAV Ticket Details Page
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => SavTicketDetailsPage(ticket: ticket),
          ));
        },
        leading: CircleAvatar(
          // SAV icon
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
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
// lib/screens/administration/portal_requests_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ✅ Import the Details Page (We will create this next)
import 'package:boitex_info_app/screens/administration/portal_request_details_page.dart';

class PortalRequestsListPage extends StatefulWidget {
  const PortalRequestsListPage({super.key});

  @override
  State<PortalRequestsListPage> createState() => _PortalRequestsListPageState();
}

class _PortalRequestsListPageState extends State<PortalRequestsListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Demandes Web",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF667EEA),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔍 QUERY: Only show items that haven't been approved yet (PENDING)
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('interventionCode', isEqualTo: 'PENDING')
            .orderBy('createdAt', descending: false) // Oldest first (FIFO)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Erreur: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "Aucune nouvelle demande",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return _buildRequestCard(context, doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, String docId, Map<String, dynamic> data) {
    // Parse Date
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final dateStr = ts != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate())
        : 'Date inconnue';

    // Parse Media
    final List media = data['mediaUrls'] ?? [];
    final bool hasMedia = media.isNotEmpty;

    // Detected Service (Visual hint)
    final String serviceType = data['serviceType'] ?? 'Inconnu';
    final bool isIT = serviceType.contains('IT');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to Decision/Details Page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PortalRequestDetailsPage(interventionId: docId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Store & Time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      data['storeName'] ?? 'Magasin Inconnu',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dateStr,
                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Sub-header: Client Name
              Row(
                children: [
                  const Icon(Icons.business, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    data['clientName'] ?? 'Client Inconnu',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Description Snippet
              Text(
                data['requestDescription'] ?? 'Aucune description',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),

              const SizedBox(height: 16),

              // Footer: Tags (Service Type + Media)
              Row(
                children: [
                  // Service Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isIT ? Colors.purple.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isIT ? Colors.purple.shade200 : Colors.orange.shade200,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isIT ? Icons.computer : Icons.build,
                          size: 12,
                          color: isIT ? Colors.purple : Colors.deepOrange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          serviceType,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isIT ? Colors.purple : Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Media Tag
                  if (hasMedia)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade200, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attachment, size: 12, color: Colors.green),
                          const SizedBox(width: 6),
                          Text(
                            "${media.length} Pièce(s)",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  // Action Text
                  Text(
                    "Traiter",
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Theme.of(context).primaryColor),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
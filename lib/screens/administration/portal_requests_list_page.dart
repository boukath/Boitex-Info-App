// lib/screens/administration/portal_requests_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ✅ Import the Details Page
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
      backgroundColor: const Color(0xFFF4F7FE), // Ultra-light grey-blue background
      appBar: AppBar(
        title: Text(
          "Demandes Web",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ]
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔍 QUERY: Only show items that haven't been approved yet (PENDING)
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('interventionCode', isEqualTo: 'PENDING')
            .orderBy('createdAt', descending: false) // FIFO (First In First Out)
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
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
                        ]
                    ),
                    child: Icon(Icons.inbox_rounded, size: 60, color: Colors.blue.shade200),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Tout est calme",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Aucune nouvelle demande en attente.",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return _buildPremiumRequestCard(context, doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildPremiumRequestCard(BuildContext context, String docId, Map<String, dynamic> data) {
    // 1. DATA PARSING
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final dateStr = ts != null
        ? DateFormat('dd MMM, HH:mm').format(ts.toDate())
        : 'Date inconnue';

    final List media = data['mediaUrls'] ?? [];
    final bool hasMedia = media.isNotEmpty;

    final String serviceType = data['serviceType'] ?? 'Technique';
    final bool isIT = serviceType.contains('IT');

    // 2. STATUS LOGIC (THE GATEKEEPER)
    // 🛠 FIX: Use the correct field 'interventionType'
    final String type = data['interventionType'] ?? 'Facturable';

    // 🛠 FIX: Check for both new short value ('Corrective') and legacy long value
    final bool isCorrective = (type == 'Corrective' || type == 'Maintenance Corrective');

    // Theme Colors based on Status
    final Color statusColor = isCorrective ? const Color(0xFF00C853) : const Color(0xFFFF9100); // Green vs Orange
    final Color statusBg = isCorrective ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
    final IconData statusIcon = isCorrective ? Icons.verified_user_rounded : Icons.euro_symbol_rounded;
    final String statusLabel = isCorrective ? "SOUS CONTRAT" : "FACTURABLE";

    // ✅ 3. STORE NAME & LOCATION LOGIC
    String storeName = data['storeName'] ?? 'Magasin Inconnu';
    dynamic rawLocation = data['storeLocation'];
    String locationSuffix = '';

    // Only show if it's a String (Text address) and not empty
    if (rawLocation is String && rawLocation.isNotEmpty) {
      locationSuffix = " - $rawLocation";
    }

    String finalStoreDisplay = "$storeName$locationSuffix";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PortalRequestDetailsPage(interventionId: docId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- TOP ROW: STATUS & TIME ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ✨ THE STATUS BADGE
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // TIME
                    Text(
                      dateStr,
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // --- STORE & CLIENT INFO ---
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Color(0xFF667EEA)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            finalStoreDisplay, // ✅ UPDATED DISPLAY
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            data['clientName'] ?? 'Client Inconnu',
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // --- DESCRIPTION BUBBLE ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Text(
                    data['requestDescription'] ?? 'Aucune description fournie.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54, height: 1.5),
                  ),
                ),

                const SizedBox(height: 20),
                Divider(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 16),

                // --- FOOTER: TAGS & ACTION ---
                Row(
                  children: [
                    // SERVICE TYPE TAG
                    _buildMiniTag(
                      icon: isIT ? Icons.computer : Icons.build_circle_outlined,
                      label: serviceType,
                      color: isIT ? Colors.purple : Colors.blueGrey,
                    ),

                    const SizedBox(width: 8),

                    // MEDIA TAG
                    if (hasMedia)
                      _buildMiniTag(
                        icon: Icons.attach_file,
                        label: "${media.length}",
                        color: Colors.blue,
                        bgColor: Colors.blue.shade50,
                      ),

                    const Spacer(),

                    // TRAITER BUTTON
                    Row(
                      children: [
                        Text(
                          "Ouvrir",
                          style: GoogleFonts.poppins(
                              color: const Color(0xFF667EEA),
                              fontWeight: FontWeight.w600,
                              fontSize: 13
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF667EEA)),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniTag({required IconData icon, required String label, required Color color, Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
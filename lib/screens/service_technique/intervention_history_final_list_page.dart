// lib/screens/service_technique/intervention_history_final_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';

class InterventionHistoryFinalListPage extends StatelessWidget {
  final String serviceType;
  final String clientName;
  final String storeName;
  // ✅ 1. ADDED: The selected year variable
  final int selectedYear;

  const InterventionHistoryFinalListPage({
    super.key,
    required this.serviceType,
    required this.clientName,
    required this.storeName,
    // ✅ 2. ADDED: Require it in the constructor
    required this.selectedYear,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ 3. LOGIC: Calculate the date range for the query
    final startOfYear = DateTime(selectedYear, 1, 1);
    final endOfYear = DateTime(selectedYear, 12, 31, 23, 59, 59);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        // ✅ 4. UI: Show Store Name AND Year in the title
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(storeName,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            Text(
              "Année $selectedYear",
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('serviceType', isEqualTo: serviceType)
            .where('clientName', isEqualTo: clientName)
            .where('storeName', isEqualTo: storeName)
            .where('status', whereIn: ['Terminé', 'Clôturé'])
        // ✅ 5. QUERY: Filter by Date Range (The "Time Machine" logic)
            .where('createdAt', isGreaterThanOrEqualTo: startOfYear)
            .where('createdAt', isLessThanOrEqualTo: endOfYear)
        // ✅ 6. SORT: Must order by 'createdAt' first when filtering by range
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // Helpful for debugging
            debugPrint("Firestore Error: ${snapshot.error}");
            return const Center(
                child: Text('Erreur de chargement (Vérifiez les index Firestore)'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune intervention trouvée\npour $selectedYear.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final interventionDoc = docs[index];
              final data = interventionDoc.data();

              // --- Determine Status UI ---
              IconData iconData;
              Color iconColor;
              String titleText;
              String subtitleText;

              if (data['status'] == 'Clôturé') {
                final DateTime? closedDate =
                (data['closedAt'] as Timestamp?)?.toDate();
                final String billingStatus =
                    (data['billingStatus'] as String?) ?? 'N/A';

                iconData = Icons.check_circle;
                iconColor = Colors.green;
                titleText =
                'Clôturée le: ${closedDate != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(closedDate) : 'N/A'}';
                subtitleText = 'Statut: $billingStatus';
              } else {
                // Terminé
                final DateTime? completedDate =
                (data['completedAt'] as Timestamp?)?.toDate();

                iconData = Icons.pending_actions;
                iconColor = Colors.orange;
                titleText =
                'Terminée le: ${completedDate != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(completedDate) : 'N/A'}';
                subtitleText = 'En attente de facturation';
              }

              // Additional Info (Code, Specific Location if available)
              final String code = data['code'] ?? 'Sans code';
              final String specificLoc = data['storeLocation'] ?? '';

              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: iconColor.withOpacity(0.1),
                    child: Icon(iconData, color: iconColor, size: 22),
                  ),
                  title: Text(
                    titleText,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subtitleText,
                          style: GoogleFonts.poppins(fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        'Code: $code ${specificLoc.isNotEmpty ? "• $specificLoc" : ""}',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => InterventionDetailsPage(
                          // Casting to correct type
                          interventionDoc: interventionDoc
                          as DocumentSnapshot<Map<String, dynamic>>,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
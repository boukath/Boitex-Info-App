// lib/screens/service_technique/intervention_history_stores_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_history_final_list_page.dart';

class InterventionHistoryStoresPage extends StatelessWidget {
  final String serviceType;
  final String clientName;
  // ✅ 1. ADDED: selectedYear parameter
  final int selectedYear;

  const InterventionHistoryStoresPage({
    super.key,
    required this.serviceType,
    required this.clientName,
    // ✅ 2. ADDED: Require it in constructor
    required this.selectedYear,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ 3. LOGIC: Define the date range for the selected year
    final startOfYear = DateTime(selectedYear, 1, 1);
    final endOfYear = DateTime(selectedYear, 12, 31, 23, 59, 59);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        // ✅ 4. UI: Show Client Name AND Year
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(clientName,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            Text(
              "Magasins actifs en $selectedYear",
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('serviceType', isEqualTo: serviceType)
            .where('status', whereIn: ['Terminé', 'Clôturé'])
            .where('clientName', isEqualTo: clientName)
        // ✅ 5. QUERY: Filter by the Date Range
            .where('createdAt', isGreaterThanOrEqualTo: startOfYear)
            .where('createdAt', isLessThanOrEqualTo: endOfYear)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint("Firestore Error: ${snapshot.error}");
            return const Center(child: Text("Erreur de chargement."));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Aucun magasin trouvé avec des\ninterventions en $selectedYear.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            );
          }

          // Group by Store Name (Client-side grouping)
          final storeNames = snapshot.data!.docs
              .map((doc) => (doc.data() as Map<String, dynamic>)['storeName'] as String? ?? 'Magasin non spécifié')
              .toSet()
              .toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: storeNames.length,
            itemBuilder: (context, index) {
              final storeName = storeNames[index];
              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.store, color: Colors.blue),
                  ),
                  title: Text(
                    storeName,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    // ✅ 6. NAV: Pass selectedYear to the Final List
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InterventionHistoryFinalListPage(
                          serviceType: serviceType,
                          clientName: clientName,
                          storeName: storeName,
                          selectedYear: selectedYear, // 👈 PASS IT HERE
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
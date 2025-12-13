import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_history_final_list_page.dart';

class InterventionHistoryStoresPage extends StatelessWidget {
  final String serviceType;
  final String clientName;

  const InterventionHistoryStoresPage({
    super.key,
    required this.serviceType,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(clientName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucun magasin trouvé avec des interventions terminées.'));
          }

          // Group by Store Name
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
                    // ✅ FIXED FLOW: Navigate DIRECTLY to the Final List (Bypassing Location Page)
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InterventionHistoryFinalListPage(
                          serviceType: serviceType,
                          clientName: clientName,
                          storeName: storeName,
                          // locationName is removed from here!
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
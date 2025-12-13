// lib/screens/service_technique/intervention_history_clients_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_history_stores_page.dart';
import 'package:boitex_info_app/screens/service_technique/universal_intervention_search_page.dart';

class InterventionHistoryClientsPage extends StatelessWidget {
  final String serviceType;

  const InterventionHistoryClientsPage({super.key, required this.serviceType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ CHANGED: Set to a clean, professional off-white color.
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Historique des Interventions',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 4.0,
        shadowColor: Colors.black.withOpacity(0.1),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UniversalInterventionSearchPage(
                    serviceType: serviceType,
                  ),
                ),
              );
            },
            tooltip: 'Recherche Globale',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('serviceType', isEqualTo: serviceType)
            .where('status', whereIn: ['Terminé', 'Clôturé'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Aucune intervention clôturée trouvée.',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            );
          }

          final clientNames = snapshot.data!.docs
              .map((doc) =>
          (doc.data() as Map<String, dynamic>)['clientName']
          as String? ??
              'Client non spécifié')
              .toSet()
              .toList();

          clientNames.sort();

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: clientNames.length,
            itemBuilder: (context, index) {
              final clientName = clientNames[index];
              // ✅ ADDED: New light-theme card widget
              return _buildElegantCard(
                context: context,
                clientName: clientName,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InterventionHistoryStoresPage(
                        serviceType: serviceType,
                        clientName: clientName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ✅ ADDED: A new method for the elegant light-theme card design
  Widget _buildElegantCard({
    required BuildContext context,
    required String clientName,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 12),
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1e3a8a).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.business_center,
                  color: Color(0xFF1e3a8a),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  clientName,
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
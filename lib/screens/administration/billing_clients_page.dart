// lib/screens/administration/billing_clients_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'billing_stores_page.dart';

class BillingClientsPage extends StatelessWidget {
  const BillingClientsPage({super.key});

  // Helper to build the header
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          // Back button
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF1E1E2A),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Title
          Text(
            'Historique Facturation',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E1E2A),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get avatar color
  Color _getAvatarColor(String text) {
    return Colors.primaries[text.hashCode % Colors.primaries.length].shade300;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC), // Light background
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Text(
                'Sélectionner un Client',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('global_activity_log')
                // --- MODIFIED: Use whereIn for type ---
                    .where('type', whereIn: ['Facturation', 'Intervention Facturée'])
                // --- END MODIFIED ---
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Aucun historique de facturation trouvé.'));
                  }

                  // Process Data to Find Unique Client Names
                  final logs = snapshot.data!.docs;
                  final Set<String> uniqueClientNames = {};
                  for (var doc in logs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final clientName = data['clientName'] as String?;
                    if (clientName != null && clientName.isNotEmpty) {
                      uniqueClientNames.add(clientName);
                    }
                  }
                  final sortedClientNames = uniqueClientNames.toList()..sort();

                  if (sortedClientNames.isEmpty) {
                    return const Center(child: Text('Aucun client trouvé dans l\'historique.'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemCount: sortedClientNames.length,
                    itemBuilder: (context, index) {
                      final clientName = sortedClientNames[index];
                      return Card(
                        elevation: 2.0,
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getAvatarColor(clientName),
                            child: Text(
                              clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                          title: Text(
                            clientName,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BillingStoresPage(clientName: clientName),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
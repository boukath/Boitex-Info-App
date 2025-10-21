// lib/screens/administration/billing_stores_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'billing_locations_page.dart';

class BillingStoresPage extends StatelessWidget {
  final String clientName;

  const BillingStoresPage({super.key, required this.clientName});

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
          // Title - Show client name here
          Expanded( // Use Expanded to prevent overflow
            child: Text(
              clientName, // Display the selected client's name
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E1E2A),
              ),
              overflow: TextOverflow.ellipsis, // Handle long names
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get avatar color
  Color _getAvatarColor(String text) {
    return Colors.accents[text.hashCode % Colors.accents.length].shade200;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Text(
                'Sélectionner un Magasin',
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
                    .where('clientName', isEqualTo: clientName) // Filter by the selected client
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
                    return Center(child: Text('Aucun historique trouvé pour $clientName.'));
                  }

                  // Process Data to Find Unique Store Names
                  final logs = snapshot.data!.docs;
                  final Set<String> uniqueStoreNames = {};
                  for (var doc in logs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final storeName = data['storeName'] as String?;
                    if (storeName != null && storeName.isNotEmpty) {
                      uniqueStoreNames.add(storeName);
                    }
                  }
                  final sortedStoreNames = uniqueStoreNames.toList()..sort();

                  if (sortedStoreNames.isEmpty) {
                    return Center(child: Text('Aucun magasin trouvé pour $clientName dans l\'historique.'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemCount: sortedStoreNames.length,
                    itemBuilder: (context, index) {
                      final storeName = sortedStoreNames[index];
                      return Card(
                        elevation: 2.0,
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getAvatarColor(storeName),
                            child: Icon(Icons.storefront, color: Colors.grey.shade700, size: 20), // Store icon
                          ),
                          title: Text(
                            storeName,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BillingLocationsPage(
                                  clientName: clientName,
                                  storeName: storeName, // Pass store name
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
            ),
          ],
        ),
      ),
    );
  }
}
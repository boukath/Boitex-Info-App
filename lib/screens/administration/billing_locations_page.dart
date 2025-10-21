// lib/screens/administration/billing_locations_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'billing_history_page.dart'; // Import the original page for the final view

class BillingLocationsPage extends StatelessWidget {
  final String clientName;
  final String storeName;

  const BillingLocationsPage({
    super.key,
    required this.clientName,
    required this.storeName,
  });

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
          // Title - Show client and store name
          Expanded( // Use Expanded to prevent overflow
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  style: GoogleFonts.poppins(
                    fontSize: 14, // Smaller font for the client name
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  storeName, // Display the selected store's name
                  style: GoogleFonts.poppins(
                    fontSize: 20, // Keep store name larger
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E1E2A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get avatar color
  Color _getAvatarColor(String text) {
    return Colors.primaries[text.length % Colors.primaries.length].shade100;
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
                'Sélectionner un Emplacement',
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
                    .where('clientName', isEqualTo: clientName)
                    .where('storeName', isEqualTo: storeName) // Filter by client AND store
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
                    return Center(child: Text('Aucun historique trouvé pour $storeName ($clientName).'));
                  }

                  // Process Data to Find Unique Store Locations
                  final logs = snapshot.data!.docs;
                  final Set<String> uniqueLocations = {};
                  for (var doc in logs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final location = data['storeLocation'] as String?;
                    if (location != null && location.isNotEmpty) {
                      uniqueLocations.add(location);
                    } else {
                      uniqueLocations.add("Emplacement non spécifié"); // Handle logs missing location
                    }
                  }
                  final sortedLocations = uniqueLocations.toList()..sort();

                  if (sortedLocations.isEmpty) {
                    return Center(child: Text('Aucun emplacement trouvé pour $storeName ($clientName).'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemCount: sortedLocations.length,
                    itemBuilder: (context, index) {
                      final location = sortedLocations[index];
                      return Card(
                        elevation: 2.0,
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getAvatarColor(location),
                            child: Icon(Icons.location_pin, color: Colors.red.shade400, size: 20), // Location icon
                          ),
                          title: Text(
                            location,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BillingHistoryPage(
                                  clientNameFilter: clientName,
                                  storeNameFilter: storeName,
                                  storeLocationFilter: location == "Emplacement non spécifié" ? null : location,
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
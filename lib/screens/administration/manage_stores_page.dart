// lib/screens/administration/manage_stores_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/add_store_page.dart';
import 'package:boitex_info_app/screens/administration/store_details_page.dart';
import 'package:boitex_info_app/screens/administration/store_equipment_page.dart';

class ManageStoresPage extends StatelessWidget {
  final String clientId;
  final String clientName;

  const ManageStoresPage(
      {super.key, required this.clientId, required this.clientName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(clientName), // Displays the client's name
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .collection('stores')
            .orderBy('name') // Order stores alphabetically by name
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucun magasin trouvé pour ce client.'));
          }

          final storeDocs = snapshot.data!.docs;

          return ListView.builder(
            // Added padding for FAB
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            itemCount: storeDocs.length,
            itemBuilder: (context, index) {
              final store = storeDocs[index];
              // Safely cast data, default to empty map if null
              final storeData = store.data() as Map<String, dynamic>? ?? {};
              final storeName = storeData['name'] ?? 'Nom Inconnu';
              final storeLocation = storeData['location'] ?? 'Emplacement Inconnu';
              final storeId = store.id; // Get the document ID

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    // Use a store icon or first letter
                    child: Text(storeName.isNotEmpty ? storeName[0].toUpperCase() : 'M'),
                    backgroundColor: Colors.teal.shade100,
                  ),
                  title: Text(storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(storeLocation),
                  // ✅ MODIFIED: Trailing now includes Edit, Equipment, and Arrow icons
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- Edit Store Button ---
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: Colors.blue.shade700),
                        tooltip: 'Modifier Magasin',
                        onPressed: () {
                          // Navigate to AddStorePage in Edit Mode
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddStorePage(
                                clientId: clientId,
                                storeId: storeId,       // Pass Store ID
                                initialData: storeData, // Pass current data
                              ),
                            ),
                          );
                        },
                      ),
                      // --- Equipment Button ---
                      IconButton(
                        icon: Icon(Icons.inventory_2_outlined, color: Colors.blueGrey.shade700),
                        tooltip: 'Voir Matériel Installé',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoreEquipmentPage(
                                clientId: clientId,
                                storeId: storeId, // Use storeId here
                                storeName: storeName,
                              ),
                            ),
                          );
                        },
                      ),
                      // --- Arrow Icon (no action, just visual) ---
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                  onTap: () {
                    // Navigate to Store Details Page when tapping the tile itself
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StoreDetailsPage(
                          clientId: clientId,
                          storeId: storeId, // Use storeId here
                          storeName: storeName,
                          storeLocation: storeLocation,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to AddStorePage in Add Mode
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => AddStorePage(clientId: clientId)));
        },
        tooltip: 'Ajouter un Magasin',
        child: const Icon(Icons.add_business_outlined), // Changed icon
        backgroundColor: Colors.teal, // Match theme
      ),
    );
  }
}
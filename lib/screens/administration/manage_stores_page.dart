// lib/screens/administration/manage_stores_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/add_store_page.dart';
// ✅ THIS IMPORT WAS MISSING:
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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_mall_directory_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aucun magasin trouvé.',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var storeDoc = snapshot.data!.docs[index];
              var storeData = storeDoc.data() as Map<String, dynamic>;
              String storeName = storeData['name'] ?? 'Nom Inconnu';
              String storeLocation = storeData['location'] ?? 'Localisation Inconnue';
              String storeId = storeDoc.id; // Get the document ID

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  splashColor: Colors.teal.withOpacity(0.1),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        // --- Icon Container ---
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.store,
                              color: Colors.teal, size: 24),
                        ),
                        const SizedBox(width: 16),
                        // --- Text Content ---
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                storeName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      storeLocation,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // --- Arrow Icon (no action, just visual) ---
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                  // ✅ Navigate DIRECTLY to Store Equipment Page
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StoreEquipmentPage(
                          clientId: clientId,
                          storeId: storeId,
                          storeName: storeName,
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
        backgroundColor: Colors.teal, // Match theme
        child: const Icon(Icons.add_business_outlined),
      ),
    );
  }
}
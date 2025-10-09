import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/add_store_page.dart';
import 'package:boitex_info_app/screens/administration/store_details_page.dart';

class ManageStoresPage extends StatelessWidget {
  final String clientId;
  final String clientName;

  const ManageStoresPage({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(clientName),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // **MODIFIED**: Added .orderBy('name') to sort the list alphabetically
        stream: FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .collection('stores')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucun magasin trouvé pour ce client.'));
          }

          final storeDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
            itemCount: storeDocs.length,
            itemBuilder: (context, index) {
              final storeDoc = storeDocs[index];
              final storeData = storeDoc.data() as Map<String, dynamic>;
              final storeName = storeData['name'] ?? 'Nom inconnu';
              final storeLocation = storeData['location'] ?? 'Emplacement inconnu';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    // Use the same color logic as the client list for consistency
                    backgroundColor: Colors.blueGrey.shade300,
                    child: const Icon(Icons.storefront_outlined, color: Colors.white),
                  ),
                  title: Text(storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(storeLocation),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => StoreDetailsPage(
                          clientId: clientId,
                          storeId: storeDoc.id,
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
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => AddStorePage(clientId: clientId)),
          );
        },
        tooltip: 'Ajouter un magasin',
        child: const Icon(Icons.add),
      ),
    );
  }
}
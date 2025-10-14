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
        title: Text(clientName),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .collection('stores')
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
            itemCount: storeDocs.length,
            itemBuilder: (context, index) {
              final store = storeDocs[index];
              final storeData = store.data() as Map<String, dynamic>;
              final storeName = storeData['name'] ?? 'Nom du magasin inconnu';
              final storeLocation = storeData['location'] ?? 'Localisation non spécifiée';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.store_mall_directory_outlined),
                  title: Text(storeName),
                  subtitle: Text(storeLocation),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.inventory_2_outlined),
                        tooltip: 'Voir le Matériel Installé',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoreEquipmentPage(
                                clientId: clientId,
                                storeId: store.id,
                                storeName: storeName,
                              ),
                            ),
                          );
                        },
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                  onTap: () {
                    // ✅ THIS IS THE FIX: We now pass the required parameters.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StoreDetailsPage(
                          clientId: clientId,
                          storeId: store.id,
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
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => AddStorePage(clientId: clientId)));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
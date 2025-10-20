// lib/screens/administration/store_equipment_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// ✅ 1. Import the new page we will create
import 'package:boitex_info_app/screens/administration/add_store_equipment_page.dart';

class StoreEquipmentPage extends StatelessWidget {
  final String clientId;
  final String storeId;
  final String storeName;

  const StoreEquipmentPage({
    super.key,
    required this.clientId,
    required this.storeId,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Matériel - $storeName'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .collection('stores')
            .doc(storeId)
            .collection('materiel_installe')
            .orderBy('installationDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Aucun matériel installé enregistré pour ce magasin.',
                textAlign: TextAlign.center,
              ),
            );
          }

          final equipmentDocs = snapshot.data!.docs;

          return ListView.builder(
            // ✅ 2. Added padding for FAB
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            itemCount: equipmentDocs.length,
            itemBuilder: (context, index) {
              final doc = equipmentDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final equipmentId = doc.id; // Get the document ID for editing

              final timestamp = data['installationDate'] as Timestamp?;
              final formattedDate = timestamp != null
                  ? DateFormat('dd/MM/yyyy').format(timestamp.toDate())
                  : 'Date inconnue';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  leading: const Icon(Icons.build_circle_outlined, color: Colors.blueGrey),
                  title: Text(
                    data['productName'] ?? 'Produit inconnu',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Référence: ${data['partNumber'] ?? 'N/A'}'),
                      Text('N° de Série: ${data['serialNumber'] ?? 'N/A'}'),
                      Text('Installé le: $formattedDate'),
                    ],
                  ),
                  // ✅ 3. Added Edit Button
                  trailing: IconButton(
                    icon: Icon(Icons.edit_outlined, color: Colors.orange.shade700),
                    tooltip: 'Modifier',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AddStoreEquipmentPage(
                            clientId: clientId,
                            storeId: storeId,
                            // Pass existing data for editing
                            equipmentId: equipmentId,
                            initialData: data,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      // ✅ 4. Added Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddStoreEquipmentPage(
                clientId: clientId,
                storeId: storeId,
                // No equipmentId or initialData means "Add Mode"
              ),
            ),
          );
        },
        tooltip: 'Ajouter du Matériel',
        child: const Icon(Icons.add),
      ),
    );
  }
}
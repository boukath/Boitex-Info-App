// lib/screens/administration/store_equipment_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
        // ✅ CORRECTED PATH: Queries the sub-collection inside the specific store.
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
              child: Text('Aucun matériel installé trouvé pour ce magasin.'),
            );
          }

          final equipmentDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: equipmentDocs.length,
            itemBuilder: (context, index) {
              final doc = equipmentDocs[index];
              final data = doc.data() as Map<String, dynamic>;

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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
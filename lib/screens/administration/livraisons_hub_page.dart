// lib/screens/administration/livraisons_hub_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/add_livraison_page.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';

class LivraisonsHubPage extends StatelessWidget {
  final String? serviceType;
  const LivraisonsHubPage({super.key, this.serviceType});

  Widget _getStatusChip(String status) {
    Color color;
    switch (status) {
      case 'À Préparer': color = Colors.orange; break;
      case 'En Cours de Livraison': color = Colors.blue; break;
      case 'Livré': color = Colors.green; break;
      default: color = Colors.grey;
    }

    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CHANGED: The base query is now outside the StreamBuilder
    Query query = FirebaseFirestore.instance.collection('livraisons');

    if (serviceType != null) {
      query = query.where('serviceType', isEqualTo: serviceType);
    }

    // ✅ CHANGED: The final stream now has the status filter
    final Stream<QuerySnapshot> livraisonsStream = query
        .where('status', whereIn: ['À Préparer', 'En Cours de Livraison'])
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(serviceType == null
            ? 'Livraisons Actives' // ✅ CHANGED: Title updated for clarity
            : 'Livraisons Actives - $serviceType'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ CHANGED: Use the new stream variable
        stream: livraisonsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune livraison active',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final livraisons = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: livraisons.length,
            itemBuilder: (context, index) {
              final doc = livraisons[index];
              final data = doc.data() as Map<String, dynamic>;
              final bonNumber = data['blCode'] ?? 'N/A';
              final clientName = data['clientName'] ?? 'Client inconnu';
              final status = data['status'] ?? 'À Préparer';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final formattedDate = createdAt != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt)
                  : 'Date inconnue';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(Icons.local_shipping, color: Colors.blue.shade700),
                  ),
                  title: Text(
                    'Bon $bonNumber',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Client: $clientName'),
                      Text('Date: $formattedDate', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      _getStatusChip(status),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LivraisonDetailsPage(livraisonId: doc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddLivraisonPage(serviceType: serviceType),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle Livraison'),
      ),
    );
  }
}
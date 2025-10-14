// lib/screens/administration/livraison_history_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';

class LivraisonHistoryPage extends StatefulWidget {
  final String serviceType;
  const LivraisonHistoryPage({super.key, required this.serviceType});

  @override
  State<LivraisonHistoryPage> createState() => _LivraisonHistoryPageState();
}

class _LivraisonHistoryPageState extends State<LivraisonHistoryPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique Livraisons - ${widget.serviceType}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                // ✅ UPDATED: Label reflects new search capabilities
                labelText: 'Rechercher (BL, Client, Produit, Marque...)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12.0)),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('livraisons')
                  .where('serviceType', isEqualTo: widget.serviceType)
                  .where('status', isEqualTo: 'Livré')
                  .orderBy('createdAt', descending: true)
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
                    child: Text('Aucune livraison effectuée trouvée.'),
                  );
                }

                // ✅ UPDATED: Filtering logic now includes products and brands
                final allDocs = snapshot.data!.docs;
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final query = _searchQuery.toLowerCase();

                  final bonNumber =
                  (data['bonLivraisonCode'] as String? ?? '').toLowerCase();
                  if (bonNumber.contains(query)) {
                    return true;
                  }

                  final clientName =
                  (data['clientName'] as String? ?? '').toLowerCase();
                  if (clientName.contains(query)) {
                    return true;
                  }

                  // Check inside the products list
                  if (data.containsKey('products') && data['products'] is List) {
                    final products = data['products'] as List;
                    for (final product in products) {
                      if (product is Map<String, dynamic>) {
                        final productName = (product['productName'] as String? ?? '').toLowerCase();
                        if (productName.contains(query)) {
                          return true;
                        }

                        final marque = (product['marque'] as String? ?? '').toLowerCase();
                        if (marque.contains(query)) {
                          return true;
                        }
                      }
                    }
                  }

                  return false;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('Aucun résultat trouvé.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final bonNumber = data['blCode'] ?? 'N/A';
                    final clientName = data['clientName'] ?? 'Client inconnu';
                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                    final formattedDate = createdAt != null
                        ? DateFormat('dd/MM/yyyy').format(createdAt)
                        : 'Date inconnue';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade100,
                          child: Icon(Icons.check_circle,
                              color: Colors.grey.shade700),
                        ),
                        title: Text(
                          'Bon $bonNumber',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Client: $clientName'),
                        trailing: Text(formattedDate,
                            style: const TextStyle(fontSize: 12)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  LivraisonDetailsPage(livraisonId: doc.id),
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
    );
  }
}
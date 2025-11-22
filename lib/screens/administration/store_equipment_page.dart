// lib/screens/administration/store_equipment_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:boitex_info_app/screens/administration/add_store_equipment_page.dart';
// ✅ NEW: Import the details page
import 'package:boitex_info_app/screens/administration/store_equipment_details_page.dart';

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

  // ✅ SMART FIX: Helper to get the real name if the saved name is generic
  Future<String> _resolveProductName(Map<String, dynamic> data) async {
    String currentName = data['nom'] ?? data['name'] ?? 'Produit Inconnu';
    String? productId = data['productId'] ?? data['id'];

    // List of generic names to detect (Case insensitive check can be added if needed)
    const List<String> genericNames = [
      'Produit Inconnu',
      'Equipment Inconnu',
      'N/A',
      'Matériel'
    ];

    // If name is generic AND we have a product ID, fetch the real name
    if (genericNames.contains(currentName) && productId != null && productId.isNotEmpty) {
      try {
        final productDoc = await FirebaseFirestore.instance
            .collection('produits')
            .doc(productId)
            .get(); //

        if (productDoc.exists) {
          return productDoc.data()?['nom'] ?? currentName;
        }
      } catch (e) {
        print('Error resolving name: $e');
      }
    }
    return currentName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Parc Installé', style: TextStyle(fontSize: 16)),
            Text(storeName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: const Color(0xFF667EEA),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .collection('stores')
            .doc(storeId)
            .collection('materiel_installe')
            .orderBy('installDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Aucun équipement installé', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;

              // Extract basic data for display
              final String serial = data['serialNumber'] ?? data['serial'] ?? 'S/N Inconnu';
              final Timestamp? lastSeen = data['lastInterventionDate'] as Timestamp?;
              final Timestamp? installDate = data['installDate'] as Timestamp?;
              final String? imageUrl = data['image'];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoreEquipmentDetailsPage(
                        clientId: clientId,
                        storeId: storeId,
                        equipmentId: id,
                      ),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            image: imageUrl != null
                                ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                                : null,
                          ),
                          child: imageUrl == null
                              ? const Icon(Icons.devices_other, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 16),

                        // Content with FutureBuilder for Name Resolution
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ✅ UPDATED: Use FutureBuilder to get the REAL name
                              FutureBuilder<String>(
                                  future: _resolveProductName(data), //
                                  initialData: data['nom'] ?? 'Chargement...',
                                  builder: (context, nameSnapshot) {
                                    return Text(
                                      nameSnapshot.data ?? 'Équipement',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1E293B),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4)
                                ),
                                child: Text(
                                  "S/N: $serial",
                                  style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.w600
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (lastSeen != null)
                                    _buildInfoTag(
                                        Icons.history,
                                        "Vu ${timeago.format(lastSeen.toDate(), locale: 'fr_short')}",
                                        Colors.grey.shade600
                                    ),
                                  const SizedBox(width: 12),
                                  if (installDate != null)
                                    _buildInfoTag(
                                        Icons.calendar_today,
                                        DateFormat('yyyy').format(installDate.toDate()),
                                        Colors.grey.shade600
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                            padding: EdgeInsets.only(top: 24, left: 8),
                            child: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF667EEA),
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddStoreEquipmentPage(
                clientId: clientId,
                storeId: storeId,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTag(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
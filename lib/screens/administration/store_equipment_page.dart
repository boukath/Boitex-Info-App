// lib/screens/administration/store_equipment_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_slidable/flutter_slidable.dart'; // ✅ IMPORTANT: Import Slidable
import 'package:boitex_info_app/screens/administration/add_store_equipment_page.dart';
import 'package:boitex_info_app/screens/administration/store_equipment_details_page.dart';
import 'package:boitex_info_app/screens/administration/add_store_page.dart';

// ✅ NEW: Import Service Contracts for logic
import 'package:boitex_info_app/models/service_contracts.dart';

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

  // Helper to get the real name if the saved name is generic
  Future<String> _resolveProductName(Map<String, dynamic> data) async {
    String currentName = data['nom'] ?? data['name'] ?? 'Produit Inconnu';
    String? productId = data['productId'] ?? data['id'];

    const List<String> genericNames = [
      'Produit Inconnu',
      'Equipment Inconnu',
      'N/A',
      'Matériel'
    ];

    if (genericNames.contains(currentName) && productId != null && productId.isNotEmpty) {
      try {
        final productDoc = await FirebaseFirestore.instance
            .collection('produits')
            .doc(productId)
            .get();

        if (productDoc.exists) {
          return productDoc.data()?['nom'] ?? currentName;
        }
      } catch (e) {
        print('Error resolving name: $e');
      }
    }
    return currentName;
  }

  // ✅ NEW: Function to delete equipment
  Future<void> _deleteEquipment(BuildContext context, String equipmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cet équipement du magasin ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .collection('stores')
            .doc(storeId)
            .collection('materiel_installe')
            .doc(equipmentId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Équipement supprimé')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression: $e')),
          );
        }
      }
    }
  }

  // ✅ NEW: Function to edit equipment
  void _editEquipment(BuildContext context, String equipmentId, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddStoreEquipmentPage(
          clientId: clientId,
          storeId: storeId,
          equipmentId: equipmentId,
          initialData: data, // Pass existing data to populate the form
        ),
      ),
    );
  }

  // 🟢 NEW: Build the Traffic Light Badge for Warranty
  Widget _buildWarrantyBadge(Map<String, dynamic> data) {
    EquipmentWarranty? warranty;

    // 1. Try to parse explicit warranty data
    if (data['warranty'] != null) {
      try {
        warranty = EquipmentWarranty.fromMap(data['warranty']);
      } catch (e) {
        // Fallback if data is malformed
      }
    }
    // 2. Legacy Fallback: If no explicit warranty data, assume 1 year from install date
    if (warranty == null && data['installDate'] != null) {
      final installDate = (data['installDate'] as Timestamp).toDate();
      warranty = EquipmentWarranty.defaultOneYear(installDate);
    }

    // 3. Render Badge based on status
    if (warranty == null) {
      // If we have no dates at all, don't show anything
      return const SizedBox.shrink();
    }

    if (warranty.isValid) {
      if (warranty.isExpiringSoon) {
        return _buildStatusChip(Colors.orange, "Expire bientôt", Icons.access_time);
      }
      return _buildStatusChip(Colors.green, "Sous Garantie", Icons.verified_user);
    } else {
      return _buildStatusChip(Colors.redAccent, "Expirée", Icons.highlight_off);
    }
  }

  Widget _buildStatusChip(Color color, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_location_alt_outlined),
            tooltip: 'Modifier le Magasin',
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('clients')
                  .doc(clientId)
                  .collection('stores')
                  .doc(storeId)
                  .get()
                  .then((doc) {
                if (doc.exists && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddStorePage(
                        clientId: clientId,
                        storeId: storeId,
                        initialData: doc.data(),
                      ),
                    ),
                  );
                }
              });
            },
          ),
        ],
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

              final String serial = data['serialNumber'] ?? data['serial'] ?? 'S/N Inconnu';
              final Timestamp? lastSeen = data['lastInterventionDate'] as Timestamp?;
              final Timestamp? installDate = data['installDate'] as Timestamp?;
              final String? imageUrl = data['image'];

              // ✅ WRAPPED CARD IN SLIDABLE FOR SWIPE ACTIONS
              return Slidable(
                key: ValueKey(id),
                startActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) => _editEquipment(context, id, data),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      icon: Icons.edit,
                      label: 'Modifier',
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                    ),
                  ],
                ),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) => _deleteEquipment(context, id),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Supprimer',
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                    ),
                  ],
                ),
                child: GestureDetector(
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

                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FutureBuilder<String>(
                                    future: _resolveProductName(data),
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

                                // 🟢 MODIFIED: Info Row with Warranty Badge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Left side: Dates
                                    Row(
                                      children: [
                                        if (lastSeen != null)
                                          _buildInfoTag(
                                              Icons.history,
                                              "Vu ${timeago.format(lastSeen.toDate(), locale: 'fr_short')}",
                                              Colors.grey.shade600
                                          ),
                                        if (lastSeen != null && installDate != null)
                                          const SizedBox(width: 8),
                                        if (installDate != null)
                                          _buildInfoTag(
                                              Icons.calendar_today,
                                              DateFormat('yyyy').format(installDate.toDate()),
                                              Colors.grey.shade600
                                          ),
                                      ],
                                    ),

                                    // Right side: Warranty Badge
                                    _buildWarrantyBadge(data),
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
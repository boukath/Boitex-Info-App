// lib/screens/administration/store_equipment_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:boitex_info_app/screens/administration/add_store_equipment_page.dart';
import 'package:boitex_info_app/screens/administration/store_equipment_details_page.dart';
import 'package:boitex_info_app/screens/administration/add_store_page.dart';

// ✅ Import Service Contracts for logic
import 'package:boitex_info_app/models/service_contracts.dart';

class StoreEquipmentPage extends StatefulWidget {
  final String clientId;
  final String storeId;
  final String storeName;
  final String? logoUrl;

  const StoreEquipmentPage({
    super.key,
    required this.clientId,
    required this.storeId,
    required this.storeName,
    this.logoUrl,
  });

  @override
  State<StoreEquipmentPage> createState() => _StoreEquipmentPageState();
}

class _StoreEquipmentPageState extends State<StoreEquipmentPage> {

  @override
  void initState() {
    super.initState();
    // 🚀 TRIGGER AUTO-IMPORT ON LOAD
    _syncFromDeliveries();
  }

  // ==============================================================================
  // 🔄 AUTO-IMPORT LOGIC (The Lazy Sync)
  // ==============================================================================
  Future<void> _syncFromDeliveries() async {
    try {
      final deliveriesSnapshot = await FirebaseFirestore.instance
          .collection('livraisons')
          .where('clientId', isEqualTo: widget.clientId)
          .where('storeId', isEqualTo: widget.storeId)
          .where('status', whereIn: ['Livré', 'Livraison Partielle'])
          .get();

      if (deliveriesSnapshot.docs.isEmpty) return;

      final equipmentRef = FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('stores')
          .doc(widget.storeId)
          .collection('materiel_installe');

      final equipmentSnapshot = await equipmentRef.get();
      final Set<String> existingSerials = equipmentSnapshot.docs
          .map((doc) => doc.data()['serialNumber']?.toString().trim().toUpperCase())
          .where((s) => s != null)
          .cast<String>()
          .toSet();

      final batch = FirebaseFirestore.instance.batch();
      int addedCount = 0;

      for (var doc in deliveriesSnapshot.docs) {
        final data = doc.data();
        final List products = data['products'] ?? [];
        final String deliveryId = doc.id;
        final Timestamp? deliveryDate = data['completedAt'] as Timestamp? ?? data['createdAt'] as Timestamp?;

        for (var item in products) {
          List<dynamic> serialsToAdd = [];

          if (item['deliveredSerials'] != null && (item['deliveredSerials'] as List).isNotEmpty) {
            serialsToAdd = item['deliveredSerials'];
          }
          else if (item['serialNumbers'] != null && (item['serialNumbers'] as List).isNotEmpty) {
            int deliveredQty = item['deliveredQuantity'] ?? item['quantity'] ?? 0;
            if (deliveredQty > 0) {
              serialsToAdd = (item['serialNumbers'] as List).take(deliveredQty).toList();
            }
          }

          for (var serial in serialsToAdd) {
            final String serialStr = serial.toString().trim();
            final String serialCheck = serialStr.toUpperCase();

            if (!existingSerials.contains(serialCheck) && serialStr.isNotEmpty && serialStr != 'N/A') {

              final newDoc = equipmentRef.doc();
              batch.set(newDoc, {
                'name': item['productName'] ?? 'Équipement',
                'category': item['category'] ?? 'N/A',
                'marque': item['marque'] ?? 'N/A',
                'reference': item['partNumber'] ?? item['reference'] ?? 'N/A',
                'serialNumber': serialStr,
                'installDate': deliveryDate ?? FieldValue.serverTimestamp(),
                'status': 'Installé',
                'source': 'Livraison',
                'firstSeenInstallationId': deliveryId,
                'warrantyEnd': null,
                'addedBy': 'Auto-Sync',
                'createdAt': FieldValue.serverTimestamp(),
              });

              existingSerials.add(serialCheck);
              addedCount++;
            }
          }
        }
      }

      if (addedCount > 0) {
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$addedCount équipements importés depuis les livraisons 📦"),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

    } catch (e) {
      debugPrint("Error syncing deliveries: $e");
    }
  }
  // ==============================================================================

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
        debugPrint('Error resolving name: $e');
      }
    }
    return currentName;
  }

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
            .doc(widget.clientId)
            .collection('stores')
            .doc(widget.storeId)
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

  void _editEquipment(BuildContext context, String equipmentId, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddStoreEquipmentPage(
          clientId: widget.clientId,
          storeId: widget.storeId,
          equipmentId: equipmentId,
          initialData: data,
        ),
      ),
    );
  }

  Widget _buildWarrantyBadge(Map<String, dynamic> data) {
    EquipmentWarranty? warranty;

    if (data['warranty'] != null) {
      try {
        warranty = EquipmentWarranty.fromMap(data['warranty']);
      } catch (e) {}
    }

    // ✅ FIXED: Support both 'installDate' and 'installationDate' for warranty check
    final Timestamp? ts = data['installDate'] ?? data['installationDate'];

    if (warranty == null && ts != null) {
      final installDate = ts.toDate();
      warranty = EquipmentWarranty.defaultOneYear(installDate);
    }

    if (warranty == null) {
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (widget.logoUrl != null) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: const BackButton(color: Colors.black87),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.logoUrl!),
              radius: 18,
              backgroundColor: Colors.grey.shade100,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.storeName, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text("Parc Installé", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_location_alt_outlined, color: Colors.blueAccent),
            tooltip: 'Modifier le Magasin',
            onPressed: () => _openStoreSettings(context),
          ),
        ],
      );
    } else {
      return AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Parc Installé', style: TextStyle(fontSize: 16)),
            Text(widget.storeName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: const Color(0xFF667EEA),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_location_alt_outlined),
            tooltip: 'Modifier le Magasin',
            onPressed: () => _openStoreSettings(context),
          ),
        ],
      );
    }
  }

  void _openStoreSettings(BuildContext context) {
    FirebaseFirestore.instance
        .collection('clients')
        .doc(widget.clientId)
        .collection('stores')
        .doc(widget.storeId)
        .get()
        .then((doc) {
      if (doc.exists && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddStorePage(
              clientId: widget.clientId,
              storeId: widget.storeId,
              initialData: doc.data(),
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('stores')
            .doc(widget.storeId)
            .collection('materiel_installe')
        // ❌ FIXED: Removed orderBy('installDate') to prevent hiding new items
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ✅ SMART SORT: Sort in memory to handle mixed date fields
          final docs = snapshot.data!.docs;

          docs.sort((a, b) {
            final da = a.data() as Map<String, dynamic>;
            final db = b.data() as Map<String, dynamic>;

            // Try 'installDate', then 'installationDate', then 'createdAt'
            final Timestamp? tA = da['installDate'] ?? da['installationDate'] ?? da['createdAt'];
            final Timestamp? tB = db['installDate'] ?? db['installationDate'] ?? db['createdAt'];

            if (tA == null) return 1; // Put nulls at the end
            if (tB == null) return -1;
            return tB.compareTo(tA); // Descending order (Newest first)
          });

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

              // ✅ FIXED: Read from both possible date fields
              final Timestamp? installDate = (data['installDate'] ?? data['installationDate']) as Timestamp?;

              final String? imageUrl = data['image'];

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
                          clientId: widget.clientId,
                          storeId: widget.storeId,
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
                                    initialData: data['nom'] ?? data['name'] ?? 'Chargement...',
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

                                // Info Row with Warranty Badge
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
                clientId: widget.clientId,
                storeId: widget.storeId,
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
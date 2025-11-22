// lib/screens/administration/store_equipment_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/add_store_equipment_page.dart';

class StoreEquipmentDetailsPage extends StatefulWidget {
  final String clientId;
  final String storeId;
  final String equipmentId;

  const StoreEquipmentDetailsPage({
    super.key,
    required this.clientId,
    required this.storeId,
    required this.equipmentId,
  });

  @override
  State<StoreEquipmentDetailsPage> createState() => _StoreEquipmentDetailsPageState();
}

class _StoreEquipmentDetailsPageState extends State<StoreEquipmentDetailsPage> {

  Future<void> _updateInstallationDate(BuildContext context, DateTime? currentDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
    );

    if (picked != null && picked != currentDate) {
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('stores')
          .doc(widget.storeId)
          .collection('materiel_installe')
          .doc(widget.equipmentId)
          .update({
        'installDate': Timestamp.fromDate(picked),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Date d\'installation mise à jour')),
        );
      }
    }
  }

  // ✅ NEW: Function to delete equipment from details page
  Future<void> _deleteEquipment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cet équipement ?'),
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
            .doc(widget.equipmentId)
            .delete();

        if (mounted) {
          Navigator.pop(context); // Return to list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Équipement supprimé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  Future<Map<String, dynamic>> _enrichProductData(Map<String, dynamic> inventoryData) async {
    if (inventoryData['marque'] != null && inventoryData['marque'] != 'N/A') {
      return inventoryData;
    }

    String? productId = inventoryData['productId'] ?? inventoryData['id'];
    if (productId != null && productId.isNotEmpty) {
      try {
        final productDoc = await FirebaseFirestore.instance.collection('produits').doc(productId).get();
        if (productDoc.exists) {
          final productData = productDoc.data()!;
          return {
            ...inventoryData,
            'marque': productData['marque'] ?? 'N/A',
            'reference': productData['reference'] ?? 'N/A',
            'categorie': productData['categorie'] ?? 'N/A',
            'image': productData['imageUrls'] is List && (productData['imageUrls'] as List).isNotEmpty
                ? (productData['imageUrls'] as List).first
                : inventoryData['image'],
          };
        }
      } catch (e) {
        print("Error fetching product details: $e");
      }
    }
    return inventoryData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails Équipement'),
        backgroundColor: const Color(0xFF667EEA),
        actions: [
          // ✅ UPDATED: Edit Button Logic
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier',
            onPressed: () {
              // Fetch current data then navigate
              FirebaseFirestore.instance
                  .collection('clients')
                  .doc(widget.clientId)
                  .collection('stores')
                  .doc(widget.storeId)
                  .collection('materiel_installe')
                  .doc(widget.equipmentId)
                  .get()
                  .then((doc) {
                if (doc.exists && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddStoreEquipmentPage(
                        clientId: widget.clientId,
                        storeId: widget.storeId,
                        equipmentId: widget.equipmentId,
                        initialData: doc.data(), // Pass data for editing
                      ),
                    ),
                  );
                }
              });
            },
          ),
          // ✅ ADDED: Delete Button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
            onPressed: _deleteEquipment,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('stores')
            .doc(widget.storeId)
            .collection('materiel_installe')
            .doc(widget.equipmentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Erreur de chargement'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Équipement introuvable (peut-être supprimé)'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return FutureBuilder<Map<String, dynamic>>(
              future: _enrichProductData(data),
              builder: (context, enrichedSnapshot) {

                final displayData = enrichedSnapshot.data ?? data;

                final nom = displayData['nom'] ?? displayData['name'] ?? 'Inconnu';
                final marque = displayData['marque'] ?? 'N/A';
                final reference = displayData['reference'] ?? 'N/A';
                final categorie = displayData['categorie'] ?? displayData['category'] ?? 'N/A';
                final serial = displayData['serialNumber'] ?? displayData['serial'] ?? 'Non spécifié';
                final installDate = displayData['installDate'] as Timestamp?;
                final imageUrl = displayData['image'];

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                  image: imageUrl != null
                                      ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: imageUrl == null
                                    ? const Icon(Icons.devices_other, size: 40, color: Colors.grey)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nom,
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "S/N: $serial",
                                        style: TextStyle(
                                          color: Colors.blue.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text("Informations Techniques", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildDetailRow("Nom", nom),
                              const Divider(),
                              _buildDetailRow("Marque", marque),
                              const Divider(),
                              _buildDetailRow("Référence", reference),
                              const Divider(),
                              _buildDetailRow("Catégorie", categorie),
                              const Divider(),
                              _buildDetailRow("Source Données", displayData['source'] ?? 'Automatique'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text("Installation & Maintenance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.calendar_today, color: Color(0xFF667EEA)),
                          title: const Text("Date d'installation"),
                          subtitle: Text(
                            installDate != null
                                ? DateFormat('dd MMMM yyyy', 'fr_FR').format(installDate.toDate())
                                : "Non définie",
                          ),
                          trailing: const Icon(Icons.edit, size: 20, color: Colors.grey),
                          onTap: () => _updateInstallationDate(context, installDate?.toDate()),
                        ),
                      ),
                    ],
                  ),
                );
              }
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
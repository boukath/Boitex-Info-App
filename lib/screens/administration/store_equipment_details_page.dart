// lib/screens/administration/store_equipment_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/add_store_equipment_page.dart';

class StoreEquipmentDetailsPage extends StatelessWidget {
  final String clientId;
  final String storeId;
  final String equipmentId;

  const StoreEquipmentDetailsPage({
    super.key,
    required this.clientId,
    required this.storeId,
    required this.equipmentId,
  });

  // ✅ FEATURE: One-tap Installation Date Update
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
          .doc(clientId)
          .collection('stores')
          .doc(storeId)
          .collection('materiel_installe')
          .doc(equipmentId)
          .update({
        'installDate': Timestamp.fromDate(picked),
      });

      if(context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Date d'installation mise à jour avec succès"),
              backgroundColor: Colors.green
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .collection('stores')
            .doc(storeId)
            .collection('materiel_installe')
            .doc(equipmentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Équipement introuvable"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          // ✅ UPDATED: Data Mapping based on your request
          // We check both the new French keys and fallback to English keys if data is old
          final String nom = data['nom'] ?? data['name'] ?? 'Produit Inconnu';
          final String marque = data['marque'] ?? 'Non spécifiée';
          final String reference = data['reference'] ?? 'N/A';
          final String categorie = data['categorie'] ?? data['category'] ?? 'N/A';

          final String serial = data['serialNumber'] ?? 'N/A';
          final String? imageUrl = data['imageUrl'];
          final Timestamp? installDateTs = data['installDate'] as Timestamp?;
          final DateTime? installDate = installDateTs?.toDate();
          final String status = data['status'] ?? 'Inconnu';

          return CustomScrollView(
            slivers: [
              // 1. Hero Header
              SliverAppBar(
                expandedHeight: 250.0,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    nom,
                    style: const TextStyle(
                      fontSize: 16,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
                  background: imageUrl != null
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : Container(
                    color: const Color(0xFF667EEA),
                    child: const Center(child: Icon(Icons.inventory_2, size: 64, color: Colors.white30)),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: "Modifier tout",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddStoreEquipmentPage(
                            clientId: clientId,
                            storeId: storeId,
                            equipmentId: equipmentId,
                            initialData: data,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // 2. Content Body
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: status == 'Opérationnel' ? Colors.green.shade100 : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: status == 'Opérationnel' ? Colors.green.shade800 : Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- IDENTITY CARD ---
                      const Text("IDENTIFICATION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.qr_code, color: Color(0xFF667EEA)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Numéro de Série", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(serial, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- LIFECYCLE (Editable Date) ---
                      const Text("CYCLE DE VIE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEFF6FF),
                            child: Icon(Icons.calendar_today, color: Color(0xFF667EEA)),
                          ),
                          title: const Text("Date d'Installation"),
                          subtitle: Text(
                            installDate != null
                                ? DateFormat('dd MMMM yyyy', 'fr_FR').format(installDate)
                                : "Non définie (Touchez pour ajouter)",
                            style: TextStyle(
                              color: installDate == null ? Colors.red : Colors.black87,
                              fontWeight: installDate == null ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: const Icon(Icons.edit, color: Colors.grey, size: 20),
                          onTap: () => _updateInstallationDate(context, installDate),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // --- TECHNICAL SPECS ---
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          children: [
                            // ✅ UPDATED: Using correct field names
                            _buildDetailRow("Nom", nom),
                            const Divider(),
                            _buildDetailRow("Marque", marque),
                            const Divider(),
                            _buildDetailRow("Référence", reference),
                            const Divider(),
                            _buildDetailRow("Catégorie", categorie),
                            const Divider(),
                            _buildDetailRow("Source Données", data['source'] ?? 'Manuel'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
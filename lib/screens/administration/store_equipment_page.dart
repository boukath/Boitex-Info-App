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
            .orderBy('lastInterventionDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              return _buildAssetCard(context, data, docId);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddStoreEquipmentPage(
                clientId: clientId,
                storeId: storeId,
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF667EEA),
        icon: const Icon(Icons.add),
        label: const Text('Ajout Manuel'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Aucun équipement recensé",
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Effectuez une intervention pour\ndétecter automatiquement le matériel.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCard(BuildContext context, Map<String, dynamic> data, String docId) {
    final String name = data['name'] ?? 'Équipement Inconnu';
    final String serial = data['serialNumber'] ?? 'N/A';
    final String? imageUrl = data['imageUrl'];
    final Timestamp? lastSeen = data['lastInterventionDate'] as Timestamp?;
    final Timestamp? installDate = data['installDate'] as Timestamp?;
    final bool isRecent = lastSeen != null && DateTime.now().difference(lastSeen.toDate()).inDays < 30;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          // ✅ UPGRADED: Opens the new Details Page
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => StoreEquipmentDetailsPage(
                  clientId: clientId,
                  storeId: storeId,
                  equipmentId: docId,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: imageUrl != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(imageUrl, fit: BoxFit.cover))
                      : const Icon(Icons.qr_code_2, size: 32, color: Color(0xFF667EEA)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: isRecent ? Colors.green : Colors.orange, shape: BoxShape.circle)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                        child: Text("S/N: $serial", style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (lastSeen != null) _buildInfoTag(Icons.history, "Vu ${timeago.format(lastSeen.toDate(), locale: 'fr_short')}", Colors.grey.shade600),
                          const SizedBox(width: 12),
                          if (installDate != null) _buildInfoTag(Icons.calendar_today, DateFormat('yyyy').format(installDate.toDate()), Colors.grey.shade600),
                        ],
                      ),
                    ],
                  ),
                ),
                const Padding(padding: EdgeInsets.only(top: 24, left: 8), child: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTag(IconData icon, String text, Color color) {
    return Row(children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 11, color: color))]);
  }
}
// lib/screens/administration/broken_product_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BrokenProductDetailsPage extends StatelessWidget {
  final Map<String, dynamic> productData;
  final String productId;

  const BrokenProductDetailsPage({
    super.key,
    required this.productData,
    required this.productId,
  });

  @override
  Widget build(BuildContext context) {
    final String name = productData['nom'] ?? 'Inconnu';
    final String ref = productData['reference'] ?? 'N/A';
    final int brokenQty = productData['quantiteDefectueuse'] ?? 0;

    // Get product image
    final List<dynamic>? images = productData['imageUrls'];
    final String? productImageUrl = (images != null && images.isNotEmpty)
        ? images.first.toString()
        : null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Détails Avarie / Casse"),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 📦 1. HEADER: Product Summary
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                // Product Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: productImageUrl != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(productImageUrl, fit: BoxFit.cover),
                  )
                      : const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 40),
                ),
                const SizedBox(width: 16),
                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text("Réf: $ref", style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          "Total HS : $brokenQty",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 📜 2. TIMELINE: History of Damage
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('stock_movements')
                  .where('productId', isEqualTo: productId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Aucun historique trouvé"));
                }

                // Filter locally for movements relevant to breakage
                // We want: INTERNAL_BREAKAGE, CLIENT_RETURN_DEFECTIVE, etc.
                final relevantDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'] ?? '';
                  final brokenChange = data['brokenStockChange'] ?? 0;
                  return brokenChange != 0 ||
                      type.toString().contains('DEFECTIVE') ||
                      type.toString().contains('BREAKAGE');
                }).toList();

                if (relevantDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text("Pas d'historique de casse enregistré."),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: relevantDocs.length,
                  itemBuilder: (context, index) {
                    final data = relevantDocs[index].data() as Map<String, dynamic>;
                    return _buildHistoryCard(context, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> data) {
    final String type = data['type'] ?? 'UNKNOWN';
    final String reason = data['reason'] ?? 'Aucun motif';
    final String user = data['user'] ?? 'Inconnu';
    final Timestamp? ts = data['timestamp'];
    final String dateStr = ts != null
        ? DateFormat('dd MMM yyyy à HH:mm', 'fr_FR').format(ts.toDate())
        : '-';

    // Photo Logic
    final String? evidenceUrl = data['photoUrl'];

    // Determine Color & Icon based on Type
    Color color = Colors.grey;
    IconData icon = Icons.info;
    String title = "Mouvement";

    if (type == 'INTERNAL_BREAKAGE') {
      color = Colors.red;
      icon = Icons.broken_image_rounded;
      title = "Casse Interne";
    } else if (type == 'CLIENT_RETURN_DEFECTIVE') {
      color = Colors.purple;
      icon = Icons.assignment_return_rounded;
      title = "Retour Client (Défectueux)";
    } else if (type == 'BROKEN_RESTORED') {
      color = Colors.green;
      icon = Icons.build_circle_rounded;
      title = "Réparé / Remis en Stock";
    } else if (type == 'BROKEN_DESTROYED') {
      color = Colors.black87;
      icon = Icons.delete_forever_rounded;
      title = "Détruit / Jeté";
    } else if (type == 'BROKEN_STOCK_CORRECTION') {
      color = Colors.blue;
      icon = Icons.edit_note;
      title = "Correction Inventaire";
    }

    final int change = data['brokenStockChange'] ?? 0;
    final String qtySign = change > 0 ? "+$change" : "$change";

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const Spacer(),
                Text(qtySign, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Evidence Photo (If exists)
                if (evidenceUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        // Simple full screen view
                        showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              child: Image.network(evidenceUrl),
                            )
                        );
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                            image: DecorationImage(
                                image: NetworkImage(evidenceUrl),
                                fit: BoxFit.cover
                            )
                        ),
                        child: const Center(child: Icon(Icons.zoom_in, color: Colors.white70)),
                      ),
                    ),
                  ),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reason, style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(user, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(width: 12),
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
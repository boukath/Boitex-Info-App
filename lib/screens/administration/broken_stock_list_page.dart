// lib/screens/administration/broken_stock_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ✅ IMPORTS
import 'package:boitex_info_app/screens/administration/report_breakage_page.dart';
import 'package:boitex_info_app/services/stock_service.dart';
import 'package:boitex_info_app/screens/administration/broken_product_details_page.dart';

class BrokenStockListPage extends StatefulWidget {
  const BrokenStockListPage({super.key});

  @override
  State<BrokenStockListPage> createState() => _BrokenStockListPageState();
}

class _BrokenStockListPageState extends State<BrokenStockListPage> {

  // ✏️ EDIT LOGIC
  Future<void> _editQuantity(String productId, int currentQty) async {
    final controller = TextEditingController(text: currentQty.toString());

    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Modifier la quantité"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Nouvelle quantité HS", border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () async {
                final int? newQty = int.tryParse(controller.text);
                if (newQty == null || newQty < 0) return;

                final user = FirebaseAuth.instance.currentUser;
                await StockService().updateBrokenQuantity(
                    productId: productId,
                    newQuantity: newQty,
                    reason: "Correction manuelle",
                    userName: user?.displayName ?? "Admin"
                );
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text("Enregistrer"),
            )
          ],
        )
    );
  }

  // 🗑️ DELETE/RESOLVE LOGIC
  Future<void> _resolveItem(String productId, String productName, int currentBrokenQty) async {
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Retirer de la Quarantaine"),
          content: Text("Que voulez-vous faire de : $productName ?"),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowDirection: VerticalDirection.up,
          actions: [
            // CANCEL
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler", style: TextStyle(color: Colors.grey))
            ),

            const SizedBox(height: 8),

            // OPTION A: TRASH
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45)
              ),
              icon: const Icon(Icons.delete_forever),
              label: const Text("Jeter / Détruire (Perte Sèche)"),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                await StockService().resolveBrokenItem(
                    productId: productId,
                    quantityToRemove: currentBrokenQty,
                    restoreToHealthyStock: false, // 🗑️ DESTROY
                    userName: user?.displayName ?? "Admin"
                );
                if (mounted) Navigator.pop(ctx);
              },
            ),

            const SizedBox(height: 8),

            // OPTION B: RESTORE
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45)
              ),
              icon: const Icon(Icons.replay_circle_filled_rounded),
              label: const Text("Remettre en Stock (Réparé/Erreur)"),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                await StockService().resolveBrokenItem(
                    productId: productId,
                    quantityToRemove: currentBrokenQty,
                    restoreToHealthyStock: true, // ♻️ RESTORE
                    userName: user?.displayName ?? "Admin"
                );
                if (mounted) Navigator.pop(ctx);
              },
            ),
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text(
          "⚠️ Zone de Quarantaine",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportBreakagePage()),
          );
        },
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text("DÉCLARER CASSE"),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('produits')
            .where('quantiteDefectueuse', isGreaterThan: 0)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.red));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "Zone de Quarantaine Vide",
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String id = docs[index].id;
              final String name = data['nom'] ?? 'Produit Inconnu';
              final String ref = data['reference'] ?? 'N/A';
              final int brokenQty = data['quantiteDefectueuse'] ?? 0;

              final List<dynamic>? images = data['imageUrls'];
              final String? imageUrl = (images != null && images.isNotEmpty)
                  ? images.first.toString()
                  : null;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    // ✅ CLICKABLE AREA -> GO TO DETAILS
                    InkWell(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      onTap: () {
                        // Navigate to Details Page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BrokenProductDetailsPage(
                              productData: data,
                              productId: id,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // PHOTO
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: imageUrl != null
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(imageUrl, fit: BoxFit.cover),
                              )
                                  : const Icon(Icons.broken_image_rounded, color: Colors.grey),
                            ),
                            const SizedBox(width: 12),
                            // TEXT
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text("Réf: $ref", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.info_outline, size: 14, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Voir l'historique",
                                        style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // QTY BADGE
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                "$brokenQty HS",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    // ROW 2: ACTIONS
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: () => _editQuantity(id, brokenQty),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text("Modifier"),
                            style: TextButton.styleFrom(foregroundColor: Colors.blue.shade700),
                          ),
                          Container(width: 1, height: 20, color: Colors.grey.shade300),
                          TextButton.icon(
                            onPressed: () => _resolveItem(id, name, brokenQty),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text("Traiter / Sortir"),
                            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
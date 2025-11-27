// lib/screens/administration/product_stock_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ProductStockListPage extends StatelessWidget {
  final String category;
  final Color categoryColor;

  const ProductStockListPage({
    super.key,
    required this.category,
    required this.categoryColor,
  });

  void _showAdjustStockDialog(BuildContext context, DocumentSnapshot productDoc) {
    final formKey = GlobalKey<FormState>();
    final productData = productDoc.data() as Map<String, dynamic>;

    // Initial Auth User Check
    final authUser = FirebaseAuth.instance.currentUser;
    final String initialUid = authUser?.uid ?? 'unknown_uid';

    // Get old quantity
    final int oldQuantity = productData['quantiteEnStock'] ?? 0;

    // Controllers
    final newQuantityController = TextEditingController(text: oldQuantity.toString());
    final notesController = TextEditingController();

    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {

            // --- The Save Function ---
            Future<void> _onSave() async {
              if (isLoading) return;
              if (!formKey.currentState!.validate()) {
                return;
              }

              setState(() { isLoading = true; });

              final int newQuantity = int.tryParse(newQuantityController.text) ?? oldQuantity;
              final String notes = notesController.text.trim();

              if (newQuantity == oldQuantity) {
                Navigator.of(context).pop();
                return;
              }

              final int quantityChange = newQuantity - oldQuantity;
              final db = FirebaseFirestore.instance;
              final productRef = productDoc.reference;
              final ledgerRef = db.collection('stock_movements').doc();

              // ✅ 1. SMART NAME LOOKUP
              // We try to find the real name from Firestore before saving
              String finalUserName = 'Utilisateur'; // Default
              String finalUserId = initialUid;

              if (authUser != null) {
                // Try to use local display name first if available
                if (authUser.displayName != null && authUser.displayName!.isNotEmpty) {
                  finalUserName = authUser.displayName!;
                }
                // If local name is missing/empty, fetch from Firestore
                else {
                  try {
                    final userDoc = await db.collection('users').doc(authUser.uid).get();
                    if (userDoc.exists) {
                      final data = userDoc.data();
                      // Check 'displayName' then 'fullName'
                      finalUserName = data?['displayName'] ?? data?['fullName'] ?? 'Utilisateur';
                    }
                  } catch (e) {
                    print("Error fetching user name: $e");
                  }
                }
              }

              try {
                // Use a transaction for safety
                await db.runTransaction((transaction) async {
                  // 2. Create the Ledger Entry
                  transaction.set(ledgerRef, {
                    'productId': productDoc.id,
                    'productRef': productData['reference'] ?? 'N/A',
                    'productName': productData['nom'] ?? 'Nom inconnu',
                    'quantityChange': quantityChange,
                    'oldQuantity': oldQuantity,
                    'newQuantity': newQuantity,
                    'type': 'ADJUST',
                    'notes': notes,
                    'userId': finalUserId,

                    // ✅ Correctly set the fetched name
                    'user': finalUserName,
                    'userDisplayName': finalUserName,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  // 3. Update the Product with Signature
                  transaction.update(productRef, {
                    'quantiteEnStock': newQuantity,
                    // ✅ This stops "Système" and "Inconnu"
                    'lastModifiedBy': finalUserName,
                    'lastModifiedAt': FieldValue.serverTimestamp(),
                  });
                });

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Stock mis à jour par $finalUserName !'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                print("Transaction failed: $e");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (context.mounted) {
                  setState(() { isLoading = false; });
                }
              }
            }
            // --- End of Save Function ---

            return AlertDialog(
              title: Text(productData['nom'] ?? 'Ajuster le Stock'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Actuel: $oldQuantity',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newQuantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Nouvelle Quantité en Stock',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer une quantité';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Veuillez entrer un nombre valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Obligatoire)',
                        hintText: 'Ex: comptage inventaire, perte, ...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Une note est obligatoire pour l\'audit';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton.icon(
                  icon: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer'),
                  onPressed: isLoading ? null : _onSave,
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category),
        backgroundColor: categoryColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('produits')
            .where('categorie', isEqualTo: category)
            .orderBy('nom')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucun produit dans cette catégorie.'));
          }

          final productDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: productDocs.length,
            itemBuilder: (context, index) {
              final productDoc = productDocs[index];
              final productData = productDoc.data() as Map<String, dynamic>;
              final stockQuantity = productData['quantiteEnStock'] ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: categoryColor.withOpacity(0.1),
                    child: Icon(Icons.inventory_2_outlined, color: categoryColor),
                  ),
                  title: Text(productData['nom'] ?? 'Nom inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Référence: ${productData['reference'] ?? 'N/A'}'),
                  trailing: Text(
                    stockQuantity.toString(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: stockQuantity > 5 ? Colors.green.shade700 : (stockQuantity > 0 ? Colors.orange.shade700 : Colors.red.shade700),
                    ),
                  ),
                  onTap: () => _showAdjustStockDialog(context, productDoc),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
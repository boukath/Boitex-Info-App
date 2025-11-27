// lib/screens/administration/product_stock_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // ✅ ADDED for number input

class ProductStockListPage extends StatelessWidget {
  final String category;
  final Color categoryColor;

  const ProductStockListPage({
    super.key,
    required this.category,
    required this.categoryColor,
  });

  /// ✅ --- REBUILT DIALOG LOGIC ---
  /// This dialog now uses a Firebase Transaction to create a
  /// stock_movements ledger entry for every change.
  void _showAdjustStockDialog(BuildContext context, DocumentSnapshot productDoc) {
    final formKey = GlobalKey<FormState>();
    final productData = productDoc.data() as Map<String, dynamic>;

    // Get current user details
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserName = currentUser?.displayName ?? 'Inconnu';
    final currentUserId = currentUser?.uid ?? 'unknown_uid';

    // Get old quantity
    final int oldQuantity = productData['quantiteEnStock'] ?? 0;

    // Controllers
    final newQuantityController = TextEditingController(text: oldQuantity.toString());
    final notesController = TextEditingController();

    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: !isLoading, // Prevent closing while saving
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

              // Check if anything actually changed
              if (newQuantity == oldQuantity) {
                Navigator.of(context).pop();
                return;
              }

              // Calculate the difference
              final int quantityChange = newQuantity - oldQuantity;

              final db = FirebaseFirestore.instance;
              final productRef = productDoc.reference;
              final ledgerRef = db.collection('stock_movements').doc(); // New ledger entry

              try {
                // Use a transaction for safety
                await db.runTransaction((transaction) async {
                  // 1. Create the new Stock Movement Log (Your Ledger)
                  transaction.set(ledgerRef, {
                    'productId': productDoc.id,
                    'productRef': productData['reference'] ?? 'N/A',
                    'productName': productData['nom'] ?? 'Nom inconnu',
                    'quantityChange': quantityChange,
                    'oldQuantity': oldQuantity,
                    'newQuantity': newQuantity,
                    'type': 'ADJUST', // Manual adjustment
                    'notes': notes,
                    'userId': currentUserId,
                    'userDisplayName': currentUserName,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  // 2. Update the product's main stock level
                  // ✅ CRITICAL FIX: We now send 'lastModifiedBy' so the Cloud Function knows who you are
                  transaction.update(productRef, {
                    'quantiteEnStock': newQuantity,
                    'lastModifiedBy': currentUserName, // <--- THIS FIXES THE PDF USER NAME
                    'lastModifiedAt': FieldValue.serverTimestamp(),
                  });
                });

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Stock pour ${productData['nom']} mis à jour!'),
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
  // ✅ --- END OF REBUILT DIALOG ---

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
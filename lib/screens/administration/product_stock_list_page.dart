import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    List<bool> isSelected = [true, false];
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Ajuster le Stock'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ToggleButtons(
                      isSelected: isSelected,
                      onPressed: (int index) {
                        setState(() { isSelected = [index == 0, index == 1]; });
                      },
                      borderRadius: BorderRadius.circular(8.0),
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Ajouter')),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Retirer')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: quantityController,
                      decoration: const InputDecoration(labelText: 'Quantité'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty || int.tryParse(value) == null || int.parse(value) <= 0) {
                          return 'Veuillez entrer un nombre valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes (ex: Arrivage, Vente)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setState(() { isLoading = true; });
                      final int quantityChange = int.parse(quantityController.text);
                      final bool isAdding = isSelected[0];
                      final user = FirebaseAuth.instance.currentUser;

                      try {
                        await FirebaseFirestore.instance.runTransaction((transaction) async {
                          final productRef = FirebaseFirestore.instance.collection('produits').doc(productDoc.id);
                          final freshSnap = await transaction.get(productRef);
                          final currentQuantity = freshSnap.data()?['quantiteEnStock'] ?? 0;
                          final newQuantity = isAdding ? currentQuantity + quantityChange : currentQuantity - quantityChange;
                          transaction.update(productRef, {'quantiteEnStock': newQuantity});
                          final historyRef = productRef.collection('stock_history').doc();
                          transaction.set(historyRef, {
                            'change': isAdding ? quantityChange : -quantityChange,
                            'newQuantity': newQuantity,
                            'notes': notesController.text,
                            'timestamp': FieldValue.serverTimestamp(),
                            'updatedByUid': user?.uid,
                          });
                        });
                        if(context.mounted) Navigator.of(context).pop();
                      } catch (e) {
                        print("Error updating stock: $e");
                        if(context.mounted) Navigator.of(context).pop();
                      }
                    }
                  },
                  child: isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Mettre à jour'),
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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('produits')
            .where('categorie', isEqualTo: category)
            .orderBy('nom')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final productDocs = snapshot.data!.docs;
          if (productDocs.isEmpty) return const Center(child: Text('Aucun produit dans cette catégorie.'));

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
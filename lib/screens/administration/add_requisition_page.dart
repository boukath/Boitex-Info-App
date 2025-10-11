import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Helper class to manage items in the requisition list
class RequisitionItem {
  final DocumentSnapshot productDoc;
  final int quantity;

  RequisitionItem({required this.productDoc, required this.quantity});

  String get name => productDoc['nom'];
  String get id => productDoc.id;

  Map<String, dynamic> toJson() {
    return {
      'productId': id,
      'productName': name,
      'quantity': quantity,
    };
  }
}

class AddRequisitionPage extends StatefulWidget {
  const AddRequisitionPage({super.key});

  @override
  State<AddRequisitionPage> createState() => _AddRequisitionPageState();
}

class _AddRequisitionPageState extends State<AddRequisitionPage> {
  final _formKey = GlobalKey<FormState>();
  final List<RequisitionItem> _items = [];
  bool _isLoading = false;

  Future<void> _showAddItemDialog() async {
    final result = await showDialog<RequisitionItem>(
      context: context,
      builder: (ctx) => const _AddItemDialog(),
    );

    if (result != null) {
      setState(() {
        if (!_items.any((item) => item.id == result.id)) {
          _items.add(result);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce produit est déjà dans la liste.')));
        }
      });
    }
  }

  // Replace the entire _saveRequisition function with this

  Future<void> _saveRequisition() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez ajouter au moins un produit.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Utilisateur non connecté.");
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final creatorName = userDoc.data()?['displayName'] ?? user.email ?? 'Utilisateur inconnu';

      // ✅ ADDED: The new code generation logic
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final currentYear = DateTime.now().year;
        final counterRef = FirebaseFirestore.instance.collection('counters').doc('requisition_counter_$currentYear');
        final counterSnap = await transaction.get(counterRef);
        final newCount = (counterSnap.data()?['count'] as int? ?? 0) + 1;
        final newCode = 'CM-$newCount/$currentYear';

        final requisitionRef = FirebaseFirestore.instance.collection('requisitions').doc();
        transaction.set(requisitionRef, {
          'requisitionCode': newCode, // The new unique code
          'requestedBy': creatorName,
          'requestedByUid': user.uid,
          'createdAt': Timestamp.now(),
          'status': "En attente d'approbation",
          'items': _items.map((item) => item.toJson()).toList(),
        });

        transaction.set(counterRef, {'count': newCount}, SetOptions(merge: true));
      });

      if(mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande d\'achat envoyée pour approbation.')));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.indigo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle Demande d\'Achat'),
        backgroundColor: primaryColor,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Produits Demandés', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Expanded(
                child: _items.isEmpty
                    ? Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(child: Text('Aucun produit ajouté.', style: TextStyle(color: Colors.grey))),
                )
                    : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text('Quantité: ${item.quantity}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => setState(() => _items.removeAt(index)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _showAddItemDialog,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un Produit'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveRequisition,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Soumettre pour Approbation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// Paste this entire block at the bottom of add_requisition_page.dart, replacing the old _AddItemDialog

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog();
  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  // State for the new 3-level selection
  final List<String> _mainCategories = ['Antivol', 'TPV', 'Compteur Client'];
  String? _selectedMainCategory;
  List<String> _subCategories = [];
  bool _isLoadingSubCategories = false;
  String? _selectedSubCategory;
  List<DocumentSnapshot> _products = [];
  bool _isLoadingProducts = false;
  DocumentSnapshot? _selectedProduct;

  final _quantityController = TextEditingController(text: "1");
  final _dialogFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategoriesForMainSection(String mainCategory) async {
    setState(() {
      _isLoadingSubCategories = true;
      _subCategories = [];
      _selectedSubCategory = null;
      _products = [];
      _selectedProduct = null;
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('produits')
        .where('mainCategory', isEqualTo: mainCategory)
        .get();

    final categoriesSet = <String>{};
    for (var doc in snapshot.docs) {
      categoriesSet.add(doc.data()['categorie'] as String);
    }

    final sortedList = categoriesSet.toList();
    sortedList.sort();

    if (mounted) {
      setState(() {
        _subCategories = sortedList;
        _isLoadingSubCategories = false;
      });
    }
  }

  Future<void> _fetchProductsForSubCategory(String category) async {
    setState(() { _isLoadingProducts = true; _products = []; _selectedProduct = null; });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('categorie', isEqualTo: category)
          .orderBy('nom')
          .get();
      if (mounted) setState(() { _products = snapshot.docs; _isLoadingProducts = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingProducts = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un Produit'),
      content: Form(
        key: _dialogFormKey,
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Main Section Dropdown
              DropdownButtonFormField<String>(
                value: _selectedMainCategory,
                items: _mainCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if(val != null) {
                    setState(() => _selectedMainCategory = val);
                    _fetchCategoriesForMainSection(val);
                  }
                },
                decoration: const InputDecoration(labelText: 'Section Principale', border: OutlineInputBorder()),
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 16),

              // 2. Sub-Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedSubCategory,
                items: _subCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: _selectedMainCategory == null || _isLoadingSubCategories ? null : (val) {
                  if (val != null) {
                    setState(() => _selectedSubCategory = val);
                    _fetchProductsForSubCategory(val);
                  }
                },
                decoration: const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder()),
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 16),

              // 3. Product Dropdown
              DropdownButtonFormField<DocumentSnapshot>(
                value: _selectedProduct,
                items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p['nom']))).toList(),
                onChanged: _selectedSubCategory == null || _isLoadingProducts ? null : (val) => setState(() => _selectedProduct = val),
                decoration: const InputDecoration(labelText: 'Produit', border: OutlineInputBorder()),
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Quantité', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Quantité requise' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () {
            if (_dialogFormKey.currentState!.validate()) {
              final quantity = int.tryParse(_quantityController.text) ?? 0;
              Navigator.of(context).pop(RequisitionItem(productDoc: _selectedProduct!, quantity: quantity));
            }
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
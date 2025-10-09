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

      await FirebaseFirestore.instance.collection('requisitions').add({
        'requestedBy': creatorName,
        'requestedByUid': user.uid,
        'createdAt': Timestamp.now(),
        'status': "En attente d'approbation",
        'items': _items.map((item) => item.toJson()).toList(),
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


class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog();
  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  List<String> _categories = [];
  List<QueryDocumentSnapshot> _productsForCategory = [];
  bool _isLoadingCategories = true;
  bool _isLoadingProducts = false;
  String? _selectedCategory;
  DocumentSnapshot? _selectedProduct;
  final _quantityController = TextEditingController();
  final _dialogFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchProductCategories();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _fetchProductCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('produits').get();
      final categories = snapshot.docs.map((doc) => doc.data()['categorie'] as String?).where((c) => c != null && c.isNotEmpty).toSet().toList();
      categories.sort();
      if (mounted) setState(() { _categories = categories.cast<String>(); _isLoadingCategories = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingCategories = false; });
    }
  }

  Future<void> _fetchProductsForCategory(String category) async {
    setState(() { _isLoadingProducts = true; _productsForCategory = []; _selectedProduct = null; });
    try {
      final snapshot = await FirebaseFirestore.instance.collection('produits').where('categorie', isEqualTo: category).orderBy('nom').get();
      if (mounted) setState(() { _productsForCategory = snapshot.docs; _isLoadingProducts = false; });
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
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) { if(val != null) { setState(() => _selectedCategory = val); _fetchProductsForCategory(val); } },
                decoration: InputDecoration(labelText: 'Catégorie', border: const OutlineInputBorder()),
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DocumentSnapshot>(
                value: _selectedProduct,
                items: _productsForCategory.map((p) => DropdownMenuItem(value: p, child: Text(p['nom']))).toList(),
                onChanged: _selectedCategory == null ? null : (val) => setState(() => _selectedProduct = val),
                decoration: InputDecoration(labelText: 'Produit', border: const OutlineInputBorder()),
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
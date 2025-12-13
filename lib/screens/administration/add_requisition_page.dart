// lib/screens/administration/add_requisition_page.dart

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
      'orderedQuantity': quantity,
      'receivedQuantity': 0, // Assume 0 when creating/updating
    };
  }
}

class AddRequisitionPage extends StatefulWidget {
  // Optional parameter to accept an existing requisition ID for editing
  final String? requisitionId;

  const AddRequisitionPage({super.key, this.requisitionId});

  @override
  State<AddRequisitionPage> createState() => _AddRequisitionPageState();
}

class _AddRequisitionPageState extends State<AddRequisitionPage> {
  final _formKey = GlobalKey<FormState>();
  final List<RequisitionItem> _items = [];
  bool _isLoading = false;

  late bool _isEditMode;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.requisitionId != null;
    if (_isEditMode) {
      _loadExistingRequisition();
    }
  }

  Future<void> _loadExistingRequisition() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('requisitions')
          .doc(widget.requisitionId!)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Demande non trouvée.')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final itemsFromDb = List<Map<String, dynamic>>.from(data['items'] ?? []);

      for (var itemMap in itemsFromDb) {
        final productDoc = await FirebaseFirestore.instance
            .collection('produits')
            .doc(itemMap['productId'])
            .get();

        if (productDoc.exists) {
          _items.add(RequisitionItem(
            productDoc: productDoc,
            quantity: itemMap['orderedQuantity'],
          ));
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }


  Future<void> _showAddItemDialog() async {
    final result = await showDialog<RequisitionItem>(
      context: context,
      builder: (ctx) => const _AddItemDialog(),
    );
    if (result != null) {
      setState(() {
        if (_items.any((item) => item.id == result.id)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ce produit est déjà dans la liste.')),
          );
        } else {
          _items.add(result);
        }
      });
    }
  }

  // ✅ NEW: Function to show an edit dialog for an item's quantity
  Future<void> _showEditItemQuantityDialog(int index) async {
    final item = _items[index];
    final quantityController =
    TextEditingController(text: item.quantity.toString());

    final newQuantity = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Modifier Quantité'),
          content: TextFormField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantité',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            validator: (v) {
              return (int.tryParse(v ?? '') ?? 0) <= 0
                  ? 'Quantité requise'
                  : null;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final int? qty = int.tryParse(quantityController.text);
                if (qty != null && qty > 0) {
                  Navigator.of(context).pop(qty);
                } else {
                  // Show a small error without closing
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez entrer une quantité valide.')),
                  );
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    if (newQuantity != null && newQuantity > 0) {
      // Update the item in the list
      final updatedItem = RequisitionItem(
        productDoc: item.productDoc,
        quantity: newQuantity,
      );
      setState(() {
        _items.removeAt(index);
        _items.insert(index, updatedItem);
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _submitRequisition() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins un produit.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (_isEditMode) {
      await _updateRequisition();
    } else {
      await _createNewRequisition();
    }
  }

  Future<void> _updateRequisition() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['displayName'] ?? 'Utilisateur Inconnu';

      final itemsJson = _items.map((item) => item.toJson()).toList();

      final logEntry = {
        'action': 'Modification',
        'user': userName,
        'timestamp': Timestamp.now(),
        'details': 'La liste des articles a été modifiée.'
      };

      await FirebaseFirestore.instance
          .collection('requisitions')
          .doc(widget.requisitionId)
          .update({
        'items': itemsJson,
        'activityLog': FieldValue.arrayUnion([logEntry]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande modifiée avec succès.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewRequisition() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté.');
      }

      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['displayName'] ?? 'Utilisateur Inconnu';
      final userRole = userDoc.data()?['role'] ?? 'Inconnu';

      final counterDocRef = FirebaseFirestore.instance
          .collection('counters')
          .doc('requisition_counter');

      final counterDoc = await counterDocRef.get();
      int nextId = 1;

      if (counterDoc.exists) {
        nextId = (counterDoc.data()?['currentId'] ?? 0) + 1;
      }
      await counterDocRef.set({'currentId': nextId}, SetOptions(merge: true));

      final String requisitionCode =
          'CM-${DateTime.now().year}-${nextId.toString().padLeft(4, '0')}';

      final itemsJson = _items.map((item) => item.toJson()).toList();

      final newRequisition = {
        'requisitionCode': requisitionCode,
        'requestedBy': userName,
        'requestedById': user.uid,
        'requestedByRole': userRole,
        'status': "En attente d'approbation",
        'createdAt': Timestamp.now(),
        'items': itemsJson,
        'activityLog': [
          {
            'action': 'Création',
            'user': userName,
            'timestamp': Timestamp.now(),
          }
        ],
      };

      await FirebaseFirestore.instance
          .collection('requisitions')
          .add(newRequisition);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande soumise avec succès.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Modifier la Demande' : 'Nouvelle Demande'),
      ),
      body: _isLoading && _isEditMode
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: _items.isEmpty
                    ? const Center(
                  child: Text('Veuillez ajouter des produits.'),
                )
                    : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ListTile(
                      // ✅ NEW: Added leading icon for editing
                      leading: const Icon(Icons.edit, color: Colors.blue),
                      title: Text(item.name),
                      subtitle: Text('Quantité: ${item.quantity}'),
                      // ✅ NEW: onTap to trigger the edit dialog
                      onTap: () {
                        _showEditItemQuantityDialog(index);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red),
                        onPressed: () => _removeItem(index),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un Produit'),
                onPressed: _showAddItemDialog,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 20),
                  side: BorderSide(color: Theme.of(context).primaryColor),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Icon(_isEditMode
                      ? Icons.save
                      : Icons.send),
                  label: Text(_isLoading
                      ? 'Chargement...'
                      : _isEditMode
                      ? 'Enregistrer les Modifications'
                      : 'Soumettre la Demande'),
                  onPressed: _isLoading ? null : _submitRequisition,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ... (The _AddItemDialog class remains exactly the same)
class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog();

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
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

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('mainCategory', isEqualTo: mainCategory)
          .get();
      final categoriesSet = <String>{};
      for (var doc in snapshot.docs) {
        final categoryValue = doc.data()?['categorie'];
        if (categoryValue != null && categoryValue is String) {
          categoriesSet.add(categoryValue);
        }
      }

      final sortedList = categoriesSet.toList();
      sortedList.sort();

      if (mounted) {
        setState(() {
          _subCategories = sortedList;
          _isLoadingSubCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSubCategories = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _fetchProductsForSubCategory(String category) async {
    setState(() {
      _isLoadingProducts = true;
      _products = [];
      _selectedProduct = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('categorie', isEqualTo: category)
          .orderBy('nom')
          .get();
      if (mounted) {
        setState(() {
          _products = snapshot.docs;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un Produit'),
      content: Form(
        key: _dialogFormKey,
        child: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedMainCategory,
                  items: _mainCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedMainCategory = val);
                      _fetchCategoriesForMainSection(val);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Section Principale',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedSubCategory,
                  items: _subCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: _selectedMainCategory == null || _isLoadingSubCategories
                      ? null
                      : (val) {
                    if (val != null) {
                      setState(() => _selectedSubCategory = val);
                      _fetchProductsForSubCategory(val);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<DocumentSnapshot>(
                  value: _selectedProduct,
                  items: _products
                      .map((p) => DropdownMenuItem(value: p, child: Text(p['nom'])))
                      .toList(),
                  onChanged: _selectedSubCategory == null || _isLoadingProducts
                      ? null
                      : (val) => setState(() => _selectedProduct = val),
                  decoration: const InputDecoration(
                    labelText: 'Produit',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantité',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    return (int.tryParse(v ?? '') ?? 0) <= 0
                        ? 'Quantité requise'
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_dialogFormKey.currentState!.validate()) {
              final quantity = int.tryParse(_quantityController.text) ?? 0;
              Navigator.of(context).pop(
                RequisitionItem(
                  productDoc: _selectedProduct!,
                  quantity: quantity,
                ),
              );
            }
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
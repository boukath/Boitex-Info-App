// lib/screens/administration/add_requisition_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ IMPORT GLOBAL SEARCH
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';

// Helper class to manage items in the requisition list
class RequisitionItem {
  final DocumentSnapshot productDoc;
  final int quantity;

  RequisitionItem({required this.productDoc, required this.quantity});

  String get name => productDoc['nom'];
  String get id => productDoc.id;

  Map<String, dynamic> toJson() {
    // Attempt to get image if available
    final data = productDoc.data() as Map<String, dynamic>?;
    String? imageUrl;
    if (data != null &&
        data.containsKey('imageUrls') &&
        (data['imageUrls'] is List) &&
        (data['imageUrls'] as List).isNotEmpty) {
      imageUrl = (data['imageUrls'] as List).first;
    }

    return {
      'productId': id,
      'productName': name,
      if (imageUrl != null) 'productImage': imageUrl,
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

  // ✅ NEW: Controllers for Title and Supplier
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();

  // ✅ NEW: List to store unique brands/suppliers fetched from products
  List<String> _knownSuppliers = [];

  final List<RequisitionItem> _items = [];
  bool _isLoading = false;
  late bool _isEditMode;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.requisitionId != null;

    // ✅ NEW: Fetch known suppliers (marques) for autocomplete
    _fetchKnownSuppliers();

    if (_isEditMode) {
      _loadExistingRequisition();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  // ✅ NEW: Logic to get unique "marque" values from "produits" collection
  Future<void> _fetchKnownSuppliers() async {
    try {
      // Note: In a real production app with thousands of products,
      // you should cache this list or use a dedicated 'suppliers' collection.
      final querySnapshot = await FirebaseFirestore.instance
          .collection('produits')
          .limit(500) // Limit to avoid reading too many docs
          .get();

      final Set<String> brands = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('marque') && data['marque'] != null) {
          final String brand = data['marque'].toString().trim();
          if (brand.isNotEmpty) {
            brands.add(brand);
          }
        }
      }

      if (mounted) {
        setState(() {
          _knownSuppliers = brands.toList()..sort();
        });
      }
    } catch (e) {
      debugPrint("Erreur lors du chargement des fournisseurs: $e");
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

      // ✅ NEW: Populate controllers from existing data
      _titleController.text = data['title'] ?? '';
      _supplierController.text = data['supplierName'] ?? '';

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

  void _openProductSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GlobalProductSearchPage(
          isSelectionMode: true,
          onProductSelected: (productMap) async {
            final String productId = productMap['productId'];
            final int quantity = productMap['quantity'] ?? 1;

            if (_items.any((item) => item.id == productId)) {
              return;
            }

            try {
              final doc = await FirebaseFirestore.instance
                  .collection('produits')
                  .doc(productId)
                  .get();

              if (doc.exists && mounted) {
                setState(() {
                  _items.add(RequisitionItem(
                    productDoc: doc,
                    quantity: quantity,
                  ));
                });
              }
            } catch (e) {
              debugPrint("Error fetching product details: $e");
            }
          },
        ),
      ),
    );
  }

  Future<void> _showEditItemQuantityDialog(int index) async {
    final item = _items[index];
    final quantityController =
    TextEditingController(text: item.quantity.toString());

    final newQuantity = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifier Quantité'),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Veuillez entrer une quantité valide.')),
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
    // ✅ NEW: Validate that title is entered
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un objet pour la demande.')),
      );
      return;
    }

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
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
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
        // ✅ NEW: Save new fields
        'title': _titleController.text.trim(),
        'supplierName': _supplierController.text.trim(),
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

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName = userDoc.data()?['displayName'] ?? 'Utilisateur Inconnu';
      final userRole = userDoc.data()?['role'] ?? 'Inconnu';

      // Use a Transaction to safely increment ID (Best Practice)
      final String requisitionCode = await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterDocRef = FirebaseFirestore.instance
            .collection('counters')
            .doc('requisition_counter');

        final counterSnapshot = await transaction.get(counterDocRef);
        int nextId = 1;
        if (counterSnapshot.exists) {
          nextId = (counterSnapshot.data()?['currentId'] ?? 0) + 1;
        }
        transaction.set(counterDocRef, {'currentId': nextId}, SetOptions(merge: true));
        return 'CM-${DateTime.now().year}-${nextId.toString().padLeft(4, '0')}';
      });

      final itemsJson = _items.map((item) => item.toJson()).toList();

      final newRequisition = {
        'requisitionCode': requisitionCode,
        // ✅ NEW: Save new fields
        'title': _titleController.text.trim(),
        'supplierName': _supplierController.text.trim(),
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
              // ✅ NEW: Header Card with Title and Supplier Inputs
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Objet de la demande (Requis)',
                          hintText: 'Ex: Renouvellement parc informatique',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 16),
                      // ✅ NEW: Autocomplete Field for Supplier using "marque" data
                      LayoutBuilder(
                          builder: (context, constraints) {
                            return Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text == '') {
                                  return const Iterable<String>.empty();
                                }
                                return _knownSuppliers.where((String option) {
                                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                });
                              },
                              onSelected: (String selection) {
                                _supplierController.text = selection;
                              },
                              // Sync text field with controller if user types something not in list
                              fieldViewBuilder: (context, fieldTextEditingController, fieldFocusNode, onFieldSubmitted) {
                                // Ensure our main controller stays in sync if we start edit mode
                                if (_supplierController.text.isNotEmpty && fieldTextEditingController.text.isEmpty) {
                                  fieldTextEditingController.text = _supplierController.text;
                                }

                                return TextFormField(
                                  controller: fieldTextEditingController,
                                  focusNode: fieldFocusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Fournisseur / Marque (Optionnel)',
                                    hintText: 'Ex: Dell, HP, Amazon...',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.store),
                                  ),
                                  onChanged: (val) => _supplierController.text = val,
                                );
                              },
                            );
                          }
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: _items.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun produit ajouté',
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Appuyez sur "Rechercher des Produits"\npour commencer.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Card(
                      margin:
                      const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: Text(
                            '${item.quantity}',
                            style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(item.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        subtitle: const Text(
                            'Appuyez pour modifier la quantité'),
                        onTap: () {
                          _showEditItemQuantityDialog(index);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _removeItem(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Rechercher / Ajouter des Produits'),
                  onPressed: _openProductSearch,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
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
                      : Icon(_isEditMode ? Icons.save : Icons.send),
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
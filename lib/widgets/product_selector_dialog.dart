// lib/widgets/product_selector_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/selection_models.dart';

// ✅ REFACTORED: This dialog now manages and returns a list of products.
class ProductSelectorDialog extends StatefulWidget {
  // ✅ CHANGED: Accepts the list of already selected products.
  final List<ProductSelection> initialProducts;

  const ProductSelectorDialog({super.key, required this.initialProducts});

  @override
  State<ProductSelectorDialog> createState() => _ProductSelectorDialogState();
}

class _ProductSelectorDialogState extends State<ProductSelectorDialog> {
  // State for the cascaded dropdowns
  final List<String> _mainCategories = ['Antivol', 'TPV', 'Compteur Client'];
  String? _selectedMainCategory;
  List<String> _categories = [];
  String? _selectedCategory;
  List<SelectableItem> _products = [];
  SelectableItem? _selectedProduct;

  final _quantityController = TextEditingController(text: '1');
  bool _isLoadingCategories = false;
  bool _isLoadingProducts = false;

  // ✅ NEW: Local list to manage products before confirming.
  late List<ProductSelection> _selectedProducts;

  @override
  void initState() {
    super.initState();
    // Initialize with products passed to the dialog
    _selectedProducts = List.from(widget.initialProducts);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategoriesForMainSection(String mainCategory) async {
    setState(() {
      _isLoadingCategories = true;
      _categories = [];
      _selectedCategory = null;
      _products = [];
      _selectedProduct = null;
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('produits')
        .where('mainCategory', isEqualTo: mainCategory)
        .get();

    final categoriesSet = <String>{};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('categorie')) {
        categoriesSet.add(data['categorie'] as String);
      }
    }

    final sortedList = categoriesSet.toList();
    sortedList.sort();

    if (mounted) {
      setState(() {
        _categories = sortedList;
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _fetchProducts(String category) async {
    setState(() {
      _isLoadingProducts = true;
      _products = [];
      _selectedProduct = null;
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('produits')
        .where('categorie', isEqualTo: category)
        .orderBy('nom')
        .get();

    if (mounted) {
      setState(() {
        _products = snapshot.docs
            .map((d) => SelectableItem(id: d.id, name: d['nom']))
            .toList();
        _isLoadingProducts = false;
      });
    }
  }

  // ✅ CHANGED: Adds a product to the local list inside the dialog.
  void _addProductToList() {
    final qty = int.tryParse(_quantityController.text);
    if (_selectedProduct != null && qty != null && qty > 0) {
      setState(() {
        // Check if product already exists and update quantity
        final index = _selectedProducts
            .indexWhere((p) => p.productId == _selectedProduct!.id);
        if (index != -1) {
          _selectedProducts[index] = ProductSelection(
            productId: _selectedProduct!.id,
            productName: _selectedProduct!.name,
            quantity: _selectedProducts[index].quantity + qty,
          );
        } else {
          _selectedProducts.add(ProductSelection(
            productId: _selectedProduct!.id,
            productName: _selectedProduct!.name,
            quantity: qty,
          ));
        }
        // Reset for next entry
        _selectedProduct = null;
        _quantityController.text = '1';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Veuillez sélectionner un produit et entrer une quantité valide.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter des produits'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Selection Form
              DropdownButtonFormField<String>(
                value: _selectedMainCategory,
                isExpanded: true,
                hint: const Text('Sélectionner une Section'),
                items: _mainCategories
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedMainCategory = value);
                    _fetchCategoriesForMainSection(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                isExpanded: true,
                hint: Text(_isLoadingCategories
                    ? 'Chargement...'
                    : 'Sélectionner une Catégorie'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged:
                _selectedMainCategory == null || _isLoadingCategories
                    ? null
                    : (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                    _fetchProducts(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<SelectableItem>(
                value: _selectedProduct,
                isExpanded: true,
                hint: Text(_isLoadingProducts
                    ? 'Chargement...'
                    : 'Sélectionner un Produit'),
                items: _products
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: _selectedCategory == null || _isLoadingProducts
                    ? null
                    : (value) => setState(() => _selectedProduct = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantité'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addProductToList,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter à la liste'),
                ),
              ),

              const Divider(height: 32),

              // Display for selected products
              const Text('Produits Sélectionnés',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _selectedProducts.isEmpty
                  ? const Text('Aucun produit ajouté.')
                  : Column(
                children: _selectedProducts
                    .map((p) => ListTile(
                  title: Text(p.productName),
                  trailing: Text('Qté: ${p.quantity}'),
                  dense: true,
                  leading: IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _selectedProducts.remove(p);
                      });
                    },
                  ),
                ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler')),
        // ✅ CHANGED: Returns the entire list of products.
        ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_selectedProducts),
            child: const Text('Confirmer')),
      ],
    );
  }
}
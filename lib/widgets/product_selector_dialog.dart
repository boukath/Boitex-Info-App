// lib/widgets/product_selector_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/selection_models.dart';

class ProductSelectorDialog extends StatefulWidget {
  final Function(ProductSelection) onProductSelected;
  const ProductSelectorDialog({super.key, required this.onProductSelected});

  @override
  State<ProductSelectorDialog> createState() => _ProductSelectorDialogState();
}

class _ProductSelectorDialogState extends State<ProductSelectorDialog> {
  // Hardcoded list of main sections
  final List<String> _mainCategories = ['Antivol', 'TPV', 'Compteur Client'];

  // State for the cascaded dropdowns
  String? _selectedMainCategory;
  List<String> _categories = [];
  String? _selectedCategory;
  List<SelectableItem> _products = [];
  SelectableItem? _selectedProduct;

  final _quantityController = TextEditingController(text: '1');
  bool _isLoadingCategories = false;
  bool _isLoadingProducts = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  // Fetches sub-categories based on the selected main section
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

  // Fetches products based on the selected sub-category
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

    if(mounted) {
      setState(() {
        _products = snapshot.docs.map((d) => SelectableItem(id: d.id, name: d['nom'])).toList();
        _isLoadingProducts = false;
      });
    }
  }

  void _addProduct() {
    final qty = int.tryParse(_quantityController.text);
    if (_selectedProduct != null && qty != null && qty > 0) {
      widget.onProductSelected(ProductSelection(
          productId: _selectedProduct!.id,
          productName: _selectedProduct!.name,
          quantity: qty
      ));
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez sélectionner un produit et entrer une quantité valide.'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un produit'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Main Section Dropdown
              DropdownButtonFormField<String>(
                value: _selectedMainCategory,
                isExpanded: true,
                hint: const Text('Sélectionner une Section'),
                items: _mainCategories.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedMainCategory = value);
                    _fetchCategoriesForMainSection(value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // 2. Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                isExpanded: true,
                hint: Text(_isLoadingCategories ? 'Chargement...' : 'Sélectionner une Catégorie'),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: _selectedMainCategory == null || _isLoadingCategories
                    ? null
                    : (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                    _fetchProducts(value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // 3. Product Dropdown
              DropdownButtonFormField<SelectableItem>(
                value: _selectedProduct,
                isExpanded: true,
                hint: Text(_isLoadingProducts ? 'Chargement...' : 'Sélectionner un Produit'),
                items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                onChanged: _selectedCategory == null || _isLoadingProducts
                    ? null
                    : (value) => setState(() => _selectedProduct = value),
              ),
              const SizedBox(height: 16),

              // Quantity Input
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantité'),
                validator: (value) {
                  if (value == null || value.isEmpty || int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Quantité invalide';
                  }
                  return null;
                },
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(onPressed: _addProduct, child: const Text('Ajouter')),
      ],
    );
  }
}
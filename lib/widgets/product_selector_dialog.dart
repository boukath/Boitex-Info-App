// lib/widgets/product_selector_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/screens/widgets/scanner_page.dart';

class ProductSelectorDialog extends StatefulWidget {
  final List<ProductSelection> initialProducts;

  const ProductSelectorDialog({super.key, required this.initialProducts});

  @override
  State<ProductSelectorDialog> createState() => _ProductSelectorDialogState();
}

class _ProductSelectorDialogState extends State<ProductSelectorDialog> {
  final List<String> _mainCategories = ['Antivol', 'TPV', 'Compteur Client'];
  String? _selectedMainCategory;
  List<String> _categories = [];
  String? _selectedCategory;
  List<SelectableItem> _products = [];
  SelectableItem? _selectedProduct;

  final _quantityController = TextEditingController(text: '1');
  bool _isLoadingCategories = false;
  bool _isLoadingProducts = false;

  late List<ProductSelection> _selectedProducts;

  @override
  void initState() {
    super.initState();
    _selectedProducts = List.from(widget.initialProducts);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _scanAndAddProduct() async {
    String? scannedCode;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerPage(
          onScan: (code) {
            scannedCode = code;
          },
        ),
      ),
    );

    if (scannedCode == null || scannedCode!.isEmpty) {
      return;
    }

    try {
      // ✅ FIXED: Corrected collection name
      final querySnapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('reference', isEqualTo: scannedCode!.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produit non trouvé.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final productDoc = querySnapshot.docs.first;
      final productData = productDoc.data() as Map<String, dynamic>;
      final productId = productDoc.id;

      final dynamic nomData = productData['nom'];
      final dynamic marqueData = productData['marque'];

      final String productName = (nomData is String) ? nomData : 'Donnée Invalide';
      final String marque = (marqueData is String) ? marqueData : 'Donnée Invalide';

      final existingProductIndex =
      _selectedProducts.indexWhere((p) => p.productId == productId);

      setState(() {
        if (existingProductIndex != -1) {
          _selectedProducts[existingProductIndex].quantity++;
        } else {
          _selectedProducts.add(ProductSelection(
            productId: productId,
            productName: productName,
            marque: marque,
            quantity: 1,
          ));
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _fetchCategories(String mainCategory) async {
    setState(() {
      _isLoadingCategories = true;
      _categories = [];
      _selectedCategory = null;
      _products = [];
      _selectedProduct = null;
    });
    try {
      // ✅ FIXED: Corrected collection name
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('mainCategory', isEqualTo: mainCategory)
          .get();
      final categories =
      snapshot.docs.map((doc) => doc['categorie'] as String).toSet().toList();
      categories.sort();
      if (mounted) setState(() => _categories = categories);
    } catch (e) {
      print('Error fetching categories: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  void _fetchProducts(String category) async {
    setState(() {
      _isLoadingProducts = true;
      _products = [];
      _selectedProduct = null;
    });
    try {
      // ✅ FIXED: Corrected collection name
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('categorie', isEqualTo: category)
          .get();
      final products = snapshot.docs
          .map((doc) => SelectableItem(id: doc.id, name: doc['nom'], data: {'marque': doc['marque']}))
          .toList();
      if (mounted) setState(() => _products = products);
    } catch (e) {
      print('Error fetching products: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _addProductToList() {
    if (_selectedProduct == null) return;
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    if (quantity <= 0) return;

    final existingProductIndex = _selectedProducts.indexWhere((p) => p.productId == _selectedProduct!.id);

    setState(() {
      if (existingProductIndex != -1) {
        _selectedProducts[existingProductIndex].quantity += quantity;
      } else {
        _selectedProducts.add(ProductSelection(
          productId: _selectedProduct!.id,
          productName: _selectedProduct!.name,
          marque: _selectedProduct!.data?['marque'] ?? '',
          quantity: quantity,
        ));
      }
    });

    _quantityController.text = '1';
    setState(() {
      _selectedProduct = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter des Produits'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _scanAndAddProduct,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scanner un Produit'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text("OU"),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedMainCategory,
                hint: const Text('Choisir le type de produit'),
                items: _mainCategories
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedMainCategory = value);
                    _fetchCategories(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              if (_selectedMainCategory != null)
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  hint: const Text('Choisir une Catégorie'),
                  items: _categories
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: _isLoadingCategories
                      ? null
                      : (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                      _fetchProducts(value);
                    }
                  },
                ),
              const SizedBox(height: 12),
              if (_selectedCategory != null)
                DropdownButtonFormField<SelectableItem>(
                  value: _selectedProduct,
                  hint: const Text('Choisir un Produit'),
                  items: _products
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                      .toList(),
                  onChanged: _isLoadingProducts
                      ? null
                      : (value) => setState(() => _selectedProduct = value),
                ),
              if (_selectedProduct != null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(labelText: 'Quantité'),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _selectedProduct != null ? _addProductToList : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter à la Liste'),
                ),
              ),

              const Divider(height: 32),

              const Text('Produits Sélectionnés',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _selectedProducts.isEmpty
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Aucun produit ajouté.'),
              )
                  : Column(
                children: _selectedProducts
                    .map((p) => ListTile(
                  title: Text(p.productName),
                  subtitle: Text('Marque: ${p.marque}'),
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
        ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_selectedProducts),
            child: const Text('Confirmer')),
      ],
    );
  }
}
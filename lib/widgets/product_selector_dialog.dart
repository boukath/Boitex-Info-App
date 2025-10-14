// lib/widgets/product_selector_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/screens/widgets/scanner_page.dart';
import 'package:boitex_info_app/widgets/serial_number_scanner_dialog.dart';

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

  void _showSerialNumberScanner(ProductSelection product) async {
    final List<String>? updatedSerialNumbers = await showDialog(
      context: context,
      builder: (context) => SerialNumberScannerDialog(productSelection: product),
    );

    if (updatedSerialNumbers != null) {
      setState(() {
        final productIndex = _selectedProducts.indexOf(product);
        if (productIndex != -1) {
          _selectedProducts[productIndex].serialNumbers = updatedSerialNumbers;
        }
      });
    }
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
      // ✅ FINAL FIX: Corrected collection name to 'produits'
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
      // ✅ FINAL FIX: Cast the data to the correct type
      final productData = productDoc.data() as Map<String, dynamic>;
      final productId = productDoc.id;

      final String productName = productData['nom'] as String? ?? 'Donnée Invalide';
      final String marque = productData['marque'] as String? ?? 'Donnée Invalide';
      final String partNumber = productData['reference'] as String? ?? 'N/A';

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
            partNumber: partNumber,
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
      // ✅ FINAL FIX: Corrected collection name
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
      // ✅ FINAL FIX: Corrected collection name
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('categorie', isEqualTo: category)
          .get();
      final products = snapshot.docs
          .map((doc) => SelectableItem(id: doc.id, name: doc['nom'], data: {'marque': doc['marque'], 'reference': doc['reference']}))
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
        final String partNumber = _selectedProduct!.data?['reference'] ?? 'N/A';
        _selectedProducts.add(ProductSelection(
          productId: _selectedProduct!.id,
          productName: _selectedProduct!.name,
          marque: _selectedProduct!.data?['marque'] ?? '',
          partNumber: partNumber,
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
                  label: const Text('Scanner un Produit (Par Réf.)'),
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
                  leading: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => setState(() => _selectedProducts.remove(p)),
                  ),
                  title: Text(p.productName),
                  subtitle: Text('Scannés: ${p.serialNumbers.length} / ${p.quantity}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Qté: ${p.quantity}'),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        onPressed: () => _showSerialNumberScanner(p),
                        tooltip: 'Scanner les N° de Série',
                      ),
                    ],
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
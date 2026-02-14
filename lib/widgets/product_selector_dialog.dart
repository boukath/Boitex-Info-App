// lib/widgets/product_selector_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/screens/widgets/batch_scanner_page.dart';
import 'package:boitex_info_app/widgets/serial_number_scanner_dialog.dart';

class ProductSelectorDialog extends StatefulWidget {
  final List<ProductSelection> initialProducts;

  // ✅ ADDED: Flag to toggle between "Request Mode" (Qty only) and "Stock Mode" (Scanning)
  final bool isRequestMode;

  const ProductSelectorDialog({
    super.key,
    required this.initialProducts,
    this.isRequestMode = false, // Defaults to false to keep old behavior
  });

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
    _selectedProducts = widget.initialProducts.map((p) => p.copy()).toList();
  }

  Future<void> _fetchCategories(String mainCategory) async {
    if (!mounted) return;
    setState(() {
      _isLoadingCategories = true;
      _categories = [];
      _selectedCategory = null;
      _products = [];
      _selectedProduct = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('mainCategory', isEqualTo: mainCategory)
          .get();

      // ✅ FINAL FIX IS HERE:
      // We explicitly cast the final list to <String> to satisfy the type checker.
      final categories = snapshot.docs
          .map((doc) => doc.data()['categorie'] as String?)
          .where((categorie) => categorie != null && categorie.isNotEmpty)
          .cast<String>() // This line solves the error
          .toSet()
          .toList();

      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      print('Error fetching categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des catégories: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _fetchProducts(String category) async {
    if (!mounted) return;
    setState(() {
      _isLoadingProducts = true;
      _products = [];
      _selectedProduct = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('mainCategory', isEqualTo: _selectedMainCategory)
          .where('categorie', isEqualTo: category)
          .get();

      final products = snapshot.docs
          .map((doc) => SelectableItem.fromFirestore(doc))
          .toList();

      if (mounted) {
        setState(() {
          _products = products;
        });
      }
    } catch (e) {
      print('Error fetching products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des produits: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  void _addProduct() {
    if (_selectedProduct == null || _selectedProduct!.partNumber == null) return;
    final int quantity = int.tryParse(_quantityController.text) ?? 1;

    setState(() {
      final existingProductIndex = _selectedProducts
          .indexWhere((p) => p.partNumber == _selectedProduct!.partNumber!);

      if (existingProductIndex != -1) {
        _selectedProducts[existingProductIndex].quantity += quantity;
      } else {
        _selectedProducts.add(ProductSelection(
          productId: _selectedProduct!.id,
          productName: _selectedProduct!.name,
          partNumber: _selectedProduct!.partNumber!,
          marque: _selectedProduct!.data?['marque'] ?? 'N/A',
          quantity: quantity,
          serialNumbers: [], // Empty for request mode or initial add
          // ✅ CRITICAL FIX: Extract flags from the selected item's data
          isConsumable: _selectedProduct!.data?['isConsumable'] == true,
          isSoftware: _selectedProduct!.data?['isSoftware'] == true,
        ));
      }
    });
  }

  void _showSerialNumberScanner(ProductSelection product) async {
    final List<String>? updatedSerials = await showDialog(
      context: context,
      builder: (_) => SerialNumberScannerDialog(productSelection: product),
    );

    if (updatedSerials != null) {
      setState(() {
        product.serialNumbers = updatedSerials;
      });
    }
  }

  void _openBatchScanner() async {
    final List<ProductSelection>? result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BatchScannerPage(initialProducts: _selectedProducts),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedProducts = result;
      });
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // ✅ 1. Title changes based on mode
      title: Text(widget.isRequestMode ? 'Créer une Demande' : 'Sélectionner des Produits'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedMainCategory,
                decoration: const InputDecoration(
                    labelText: 'Catégorie Principale', border: OutlineInputBorder()),
                items: _mainCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedMainCategory = value);
                  _fetchCategories(value);
                },
              ),
              const SizedBox(height: 16),
              if (_isLoadingCategories) const Center(child: CircularProgressIndicator()),
              if (!_isLoadingCategories && _selectedMainCategory != null)
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                      labelText: 'Catégorie',
                      border: const OutlineInputBorder(),
                      hintText: _categories.isEmpty ? 'Aucune catégorie trouvée' : 'Sélectionner'),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: _categories.isEmpty ? null : (value) {
                    if (value == null) return;
                    setState(() => _selectedCategory = value);
                    _fetchProducts(value);
                  },
                ),
              const SizedBox(height: 16),
              if (_isLoadingProducts) const Center(child: CircularProgressIndicator()),
              if (!_isLoadingProducts && _selectedCategory != null)
                DropdownButtonFormField<SelectableItem>(
                  value: _selectedProduct,
                  decoration: InputDecoration(
                      labelText: 'Produit',
                      border: const OutlineInputBorder(),
                      hintText: _products.isEmpty ? 'Aucun produit trouvé' : 'Sélectionner'),
                  items: _products
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                      .toList(),
                  onChanged: _products.isEmpty ? null : (value) {
                    setState(() => _selectedProduct = value);
                  },
                ),
              const SizedBox(height: 16),
              if (_selectedProduct != null)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                            labelText: 'Quantité', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addProduct,
                      child: const Text('Ajouter'),
                    ),
                  ],
                ),

              // ✅ 2. Hide Batch Scanner in Request Mode
              if (!widget.isRequestMode) ...[
                const Divider(height: 32),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scanner en Rafale'),
                    onPressed: _openBatchScanner,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              ],

              const Divider(height: 32),
              const Text('Produits Sélectionnés',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              _selectedProducts.isEmpty
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Aucun produit ajouté.'),
              )
                  : Column(
                children: _selectedProducts
                    .map((p) => Card(  // ✅ Changed from ListTile to Card for better layout
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        // Remove button
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => setState(() => _selectedProducts.remove(p)),
                        ),
                        // Product info - takes remaining space
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,  // ✅ Handle long names
                              ),
                              const SizedBox(height: 4),
                              // ✅ 3. Simplify text in Request Mode (Hide "Scanned X/Y")
                              Text(
                                widget.isRequestMode
                                    ? 'Quantité: ${p.quantity}'
                                    : 'Scannés: ${p.serialNumbers.length} / ${p.quantity}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.isRequestMode ? Colors.blue[800] : Colors.grey[600],
                                  fontWeight: widget.isRequestMode ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Quantity and scanner button
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Qté: ${p.quantity}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // ✅ 4. Hide Individual Scanner Button in Request Mode
                            if (!widget.isRequestMode)
                              IconButton(
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                                onPressed: () => _showSerialNumberScanner(p),
                                tooltip: 'Scanner les N° de Série',
                              ),
                          ],
                        ),
                      ],
                    ),
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
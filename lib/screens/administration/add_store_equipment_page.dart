// lib/screens/administration/add_store_equipment_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Import product selector dialog
import 'package:boitex_info_app/widgets/product_selector_dialog.dart';
// Import selection model used by the dialog
import 'package:boitex_info_app/models/selection_models.dart';
// Import the scanner page/dialog
import 'package:boitex_info_app/widgets/serial_number_scanner_dialog.dart';

class AddStoreEquipmentPage extends StatefulWidget {
  final String clientId;
  final String storeId;
  // Optional: For editing existing equipment
  final String? equipmentId;
  final Map<String, dynamic>? initialData;

  const AddStoreEquipmentPage({
    super.key,
    required this.clientId,
    required this.storeId,
    this.equipmentId,
    this.initialData,
  });

  @override
  State<AddStoreEquipmentPage> createState() => _AddStoreEquipmentPageState();
}

class _AddStoreEquipmentPageState extends State<AddStoreEquipmentPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late bool _isEditMode;

  // Form state variables
  ProductSelection? _selectedProduct;
  final _serialNumberController = TextEditingController();
  DateTime? _installationDate;

  // ✅ NEW: Variables to hold rich data fetched from DB
  String? _richCategory;
  String? _richReference;
  String? _richImage;
  String? _richMarque;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.equipmentId != null;
    // Default date to today if adding new
    _installationDate = DateTime.now();

    if (_isEditMode && widget.initialData != null) {
      _populateFormForEdit();
    }
  }

  void _populateFormForEdit() {
    final data = widget.initialData!;

    // Populate local rich variables from existing data
    _richCategory = data['categorie'] ?? data['category'];
    _richReference = data['reference'] ?? data['partNumber'];
    _richMarque = data['marque'];
    _richImage = data['image'];

    // Populate Product Data
    _selectedProduct = ProductSelection(
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? data['nom'] ?? 'Produit Inconnu',
      partNumber: _richReference ?? 'N/A',
      marque: _richMarque ?? 'N/A',
      quantity: 1,
      serialNumbers: List<String>.from(data['serialNumbers'] ?? []),
    );

    // Populate Serial
    _serialNumberController.text = data['serialNumber'] ?? data['serial'] ?? '';

    final Timestamp? timestamp = data['installDate'] ?? data['installationDate'];
    if (timestamp != null) {
      _installationDate = timestamp.toDate();
    }
  }

  @override
  void dispose() {
    _serialNumberController.dispose();
    super.dispose();
  }

  // ✅ NEW: Helper to fetch full details when a product is selected
  Future<void> _fetchFullProductDetails(String productId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('produits').doc(productId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _richMarque = data['marque']; // Ensure we get the canonical brand
          _richCategory = data['categorie'] ?? data['category']; // Get category
          _richReference = data['reference'] ?? data['partNumber']; // Get reference

          // Handle image
          if (data['imageUrls'] is List && (data['imageUrls'] as List).isNotEmpty) {
            _richImage = (data['imageUrls'] as List).first;
          } else {
            _richImage = data['image'];
          }

          // Update visual selection if needed (optional, but keeps UI in sync)
          if (_selectedProduct != null) {
            _selectedProduct = ProductSelection(
                productId: _selectedProduct!.productId,
                productName: data['nom'] ?? _selectedProduct!.productName,
                partNumber: _richReference ?? _selectedProduct!.partNumber,
                marque: _richMarque ?? _selectedProduct!.marque,
                quantity: 1,
                serialNumbers: []
            );
          }
        });
      }
    } catch (e) {
      print("Error fetching product details: $e");
    }
  }

  Future<void> _selectProduct() async {
    final List<ProductSelection>? result = await showDialog<List<ProductSelection>>(
      context: context,
      builder: (_) => ProductSelectorDialog(
        initialProducts: _selectedProduct != null ? [_selectedProduct!] : [],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final selected = result.first;
      setState(() {
        _selectedProduct = selected;
        // Reset rich variables until fetched
        _richCategory = null;
        _richImage = null;
        _richReference = selected.partNumber;
        _richMarque = selected.marque;
      });

      // ✅ Trigger fetch immediately
      await _fetchFullProductDetails(selected.productId);
    }
  }

  Future<void> _scanSerialNumber() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez d\'abord sélectionner un produit.'),
            backgroundColor: Colors.orange
        ),
      );
      return;
    }

    final String? scannedValue = await showDialog<String>(
      context: context,
      builder: (_) => SerialNumberScannerDialog(
        productSelection: _selectedProduct!.copyWith(quantity: 1),
      ),
    );

    if (scannedValue != null && scannedValue.isNotEmpty) {
      setState(() {
        _serialNumberController.text = scannedValue;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _installationDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && picked != _installationDate) {
      setState(() {
        _installationDate = picked;
      });
    }
  }

  Future<void> _saveEquipment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez sélectionner un produit'),
            backgroundColor: Colors.redAccent
        ),
      );
      return;
    }

    if (_installationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez choisir une date'),
            backgroundColor: Colors.redAccent
        ),
      );
      return;
    }

    setState(() { _isLoading = true; });

    // ✅ FIXED: Use the fetched rich data and correct keys
    final dataToSave = {
      'productId': _selectedProduct!.productId,
      'productName': _selectedProduct!.productName,
      'nom': _selectedProduct!.productName,
      // Save BOTH keys to be safe
      'partNumber': _richReference ?? _selectedProduct!.partNumber,
      'reference': _richReference ?? _selectedProduct!.partNumber,
      'marque': _richMarque ?? _selectedProduct!.marque,
      'categorie': _richCategory ?? 'N/A', // ✅ Saving Category now
      'category': _richCategory ?? 'N/A',  // ✅ Saving backup key
      'serialNumber': _serialNumberController.text.trim(),
      'serial': _serialNumberController.text.trim(),
      'installDate': Timestamp.fromDate(_installationDate!),
      'image': _richImage, // ✅ Saving Image URL
    };

    try {
      final collectionRef = FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('stores')
          .doc(widget.storeId)
          .collection('materiel_installe');

      if (_isEditMode) {
        await collectionRef.doc(widget.equipmentId!).update(dataToSave);
      } else {
        await collectionRef.add(dataToSave);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditMode ? 'Matériel mis à jour' : 'Matériel ajouté')),
        );
      }
    } catch (e) {
      print("Erreur sauvegarde matériel: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF667EEA);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_isEditMode ? 'Modifier Matériel' : 'Ajouter Matériel'),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Product Selection Card ---
              const Text(
                  'INFORMATION PRODUIT',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: InkWell(
                  onTap: _selectProduct,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        // ✅ Improved: Show fetched image if available
                        Container(
                          width: 50, height: 50,
                          padding: _richImage == null ? const EdgeInsets.all(12) : null,
                          decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              image: _richImage != null
                                  ? DecorationImage(image: NetworkImage(_richImage!), fit: BoxFit.cover)
                                  : null
                          ),
                          child: _richImage == null
                              ? Icon(Icons.inventory_2, color: primaryColor)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedProduct?.productName ?? 'Sélectionner un produit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedProduct != null ? Colors.black87 : Colors.grey,
                                ),
                              ),
                              if (_selectedProduct != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Réf: ${_richReference ?? _selectedProduct!.partNumber} • ${_richMarque ?? _selectedProduct!.marque}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                if (_richCategory != null)
                                  Text(
                                    'Catégorie: $_richCategory',
                                    style: TextStyle(fontSize: 12, color: primaryColor),
                                  ),
                              ]
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                  'DÉTAILS INSTALLATION',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _serialNumberController,
                decoration: InputDecoration(
                  labelText: 'Numéro de Série (S/N)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: primaryColor),
                    onPressed: _scanSerialNumber,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.grey),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Date d\'installation', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            _installationDate == null
                                ? 'Sélectionner une date'
                                : DateFormat('dd MMMM yyyy', 'fr_FR').format(_installationDate!),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEquipment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                    _isEditMode ? 'ENREGISTRER' : 'AJOUTER AU MAGASIN',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

// Helper extension
extension ProductSelectionCopy on ProductSelection {
  ProductSelection copyWith({int? quantity}) {
    return ProductSelection(
      productId: productId,
      productName: productName,
      partNumber: partNumber,
      marque: marque,
      quantity: quantity ?? this.quantity,
      serialNumbers: List.from(serialNumbers),
    );
  }
}
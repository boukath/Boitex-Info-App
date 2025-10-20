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
  ProductSelection? _selectedProduct; // Holds the chosen product
  String? _partNumber; // The reference number (also stored in _selectedProduct now)
  final _serialNumberController = TextEditingController();
  DateTime? _installationDate;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.equipmentId != null;

    if (_isEditMode && widget.initialData != null) {
      // Pre-fill form for editing
      _partNumber = widget.initialData!['partNumber']; // Get part number first
      _selectedProduct = ProductSelection(
        productId: widget.initialData!['productId'] ?? '',
        productName: widget.initialData!['productName'] ?? '',
        // ✅ CORRECTION 1: Provide the required partNumber
        partNumber: _partNumber ?? 'N/A', // Use fetched partNumber or fallback
        marque: widget.initialData!['marque'] ?? '', // Assuming 'marque' is saved too
        quantity: 1,
        serialNumbers: List<String>.from(widget.initialData!['serialNumbers'] ?? []),
      );
      _serialNumberController.text = widget.initialData!['serialNumber'] ?? '';
      final timestamp = widget.initialData!['installationDate'] as Timestamp?;
      _installationDate = timestamp?.toDate();
    }
  }

  @override
  void dispose() {
    _serialNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectProduct() async {
    final List<ProductSelection>? result = await showDialog<List<ProductSelection>>(
      context: context,
      builder: (_) => ProductSelectorDialog(
        initialProducts: _selectedProduct != null ? [_selectedProduct!] : [],
        // Assuming ProductSelectorDialog handles single selection logic
        // and returns a ProductSelection object including partNumber and marque
      ),
    );

    if (result != null && result.isNotEmpty) {
      final selected = result.first;
      setState(() {
        _selectedProduct = selected;
        // ✅ Update _partNumber from the selected product object
        _partNumber = selected.partNumber;
        // Optionally clear serial number when product changes
        // _serialNumberController.clear();
      });
      // No need to fetch again if the dialog returns the full ProductSelection object
    }
  }


  Future<void> _scanSerialNumber() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord sélectionner un produit.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final String? scannedValue = await showDialog<String>(
      context: context,
      builder: (_) => SerialNumberScannerDialog(
        // Pass a copy with quantity 1 for single scan
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
    if (_formKey.currentState!.validate()) {
      if (_selectedProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez sélectionner un produit'), backgroundColor: Colors.orange),
        );
        return;
      }
      if (_installationDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez sélectionner une date d\'installation'), backgroundColor: Colors.orange),
        );
        return;
      }

      setState(() { _isLoading = true; });

      final dataToSave = {
        'productId': _selectedProduct!.productId,
        'productName': _selectedProduct!.productName,
        // ✅ Use partNumber from the ProductSelection object
        'partNumber': _selectedProduct!.partNumber,
        'marque': _selectedProduct!.marque, // Also save marque
        'serialNumber': _serialNumberController.text.trim(),
        'installationDate': Timestamp.fromDate(_installationDate!),
        // Save the single serial number in an array for consistency?
        'serialNumbers': [_serialNumberController.text.trim()],
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
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.blueGrey;
    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Modifier Matériel' : 'Ajouter Matériel'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // --- Product Selection ---
              const Text('Produit Installé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.category_outlined, color: primaryColor),
                  title: Text(_selectedProduct?.productName ?? 'Sélectionner un produit'),
                  // ✅ Display partNumber from the ProductSelection object
                  subtitle: _selectedProduct?.partNumber != null ? Text('Réf: ${_selectedProduct!.partNumber}') : null,
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: _selectProduct,
                ),
              ),
              const SizedBox(height: 16),

              // --- Serial Number ---
              TextFormField(
                controller: _serialNumberController,
                decoration: inputDecoration.copyWith(
                  labelText: 'Numéro de Série',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'Scanner N° Série',
                    onPressed: _scanSerialNumber,
                  ),
                ),
                validator: (value) {
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- Installation Date ---
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: inputDecoration.copyWith(
                    labelText: "Date d'installation",
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        _installationDate == null
                            ? 'Sélectionner une date'
                            : DateFormat('dd MMMM yyyy', 'fr_FR').format(_installationDate!),
                      ),
                      const Icon(Icons.calendar_today, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // --- Save Button ---
              ElevatedButton.icon(
                icon: Icon(_isEditMode ? Icons.save : Icons.add_circle_outline),
                label: Text(_isEditMode ? 'Enregistrer Modifications' : 'Ajouter le Matériel'),
                onPressed: _isLoading ? null : _saveEquipment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (_isLoading) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper extension to easily create a copy with modified quantity
extension ProductSelectionCopy on ProductSelection {
  ProductSelection copyWith({int? quantity}) {
    // ✅ CORRECTION 2: Provide the required partNumber when copying
    return ProductSelection(
      productId: productId,
      productName: productName,
      partNumber: partNumber, // Include partNumber
      marque: marque,       // Include marque
      quantity: quantity ?? this.quantity,
      serialNumbers: List.from(serialNumbers),
    );
  }
}
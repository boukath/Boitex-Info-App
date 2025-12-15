// lib/screens/administration/add_store_equipment_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/widgets/serial_number_scanner_dialog.dart';

// Helper class: Manages each item in the list independently
class EquipmentBatchItem {
  final String id; // Unique ID for UI keys
  final ProductSelection product;
  final TextEditingController serialController;

  // Rich data (fetched from DB)
  String? richCategory;
  String? richReference;
  String? richImage;
  String? richMarque;

  EquipmentBatchItem({
    required this.id,
    required this.product,
    String? initialSerial,
  }) : serialController = TextEditingController(text: initialSerial);
}

class AddStoreEquipmentPage extends StatefulWidget {
  final String clientId;
  final String storeId;
  final String? equipmentId; // Optional: For editing single item
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
  bool _isLoading = false;
  late bool _isEditMode;

  final List<EquipmentBatchItem> _batchItems = [];
  DateTime? _installationDate;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.equipmentId != null;
    _installationDate = DateTime.now();

    if (_isEditMode && widget.initialData != null) {
      _populateFormForEdit();
    }
  }

  // Handle Edit Mode
  void _populateFormForEdit() {
    final data = widget.initialData!;
    final product = ProductSelection(
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? data['nom'] ?? 'Produit Inconnu',
      partNumber: data['reference'] ?? data['partNumber'] ?? 'N/A',
      marque: data['marque'] ?? 'N/A',
      quantity: 1,
      serialNumbers: [],
    );

    final item = EquipmentBatchItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      product: product,
      initialSerial: data['serialNumber'] ?? data['serial'],
    );

    // Pre-fill rich data
    item.richCategory = data['categorie'] ?? data['category'];
    item.richReference = data['reference'];
    item.richMarque = data['marque'];
    item.richImage = data['image'];

    setState(() {
      _batchItems.add(item);
      if (data['installDate'] != null) {
        _installationDate = (data['installDate'] as Timestamp).toDate();
      }
    });
  }

  @override
  void dispose() {
    for (var item in _batchItems) {
      item.serialController.dispose();
    }
    super.dispose();
  }

  Future<void> _enrichItem(EquipmentBatchItem item) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('produits').doc(item.product.productId).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          item.richMarque = data['marque'];
          item.richCategory = data['categorie'] ?? data['category'];
          item.richReference = data['reference'] ?? data['partNumber'];

          if (data['imageUrls'] is List && (data['imageUrls'] as List).isNotEmpty) {
            item.richImage = (data['imageUrls'] as List).first;
          } else {
            item.richImage = data['image'];
          }
        });
      }
    } catch (e) {
      print("Error fetching details: $e");
    }
  }

  // ✅ FIXED LOGIC: Loops through quantity to create distinct rows
  Future<void> _openProductSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GlobalProductSearchPage(
          isSelectionMode: true,
          onProductSelected: (productMap) {

            // 1. Get the quantity requested (e.g. 2)
            final int qty = productMap['quantity'] ?? 1;

            // 2. Loop to create 'qty' separate items
            for (int i = 0; i < qty; i++) {
              final newItem = EquipmentBatchItem(
                // Use a unique ID combination to avoid key collisions
                id: "${DateTime.now().microsecondsSinceEpoch}_$i",
                product: ProductSelection(
                  productId: productMap['productId'],
                  productName: productMap['productName'] ?? 'Produit Inconnu',
                  partNumber: productMap['partNumber'] ?? 'N/A',
                  marque: productMap['marque'] ?? 'N/A',
                  quantity: 1, // Reset to 1 because this row represents ONE physical unit
                  serialNumbers: [],
                ),
              );

              // 3. Add to list
              setState(() {
                _batchItems.add(newItem);
              });

              // 4. Fetch details
              _enrichItem(newItem);
            }

            // Note: We intentionally do NOT pop here so you can add more products.
          },
        ),
      ),
    );
  }

  Future<void> _scanSerialForItem(EquipmentBatchItem item) async {
    final String? scannedValue = await showDialog<String>(
      context: context,
      builder: (_) => SerialNumberScannerDialog(
        productSelection: item.product,
      ),
    );

    if (scannedValue != null && scannedValue.isNotEmpty) {
      setState(() {
        item.serialController.text = scannedValue;
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _batchItems.removeAt(index);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _installationDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {
        _installationDate = picked;
      });
    }
  }

  // ✅ SAVE ALL ITEMS
  Future<void> _saveBatch() async {
    if (_batchItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun produit ajouté'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_installationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une date'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final collectionRef = FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('stores')
          .doc(widget.storeId)
          .collection('materiel_installe');

      for (var item in _batchItems) {
        final data = {
          'productId': item.product.productId,
          'productName': item.product.productName,
          'nom': item.product.productName,
          'partNumber': item.richReference ?? item.product.partNumber,
          'reference': item.richReference ?? item.product.partNumber,
          'marque': item.richMarque ?? item.product.marque,
          'categorie': item.richCategory ?? 'N/A',
          'category': item.richCategory ?? 'N/A',
          'serialNumber': item.serialController.text.trim(),
          'serial': item.serialController.text.trim(),
          'installDate': Timestamp.fromDate(_installationDate!),
          'image': item.richImage,
        };

        if (_isEditMode && widget.equipmentId != null) {
          batch.update(collectionRef.doc(widget.equipmentId!), data);
        } else {
          batch.set(collectionRef.doc(), data);
        }
      }

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_batchItems.length} équipement(s) ajouté(s)')),
        );
      }
    } catch (e) {
      print("Error batch saving: $e");
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
        title: Text(_isEditMode ? 'Modifier' : 'Ajout Multiple'),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: "Ajouter Produit",
            onPressed: _openProductSearch,
          )
        ],
      ),
      body: Column(
        children: [
          // --- 1. Global Settings (Date) ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
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
                        const Text('Date d\'installation (pour tous)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          _installationDate == null
                              ? 'Sélectionner une date'
                              : DateFormat('dd MMMM yyyy', 'fr_FR').format(_installationDate!),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // --- 2. List of Added Products ---
          Expanded(
            child: _batchItems.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.playlist_add, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text("Appuyez sur + pour ajouter des produits", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openProductSearch,
                    icon: const Icon(Icons.search),
                    label: const Text("Ouvrir le Catalogue"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  )
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _batchItems.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _batchItems[index];
                return _buildItemCard(item, index, primaryColor);
              },
            ),
          ),

          // --- 3. Save Button ---
          if (_batchItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveBatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                    "ENREGISTRER ${_batchItems.length} ÉLÉMENTS",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemCard(EquipmentBatchItem item, int index, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Row 1: Product Info & Delete
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    image: item.richImage != null
                        ? DecorationImage(image: NetworkImage(item.richImage!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: item.richImage == null ? Icon(Icons.inventory_2, size: 20, color: color) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${item.richMarque ?? "N/A"} • ${item.richReference ?? "N/A"}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                  onPressed: () => _removeItem(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Serial Input
            TextFormField(
              controller: item.serialController,
              decoration: InputDecoration(
                labelText: 'Numéro de Série',
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  color: color,
                  onPressed: () => _scanSerialForItem(item),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
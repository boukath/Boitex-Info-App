import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/barcode_scanner_page.dart';

class AddProductPage extends StatefulWidget {
  // We now optionally accept a product document for editing
  final DocumentSnapshot? productDoc;

  const AddProductPage({super.key, this.productDoc});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _categorieController = TextEditingController();
  final _marqueController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();
  final _origineController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isLoading = false;

  // A helper to know if we are in "Edit Mode"
  bool get _isEditing => widget.productDoc != null;

  @override
  void initState() {
    super.initState();
    // If we are editing, pre-fill all the fields from the document data
    if (_isEditing) {
      final data = widget.productDoc!.data() as Map<String, dynamic>;
      _nomController.text = data['nom'] ?? '';
      _categorieController.text = data['categorie'] ?? '';
      _marqueController.text = data['marque'] ?? '';
      _referenceController.text = data['reference'] ?? '';
      _origineController.text = data['origine'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      // Join the tags array back into a comma-separated string for editing
      _tagsController.text = (data['tags'] as List<dynamic>? ?? []).join(', ');
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _categorieController.dispose();
    _marqueController.dispose();
    _descriptionController.dispose();
    _referenceController.dispose();
    _origineController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const BarcodeScannerPage()),
    );
    if (scannedCode != null && mounted) {
      setState(() {
        _referenceController.text = scannedCode;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      try {
        final tags = _tagsController.text.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();

        final productData = {
          'nom': _nomController.text.trim(),
          'categorie': _categorieController.text.trim(),
          'marque': _marqueController.text.trim(),
          'reference': _referenceController.text.trim(),
          'origine': _origineController.text.trim(),
          'description': _descriptionController.text.trim(),
          'tags': tags,
        };

        if (_isEditing) {
          // If editing, UPDATE the existing document
          await FirebaseFirestore.instance.collection('produits').doc(widget.productDoc!.id).update(productData);
        } else {
          // If adding, CREATE a new document
          productData['createdAt'] = Timestamp.now();
          await FirebaseFirestore.instance.collection('produits').add(productData);
        }

        if (mounted) {
          Navigator.of(context).pop(); // Go back to the previous screen
        }
      } catch (e) {
        print("Error saving product: $e");
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The title changes depending on the mode
        title: Text(_isEditing ? 'Modifier le Produit' : 'Ajouter un Produit'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(controller: _nomController, decoration: const InputDecoration(labelText: 'Nom du produit'), validator: (value) => value!.isEmpty ? 'Champ requis' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _categorieController, decoration: const InputDecoration(labelText: 'Catégorie'), validator: (value) => value!.isEmpty ? 'Champ requis' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _marqueController, decoration: const InputDecoration(labelText: 'Marque')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _referenceController,
              decoration: InputDecoration(
                labelText: 'Référence',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanBarcode,
                  tooltip: 'Scanner le code-barres',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _origineController, decoration: const InputDecoration(labelText: 'Produit origine')),
            const SizedBox(height: 12),
            TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            const SizedBox(height: 12),
            TextFormField(controller: _tagsController, decoration: const InputDecoration(labelText: 'Tags (séparés par une virgule)')),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProduct,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16.0)),
              // The button text also changes depending on the mode
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_isEditing ? 'Mettre à Jour le Produit' : 'Enregistrer le Produit'),
            ),
          ],
        ),
      ),
    );
  }
}
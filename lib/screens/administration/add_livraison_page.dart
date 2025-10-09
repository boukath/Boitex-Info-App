// lib/screens/administration/add_livraison_page.dart
// ✅ PERFECT: All string interpolation with SINGLE dollar signs
// ✅ Year-based BL codes: BL-1/2025, BL-2/2025...

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boitex_info_app/widgets/animated_truck_button.dart';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/widgets/product_selector_dialog.dart';

class AddLivraisonPage extends StatefulWidget {
  final String? serviceType;
  const AddLivraisonPage({super.key, this.serviceType});

  @override
  State<AddLivraisonPage> createState() => _AddLivraisonPageState();
}

class _AddLivraisonPageState extends State<AddLivraisonPage> {
  final _formKey = GlobalKey<FormState>();

  SelectableItem? _selectedClient;
  SelectableItem? _selectedStore;
  List<dynamic> _selectedProducts = [];
  String? _selectedServiceType;

  List<SelectableItem> _clients = [];
  List<SelectableItem> _stores = [];
  bool _isLoadingClients = true;
  bool _isLoadingStores = false;

  @override
  void initState() {
    super.initState();
    _selectedServiceType = widget.serviceType;
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    final snapshot = await FirebaseFirestore.instance.collection('clients').orderBy('name').get();
    if(mounted) setState(() {
      _clients = snapshot.docs.map((d) => SelectableItem(id: d.id, name: d['name'])).toList();
      _isLoadingClients = false;
    });
  }

  Future<void> _fetchStores(String clientId) async {
    setState(() { _isLoadingStores = true; _stores = []; _selectedStore = null; });
    final snapshot = await FirebaseFirestore.instance.collection('clients').doc(clientId).collection('stores').orderBy('name').get();
    if(mounted) setState(() {
      _stores = snapshot.docs.map((d) => SelectableItem(id: d.id, name: d['name'], subtitle: d['location'])).toList();
      _isLoadingStores = false;
    });
  }

  void _showProductSelectorDialog() {
    showDialog(
      context: context,
      builder: (context) => ProductSelectorDialog(
        onProductSelected: (product) {
          setState(() {
            if (!_selectedProducts.any((p) => p.productId == product.productId)) {
              _selectedProducts.add(product);
            }
          });
        },
      ),
    );
  }

  Future<void> _saveLivraison() async {
    if (!_formKey.currentState!.validate() || _selectedProducts.isEmpty) {
      throw Exception('Veuillez remplir tous les champs et ajouter au moins un produit.');
    }

    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final currentYear = DateTime.now().year;
      final counterRef = FirebaseFirestore.instance.collection('counters').doc('livraison_counter_$currentYear');
      final counterSnap = await transaction.get(counterRef);
      final currentCount = (counterSnap.data()?['count'] as int?) ?? 0;

      Map<String, DocumentSnapshot> productSnaps = {};
      for (var product in _selectedProducts) {
        final productRef = FirebaseFirestore.instance.collection('produits').doc(product.productId);
        productSnaps[product.productId] = await transaction.get(productRef);
      }

      for (var product in _selectedProducts) {
        final snap = productSnaps[product.productId]!;
        final currentStock = (snap.data() as Map?)?['quantiteEnStock'] ?? 0;
        if (currentStock < product.quantity) {
          throw Exception('Stock insuffisant pour ${product.productName} (disponible: $currentStock)');
        }

        transaction.update(snap.reference, {'quantiteEnStock': currentStock - product.quantity});

        final historyRef = snap.reference.collection('stock_history').doc();
        transaction.set(historyRef, {
          'change': -product.quantity,
          'newQuantity': currentStock - product.quantity,
          'notes': 'Livraison BL-${currentCount + 1}/$currentYear',
          'timestamp': FieldValue.serverTimestamp(),
          'updatedByUid': user?.uid,
        });
      }

      final newCount = currentCount + 1;
      final blCode = 'BL-$newCount/$currentYear';
      final livraisonRef = FirebaseFirestore.instance.collection('livraisons').doc();

      final String destinationName = _selectedStore != null
          ? '${_selectedStore!.name} - ${_selectedStore!.subtitle}'
          : _selectedClient!.name;

      transaction.set(livraisonRef, {
        'blCode': blCode,
        'serviceType': _selectedServiceType,
        'clientId': _selectedClient!.id,
        'clientName': _selectedClient!.name,
        'storeId': _selectedStore?.id,
        'destinationName': destinationName,
        'items': _selectedProducts.map((p) => {
          'productId': p.productId,
          'productName': p.productName,
          'quantity': p.quantity
        }).toList(),
        'status': 'À Préparer',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user?.displayName ?? 'N/A'
      });

      transaction.set(counterRef, {'count': newCount}, SetOptions(merge: true));
    });

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Colors.brown;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une Livraison'),
        backgroundColor: primaryColor,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1. Destination', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: primaryColor)),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _selectedServiceType,
                        decoration: const InputDecoration(labelText: 'Type de Service', border: OutlineInputBorder()),
                        items: ['Service Technique', 'Service IT'].map((String service) {
                          return DropdownMenuItem(value: service, child: Text(service));
                        }).toList(),
                        onChanged: widget.serviceType == null
                            ? (value) => setState(() { _selectedServiceType = value; })
                            : null,
                        validator: (v) => v == null ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<SelectableItem>(
                        value: _selectedClient,
                        decoration: InputDecoration(
                            labelText: 'Client',
                            border: const OutlineInputBorder(),
                            prefixIcon: _isLoadingClients ? const CircularProgressIndicator() : const Icon(Icons.person_outline)
                        ),
                        items: _clients.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedClient = value);
                            _fetchStores(value.id);
                          }
                        },
                        validator: (v) => v == null ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<SelectableItem>(
                        value: _selectedStore,
                        decoration: InputDecoration(
                            labelText: 'Magasin de Destination (Optionnel)',
                            border: const OutlineInputBorder(),
                            prefixIcon: _isLoadingStores ? const CircularProgressIndicator() : const Icon(Icons.store_outlined)
                        ),
                        items: _stores.map((s) => DropdownMenuItem(
                            value: s,
                            child: Text('${s.name} - ${s.subtitle}')
                        )).toList(),
                        onChanged: _selectedClient == null ? null : (value) => setState(() => _selectedStore = value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('2. Produits à Livrer', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: primaryColor)),
                      const SizedBox(height: 8),
                      if (_selectedProducts.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Aucun produit ajouté.'))),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _selectedProducts.length,
                        itemBuilder: (context, index) {
                          final product = _selectedProducts[index];
                          return ListTile(
                            leading: const Icon(Icons.inventory_2_outlined),
                            title: Text(product.productName),
                            trailing: Text('Qté: ${product.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            onLongPress: () { setState(() { _selectedProducts.removeAt(index); }); },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showProductSelectorDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter un Produit'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              AnimatedTruckButton(
                onPressed: _saveLivraison,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

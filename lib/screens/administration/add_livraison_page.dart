// lib/screens/administration/add_livraison_page.dart

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
  State createState() => _AddLivraisonPageState();
}

class _AddLivraisonPageState extends State<AddLivraisonPage> {
  final _formKey = GlobalKey<FormState>();
  String _deliveryMethod = 'Livraison Interne';
  SelectableItem? _selectedClient;
  SelectableItem? _selectedStore;
  List<ProductSelection> _selectedProducts = [];
  String? _selectedServiceType;
  SelectableItem? _selectedTechnician;
  final _externalCarrierNameController = TextEditingController();
  final _trackingNumberController = TextEditingController();

  List<SelectableItem> _clients = [];
  List<SelectableItem> _stores = [];
  List<SelectableItem> _technicians = [];
  bool _isLoadingClients = true;
  bool _isLoadingStores = false;
  bool _isLoadingTechnicians = true;
  String? _clientError;

  @override
  void initState() {
    super.initState();
    _selectedServiceType = widget.serviceType;
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _fetchClients();
        _fetchTechnicians();
      }
    });
  }

  @override
  void dispose() {
    _externalCarrierNameController.dispose();
    _trackingNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchClients() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (mounted) setState(() => _clientError = "Erreur: Utilisateur non connecté.");
      return;
    }
    setState(() => _isLoadingClients = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('clients').get();
      final clients = snapshot.docs
          .map((doc) => SelectableItem(id: doc.id, name: doc['name'] as String))
          .toList();
      clients.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() => _clients = clients);
    } catch (e) {
      if (mounted) setState(() => _clientError = "Erreur: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoadingClients = false);
    }
  }

  Future<void> _fetchStores(String clientId) async {
    setState(() {
      _isLoadingStores = true;
      _selectedStore = null;
      _stores = [];
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .get();
      final stores = snapshot.docs.map((doc) {
        final data = doc.data();
        final location = data.containsKey('location') ? data['location'] : '';
        return SelectableItem(
          id: doc.id,
          name: data['name'] as String,
          data: {'location': location},
        );
      }).toList();
      if (mounted) setState(() => _stores = stores);
    } catch (e) {
      print('Error fetching stores: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStores = false);
    }
  }

  Future<void> _fetchTechnicians() async {
    setState(() => _isLoadingTechnicians = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final technicians = snapshot.docs
          .map((doc) =>
          SelectableItem(id: doc.id, name: doc['displayName'] as String? ?? doc.id))
          .toList();
      if (mounted) setState(() => _technicians = technicians);
    } catch (e) {
      print('Error fetching technicians: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTechnicians = false);
    }
  }

  Future<String> _getNextBonLivraisonCode() async {
    final year = DateTime.now().year;
    final counterRef = FirebaseFirestore.instance.collection('counters').doc('livraison_counter_$year');

    final nextNumber = await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      if (!snapshot.exists) {
        transaction.set(counterRef, {'count': 1});
        return 1;
      } else {
        final lastNumber = (snapshot.data()?['count'] ?? 0) as int;
        final newNumber = lastNumber + 1;
        transaction.set(counterRef, {'count': newNumber});
        return newNumber;
      }
    });
    return 'BL-$nextNumber/$year';
  }

  void _showProductSelectorDialog() async {
    final List<ProductSelection>? result = await showDialog(
        context: context,
        builder: (context) => ProductSelectorDialog(initialProducts: _selectedProducts));
    if (result != null) {
      setState(() => _selectedProducts = result);
    }
  }

  Future<void> _saveLivraison() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez ajouter au moins un produit.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final bonLivraisonCode = await _getNextBonLivraisonCode();

    final deliveryData = {
      'bonLivraisonCode': bonLivraisonCode,
      'clientId': _selectedClient!.id,
      'clientName': _selectedClient!.name,
      'storeId': _selectedStore?.id,
      'storeName': _selectedStore?.name,
      'deliveryAddress': _selectedStore?.data?['location'] ?? 'N/A',
      'contactPerson': '',
      'contactPhone': '',
      'products': _selectedProducts.map((p) => p.toJson()).toList(),
      'status': 'À Préparer',
      'createdBy': user.displayName ?? user.email,
      'createdById': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'deliveryMethod': _deliveryMethod,
      if (_deliveryMethod == 'Livraison Interne') 'technicianId': _selectedTechnician?.id,
      if (_deliveryMethod == 'Livraison Interne') 'technicianName': _selectedTechnician?.name,
      if (_deliveryMethod == 'Livraison Externe') 'externalCarrierName': _externalCarrierNameController.text,
      if (_deliveryMethod == 'Livraison Externe') 'trackingNumber': _trackingNumberController.text,
    };

    try {
      final batch = FirebaseFirestore.instance.batch();
      final livraisonsCollection = FirebaseFirestore.instance.collection('livraisons');

      List<String> servicesToCreate = [];
      if (_selectedServiceType == 'Service Technique' || _selectedServiceType == 'Service IT') {
        servicesToCreate.add(_selectedServiceType!);
      } else if (_selectedServiceType == 'Les Deux') {
        servicesToCreate.add('Service Technique');
        servicesToCreate.add('Service IT');
      }

      for (final service in servicesToCreate) {
        final docRef = livraisonsCollection.doc();
        batch.set(docRef, {...deliveryData, 'serviceType': service});
      }

      if (servicesToCreate.isEmpty) { // Handle case where no service type is selected but form is submitted
        final docRef = livraisonsCollection.doc();
        batch.set(docRef, deliveryData);
      }

      await batch.commit();
      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur lors de la création de la livraison: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une Livraison'),
        backgroundColor: Colors.blue[900],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.serviceType == null) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedServiceType,
                    decoration: const InputDecoration(
                      labelText: 'Choisir le Service',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business_center),
                    ),
                    items: ['Service Technique', 'Service IT', 'Les Deux']
                        .map((label) => DropdownMenuItem(
                      value: label,
                      child: Text(label),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedServiceType = value;
                        _technicians = [];
                        _selectedTechnician = null;
                      });
                      _fetchTechnicians();
                    },
                    validator: (value) => value == null ? 'Veuillez sélectionner un service' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                DropdownButtonFormField<String>(
                  value: _deliveryMethod,
                  decoration: const InputDecoration(
                    labelText: 'Méthode de livraison',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_shipping),
                  ),
                  items: ['Livraison Interne', 'Livraison Externe']
                      .map((label) => DropdownMenuItem(
                    value: label,
                    child: Text(label),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _deliveryMethod = value!;
                      if (_deliveryMethod != 'Livraison Interne') {
                        _selectedTechnician = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                if (_deliveryMethod == 'Livraison Interne')
                  DropdownButtonFormField<SelectableItem>(
                    value: _selectedTechnician,
                    decoration: const InputDecoration(
                      labelText: 'Assigner à un Technicien',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: _technicians
                        .map((tech) => DropdownMenuItem(
                      value: tech,
                      child: Text(tech.name),
                    ))
                        .toList(),
                    onChanged: _isLoadingTechnicians
                        ? null
                        : (value) => setState(() => _selectedTechnician = value),
                    validator: (value) =>
                    value == null ? 'Veuillez sélectionner un technicien' : null,
                  )
                else ...[
                  TextFormField(
                    controller: _externalCarrierNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du transporteur',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Veuillez entrer le nom du transporteur'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _trackingNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Numéro de suivi (Optionnel)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code_scanner),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                DropdownButtonFormField<SelectableItem>(
                  value: _selectedClient,
                  hint: !_isLoadingClients && _clients.isEmpty ? const Text('Aucun client trouvé') : null,
                  decoration: InputDecoration(
                    labelText: 'Client',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.business_center),
                    errorText: _clientError,
                    suffixIcon: _isLoadingClients
                        ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    )
                        : null,
                  ),
                  items: _clients
                      .map((client) => DropdownMenuItem(
                    value: client,
                    child: Text(client.name),
                  ))
                      .toList(),
                  onChanged: _isLoadingClients || _clients.isEmpty
                      ? null
                      : (value) {
                    setState(() {
                      _selectedClient = value;
                      _selectedStore = null;
                      _stores = [];
                    });
                    if (value != null) {
                      _fetchStores(value.id);
                    }
                  },
                  validator: (value) =>
                  value == null ? 'Veuillez sélectionner un client' : null,
                ),
                const SizedBox(height: 16),

                if (_selectedClient != null)
                  DropdownButtonFormField<SelectableItem>(
                    value: _selectedStore,
                    hint: !_isLoadingStores && _stores.isEmpty ? const Text('Aucun magasin trouvé') : null,
                    decoration: InputDecoration(
                      labelText: 'Magasin / Destination',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.store),
                      suffixIcon: _isLoadingStores
                          ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child:
                          CircularProgressIndicator(strokeWidth: 3),
                        ),
                      )
                          : null,
                    ),
                    items: _stores
                        .map((store) => DropdownMenuItem(
                      value: store,
                      child: Text(
                          '${store.name} - ${store.data?['location'] ?? ''}'),
                    ))
                        .toList(),
                    onChanged: _isLoadingStores || _stores.isEmpty
                        ? null
                        : (value) => setState(() => _selectedStore = value),
                  ),
                const SizedBox(height: 24),

                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Produits à Livrer',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _selectedProducts.isEmpty
                            ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Aucun produit ajouté.'),
                          ),
                        )
                            : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _selectedProducts.length,
                          itemBuilder: (context, index) {
                            final product = _selectedProducts[index];
                            return ListTile(
                              leading:
                              const Icon(Icons.inventory_2_outlined),
                              title: Text(product.productName),
                              trailing: Text('Qté: ${product.quantity}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showProductSelectorDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter/Modifier Produits'),
                            style: ButtonStyle(
                              padding: MaterialStateProperty.all(
                                const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
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
      ),
    );
  }
}
// lib/screens/administration/add_livraison_page.dart

import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/widgets/animated_truck_button.dart';
import 'package:boitex_info_app/widgets/product_selector_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddLivraisonPage extends StatefulWidget {
  final String? serviceType;
  final String? livraisonId; // Used for editing an existing livraison

  const AddLivraisonPage({super.key, this.serviceType, this.livraisonId});

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
  bool _isLoadingPage = false; // For loading data in edit mode
  String? _clientError;

  /// A getter to determine if the page is in edit mode.
  bool get _isEditMode => widget.livraisonId != null;

  @override
  void initState() {
    super.initState();
    _selectedServiceType = widget.serviceType;

    // If a livraisonId is provided, load the existing data for editing.
    if (_isEditMode) {
      _loadLivraisonData();
    }

    // Fetch dropdown data.
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

  /// Fetches existing livraison data from Firestore and populates the form fields.
  Future<void> _loadLivraisonData() async {
    setState(() => _isLoadingPage = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('livraisons')
          .doc(widget.livraisonId!)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Erreur: Livraison non trouvée.'),
            backgroundColor: Colors.red,
          ));
          Navigator.pop(context);
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      // Populate form fields with the fetched data.
      _selectedServiceType = data['serviceType'];
      _deliveryMethod = data['deliveryMethod'] ?? 'Livraison Interne';
      _externalCarrierNameController.text = data['externalCarrierName'] ?? '';
      _trackingNumberController.text = data['trackingNumber'] ?? '';

      // Set the selected client and then fetch its stores.
      if (data['clientId'] != null && data['clientName'] != null) {
        _selectedClient =
            SelectableItem(id: data['clientId'], name: data['clientName']);
        await _fetchStores(data['clientId']); // Wait for stores to be fetched
      }

      // Now set the selected store, ensuring it exists in the fetched list.
      if (data['storeId'] != null) {
        final storeExists =
        _stores.any((store) => store.id == data['storeId']);
        if (storeExists) {
          _selectedStore =
              _stores.firstWhere((store) => store.id == data['storeId']);
        }
      }

      // Set the selected technician.
      if (data['technicianId'] != null && data['technicianName'] != null) {
        _selectedTechnician =
            SelectableItem(id: data['technicianId'], name: data['technicianName']);
      }

      // Populate the list of selected products.
      if (data['products'] is List) {
        _selectedProducts = (data['products'] as List)
            .map((p) => ProductSelection.fromJson(p))
            .toList();
      }

      setState(() {}); // Trigger a rebuild with the populated data.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur de chargement: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoadingPage = false);
    }
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

  /// Saves the livraison data to Firestore.
  /// Handles both creating a new livraison and updating an existing one.
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

    // Construct the data map for Firestore.
    final deliveryData = {
      'clientId': _selectedClient!.id,
      'clientName': _selectedClient!.name,
      'storeId': _selectedStore?.id,
      'storeName': _selectedStore?.name,
      'deliveryAddress': _selectedStore?.data?['location'] ?? 'N/A',
      'contactPerson': '', // You can add fields for these if needed
      'contactPhone': '', // You can add fields for these if needed
      'products': _selectedProducts.map((p) => p.toJson()).toList(),
      'status': 'À Préparer',
      'deliveryMethod': _deliveryMethod,
      'technicianId': _deliveryMethod == 'Livraison Interne' ? _selectedTechnician?.id : null,
      'technicianName': _deliveryMethod == 'Livraison Interne' ? _selectedTechnician?.name : null,
      'externalCarrierName': _deliveryMethod == 'Livraison Externe' ? _externalCarrierNameController.text : null,
      'trackingNumber': _deliveryMethod == 'Livraison Externe' ? _trackingNumberController.text : null,
      'serviceType': _selectedServiceType,
      'lastModifiedBy': user.displayName ?? user.email,
      'lastModifiedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_isEditMode) {
        // If editing, update the existing document.
        await FirebaseFirestore.instance
            .collection('livraisons')
            .doc(widget.livraisonId!)
            .update(deliveryData);
      } else {
        // If creating, add new fields and create the document.
        final bonLivraisonCode = await _getNextBonLivraisonCode();
        final createData = {
          ...deliveryData,
          'bonLivraisonCode': bonLivraisonCode,
          'createdBy': user.displayName ?? user.email,
          'createdById': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        };

        // Your existing batch logic for creating single or dual service types
        final batch = FirebaseFirestore.instance.batch();
        final livraisonsCollection = FirebaseFirestore.instance.collection('livraisons');
        final docRef = livraisonsCollection.doc();
        batch.set(docRef, createData);
        await batch.commit();
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de la sauvegarde: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while fetching data in edit mode.
    if (_isLoadingPage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chargement de la Livraison...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Modifier la Livraison' : 'Créer une Livraison'),
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
                    validator: (value) =>
                    value == null ? 'Veuillez sélectionner un service' : null,
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
                    validator: (value) => value == null
                        ? 'Veuillez sélectionner un technicien'
                        : null,
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
                  hint: !_isLoadingClients && _clients.isEmpty
                      ? const Text('Aucun client trouvé')
                      : null,
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
                    hint: !_isLoadingStores && _stores.isEmpty
                        ? const Text('Aucun magasin trouvé')
                        : null,
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
                          child: CircularProgressIndicator(strokeWidth: 3),
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
                              leading: const Icon(
                                  Icons.inventory_2_outlined),
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
                  title: _isEditMode ? 'Enregistrer les Modifications' : 'Créer le Bon de Livraison',
                  completedTitle: _isEditMode ? 'Modifications Enregistrées !' : 'Bon Créé !',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
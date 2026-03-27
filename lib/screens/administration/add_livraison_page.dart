// lib/screens/administration/add_livraison_page.dart

import 'dart:typed_data';
import 'package:boitex_info_app/models/selection_models.dart';
// ✅ ADDED: Import the global search page
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:developer'; // for debugPrint

// ✅ ADDED: Multi Select Package
import 'package:multi_select_flutter/multi_select_flutter.dart';

// ✅ ADDED: Import the PDF Service
import 'package:boitex_info_app/services/livraison_pdf_service.dart';

class AddLivraisonPage extends StatefulWidget {
  final String? serviceType;
  final String? livraisonId;

  const AddLivraisonPage({super.key, this.serviceType, this.livraisonId});

  @override
  State<AddLivraisonPage> createState() => _AddLivraisonPageState();
}

class _AddLivraisonPageState extends State<AddLivraisonPage> {
  final _formKey = GlobalKey<FormState>();
  String _deliveryMethod = 'Livraison Interne';
  SelectableItem? _selectedClient;
  SelectableItem? _selectedStore;
  List<ProductSelection> _selectedProducts = [];
  String? _selectedServiceType;

  List<SelectableItem> _selectedTechnicians = [];

  // ✅ ADDED: Controller for Internal Delivery Address (When Store is null or manual)
  final _internalDeliveryAddressController = TextEditingController();

  final _externalCarrierNameController = TextEditingController();

  // ✅ ADDED: New controllers for External Delivery
  final _externalClientNameController = TextEditingController();
  final _externalClientPhoneController = TextEditingController();
  final _externalClientAddressController = TextEditingController();
  final _codAmountController = TextEditingController();

  List<SelectableItem> _clients = [];
  List<SelectableItem> _stores = [];
  List<SelectableItem> _technicians = [];

  bool _isLoadingClients = true;
  bool _isLoadingStores = false;
  bool _isLoadingTechnicians = true;
  bool _isLoadingPage = false;
  String? _clientError;

  bool _isUploading = false;
  // ✅ 1. ADDED: Loading status text
  String _loadingStatus = '';

  // ✅ ADDED: Variable to store the existing status to prevent reset
  String _currentStatus = 'À Préparer';

  bool get _isEditMode => widget.livraisonId != null;

  @override
  void initState() {
    super.initState();
    _selectedServiceType = widget.serviceType;
    if (_isEditMode) {
      _loadLivraisonData();
    }
    _fetchClients();
    _fetchTechnicians();
  }

  @override
  void dispose() {
    _internalDeliveryAddressController.dispose();
    _externalCarrierNameController.dispose();
    _externalClientNameController.dispose();
    _externalClientPhoneController.dispose();
    _externalClientAddressController.dispose();
    _codAmountController.dispose();
    super.dispose();
  }

  // --- DATA FETCHING & LOGIC ---
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

      // ✅ LOAD STATUS: Preserve the current status (e.g. "En route")
      _currentStatus = data['status'] ?? 'À Préparer';

      _selectedServiceType = data['serviceType'];
      _deliveryMethod = data['deliveryMethod'] ?? 'Livraison Interne';

      // ✅ Load Internal Address
      _internalDeliveryAddressController.text = data['deliveryAddress'] ?? '';

      _externalCarrierNameController.text = data['externalCarrierName'] ?? '';
      _externalClientNameController.text = data['externalClientName'] ?? '';
      _externalClientPhoneController.text = data['externalClientPhone'] ?? '';
      _externalClientAddressController.text =
          data['externalClientAddress'] ?? '';
      _codAmountController.text = data['codAmount']?.toString() ?? '';

      if (data['clientId'] != null && data['clientName'] != null) {
        _selectedClient =
            SelectableItem(id: data['clientId'], name: data['clientName']);
        await _fetchStores(data['clientId']);
      }

      if (data['storeId'] != null) {
        final storeExists = _stores.any((store) => store.id == data['storeId']);
        if (storeExists) {
          _selectedStore =
              _stores.firstWhere((store) => store.id == data['storeId']);
        }
      }

      if (data['technicians'] != null && data['technicians'] is List) {
        final techList = data['technicians'] as List;
        _selectedTechnicians = techList
            .map((t) => SelectableItem(id: t['id'], name: t['name']))
            .toList();
      } else if (data['technicianId'] != null &&
          data['technicianName'] != null) {
        _selectedTechnicians = [
          SelectableItem(id: data['technicianId'], name: data['technicianName'])
        ];
      }

      if (data['products'] is List) {
        _selectedProducts = (data['products'] as List)
            .map((p) => ProductSelection.fromJson(p as Map<String, dynamic>))
            .toList();
      }

      setState(() {});
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
    if (FirebaseAuth.instance.currentUser == null) return;
    setState(() => _isLoadingClients = true);
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('clients').get();
      final clients = snapshot.docs
          .map((doc) => SelectableItem(id: doc.id, name: doc['name'] as String))
          .toList();
      clients.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
      final snapshot =
      await FirebaseFirestore.instance.collection('users').get();
      final technicians = snapshot.docs
          .map((doc) => SelectableItem(
          id: doc.id, name: doc['displayName'] as String? ?? doc.id))
          .toList();
      if (mounted) setState(() => _technicians = technicians);
    } catch (e) {
      print('Error fetching technicians: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTechnicians = false);
    }
  }

  // ✅ --- ADD CLIENT / STORE LOGIC ---

  Future<void> _addNewClient() async {
    final TextEditingController nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau Client'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nom du client',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                try {
                  final ref = await FirebaseFirestore.instance
                      .collection('clients')
                      .add({
                    'name': name,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  final newItem = SelectableItem(id: ref.id, name: name);
                  setState(() {
                    _clients.add(newItem);
                    _clients.sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                    _selectedClient = newItem; // Auto-select
                    _selectedStore = null;
                    _stores = [];
                    // Reset address
                    _internalDeliveryAddressController.clear();
                  });
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewStore() async {
    if (_selectedClient == null) return;
    final TextEditingController nameController = TextEditingController();
    final TextEditingController addressController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau Magasin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du magasin',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Adresse / Localisation',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final address = addressController.text.trim();
              if (name.isNotEmpty) {
                try {
                  final ref = await FirebaseFirestore.instance
                      .collection('clients')
                      .doc(_selectedClient!.id)
                      .collection('stores')
                      .add({
                    'name': name,
                    'location': address,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  final newItem = SelectableItem(
                      id: ref.id, name: name, data: {'location': address});
                  setState(() {
                    _stores.add(newItem);
                    _selectedStore = newItem; // Auto-select
                    _internalDeliveryAddressController.text =
                        address; // Auto-fill
                  });
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  // ✅ --- SEARCHABLE DIALOG LOGIC ---

  void _openSearchDialog({
    required String title,
    required List<SelectableItem> items,
    required Function(SelectableItem) onSelected,
    required VoidCallback onAddPressed,
    required String addButtonLabel,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setStateSB) {
            final filteredItems = items.where((item) {
              final nameLower = item.name.toLowerCase();
              final queryLower = searchQuery.toLowerCase();
              return nameLower.contains(queryLower);
            }).toList();

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Rechercher...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setStateSB(() => searchQuery = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredItems.length +
                            1, // +1 for the Add button at bottom
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          if (index == filteredItems.length) {
                            return ListTile(
                              leading: const Icon(Icons.add_circle,
                                  color: Colors.blue),
                              title: Text(addButtonLabel,
                                  style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold)),
                              onTap: () {
                                Navigator.pop(
                                    context); // Close search dialog first
                                onAddPressed();
                              },
                            );
                          }
                          final item = filteredItems[index];
                          final subtitle = item.data != null &&
                              item.data!.containsKey('location')
                              ? item.data!['location']
                              : null;
                          return ListTile(
                            title: Text(item.name),
                            subtitle: subtitle != null ? Text(subtitle) : null,
                            onTap: () {
                              onSelected(item);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("Fermer"),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ NEW: Opens the global search in selection mode
  Future<void> _openQuickSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GlobalProductSearchPage(
          isSelectionMode: true,
          // ✅ PASS THE CALLBACK HERE
          onProductSelected: (Map<String, dynamic> result) {
            // This runs every time you click "Ajouter" in the search page
            setState(() {
              _selectedProducts.add(ProductSelection(
                productId: result['productId'],
                productName: result['productName'],
                quantity: result['quantity'] ?? 1,
                partNumber: result['partNumber'] ?? result['reference'],
                marque: result['marque'] ?? 'N/A',
                serialNumbers: [],
                // ✅ CAPTURE THE FLAGS FROM DB
                isConsumable: result['isConsumable'] == true,
                isSoftware: result['isSoftware'] == true,
              ));
            });
          },
        ),
      ),
    );
  }

  Future<String> _getNextBonLivraisonCode() async {
    final year = DateTime.now().year;
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('livraison_counter_$year');

    final nextNumber =
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      if (!snapshot.exists) {
        transaction.set(counterRef, {'count': 1});
        return 1;
      } else {
        final data = snapshot.data();
        final count = data?['count'];
        final lastNumber = (count is num) ? count.toInt() : 0;
        final newNumber = lastNumber + 1;
        transaction.set(counterRef, {'count': newNumber});
        return newNumber;
      }
    });
    return 'BL-$nextNumber/$year';
  }

  // ✅ OPTIMIZED: "Fire and Forget" Save
  // The Cloud Function will detect this create and generate the PDF automatically.
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

    setState(() {
      _isUploading = true;
      _loadingStatus = 'Sauvegarde en cours...';
    });

    try {
      final livraisonsCollection =
      FirebaseFirestore.instance.collection('livraisons');
      final docRef = _isEditMode
          ? livraisonsCollection.doc(widget.livraisonId!)
          : livraisonsCollection.doc();

      // --- FIX: Logic to handle "Shared Access" (Both Services) ---
      List<String> accessGroups = [];
      if (_selectedServiceType == 'Les Deux') {
        accessGroups = ['Service Technique', 'Service IT'];
      } else if (_selectedServiceType != null) {
        accessGroups = [_selectedServiceType!];
      }

      // ✅ LOGIC: Determine Status
      // If we are editing, we KEEP the current status (e.g., 'En route', 'En Cours de Livraison').
      // Unless it was 'Terminée', in which case maybe we want to reopen it, but for now let's prioritize NOT resetting it.
      String statusToSave = _isEditMode ? _currentStatus : 'À Préparer';

      // --- 2. Prepare Base Data ---
      final deliveryData = <String, dynamic>{
        'clientId': _selectedClient!.id,
        'clientName': _selectedClient!.name,
        'storeId': _selectedStore?.id,
        'storeName': _selectedStore?.name,
        // ✅ CHANGED: Use the text controller instead of just the store data
        // This allows manual overrides (Client Office) even if no store is selected.
        'deliveryAddress': _internalDeliveryAddressController.text.isNotEmpty
            ? _internalDeliveryAddressController.text
            : (_selectedStore?.data?['location'] ?? 'Siège Client / N/A'),
        'contactPerson': '',
        'contactPhone': '',
        'products': _selectedProducts.map((p) => p.toJson()).toList(),

        // ✅ FIXED: Uses calculated status instead of hardcoded 'À Préparer'
        'status': statusToSave,

        'deliveryMethod': _deliveryMethod,

        // Internal Delivery
        'technicians': _deliveryMethod == 'Livraison Interne'
            ? _selectedTechnicians
            .map((t) => {'id': t.id, 'name': t.name})
            .toList()
            : [],
        'technicianId': _deliveryMethod == 'Livraison Interne' &&
            _selectedTechnicians.isNotEmpty
            ? _selectedTechnicians.first.id
            : null,
        'technicianName': _deliveryMethod == 'Livraison Interne'
            ? _selectedTechnicians.map((t) => t.name).join(', ')
            : null,

        // External Delivery
        'externalCarrierName': _deliveryMethod == 'Livraison Externe'
            ? _externalCarrierNameController.text
            : null,
        'externalClientName': _deliveryMethod == 'Livraison Externe'
            ? _externalClientNameController.text
            : null,
        'externalClientPhone': _deliveryMethod == 'Livraison Externe'
            ? _externalClientPhoneController.text
            : null,
        'externalClientAddress': _deliveryMethod == 'Livraison Externe'
            ? _externalClientAddressController.text
            : null,
        'codAmount': _deliveryMethod == 'Livraison Externe'
            ? double.tryParse(_codAmountController.text)
            : null,

        'serviceType': _selectedServiceType,
        // ✅ NEW: accessGroups ensures it appears in both lists when queried via arrayContains
        'accessGroups': accessGroups,

        'lastModifiedBy': user.displayName ?? user.email,
        'lastModifiedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditMode) {
        // Edit Mode: Just update, PDF might not need regeneration unless critical fields changed.
        // If you want to force regen on edit, set pdfStatus: 'pending' here too.
        await docRef.update(deliveryData);
      } else {
        // --- FAST PATH FOR CREATION ---
        // A. Generate ID
        final bonLivraisonCode = await _getNextBonLivraisonCode();

        // B. Save to Firestore immediately
        final createData = {
          ...deliveryData,
          'bonLivraisonCode': bonLivraisonCode,
          'createdBy': user.displayName ?? user.email,
          'createdById': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          // REMOVED: pdfStatus and latestPdfUrl since we do on-demand generation now
        };

        await docRef.set(createData);
      }

      // C. Close Screen immediately
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Livraison sauvegardée avec succès !'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de la sauvegarde: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // --- WIDGETS ---

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          _isEditMode ? 'Modifier la Livraison' : 'Créer une Livraison',
          style: textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
      ),
      body: _isLoadingPage
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionCard(
                  title: 'Informations Livraison',
                  icon: Icons.info_outline,
                  children: [
                    if (widget.serviceType == null) ...[
                      _buildDropdownField(
                        label: 'Choisir le Service',
                        value: _selectedServiceType,
                        items: [
                          'Service Technique',
                          'Service IT',
                          'Les Deux'
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedServiceType = value;
                            _technicians = [];
                            _selectedTechnicians = [];
                          });
                          _fetchTechnicians();
                        },
                        icon: Icons.business_center,
                        validator: (value) => value == null
                            ? 'Veuillez sélectionner un service'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildDropdownField(
                      label: 'Méthode de livraison',
                      value: _deliveryMethod,
                      items: ['Livraison Interne', 'Livraison Externe'],
                      onChanged: (value) {
                        setState(() {
                          _deliveryMethod = value!;
                          if (_deliveryMethod != 'Livraison Interne') {
                            _selectedTechnicians = [];
                          }
                        });
                      },
                      icon: Icons.local_shipping,
                    ),
                    const SizedBox(height: 16),
                    if (_deliveryMethod == 'Livraison Interne')
                      MultiSelectDialogField(
                        items: _technicians
                            .map((e) => MultiSelectItem(e, e.name))
                            .toList(),
                        listType: MultiSelectListType.CHIP,
                        onConfirm: (values) {
                          setState(() {
                            _selectedTechnicians =
                                values.cast<SelectableItem>();
                          });
                        },
                        initialValue: _selectedTechnicians,
                        buttonText: Text(
                          _selectedTechnicians.isEmpty
                              ? "Assigner des Techniciens"
                              : "Techniciens assignés (${_selectedTechnicians.length})",
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                        title: const Text("Techniciens"),
                        selectedColor: Colors.blue,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.transparent),
                        ),
                        buttonIcon: Icon(Icons.person_outline,
                            color: Colors.grey[600]),
                        validator: (values) =>
                        (values == null || values.isEmpty)
                            ? "Veuillez sélectionner au moins un technicien"
                            : null,
                      )
                    else ...[
                      _buildTextField(
                        controller: _externalCarrierNameController,
                        label: 'Nom du transporteur',
                        icon: Icons.business,
                        validator: (value) =>
                        value == null || value.isEmpty
                            ? 'Veuillez entrer le nom du transporteur'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _externalClientNameController,
                        label: 'Nom du Client (Destinataire)',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _externalClientPhoneController,
                        label: 'Numéro de Téléphone',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _externalClientAddressController,
                        label: 'Adresse de Livraison',
                        icon: Icons.location_on,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _codAmountController,
                        label: 'Montant à Encaisser (DZD)',
                        icon: Icons.monetization_on,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ],
                  ]),
              const SizedBox(height: 24),
              _buildSectionCard(
                  title: 'Destination',
                  icon: Icons.location_on_outlined,
                  children: [
                    _buildSearchableDropdown(
                      label: 'Client',
                      value: _selectedClient,
                      icon: Icons.business_center,
                      onClear: () {
                        setState(() {
                          _selectedClient = null;
                          _selectedStore = null;
                          _stores = [];
                          _internalDeliveryAddressController.clear();
                        });
                      },
                      onTap: () => _openSearchDialog(
                        title: 'Rechercher un Client',
                        items: _clients,
                        onSelected: (item) {
                          setState(() {
                            _selectedClient = item;
                            _selectedStore = null;
                            _stores = [];
                            _internalDeliveryAddressController.clear();
                          });
                          _fetchStores(item.id);
                        },
                        onAddPressed: _addNewClient,
                        addButtonLabel: '+ Nouveau Client',
                      ),
                      validator: (val) => val == null
                          ? 'Veuillez sélectionner un client'
                          : null,
                    ),
                    if (_selectedClient != null) ...[
                      const SizedBox(height: 16),
                      _buildSearchableDropdown(
                        label:
                        'Magasin / Destination (Optionnel)', // ✅ UI hint
                        value: _selectedStore,
                        icon: Icons.store,
                        onClear: () {
                          setState(() {
                            _selectedStore = null;
                            _internalDeliveryAddressController.clear();
                          });
                        },
                        onTap: () => _openSearchDialog(
                          title: 'Rechercher un Magasin',
                          items: _stores,
                          onSelected: (item) => setState(() {
                            _selectedStore = item;
                            // ✅ Auto-fill address if store selected
                            if (item.data != null &&
                                item.data!.containsKey('location')) {
                              _internalDeliveryAddressController.text =
                              item.data!['location'];
                            }
                          }),
                          onAddPressed: _addNewStore,
                          addButtonLabel: '+ Nouveau Magasin',
                        ),
                        // ✅ REMOVED VALIDATOR: Store is now optional
                        validator: null,
                      ),

                      // ✅ ADDED: Address field for Internal Delivery
                      if (_deliveryMethod == 'Livraison Interne') ...[
                        const SizedBox(height: 16),
                        _buildTextField(
                            controller:
                            _internalDeliveryAddressController,
                            label: 'Adresse / Lieu de Livraison',
                            icon: Icons.place,
                            validator: (val) {
                              return null;
                            }),
                      ],
                    ]
                  ]),
              const SizedBox(height: 24),
              _buildSectionCard(
                  title: 'Produits à Livrer',
                  icon: Icons.inventory_2_outlined,
                  children: [
                    if (_selectedProducts.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Aucun produit ajouté.'),
                        ),
                      )
                    else
                      ..._selectedProducts
                          .asMap()
                          .entries
                          .map((entry) =>
                          _buildProductItem(entry.value, entry.key))
                          .toList(),
                    const SizedBox(height: 16),
                    // ✅ MODIFIED: Removed Catalogue button, expanded Quick Search
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openQuickSearch,
                        icon: const Icon(Icons.search),
                        label: const Text('Ajouter un produit (Recherche)'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.blue, width: 1.5),
                          foregroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ]),
              const SizedBox(height: 40),
              // ✅ 3. MODIFIED: build method with status text
              if (_isUploading)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _loadingStatus,
                        style: GoogleFonts.poppins(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              else
                _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductItem(ProductSelection item, int index) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${item.productName} (Qté: ${item.quantity})',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: const Color(0xFF0D47A1),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                setState(() {
                  _selectedProducts.removeAt(index);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title,
        required IconData icon,
        required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue[800], size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    required IconData icon,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem(
        value: item,
        child: Text(item.toString(),
            style: GoogleFonts.poppins(fontSize: 16)),
      ))
          .toList(),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ✅ UPDATED: Supports Clear Button
  Widget _buildSearchableDropdown({
    required String label,
    required SelectableItem? value,
    required IconData icon,
    required VoidCallback onTap,
    // ✅ ADDED: Optional callback to clear the selection
    VoidCallback? onClear,
    String? Function(SelectableItem?)? validator,
  }) {
    String text = '';
    if (value != null) {
      text = value.name;
      if (value.data != null &&
          value.data!.containsKey('location') &&
          value.data!['location'].toString().isNotEmpty) {
        text += ' - ${value.data!['location']}';
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        // Prevents keyboard from opening
        child: TextFormField(
          controller: TextEditingController(text: text),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: Colors.grey[600]),
            // ✅ CHANGED: Show clear button if value exists and callback provided
            suffixIcon: (value != null && onClear != null)
                ? IconButton(
              icon: const Icon(Icons.clear, color: Colors.red),
              onPressed: onClear,
            )
                : const Icon(Icons.arrow_drop_down),
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (val) => validator != null ? validator(value) : null,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ]),
      child: ElevatedButton.icon(
        onPressed: _saveLivraison,
        icon: Icon(_isEditMode ? Icons.save_alt_rounded : Icons.send_rounded,
            color: Colors.white),
        label: Text(
          _isEditMode
              ? 'Enregistrer les Modifications'
              : 'Créer le Bon de Livraison',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
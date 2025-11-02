// lib/screens/service_technique/add_intervention_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Simple data model for a Client
class Client {
  final String id;
  final String name;
  Client({required this.id, required this.name});
  @override
  bool operator ==(Object other) => other is Client && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

// Simple data model for a Store
class Store {
  final String id;
  final String name;
  final String location;
  Store({required this.id, required this.name, required this.location});
  @override
  bool operator ==(Object other) => other is Store && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class AddInterventionPage extends StatefulWidget {
  final String serviceType;
  const AddInterventionPage({super.key, required this.serviceType});

  @override
  State<AddInterventionPage> createState() => _AddInterventionPageState();
}

class _AddInterventionPageState extends State<AddInterventionPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Existing Controllers
  final _clientPhoneController = TextEditingController();
  final _requestController = TextEditingController();

  // ✅ ADDED: Search Controllers for Autocomplete
  final _clientSearchController = TextEditingController();
  final _storeSearchController = TextEditingController();

  bool _isLoading = false;

  // Existing State
  String? _selectedInterventionType;
  String? _selectedInterventionPriority;
  Client? _selectedClient;
  Store? _selectedStore;

  // ✅ ADDED: Data and Loading States
  List<Client> _clients = [];
  List<Store> _stores = [];
  bool _isLoadingClients = true;
  bool _isLoadingStores = false;

  final List<Color> gradientColors = [
    const Color(0xFF6A1B9A), // Deep Purple
    const Color(0xFF8E24AA), // Purple
  ];

  @override
  void initState() {
    super.initState();
    // ✅ ADDED: Start fetching client data immediately
    _fetchClients();
  }

  @override
  void dispose() {
    _clientPhoneController.dispose();
    _requestController.dispose();
    // ✅ ADDED: Dispose search controllers
    _clientSearchController.dispose();
    _storeSearchController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------
  // ✅ ADDED: Data Fetching Logic (Copied/Adapted from AddProjectPage)
  // -----------------------------------------------------------------

  Future<void> _fetchClients() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('clients').orderBy('name').get();
      final clients = snapshot.docs.map((doc) {
        return Client(id: doc.id, name: doc.data()['name']);
      }).toList();

      if (mounted) {
        setState(() {
          _clients = clients;
          _isLoadingClients = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingClients = false);
      }
    }
  }

  Future<void> _fetchStores(String clientId) async {
    setState(() {
      _isLoadingStores = true;
      _stores = [];
      _selectedStore = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .orderBy('name')
          .get();

      final stores = snapshot.docs.map((doc) {
        final data = doc.data();
        return Store(id: doc.id, name: data['name'], location: data['location']);
      }).toList();

      if (mounted) {
        setState(() {
          _stores = stores;
          _isLoadingStores = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStores = false);
      }
    }
  }

  // -----------------------------------------------------------------
  // ✅ ADDED: Quick-Add Dialogs (Copied/Adapted from AddProjectPage)
  // -----------------------------------------------------------------

  Future<void> _showAddClientDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Client>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un Nouveau Client'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du Client *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone (Optionnel)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  // Save to Firestore
                  final docRef = await FirebaseFirestore.instance.collection('clients').add({
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'createdAt': Timestamp.now(),
                    'createdVia': 'intervention_quick_add', // Custom source tag
                  });

                  final newClient = Client(
                    id: docRef.id,
                    name: nameController.text.trim(),
                  );

                  Navigator.pop(context, newClient);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _clients.add(result);
        _selectedClient = result;
        _clientSearchController.text = result.name;
      });
      _fetchStores(result.id);
    }
  }

  Future<void> _showAddStoreDialog() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord sélectionner un client')),
      );
      return;
    }

    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Store>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un Nouveau Magasin'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du Magasin *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Emplacement *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty ? 'Requis' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  // Save to Firestore under client's stores subcollection
                  final docRef = await FirebaseFirestore.instance
                      .collection('clients')
                      .doc(_selectedClient!.id)
                      .collection('stores')
                      .add({
                    'name': nameController.text.trim(),
                    'location': locationController.text.trim(),
                    'createdAt': Timestamp.now(),
                    'createdVia': 'intervention_quick_add', // Custom source tag
                  });

                  final newStore = Store(
                    id: docRef.id,
                    name: nameController.text.trim(),
                    location: locationController.text.trim(),
                  );

                  Navigator.pop(context, newStore);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _stores.add(result);
        _selectedStore = result;
        _storeSearchController.text = '${result.name} - ${result.location}';
      });
    }
  }

  // -----------------------------------------------------------------
  // ✅ ADDED: Save Intervention function (Reconstructed based on app pattern)
  // -----------------------------------------------------------------

  Future<void> _saveIntervention() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final creatorName = userDoc.data()?['displayName'] ?? 'Utilisateur inconnu';

        final interventionRef = FirebaseFirestore.instance.collection('interventions');
        // Simple code generation for placeholder
        final interventionCode = 'INT-${DateFormat('yyMMdd').format(DateTime.now())}-${interventionRef.doc().id.substring(0, 4).toUpperCase()}';

        await interventionRef.add({
          'interventionCode': interventionCode,
          'serviceType': widget.serviceType,
          'clientId': _selectedClient!.id,
          'clientName': _selectedClient!.name,
          'clientPhone': _clientPhoneController.text.trim(),
          'storeId': _selectedStore!.id,
          'storeName': '${_selectedStore!.name} - ${_selectedStore!.location}',
          'requestDescription': _requestController.text.trim(),
          'interventionType': _selectedInterventionType,
          'priority': _selectedInterventionPriority,
          'status': 'Nouvelle Demande',
          'createdAt': Timestamp.now(),
          'createdByUid': user.uid,
          'createdByName': creatorName,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Intervention créée avec succès!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final Color primaryColor = gradientColors.first;

    // Default border definitions (adapted for dark background)
    final OutlineInputBorder focusedBorder = OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.white, width: 2.0),
      borderRadius: BorderRadius.circular(12.0),
    );
    final OutlineInputBorder defaultBorder = OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.white30),
      borderRadius: BorderRadius.circular(12.0),
    );

    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -----------------------------------------------------------
          // ✅ NEW: Client Autocomplete with Add Button
          // -----------------------------------------------------------
          Row(
            children: [
              Expanded(
                child: _isLoadingClients
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : Autocomplete<Client>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _clients;
                    }
                    return _clients.where((client) =>
                        client.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  displayStringForOption: (client) => client.name,
                  onSelected: (client) {
                    setState(() => _selectedClient = client);
                    _fetchStores(client.id);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    _clientSearchController.text = controller.text;
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nom du Client *',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: defaultBorder,
                        focusedBorder: focusedBorder,
                        floatingLabelStyle: const TextStyle(color: Colors.white),
                        suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      ),
                      validator: (value) =>
                      _selectedClient == null ? 'Veuillez sélectionner un client' : null,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _showAddClientDialog,
                icon: const Icon(Icons.add),
                tooltip: 'Ajouter un nouveau client',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // -----------------------------------------------------------
          // ✅ NEW: Store Autocomplete with Add Button
          // -----------------------------------------------------------
          Row(
            children: [
              Expanded(
                child: _isLoadingStores
                    ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                )
                    : Autocomplete<Store>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _stores;
                    }
                    return _stores.where((store) =>
                    store.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                        store.location.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  displayStringForOption: (store) => '${store.name} - ${store.location}',
                  onSelected: (store) {
                    setState(() => _selectedStore = store);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    _storeSearchController.text = controller.text;
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: _selectedClient != null,
                      style: TextStyle(color: _selectedClient != null ? Colors.white : Colors.white70),
                      decoration: InputDecoration(
                        labelText: 'Magasin *',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: defaultBorder,
                        focusedBorder: focusedBorder,
                        floatingLabelStyle: const TextStyle(color: Colors.white),
                        suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      ),
                      validator: (value) =>
                      _selectedStore == null ? 'Veuillez sélectionner un magasin' : null,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _selectedClient == null ? null : _showAddStoreDialog,
                icon: const Icon(Icons.add),
                tooltip: 'Ajouter un nouveau magasin',
                style: IconButton.styleFrom(
                  backgroundColor: _selectedClient == null ? Colors.grey.shade400 : Colors.white,
                  foregroundColor: primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // -----------------------------------------------------------
          // Existing Dropdowns for Type and Priority
          // -----------------------------------------------------------
          DropdownButtonFormField<String>(
            value: _selectedInterventionType,
            dropdownColor: primaryColor.withOpacity(0.9),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Type d\'Intervention *',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: defaultBorder,
              focusedBorder: focusedBorder,
              floatingLabelStyle: const TextStyle(color: Colors.white),
            ),
            items: ['Maintenance', 'Installation', 'Mise à Jour', 'Autre']
                .map((String value) => DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: const TextStyle(color: Colors.white)),
            ))
                .toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedInterventionType = newValue;
              });
            },
            validator: (value) => value == null ? 'Veuillez choisir un type' : null,
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedInterventionPriority,
            dropdownColor: primaryColor.withOpacity(0.9),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Priorité *',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: defaultBorder,
              focusedBorder: focusedBorder,
              floatingLabelStyle: const TextStyle(color: Colors.white),
            ),
            items: ['Haute', 'Moyenne', 'Basse']
                .map((String value) => DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: const TextStyle(color: Colors.white)),
            ))
                .toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedInterventionPriority = newValue;
              });
            },
            validator: (value) => value == null ? 'Veuillez choisir une priorité' : null,
          ),

          const SizedBox(height: 16),

          // -----------------------------------------------------------
          // Phone Number Field
          // -----------------------------------------------------------
          TextFormField(
            controller: _clientPhoneController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Numéro de Téléphone (Contact) *',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: defaultBorder,
              focusedBorder: focusedBorder,
              floatingLabelStyle: const TextStyle(color: Colors.white),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) =>
            value == null || value.isEmpty ? 'Veuillez entrer un numéro' : null,
          ),

          const SizedBox(height: 16),

          // -----------------------------------------------------------
          // Description Field
          // -----------------------------------------------------------
          TextFormField(
            controller: _requestController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Description de la Demande *',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: defaultBorder,
              focusedBorder: focusedBorder,
              floatingLabelStyle: const TextStyle(color: Colors.white),
            ),
            validator: (value) =>
            value == null || value.isEmpty ? 'Veuillez décrire la demande' : null,
          ),

          const SizedBox(height: 24),

          // -----------------------------------------------------------
          // Submit Button
          // -----------------------------------------------------------
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveIntervention, // Updated to use _saveIntervention
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: primaryColor) // ✅ FIX: Removed 'const'
                  : const Text('Créer Intervention'),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Nouvelle Intervention'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (ctx, constraints) {
            final maxWidth = kIsWeb ? 600.0 : constraints.maxWidth;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: formContent,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
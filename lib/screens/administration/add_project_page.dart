// lib/screens/administration/add_project_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Reusable data models for dropdowns
class Client {
  final String id;
  final String name;
  Client({required this.id, required this.name});
  @override
  bool operator ==(Object other) => other is Client && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

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

class AddProjectPage extends StatefulWidget {
  const AddProjectPage({super.key});

  @override
  State<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _requestController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  bool _isLoading = false;

  String? _selectedServiceType;
  List<Client> _clients = [];
  Client? _selectedClient;
  List<Store> _stores = [];
  Store? _selectedStore;
  bool _isLoadingClients = true;
  bool _isLoadingStores = false;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  @override
  void dispose() {
    _requestController.dispose();
    _clientPhoneController.dispose();
    super.dispose();
  }

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
        setState(() { _isLoadingClients = false; });
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
          .collection('clients').doc(clientId).collection('stores').orderBy('name').get();
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
        setState(() { _isLoadingStores = false; });
      }
    }
  }

  Future<void> _saveProject() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() { _isLoading = false; });
        return;
      }

      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final creatorName = userDoc.data()?['displayName'] ?? 'Utilisateur inconnu';

        await FirebaseFirestore.instance.collection('projects').add({
          'serviceType': _selectedServiceType,
          'clientId': _selectedClient!.id,
          'clientName': _selectedClient!.name,
          'clientPhone': _clientPhoneController.text.trim(),
          'storeId': _selectedStore!.id,
          'storeName': '${_selectedStore!.name} - ${_selectedStore!.location}',
          'initialRequest': _requestController.text.trim(),
          'status': 'Nouvelle Demande',
          'createdAt': Timestamp.now(),
          'createdByUid': user.uid,
          'createdByName': creatorName,
        });

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
          );
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Colors.deepPurple;
    final OutlineInputBorder focusedBorder = OutlineInputBorder(borderSide: const BorderSide(color: primaryColor, width: 2.0), borderRadius: BorderRadius.circular(12.0));
    final OutlineInputBorder defaultBorder = OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12.0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un Nouveau Projet'),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedServiceType,
                  decoration: InputDecoration(
                    labelText: 'Type de Service',
                    enabledBorder: defaultBorder,
                    focusedBorder: focusedBorder,
                    floatingLabelStyle: const TextStyle(color: primaryColor),
                  ),
                  items: ['Service Technique', 'Service IT'].map((String service) {
                    return DropdownMenuItem<String>(value: service, child: Text(service));
                  }).toList(),
                  onChanged: (value) {
                    setState(() { _selectedServiceType = value; });
                  },
                  validator: (value) => value == null ? 'Veuillez sélectionner un service' : null,
                ),
                const SizedBox(height: 20),
                if (_isLoadingClients)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<Client>(
                    value: _selectedClient,
                    decoration: InputDecoration(labelText: 'Nom du Client', enabledBorder: defaultBorder, focusedBorder: focusedBorder, floatingLabelStyle: const TextStyle(color: primaryColor)),
                    items: _clients.map((client) => DropdownMenuItem<Client>(value: client, child: Text(client.name))).toList(),
                    onChanged: (client) {
                      if (client != null) {
                        setState(() { _selectedClient = client; });
                        _fetchStores(client.id);
                      }
                    },
                    validator: (value) => value == null ? 'Veuillez sélectionner un client' : null,
                  ),
                const SizedBox(height: 20),
                if (_isLoadingStores)
                  const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator()))
                else
                  DropdownButtonFormField<Store>(
                    value: _selectedStore,
                    decoration: InputDecoration(labelText: 'Magasin', enabledBorder: defaultBorder, focusedBorder: focusedBorder, floatingLabelStyle: const TextStyle(color: primaryColor)),
                    items: _stores.map((store) => DropdownMenuItem<Store>(value: store, child: Text('${store.name} - ${store.location}'))).toList(),
                    onChanged: _selectedClient == null ? null : (store) => setState(() { _selectedStore = store; }),
                    validator: (value) => value == null ? 'Veuillez sélectionner un magasin' : null,
                  ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _clientPhoneController,
                  decoration: InputDecoration(labelText: 'Numéro de Téléphone (Contact)', enabledBorder: defaultBorder, focusedBorder: focusedBorder, floatingLabelStyle: const TextStyle(color: primaryColor)),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un numéro' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _requestController,
                  decoration: InputDecoration(labelText: 'Description de la Demande (matériel, etc.)', enabledBorder: defaultBorder, focusedBorder: focusedBorder, floatingLabelStyle: const TextStyle(color: primaryColor), alignLabelWithHint: true),
                  maxLines: 5,
                  validator: (value) => value == null || value.isEmpty ? 'Veuillez décrire la demande' : null,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Créer le Projet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
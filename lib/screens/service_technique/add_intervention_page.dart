// lib/screens/service_technique/add_intervention_page.dart
// UPDATED: Year-based intervention numbering (INT-1/2025, INT-2/2025, etc.)
// FIXED: Store names display issue

import 'package:flutter/material.dart';
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

class _AddInterventionPageState extends State<AddInterventionPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  // State for dropdowns
  List<Client> _clients = [];
  Client? _selectedClient;
  List<Store> _stores = [];
  Store? _selectedStore;
  bool _isLoadingClients = true;
  bool _isLoadingStores = false;
  bool _isSaving = false;

  // State for date and priority
  DateTime? _interventionDate;
  String? _selectedPriority;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .where('services', arrayContains: widget.serviceType)
          .orderBy('name')
          .get();

      final clients = snapshot.docs.map((doc) {
        return Client(id: doc.id, name: doc.data()['name']);
      }).toList();

      if(mounted) setState(() {
        _clients = clients;
        _isLoadingClients = false;
      });
    } catch (e) {
      print("Error fetching clients: $e");
      if(mounted) setState(() { _isLoadingClients = false; });
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

      if(mounted) setState(() {
        _stores = stores;
        _isLoadingStores = false;
      });
    } catch (e) {
      print("Error fetching stores: $e");
      if(mounted) setState(() { _isLoadingStores = false; });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _interventionDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
    );

    if (picked != null && picked != _interventionDate) {
      setState(() {
        _interventionDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isSaving = true; });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() { _isSaving = false; });
        return;
      }

      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final creatorName = userDoc.data()?['displayName'] ?? 'Utilisateur inconnu';

        // ════════════════════════════════════════════════════════════
        // ✅ UPDATED: Year-based intervention numbering
        // ════════════════════════════════════════════════════════════
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // Get current year
          final currentYear = DateTime.now().year;

          // Use year-specific counter: intervention_counter_2025
          final counterRef = FirebaseFirestore.instance
              .collection('counters')
              .doc('intervention_counter_$currentYear');

          final counterDoc = await transaction.get(counterRef);

          // Get count for this year (starts at 0 if doesn't exist)
          final newCount = (counterDoc.data()?['count'] as int? ?? 0) + 1;

          // Generate code with year: INT-34/2025
          final newCode = 'INT-$newCount/$currentYear';

          final interventionRef = FirebaseFirestore.instance.collection('interventions').doc();

          transaction.set(interventionRef, {
            'serviceType': widget.serviceType,
            'interventionCode': newCode, // Now includes year: INT-34/2025
            'clientId': _selectedClient!.id,
            'clientName': _selectedClient!.name,
            'storeId': _selectedStore!.id,
            'storeName': _selectedStore!.name,
            'storeLocation': _selectedStore!.location,
            'description': _descriptionController.text.trim(),
            'interventionDate': Timestamp.fromDate(_interventionDate!),
            'priority': _selectedPriority,
            'status': 'Nouveau',
            'createdAt': Timestamp.now(),
            'createdByUid': user.uid,
            'createdByName': creatorName,
          });

          // Update year-specific counter
          transaction.set(
              counterRef,
              {'count': newCount},
              SetOptions(merge: true)
          );
        });

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        print("Erreur lors de la création de l'intervention: $e");
        if(mounted) setState(() { _isSaving = false; });
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Colors.blue;

    final OutlineInputBorder focusedBorder = OutlineInputBorder(
        borderSide: const BorderSide(color: primaryColor, width: 2.0),
        borderRadius: BorderRadius.circular(12.0)
    );

    final OutlineInputBorder defaultBorder = OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12.0)
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Nouvelle Intervention ${widget.serviceType}'),
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
                // Client Dropdown
                if (_isLoadingClients)
                  const Center(child: CircularProgressIndicator())
                else if (_clients.isEmpty)
                  InputDecorator(
                    decoration: InputDecoration(
                        labelText: 'Sélectionner un Client',
                        border: defaultBorder
                    ),
                    child: Text(
                        'Aucun client trouvé pour ${widget.serviceType}',
                        style: TextStyle(color: Colors.grey.shade600)
                    ),
                  )
                else
                  DropdownButtonFormField<Client>(
                    value: _selectedClient,
                    decoration: InputDecoration(
                        labelText: 'Sélectionner un Client',
                        border: defaultBorder,
                        focusedBorder: focusedBorder,
                        floatingLabelStyle: const TextStyle(color: primaryColor)
                    ),
                    items: _clients.map((client) {
                      return DropdownMenuItem(
                          value: client,
                          child: Text(client.name)
                      );
                    }).toList(),
                    onChanged: (client) {
                      setState(() { _selectedClient = client; });
                      if (client != null) {
                        _fetchStores(client.id);
                      }
                    },
                    validator: (value) => value == null ? 'Veuillez sélectionner un client' : null,
                  ),

                const SizedBox(height: 20),

                // Store Dropdown - FIXED: Proper string interpolation
                if (_isLoadingStores)
                  const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(child: CircularProgressIndicator())
                  )
                else
                  DropdownButtonFormField<Store>(
                    value: _selectedStore,
                    decoration: InputDecoration(
                        labelText: 'Sélectionner un Magasin',
                        border: defaultBorder,
                        focusedBorder: focusedBorder,
                        floatingLabelStyle: const TextStyle(color: primaryColor)
                    ),
                    items: _stores.map((store) {
                      return DropdownMenuItem(
                          value: store,
                          // FIXED: Use proper string interpolation
                          child: Text("${store.name} - ${store.location}")
                      );
                    }).toList(),
                    onChanged: _selectedClient == null
                        ? null
                        : (store) => setState(() { _selectedStore = store; }),
                    validator: (value) => value == null ? 'Veuillez sélectionner un magasin' : null,
                  ),

                const SizedBox(height: 20),

                // Priority Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedPriority,
                  decoration: InputDecoration(
                      labelText: 'Sélectionner une Priorité',
                      border: defaultBorder,
                      focusedBorder: focusedBorder,
                      floatingLabelStyle: const TextStyle(color: primaryColor)
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Haute',
                        child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Haute')
                            ]
                        )
                    ),
                    DropdownMenuItem(
                        value: 'Moyenne',
                        child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Moyenne')
                            ]
                        )
                    ),
                    DropdownMenuItem(
                        value: 'Basse',
                        child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Basse')
                            ]
                        )
                    ),
                  ],
                  onChanged: (value) => setState(() { _selectedPriority = value; }),
                  validator: (value) => value == null ? 'Veuillez sélectionner une priorité' : null,
                ),

                const SizedBox(height: 20),

                // Date Picker
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: "Date d'intervention",
                        border: defaultBorder,
                        focusedBorder: focusedBorder,
                        floatingLabelStyle: const TextStyle(color: primaryColor),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            _interventionDate == null
                                ? 'Sélectionner une date'
                                : DateFormat('dd MMMM yyyy', 'fr_FR').format(_interventionDate!)
                        ),
                        const Icon(Icons.calendar_today, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Description TextField
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                      labelText: 'Description du problème',
                      border: defaultBorder,
                      focusedBorder: focusedBorder,
                      floatingLabelStyle: const TextStyle(color: primaryColor),
                      alignLabelWithHint: true
                  ),
                  maxLines: 5,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Veuillez décrire le problème'
                      : null,
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Créer la Demande'),
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

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
  final _descriptionController = TextEditingController();

  List<Client> _clients = [];
  Client? _selectedClient;
  List<Store> _stores = [];
  Store? _selectedStore;
  bool _isLoadingClients = true;
  bool _isLoadingStores = false;
  bool _isSaving = false;
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
      final clients = snapshot.docs
          .map((d) => Client(id: d.id, name: d.data()['name']))
          .toList();
      if (mounted) setState(() { _clients = clients; _isLoadingClients = false; });
    } catch (_) {
      if (mounted) setState(() { _isLoadingClients = false; });
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
      final stores = snapshot.docs.map((d) {
        final data = d.data();
        return Store(id: d.id, name: data['name'], location: data['location']);
      }).toList();
      if (mounted) setState(() { _stores = stores; _isLoadingStores = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingStores = false);
    }
  }

  Future<void> _selectDate(BuildContext ctx) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: _interventionDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && picked != _interventionDate) {
      setState(() => _interventionDate = picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _isSaving = false); return; }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final creator = userDoc.data()?['displayName'] ?? 'Inconnu';
      final year = DateTime.now().year;
      final counterRef = FirebaseFirestore.instance
          .collection('counters')
          .doc('intervention_counter_$year');
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final cDoc = await tx.get(counterRef);
        final newCount = (cDoc.data()?['count'] as int? ?? 0) + 1;
        final code = 'INT-$newCount/$year';
        final iRef = FirebaseFirestore.instance.collection('interventions').doc();
        tx.set(iRef, {
          'serviceType': widget.serviceType,
          'interventionCode': code,
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
          'createdByName': creator,
        });
        tx.set(counterRef, {'count': newCount}, SetOptions(merge: true));
      });
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gradientColors = [
      Color(0xFFB3E5FC),
      Color(0xFFCE93D8),
      Color(0xFFF48FB1),
    ];
    const primaryColor = Colors.blue;
    final focusedBorder = OutlineInputBorder(
      borderSide: const BorderSide(color: primaryColor, width: 2.0),
      borderRadius: BorderRadius.circular(12),
    );
    final defaultBorder = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(12),
    );

    Widget formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingClients)
            const Center(child: CircularProgressIndicator())
          else if (_clients.isEmpty)
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Client',
                border: defaultBorder,
              ),
              child: Text('Aucun client', style: TextStyle(color: Colors.grey)),
            )
          else
            DropdownButtonFormField<Client>(
              value: _selectedClient,
              decoration: InputDecoration(
                labelText: 'Client',
                border: defaultBorder,
                focusedBorder: focusedBorder,
                floatingLabelStyle: const TextStyle(color: primaryColor),
              ),
              items: _clients.map((c) => DropdownMenuItem(
                value: c,
                child: Text(c.name),
              )).toList(),
              onChanged: (c) { setState(() => _selectedClient = c); if (c != null) _fetchStores(c.id); },
              validator: (v) => v == null ? 'Sélectionner un client' : null,
            ),
          const SizedBox(height: 20),
          if (_isLoadingStores)
            const Center(child: CircularProgressIndicator())
          else
            DropdownButtonFormField<Store>(
              value: _selectedStore,
              decoration: InputDecoration(
                labelText: 'Magasin',
                border: defaultBorder,
                focusedBorder: focusedBorder,
                floatingLabelStyle: const TextStyle(color: primaryColor),
              ),
              items: _stores.map((s) => DropdownMenuItem(
                value: s,
                child: Text('${s.name} (${s.location})'),
              )).toList(),
              onChanged: _selectedClient == null ? null : (s) => setState(() => _selectedStore = s),
              validator: (v) => v == null ? 'Sélectionner un magasin' : null,
            ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedPriority,
            decoration: InputDecoration(
              labelText: 'Priorité',
              border: defaultBorder,
              focusedBorder: focusedBorder,
              floatingLabelStyle: const TextStyle(color: primaryColor),
            ),
            items: const [
              DropdownMenuItem(value: 'Haute', child: Text('Haute')),
              DropdownMenuItem(value: 'Moyenne', child: Text('Moyenne')),
              DropdownMenuItem(value: 'Basse', child: Text('Basse')),
            ],
            onChanged: (p) => setState(() => _selectedPriority = p),
            validator: (v) => v == null ? 'Sélectionner une priorité' : null,
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () => _selectDate(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date',
                border: defaultBorder,
                focusedBorder: focusedBorder,
                floatingLabelStyle: const TextStyle(color: primaryColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_interventionDate == null
                      ? 'Sélectionner une date'
                      : DateFormat('dd MMM yyyy', 'fr_FR').format(_interventionDate!)),
                  const Icon(Icons.calendar_today, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description',
              border: defaultBorder,
              focusedBorder: focusedBorder,
              floatingLabelStyle: const TextStyle(color: primaryColor),
            ),
            maxLines: 5,
            validator: (v) => v == null || v.isEmpty ? 'Décrire le problème' : null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
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
        title: Text('Nouvelle Intervention'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
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
        decoration: const BoxDecoration(
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

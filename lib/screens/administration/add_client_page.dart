// lib/screens/administration/add_client_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ ContactInfo Model
class ContactInfo {
  String type; // 'Téléphone' ou 'E-mail'
  String label; // Ex: 'Facturation', 'Technique', 'Principal'
  String value; // Le numéro ou l'adresse e-mail

  // Unique ID for list management
  final String id;

  ContactInfo({
    required this.type,
    required this.label,
    required this.value,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  IconData get icon {
    switch (type) {
      case 'E-mail':
        return Icons.email;
      case 'Fax':
        return Icons.fax_outlined;
      default:
        return Icons.phone;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'label': label,
      'value': value,
    };
  }

  factory ContactInfo.fromMap(Map<String, dynamic> map, String id) {
    return ContactInfo(
      type: map['type'] ?? 'Téléphone',
      label: map['label'] ?? '',
      value: map['value'] ?? '',
      id: id,
    );
  }
}

class AddClientPage extends StatefulWidget {
  final String? clientId;
  final Map<String, dynamic>? initialData;
  final String? preselectedServiceType;

  const AddClientPage({
    super.key,
    this.clientId,
    this.initialData,
    this.preselectedServiceType,
  });

  @override
  State<AddClientPage> createState() => _AddClientPageState();
}

class _AddClientPageState extends State<AddClientPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  // Controllers for Business Identifiers
  final _rcController = TextEditingController();
  final _artController = TextEditingController();
  final _fiscController = TextEditingController();

  final Map<String, bool> _services = {
    'Service Technique': false,
    'Service IT': false,
  };

  List<ContactInfo> _contacts = [];

  bool _isLoading = false;
  bool get _isEditMode => widget.clientId != null;

  // Colors
  final Color primaryColor = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();

    if (widget.preselectedServiceType != null) {
      if (_services.containsKey(widget.preselectedServiceType)) {
        _services[widget.preselectedServiceType!] = true;
      }
    }

    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEditMode) {
      _loadClientData();
    } else {
      _addContact();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _rcController.dispose();
    _artController.dispose();
    _fiscController.dispose();
    super.dispose();
  }

  void _populateData(Map<String, dynamic> data) {
    _nameController.text = data['name'] ?? '';
    _addressController.text = data['location'] ?? '';
    _rcController.text = data['rc'] ?? '';
    _artController.text = data['art'] ?? '';
    _fiscController.text = data['nif'] ?? '';

    if (data['services'] != null) {
      final servicesList = List<String>.from(data['services']);
      setState(() {
        _services['Service Technique'] = servicesList.contains('Service Technique');
        _services['Service IT'] = servicesList.contains('Service IT');
      });
    }

    if (data['contacts'] != null) {
      final List<dynamic> contactsData = data['contacts'];
      setState(() {
        _contacts = contactsData.map((c) => ContactInfo.fromMap(c as Map<String, dynamic>, DateTime.now().millisecondsSinceEpoch.toString())).toList();
      });
    } else if (_contacts.isEmpty) {
      _addContact();
    }
  }

  Future<void> _loadClientData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .get();

      if (doc.exists) {
        _populateData(doc.data()!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addContact() {
    setState(() {
      _contacts.add(ContactInfo(type: 'Téléphone', label: '', value: ''));
    });
  }

  void _removeContact(int index) {
    setState(() {
      _contacts.removeAt(index);
    });
  }

  /// ✅ 1. PRO FEATURE: Slug Generator
  String _generateSlug(String input) {
    String slug = input.trim().toLowerCase();
    const withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñ';
    const withoutDia = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuuyNn';

    for (int i = 0; i < withDia.length; i++) {
      slug = slug.replaceAll(withDia[i], withoutDia[i]);
    }
    slug = slug.replaceAll(RegExp(r'[^a-z0-9]'), '_');
    slug = slug.replaceAll(RegExp(r'_+'), '_');
    if (slug.startsWith('_')) slug = slug.substring(1);
    if (slug.endsWith('_')) slug = slug.substring(0, slug.length - 1);

    return slug;
  }

  /// ✅ 2. PRO FEATURE: Search Keywords Generator
  List<String> _generateSearchKeywords(String name) {
    List<String> keywords = [];
    String current = "";
    for (int i = 0; i < name.length; i++) {
      current += name[i].toLowerCase();
      keywords.add(current);
    }
    return keywords;
  }

  // 🔥 THIS IS THE HYBRID PROTECTION LOGIC 🔥
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final selectedServices = _services.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      // Generate Metadata
      final slug = _generateSlug(_nameController.text);
      final searchKeywords = _generateSearchKeywords(_nameController.text.trim());

      final clientData = {
        'name': _nameController.text.trim(),
        'location': _addressController.text.trim(),
        'services': selectedServices,
        'rc': _rcController.text.trim(),
        'art': _artController.text.trim(),
        'nif': _fiscController.text.trim(),
        'contacts': _contacts.map((c) => c.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),

        // ✅ CRITICAL: Always save these now
        'slug': slug,
        'search_keywords': searchKeywords,
      };

      if (_isEditMode) {
        // Edit Mode: Update existing doc (ID does not change)
        await FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .update(clientData);
      } else {
        // ✅ ADD Mode: "Hybrid" Duplicate Check
        if (slug.isEmpty) throw "Le nom de l'entreprise est invalide.";

        // 1️⃣ CHECK NEW SYSTEM (ID Collision)
        // Does 'zara_algerie' exist as a document ID?
        final docRef = FirebaseFirestore.instance.collection('clients').doc(slug);
        final docSnapshot = await docRef.get();

        if (docSnapshot.exists) {
          throw "Ce client existe déjà ! (ID: $slug).\nVeuillez vérifier la liste.";
        }

        // 2️⃣ CHECK OLD SYSTEM (Field Collision)
        // Does any document (even with random ID) have 'slug' == 'zara_algerie'?
        final legacyCheck = await FirebaseFirestore.instance
            .collection('clients')
            .where('slug', isEqualTo: slug)
            .limit(1)
            .get();

        if (legacyCheck.docs.isNotEmpty) {
          final oldId = legacyCheck.docs.first.id;
          throw "Ce client existe déjà dans l'ancien système !\n(ID: $oldId)";
        }

        // 3️⃣ CREATE (Safe to proceed)
        clientData['createdAt'] = FieldValue.serverTimestamp();
        await docRef.set(clientData);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Modifier Client' : 'Ajouter Client'),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Informations Générales'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nom de l\'entreprise / Client',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.business),
                  filled: true,
                  fillColor: Colors.grey[100],
                  helperText: "Sera utilisé pour vérifier les doublons.",
                ),
                validator: (value) => value!.isEmpty ? 'Veuillez entrer un nom' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Adresse / Localisation',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.map),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Informations Fiscales & Légales'),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rcController,
                      decoration: InputDecoration(
                        labelText: 'N° RC',
                        hintText: 'Registre de Commerce',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.confirmation_number_outlined),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _artController,
                      decoration: InputDecoration(
                        labelText: 'N° ART',
                        hintText: 'Article d\'Imposition',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.numbers),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fiscController,
                decoration: InputDecoration(
                  labelText: 'N° FISC (NIF)',
                  hintText: 'Numéro d\'Identification Fiscale',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.account_balance),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Contacts'),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: _addContact,
                    tooltip: 'Ajouter un contact',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_contacts.isEmpty)
                const Text('Aucun contact ajouté.', style: TextStyle(color: Colors.grey)),
              ..._contacts.asMap().entries.map((entry) {
                int index = entry.key;
                ContactInfo contact = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: contact.type,
                                decoration: const InputDecoration(
                                  labelText: 'Type',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                ),
                                items: ['Téléphone', 'E-mail', 'Fax', 'Autre']
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                    .toList(),
                                onChanged: (val) => setState(() => contact.type = val!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: contact.label,
                                decoration: const InputDecoration(
                                  labelText: 'Libellé (ex: DG, Compta)',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                ),
                                onChanged: (val) => contact.label = val,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeContact(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: contact.value,
                          decoration: InputDecoration(
                            labelText: contact.type == 'E-mail' ? 'Adresse E-mail' : 'Numéro / Valeur',
                            prefixIcon: Icon(contact.type == 'E-mail' ? Icons.email : Icons.phone),
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: contact.type == 'E-mail' ? TextInputType.emailAddress : TextInputType.phone,
                          onChanged: (val) => contact.value = val,
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 24),
              _buildSectionTitle('Services Concernés'),
              CheckboxListTile(
                title: const Text('Service Technique'),
                value: _services['Service Technique'],
                onChanged: (bool? value) {
                  setState(() { _services['Service Technique'] = value!; });
                },
              ),
              CheckboxListTile(
                title: const Text('Service IT'),
                value: _services['Service IT'],
                onChanged: (bool? value) {
                  setState(() { _services['Service IT'] = value!; });
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(_isEditMode ? Icons.save : Icons.add),
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  ),
                  label: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Text(_isEditMode ? 'Enregistrer les Modifications' : 'Ajouter le Client'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: primaryColor,
      ),
    );
  }
}
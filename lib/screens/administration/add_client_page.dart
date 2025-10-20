// lib/screens/administration/add_client_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ 1. NOUVEAU: Modèle pour représenter une information de contact
class ContactInfo {
  String type; // 'Téléphone' ou 'E-mail'
  String label; // Ex: 'Facturation', 'Technique', 'Principal'
  String value; // Le numéro ou l'adresse e-mail

  // Unique ID for list management (optional but helpful)
  final String id;

  ContactInfo({
    required this.type,
    required this.label,
    required this.value,
    String? id, // Allow providing an ID for existing items
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(); // Generate unique ID

  // Convertir un objet ContactInfo en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'label': label,
      'value': value,
    };
  }

  // Créer un objet ContactInfo depuis une Map Firestore
  factory ContactInfo.fromMap(Map<String, dynamic> map, String id) {
    return ContactInfo(
      type: map['type'] ?? 'Téléphone', // Default type
      label: map['label'] ?? '',
      value: map['value'] ?? '',
      id: id, // Use provided ID if available (e.g., index)
    );
  }

  // Helper for display
  IconData get icon => type == 'Téléphone' ? Icons.phone_outlined : Icons.email_outlined;
}


class AddClientPage extends StatefulWidget {
  final String? clientId;
  final Map<String, dynamic>? initialData;

  const AddClientPage({
    super.key,
    this.clientId,
    this.initialData,
  });

  @override
  State<AddClientPage> createState() => _AddClientPageState();
}

class _AddClientPageState extends State<AddClientPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  // ✅ 2. MODIFIÉ: Utiliser une liste pour les contacts
  List<ContactInfo> _contacts = [];

  final Map<String, bool> _services = {
    'Service Technique': false,
    'Service IT': false,
  };
  bool _isLoading = false;
  late bool _isEditMode;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.clientId != null;
    _nameController = TextEditingController();

    if (_isEditMode && widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';

      // Charger les services existants
      final List<String> currentServices = List<String>.from(widget.initialData!['services'] ?? []);
      for (String service in currentServices) {
        if (_services.containsKey(service)) {
          _services[service] = true;
        }
      }

      // ✅ 3. MODIFIÉ: Charger les contacts existants depuis la liste 'contacts'
      final List<dynamic> contactsData = widget.initialData!['contacts'] ?? [];
      _contacts = contactsData
          .asMap() // Get index as ID
          .entries
          .map((entry) => ContactInfo.fromMap(entry.value as Map<String, dynamic>, entry.key.toString()))
          .toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ✅ 4. NOUVEAU: Fonction pour afficher le dialogue d'ajout/modification de contact
  Future<void> _showContactDialog({ContactInfo? existingContact, int? index}) async {
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();
    String type = existingContact?.type ?? 'Téléphone'; // Default to Phone
    final labelController = TextEditingController(text: existingContact?.label ?? '');
    final valueController = TextEditingController(text: existingContact?.value ?? '');

    final result = await showDialog<ContactInfo>(
      context: context,
      builder: (BuildContext context) {
        // Use StatefulBuilder for the dropdown inside the dialog
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(existingContact == null ? 'Ajouter un Contact' : 'Modifier le Contact'),
                content: Form(
                  key: dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: type,
                        items: ['Téléphone', 'E-mail']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() { // Use setDialogState to update dropdown
                            type = value!;
                          });
                        },
                        decoration: const InputDecoration(labelText: 'Type'),
                      ),
                      TextFormField(
                        controller: labelController,
                        decoration: const InputDecoration(labelText: 'Étiquette (Ex: Facturation)'),
                        validator: (value) => value == null || value.isEmpty ? 'Étiquette requise' : null,
                      ),
                      TextFormField(
                        controller: valueController,
                        decoration: InputDecoration(labelText: type == 'Téléphone' ? 'Numéro' : 'Adresse E-mail'),
                        keyboardType: type == 'Téléphone' ? TextInputType.phone : TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Valeur requise';
                          }
                          if (type == 'E-mail' && !value.contains('@')) {
                            return 'E-mail invalide';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (dialogFormKey.currentState!.validate()) {
                        Navigator.of(context).pop(ContactInfo(
                          type: type,
                          label: labelController.text.trim(),
                          value: valueController.text.trim(),
                          id: existingContact?.id, // Preserve ID if editing
                        ));
                      }
                    },
                    child: const Text('Enregistrer'),
                  ),
                ],
              );
            }
        );
      },
    );

    // Mettre à jour la liste principale si un contact a été ajouté/modifié
    if (result != null) {
      setState(() {
        if (existingContact != null && index != null) {
          // Edit existing contact
          _contacts[index] = result;
        } else {
          // Add new contact
          _contacts.add(result);
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      final selectedServices = _services.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      // ✅ 5. MODIFIÉ: Convertir la liste d'objets ContactInfo en liste de Maps
      final List<Map<String, dynamic>> contactsForDb = _contacts.map((c) => c.toMap()).toList();

      final clientData = {
        'name': _nameController.text.trim(),
        'services': selectedServices,
        'contacts': contactsForDb, // Enregistrer la liste de contacts
      };

      try {
        if (_isEditMode) {
          await FirebaseFirestore.instance
              .collection('clients')
              .doc(widget.clientId!)
              .update(clientData);
        } else {
          await FirebaseFirestore.instance.collection('clients').add(clientData);
        }

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_isEditMode ? 'Client mis à jour' : 'Client ajouté'))
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red)
          );
        }
      } finally {
        if(mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultBorder = OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12.0)
    );
    final focusedBorder = OutlineInputBorder(
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
        borderRadius: BorderRadius.circular(12.0)
    );
    const primaryColor = Colors.blue;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Modifier le Client' : 'Ajouter un Client'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nom du Client',
                  enabledBorder: defaultBorder,
                  focusedBorder: focusedBorder,
                  floatingLabelStyle: const TextStyle(color: primaryColor),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un nom' : null,
              ),
              const SizedBox(height: 24),

              // ✅ 6. NOUVEAU: Section pour afficher et gérer les contacts
              const Text('Contacts:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (_contacts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: Text('Aucun contact ajouté.', style: TextStyle(color: Colors.grey))),
                ),
              ListView.builder(
                shrinkWrap: true, // Important within another ListView
                physics: const NeverScrollableScrollPhysics(), // Disable scrolling
                itemCount: _contacts.length,
                itemBuilder: (context, index) {
                  final contact = _contacts[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(contact.icon, color: primaryColor),
                      title: Text(contact.value),
                      subtitle: Text(contact.label),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.orange),
                            tooltip: 'Modifier',
                            onPressed: () => _showContactDialog(existingContact: contact, index: index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Supprimer',
                            onPressed: () {
                              setState(() {
                                _contacts.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Center( // Center the button
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un Contact'),
                  onPressed: () => _showContactDialog(), // Call without parameters for adding
                ),
              ),
              const SizedBox(height: 24),


              const Text('Services Associés:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
}
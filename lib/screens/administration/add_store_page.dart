// lib/screens/administration/add_store_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ✅ 1. Import the ContactInfo model (assuming it's in add_client_page.dart for now)
//    Consider moving ContactInfo to its own file later, e.g., lib/models/contact_info.dart
import 'package:boitex_info_app/screens/administration/add_client_page.dart' show ContactInfo;

class AddStorePage extends StatefulWidget {
  final String clientId;
  // ✅ 2. Added optional parameters for editing
  final String? storeId;
  final Map<String, dynamic>? initialData;

  const AddStorePage({
    super.key,
    required this.clientId,
    this.storeId,
    this.initialData,
  });

  @override
  State<AddStorePage> createState() => _AddStorePageState();
}

class _AddStorePageState extends State<AddStorePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  bool _isLoading = false;
  // ✅ 3. Added edit mode flag and contacts list state
  late bool _isEditMode;
  List<ContactInfo> _storeContacts = [];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.storeId != null;
    _nameController = TextEditingController();
    _locationController = TextEditingController();

    // Pre-fill form if editing
    if (_isEditMode && widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _locationController.text = widget.initialData!['location'] ?? '';

      // Load existing store contacts
      final List<dynamic> contactsData = widget.initialData!['storeContacts'] ?? [];
      _storeContacts = contactsData
          .asMap()
          .entries
          .map((entry) => ContactInfo.fromMap(entry.value as Map<String, dynamic>, entry.key.toString()))
          .toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ✅ 4. Copied _showContactDialog function (identical to add_client_page.dart)
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
                title: Text(existingContact == null ? 'Ajouter Contact Magasin' : 'Modifier Contact Magasin'),
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
                        decoration: const InputDecoration(labelText: 'Étiquette (Ex: Manager)'),
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

    // Update the main list if a contact was added/edited
    if (result != null) {
      setState(() {
        if (existingContact != null && index != null) {
          // Edit existing contact
          _storeContacts[index] = result;
        } else {
          // Add new contact
          _storeContacts.add(result);
        }
      });
    }
  }


  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      // ✅ 5. Convert contacts list to map for Firestore
      final List<Map<String, dynamic>> contactsForDb = _storeContacts.map((c) => c.toMap()).toList();

      final storeData = {
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'storeContacts': contactsForDb, // Save the contacts list
      };

      try {
        final storeCollectionRef = FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('stores');

        if (_isEditMode) {
          // Update existing store document
          await storeCollectionRef.doc(widget.storeId!).update(storeData);
        } else {
          // Add new store document
          await storeCollectionRef.add(storeData);
        }

        if (mounted) {
          Navigator.of(context).pop(); // Go back after saving
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_isEditMode ? 'Magasin mis à jour' : 'Magasin ajouté'))
          );
        }
      } catch (e) {
        print("Erreur lors de l'enregistrement du magasin: $e");
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
    const primaryColor = Colors.teal; // Color for store section
    final defaultBorder = OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12.0)
    );
    final focusedBorder = OutlineInputBorder(
        borderSide: BorderSide(color: primaryColor, width: 2.0),
        borderRadius: BorderRadius.circular(12.0)
    );

    return Scaffold(
      appBar: AppBar(
        // ✅ 6. Updated AppBar Title
        title: Text(_isEditMode ? 'Modifier Magasin' : 'Ajouter Magasin'),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          // ✅ 7. Changed to ListView for scrolling
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nom du Magasin (ex: Zara)',
                  enabledBorder: defaultBorder,
                  focusedBorder: focusedBorder,
                  floatingLabelStyle: const TextStyle(color: primaryColor),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un nom' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Emplacement (ex: Bab Ezzouar Mall)',
                  enabledBorder: defaultBorder,
                  focusedBorder: focusedBorder,
                  floatingLabelStyle: const TextStyle(color: primaryColor),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un emplacement' : null,
              ),
              const SizedBox(height: 24),

              // ✅ 8. Added Contact Management Section
              const Text('Contacts du Magasin:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (_storeContacts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: Text('Aucun contact ajouté.', style: TextStyle(color: Colors.grey))),
                ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _storeContacts.length,
                itemBuilder: (context, index) {
                  final contact = _storeContacts[index];
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
                                _storeContacts.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Center(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un Contact Magasin'),
                  onPressed: () => _showContactDialog(),
                ),
              ),
              const SizedBox(height: 32), // Spacing before button

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  // ✅ 9. Updated Button Text/Icon
                  icon: Icon(_isEditMode ? Icons.save : Icons.add_business_outlined),
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  ),
                  label: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Text(_isEditMode ? 'Enregistrer les Modifications' : 'Enregistrer le Magasin'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
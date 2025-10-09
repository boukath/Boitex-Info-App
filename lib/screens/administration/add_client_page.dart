import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddClientPage extends StatefulWidget {
  const AddClientPage({super.key});

  @override
  State<AddClientPage> createState() => _AddClientPageState();
}

class _AddClientPageState extends State<AddClientPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  // A map to hold the state of our checkboxes
  final Map<String, bool> _services = {
    'Service Technique': false,
    'Service IT': false,
  };
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      // Get the list of selected services
      final selectedServices = _services.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      try {
        // Add the new client to the 'clients' collection in Firestore
        await FirebaseFirestore.instance.collection('clients').add({
          'name': _nameController.text.trim(),
          'services': selectedServices,
        });

        if (mounted) {
          // Go back to the previous screen after saving
          Navigator.of(context).pop();
        }
      } catch (e) {
        // Handle potential errors
        print("Erreur lors de l'ajout du client: $e");
        setState(() { _isLoading = false; });
        // Optionally, show an error message to the user
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un Client'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du Client',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un nom' : null,
              ),
              const SizedBox(height: 24),
              const Text('Services Associés:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              // Create a CheckboxListTile for each service
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
              const Spacer(), // Pushes the button to the bottom
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Enregistrer le Client'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
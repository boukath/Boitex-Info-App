import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddSystemPage extends StatefulWidget {
  final String clientId;
  final String storeId;

  const AddSystemPage({
    super.key,
    required this.clientId,
    required this.storeId,
  });

  @override
  State<AddSystemPage> createState() => _AddSystemPageState();
}

class _AddSystemPageState extends State<AddSystemPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      try {
        // Add the new system to the correct store's 'systems' subcollection
        await FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('stores')
            .doc(widget.storeId)
            .collection('systems')
            .add({
          'name': _nameController.text.trim(),
          'type': _typeController.text.trim(),
        });

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        print("Erreur lors de l'ajout du système: $e");
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un Système Antivol'),
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
                  labelText: 'Nom du Système (ex: Sensormatic)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un nom' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(
                  labelText: 'Type (ex: Ultra Exit)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un type' : null,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Enregistrer le Système'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
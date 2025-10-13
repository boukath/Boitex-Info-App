// lib/screens/service_technique/add_sav_ticket_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/screens/widgets/scanner_page.dart';
import 'package:signature/signature.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

class UserViewModel {
  final String id;
  final String name;
  UserViewModel({required this.id, required this.name});
}

class AddSavTicketPage extends StatefulWidget {
  final String serviceType;
  const AddSavTicketPage({super.key, required this.serviceType});

  @override
  State<AddSavTicketPage> createState() => _AddSavTicketPageState();
}

class _AddSavTicketPageState extends State<AddSavTicketPage> {
  final _formKey = GlobalKey<FormState>();
  List<DocumentSnapshot> _clients = [];
  List<DocumentSnapshot> _stores = [];
  bool _isLoadingClients = true;
  bool _isLoadingStores = false;
  String? _selectedClientId;
  String? _selectedStoreId;

  final List<String> _mainCategories = ['Antivol', 'TPV', 'Compteur Client'];
  String? _selectedMainCategory;
  List<String> _subCategories = [];
  bool _isLoadingSubCategories = false;
  String? _selectedSubCategory;
  List<DocumentSnapshot> _products = [];
  bool _isLoadingProducts = false;
  String? _selectedProductId;

  List<UserViewModel> _availableTechnicians = [];
  bool _isLoadingTechnicians = true;
  List<UserViewModel> _selectedTechnicians = [];
  final _serialNumberController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _problemDescriptionController = TextEditingController();
  DateTime? _pickupDate;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  List<File> _pickedItemPhotos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _fetchAvailableTechnicians();
  }

  @override
  void dispose() {
    _serialNumberController.dispose();
    _managerNameController.dispose();
    _problemDescriptionController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _fetchClients() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .where('services', arrayContains: widget.serviceType)
          .orderBy('name')
          .get();
      if (mounted) setState(() { _clients = snapshot.docs; _isLoadingClients = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingClients = false; });
    }
  }

  Future<void> _fetchStoresForClient(String clientId) async {
    setState(() { _isLoadingStores = true; _stores = []; _selectedStoreId = null; });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .orderBy('name')
          .get();
      if (mounted) setState(() { _stores = snapshot.docs; _isLoadingStores = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingStores = false; });
    }
  }

  Future<void> _fetchAvailableTechnicians() async {
    setState(() { _isLoadingTechnicians = true; });
    try {
      final List<String> includedRoles = [
        'Admin', 'Responsable Administratif', 'Responsable Commercial',
        'Responsable Technique', 'Responsable IT', 'Chef de Projet',
        'Technicien ST', 'Technicien IT',
      ];
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: includedRoles)
          .orderBy('role')
          .orderBy('displayName')
          .get();
      final List<UserViewModel> fetchedUsers = snapshot.docs
          .map((doc) => UserViewModel(id: doc.id, name: doc['displayName']))
          .toList();
      if (mounted) {
        setState(() {
          _availableTechnicians = fetchedUsers;
          _isLoadingTechnicians = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoadingTechnicians = false; });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors du chargement des techniciens: $e'))
        );
      }
    }
  }

  // ✅ MODIFIED: Added try-catch and data validation for resilience
  Future<void> _fetchCategoriesForMainSection(String mainCategory) async {
    setState(() {
      _isLoadingSubCategories = true;
      _subCategories = [];
      _selectedSubCategory = null;
      _products = [];
      _selectedProductId = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('mainCategory', isEqualTo: mainCategory)
          .get();

      final categoriesSet = <String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Check if the 'categorie' field exists and is a String
        if (data.containsKey('categorie') && data['categorie'] is String) {
          categoriesSet.add(data['categorie']);
        } else {
          // Log an error to the console to help identify bad data
          print('Warning: Document ${doc.id} is missing or has an invalid "categorie" field.');
        }
      }

      final sortedList = categoriesSet.toList();
      sortedList.sort();

      if (mounted) {
        setState(() {
          _subCategories = sortedList;
        });
      }
    } catch (e) {
      // Catch any potential errors during the Firestore query
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'))
        );
      }
    } finally {
      // ALWAYS ensure the loading indicator is turned off
      if (mounted) {
        setState(() {
          _isLoadingSubCategories = false;
        });
      }
    }
  }

  Future<void> _fetchProductsForSubCategory(String category) async {
    setState(() { _isLoadingProducts = true; _products = []; _selectedProductId = null; });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('categorie', isEqualTo: category)
          .orderBy('nom')
          .get();
      if (mounted) setState(() { _products = snapshot.docs; _isLoadingProducts = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingProducts = false; });
    }
  }

  Future<void> _openScanner() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const ScannerPage()),
    );
    if (scannedCode != null && mounted) {
      setState(() { _serialNumberController.text = scannedCode; });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _pickupDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _pickupDate) {
      setState(() { _pickupDate = picked; });
    }
  }

  Future<void> _pickItemPhotos() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (result != null) {
      setState(() { _pickedItemPhotos = result.paths.map((path) => File(path!)).toList(); });
    }
  }

  Future<void> _saveTicket() async {
    if (!_formKey.currentState!.validate()) return;
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La signature du gérant est requise.')));
      return;
    }
    setState(() { _isLoading = true; });
    try {
      final currentYear = DateTime.now().year;
      final counterRef = FirebaseFirestore.instance.collection('counters').doc('sav_tickets_$currentYear');
      final newCode = await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterSnap = await transaction.get(counterRef);
        final currentCount = (counterSnap.data()?['count'] as int?) ?? 0;
        final nextCount = currentCount + 1;
        transaction.set(counterRef, {'count': nextCount}, SetOptions(merge: true));
        return 'SAV-$nextCount/$currentYear';
      });

      final Uint8List? signatureData = await _signatureController.toPngBytes();
      final signatureStorageRef = FirebaseStorage.instance.ref().child('sav_signatures/$newCode.png');
      await signatureStorageRef.putData(signatureData!);
      final signatureUrl = await signatureStorageRef.getDownloadURL();

      List<String> uploadedPhotoUrls = [];
      for (var file in _pickedItemPhotos) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
        final photoStorageRef = FirebaseStorage.instance.ref().child('sav_items/$newCode/$fileName');
        await photoStorageRef.putFile(file);
        final url = await photoStorageRef.getDownloadURL();
        uploadedPhotoUrls.add(url);
      }

      final clientDoc = _clients.firstWhere((doc) => doc.id == _selectedClientId);
      final productDoc = _products.firstWhere((doc) => doc.id == _selectedProductId);

      String? storeName;
      if (_selectedStoreId != null) {
        final storeDoc = _stores.firstWhere((doc) => doc.id == _selectedStoreId);
        storeName = "${storeDoc['name']} - ${storeDoc['location']}";
      }

      final newTicket = SavTicket(
        serviceType: widget.serviceType,
        savCode: newCode,
        clientId: _selectedClientId!,
        clientName: clientDoc['name'],
        storeId: _selectedStoreId,
        storeName: storeName,
        pickupDate: _pickupDate ?? DateTime.now(),
        pickupTechnicianIds: _selectedTechnicians.map((u) => u.id).toList(),
        pickupTechnicianNames: _selectedTechnicians.map((u) => u.name).toList(),
        productName: productDoc['nom'],
        serialNumber: _serialNumberController.text,
        problemDescription: _problemDescriptionController.text,
        itemPhotoUrls: uploadedPhotoUrls,
        storeManagerName: _managerNameController.text,
        storeManagerSignatureUrl: signatureUrl,
        status: 'Nouveau',
        createdBy: 'Current User Name',
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance.collection('sav_tickets').add(newTicket.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket SAV créé avec succès!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if(mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Colors.orange;
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
        title: Text('Nouveau Ticket SAV (${widget.serviceType})'),
        backgroundColor: primaryColor,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Informations Client', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedClientId,
                isExpanded: true,
                items: _clients.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name']))).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() { _selectedClientId = value; });
                    _fetchStoresForClient(value);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Client',
                  border: defaultBorder,
                  focusedBorder: focusedBorder,
                  prefixIcon: _isLoadingClients ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()) : null,
                ),
                validator: (value) => value == null ? 'Veuillez sélectionner un client' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStoreId,
                isExpanded: true,
                items: _stores.map((doc) {
                  final name = doc['name'];
                  final location = doc['location'];
                  return DropdownMenuItem(value: doc.id, child: Text('$name - $location'));
                }).toList(),
                onChanged: _selectedClientId == null ? null : (value) => setState(() { _selectedStoreId = value; }),
                decoration: InputDecoration(
                  labelText: 'Magasin (Optionnel)',
                  border: defaultBorder,
                  focusedBorder: focusedBorder,
                  prefixIcon: _isLoadingStores ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()) : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _managerNameController,
                decoration: InputDecoration(labelText: 'Nom du Gérant', border: defaultBorder, focusedBorder: focusedBorder),
                validator: (value) => value!.isEmpty ? 'Veuillez entrer le nom du gérant' : null,
              ),
              const Divider(height: 40),
              const Text('Détails de la Récupération', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(labelText: 'Date de récupération', border: defaultBorder, focusedBorder: focusedBorder),
                  child: Text(_pickupDate == null ? 'Sélectionner une date' : DateFormat('dd/MM/yyyy').format(_pickupDate!)),
                ),
              ),
              const SizedBox(height: 16),
              MultiSelectDialogField<UserViewModel>(
                items: _availableTechnicians.map((user) => MultiSelectItem(user, user.name)).toList(),
                title: const Text("Techniciens"),
                buttonText: _isLoadingTechnicians ? const Text("Chargement...") : const Text("Assigner des techniciens"),
                onConfirm: (results) => setState(() => _selectedTechnicians = results),
                chipDisplay: MultiSelectChipDisplay(),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                validator: (values) => values == null || values.isEmpty ? 'Veuillez assigner au moins un technicien' : null,
              ),
              const Divider(height: 40),

              const Text('Informations Produit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedMainCategory,
                isExpanded: true,
                items: _mainCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() { _selectedMainCategory = value; });
                    _fetchCategoriesForMainSection(value);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Section Principale',
                  border: defaultBorder,
                  focusedBorder: focusedBorder,
                ),
                validator: (value) => value == null ? 'Veuillez sélectionner une section' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSubCategory,
                isExpanded: true,
                items: _subCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: _selectedMainCategory == null || _isLoadingSubCategories ? null : (value) {
                  if (value != null) {
                    setState(() { _selectedSubCategory = value; });
                    _fetchProductsForSubCategory(value);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Catégorie',
                  border: defaultBorder,
                  focusedBorder: focusedBorder,
                  prefixIcon: _isLoadingSubCategories ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()) : null,
                ),
                validator: (value) => value == null ? 'Veuillez sélectionner une catégorie' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedProductId,
                isExpanded: true,
                items: _products.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['nom']))).toList(),
                onChanged: _selectedSubCategory == null || _isLoadingProducts ? null : (value) => setState(() { _selectedProductId = value; }),
                decoration: InputDecoration(
                  labelText: 'Produit',
                  border: defaultBorder,
                  focusedBorder: focusedBorder,
                  prefixIcon: _isLoadingProducts ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()) : null,
                ),
                hint: !_isLoadingProducts && _selectedSubCategory != null && _products.isEmpty
                    ? const Text('Aucun produit trouvé')
                    : null,
                validator: (value) => value == null ? 'Veuillez sélectionner un produit' : null,
              ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _serialNumberController,
                decoration: InputDecoration(
                  labelText: 'Numéro de Série',
                  border: defaultBorder,
                  focusedBorder: focusedBorder,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _openScanner,
                    color: primaryColor,
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Veuillez entrer un numéro de série' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _problemDescriptionController,
                decoration: InputDecoration(
                    labelText: 'Description du Problème',
                    border: defaultBorder,
                    focusedBorder: focusedBorder,
                    alignLabelWithHint: true
                ),
                maxLines: 4,
                validator: (value) => value!.isEmpty ? 'Veuillez décrire le problème' : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickItemPhotos,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text('Prendre des photos (${_pickedItemPhotos.length})'),
                style: OutlinedButton.styleFrom(foregroundColor: primaryColor, side: const BorderSide(color: primaryColor)),
              ),
              if (_pickedItemPhotos.isNotEmpty)
                Container(
                  height: 100,
                  margin: const EdgeInsets.only(top: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pickedItemPhotos.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Image.file(_pickedItemPhotos[index], width: 100, height: 100, fit: BoxFit.cover),
                      );
                    },
                  ),
                ),
              const Divider(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Signature du Gérant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                  TextButton(
                    child: const Text('Effacer'),
                    onPressed: () => _signatureController.clear(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.grey[200]!,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Créer le Ticket SAV'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
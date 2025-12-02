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
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';

// ✅ Helper class for batch items
class TicketItem {
  final String productId;
  final String productName;
  final String serialNumber;
  final String problemDescription;

  TicketItem({
    required this.productId,
    required this.productName,
    required this.serialNumber,
    required this.problemDescription,
  });
}

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
  final _itemFormKey = GlobalKey<FormState>(); // ✅ Key for the item entry part

  // ✅ 1. ADD THIS VARIABLE: State for ticket type selector
  String _selectedTicketType = 'standard';

  // Clients and stores
  List<QueryDocumentSnapshot> _clients = [];
  List<QueryDocumentSnapshot> _stores = [];
  bool _isLoadingClients = true;
  bool _isLoadingStores = false;
  String? _selectedClientId;
  String? _selectedStoreId;

  // Categories and products
  final List<String> _mainCategories = ['Antivol', 'TPV', 'Compteur Client'];
  String? _selectedMainCategory;
  List<String> _subCategories = [];
  bool _isLoadingSubCategories = false;
  String? _selectedSubCategory;
  List<QueryDocumentSnapshot> _products = [];
  bool _isLoadingProducts = false;
  String? _selectedProductId;

  // Technicians
  List<UserViewModel> _availableTechnicians = [];
  bool _isLoadingTechnicians = true;
  List<UserViewModel> _selectedTechnicians = [];

  // Form controllers
  final _serialNumberController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerEmailController = TextEditingController();
  final _problemDescriptionController = TextEditingController();
  DateTime? _pickupDate;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  List<File> _pickedMediaFiles = [];
  bool _isLoading = false;

  // ✅ List to store multiple items
  List<TicketItem> _addedItems = [];

  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';

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
    _managerEmailController.dispose();
    _problemDescriptionController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  bool _isVideoPath(String filePath) {
    final p = filePath.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv');
  }

  Future<void> _fetchClients() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .where('services', arrayContains: widget.serviceType)
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _clients = snapshot.docs;
          _isLoadingClients = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingClients = false);
    }
  }

  Future<void> _fetchStoresForClient(String clientId) async {
    setState(() {
      _isLoadingStores = true;
      _stores = [];
      _selectedStoreId = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _stores = snapshot.docs;
          _isLoadingStores = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStores = false);
    }
  }

  Future<void> _fetchAvailableTechnicians() async {
    setState(() => _isLoadingTechnicians = true);
    try {
      final includedRoles = [
        'Admin',
        'Responsable Administratif',
        'Responsable Commercial',
        'Responsable Technique',
        'Responsable IT',
        'Chef de Projet',
        'Technicien ST',
        'Technicien IT'
      ];
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: includedRoles)
          .orderBy('role')
          .orderBy('displayName')
          .get();
      final users = snapshot.docs
          .map((doc) => UserViewModel(id: doc.id, name: doc['displayName']))
          .toList();
      if (mounted) {
        setState(() {
          _availableTechnicians = users;
          _isLoadingTechnicians = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTechnicians = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur chargement techniciens')),
        );
      }
    }
  }

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
      final Set<String> categoriesSet = <String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final cat = data['categorie'];
        if (cat is String) {
          categoriesSet.add(cat);
        }
      }
      final sortedList = categoriesSet.toList()..sort();
      if (mounted) {
        setState(() {
          _subCategories = sortedList;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur chargement catégories')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingSubCategories = false);
    }
  }

  Future<void> _fetchProductsForSubCategory(String category) async {
    setState(() {
      _isLoadingProducts = true;
      _products = [];
      _selectedProductId = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('categorie', isEqualTo: category)
          .orderBy('nom')
          .get();
      if (mounted) {
        setState(() {
          _products = snapshot.docs;
          _isLoadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  // ✅ FIXED: Removed double Navigator.pop() to prevent closing the add page
  Future<void> _openScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScannerPage(
          onScan: (result) {
            // Only update the UI. Do NOT call Navigator.pop here.
            // ScannerPage handles the pop internally.
            setState(() {
              _serialNumberController.text = result;
            });
          },
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickupDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _pickupDate) {
      setState(() => _pickupDate = picked);
    }
  }

  Future<void> _pickMediaFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
    );
    if (result != null) {
      const maxFileSize = 50 * 1024 * 1024;
      final validFiles = result.files.where((file) {
        if (file.path != null && File(file.path!).existsSync()) {
          return File(file.path!).lengthSync() <= maxFileSize;
        }
        return false;
      }).toList();

      final rejectedCount = result.files.length - validFiles.length;

      setState(() {
        _pickedMediaFiles = validFiles.map((f) => File(f.path!)).toList();
      });

      if (rejectedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('$rejectedCount fichier(s) dépassent la limite de 50 Mo.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // --- START: NEW QUICK-ADD DIALOGS ---
  Future<void> _showAddClientDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final newClientId = await showDialog<String>(
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
                  final docRef = await FirebaseFirestore.instance
                      .collection('clients')
                      .add({
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'createdAt': Timestamp.now(),
                    'createdVia': 'sav_quick_add',
                    'services': [widget.serviceType],
                  });
                  Navigator.pop(context, docRef.id);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (newClientId != null && mounted) {
      await _fetchClients();
      setState(() {
        _selectedClientId = newClientId;
      });
      _fetchStoresForClient(newClientId);
    }
  }

  Future<void> _showAddStoreDialog() async {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez d\'abord sélectionner un client')),
      );
      return;
    }

    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final newStoreId = await showDialog<String>(
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
                  final docRef = await FirebaseFirestore.instance
                      .collection('clients')
                      .doc(_selectedClientId!)
                      .collection('stores')
                      .add({
                    'name': nameController.text.trim(),
                    'location': locationController.text.trim(),
                    'createdAt': Timestamp.now(),
                    'createdVia': 'sav_quick_add',
                  });
                  Navigator.pop(context, docRef.id);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (newStoreId != null && mounted) {
      await _fetchStoresForClient(_selectedClientId!);
      setState(() {
        _selectedStoreId = newStoreId;
      });
    }
  }
  // --- END: NEW QUICK-ADD DIALOGS ---

  // ✅ --- START: B2 HELPER FUNCTIONS ---
  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response =
      await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('Failed to get B2 credentials: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error calling Cloud Function: $e');
      return null;
    }
  }

  Future<String?> _uploadFileToB2(
      File file, Map<String, dynamic> b2Creds) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final fileName = path.basename(file.path);

      String? mimeType;
      if (fileName.toLowerCase().endsWith('.jpg') ||
          fileName.toLowerCase().endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (fileName.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (fileName.toLowerCase().endsWith('.mp4')) {
        mimeType = 'video/mp4';
      } else if (fileName.toLowerCase().endsWith('.mov')) {
        mimeType = 'video/quicktime';
      }

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': mimeType ?? 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final encodedPath = (body['fileName'] as String)
            .split('/')
            .map(Uri.encodeComponent)
            .join('/');
        return (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
      } else {
        debugPrint('Failed to upload to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file to B2: $e');
      return null;
    }
  }
  // ✅ --- END: B2 HELPER FUNCTIONS ---

  // ✅ NEW: Add item to list
  void _addItemToList() {
    if (_itemFormKey.currentState!.validate()) {
      // Find product name
      final prodDoc =
      _products.firstWhere((doc) => doc.id == _selectedProductId);

      setState(() {
        _addedItems.add(TicketItem(
          productId: _selectedProductId!,
          productName: prodDoc['nom'],
          serialNumber: _serialNumberController.text,
          problemDescription: _problemDescriptionController.text,
        ));

        // Clear ONLY item specific fields
        _serialNumberController.clear();
        _problemDescriptionController.clear();
        _selectedProductId = null;
        // Optional: Clear categories if you want users to re-select
        // _selectedSubCategory = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produit ajouté à la liste!')),
      );
    }
  }

  // ✅ NEW: Remove item from list
  void _removeItemFromList(int index) {
    setState(() {
      _addedItems.removeAt(index);
    });
  }

  // ✅ MODIFIED: Save batch tickets
  Future<void> _saveTicket() async {
    // Basic validation
    if (_selectedClientId == null || _managerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir les infos client/gérant.')),
      );
      return;
    }

    if (_addedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un produit à la liste.')),
      );
      return;
    }

    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature requise.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final clientDoc =
      _clients.firstWhere((doc) => doc.id == _selectedClientId);

      String? storeName;
      if (_selectedStoreId != null) {
        final storeDoc =
        _stores.firstWhere((doc) => doc.id == _selectedStoreId);
        storeName = '${storeDoc['name']} - ${storeDoc['location']}';
      }

      // --- 1. Reserve Block of Codes ---
      final year = DateTime.now().year;
      final counterRef = FirebaseFirestore.instance
          .collection('counters')
          .doc('sav_tickets_$year');

      final int startCount = await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(counterRef);
        final current = (snap.data()?['count'] as int?) ?? 0;
        final batchSize = _addedItems.length;
        final nextEnd = current + batchSize;
        tx.set(counterRef, {'count': nextEnd}, SetOptions(merge: true));
        return current + 1; // Return the first number of the reserved block
      });

      // --- 2. Upload Shared Assets (Signature & Media) ---
      // We use the FIRST code for the signature filename, or a unique ID
      final sigCode = 'BATCH-${startCount}_$year';

      final Uint8List? sigData = await _signatureController.toPngBytes();
      if (sigData == null) throw Exception("Impossible de générer la signature.");
      final sigRef =
      FirebaseStorage.instance.ref('sav_signatures/$sigCode.png');
      await sigRef.putData(sigData);
      final sigUrl = await sigRef.getDownloadURL();

      // Upload Media
      List<String> mediaUrls = [];
      if (_pickedMediaFiles.isNotEmpty) {
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials != null) {
          for (var file in _pickedMediaFiles) {
            final downloadUrl = await _uploadFileToB2(file, b2Credentials);
            if (downloadUrl != null) {
              mediaUrls.add(downloadUrl);
            }
          }
        }
      }

      // --- 3. Batch Write to Firestore ---
      final batch = FirebaseFirestore.instance.batch();
      final ticketsCollection = FirebaseFirestore.instance.collection('sav_tickets');

      for (int i = 0; i < _addedItems.length; i++) {
        final item = _addedItems[i];
        final currentCodeNumber = startCount + i;
        final codeStr = 'SAV-$currentCodeNumber/$year';

        final ticket = SavTicket(
          serviceType: widget.serviceType,
          savCode: codeStr,
          clientId: _selectedClientId!,
          clientName: clientDoc['name'],
          storeId: _selectedStoreId,
          storeName: storeName,
          pickupDate: _pickupDate ?? DateTime.now(),
          pickupTechnicianIds: _selectedTechnicians.map((u) => u.id).toList(),
          pickupTechnicianNames: _selectedTechnicians.map((u) => u.name).toList(),
          productName: item.productName,          // From Item
          serialNumber: item.serialNumber,        // From Item
          problemDescription: item.problemDescription, // From Item
          itemPhotoUrls: mediaUrls, // Shared media
          storeManagerName: _managerNameController.text,
          storeManagerEmail: _managerEmailController.text.trim().isEmpty ? null : _managerEmailController.text.trim(),
          storeManagerSignatureUrl: sigUrl, // Shared signature
          // ✅ 3. Update the _saveTicket logic: Set status and type based on selection
          status: _selectedTicketType == 'removal' ? 'Terminé' : 'Nouveau',
          ticketType: _selectedTicketType,
          createdBy: 'Current User',
          createdAt: DateTime.now(),
        );

        final newDocRef = ticketsCollection.doc(); // Auto ID
        batch.set(newDocRef, ticket.toJson());
      }

      await batch.commit();

      // --- 4. Success ---
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('${_addedItems.length} Tickets créés avec succès!')),
      );
      navigator.pop();

    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.orange;
    final focusedBorder = OutlineInputBorder(
      borderSide: const BorderSide(color: primaryColor, width: 2),
      borderRadius: BorderRadius.circular(12),
    );
    final defaultBorder = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(12),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Nouveau Ticket SAV (${widget.serviceType})'),
        backgroundColor: primaryColor,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER INFO ---
              const Text('Informations Client',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor)),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedClientId,
                      items: _clients
                          .map((doc) => DropdownMenuItem(
                        value: doc.id,
                        child: Text(doc['name']),
                      ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedClientId = value;
                            _selectedStoreId = null;
                            _stores = [];
                            _fetchStoresForClient(value);
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Client',
                        border: defaultBorder,
                        focusedBorder: focusedBorder,
                        prefixIcon: _isLoadingClients
                            ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                      v == null ? 'Sélectionner un client' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, size: 30),
                    color: primaryColor,
                    onPressed: _showAddClientDialog,
                    tooltip: 'Ajouter un nouveau client',
                    padding: const EdgeInsets.only(top: 8),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedStoreId,
                      items: _stores
                          .map((doc) => DropdownMenuItem(
                        value: doc.id,
                        child:
                        Text('${doc['name']} - ${doc['location']}'),
                      ))
                          .toList(),
                      onChanged: _selectedClientId == null
                          ? null
                          : (v) => setState(() => _selectedStoreId = v),
                      decoration: InputDecoration(
                        labelText: 'Magasin (Optionnel)',
                        border: defaultBorder,
                        focusedBorder: focusedBorder,
                        filled: _selectedClientId == null,
                        fillColor: _selectedClientId == null
                            ? Colors.grey.shade200
                            : null,
                        prefixIcon: _isLoadingStores
                            ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.store_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, size: 30),
                    color:
                    _selectedClientId != null ? primaryColor : Colors.grey,
                    onPressed:
                    _selectedClientId != null ? _showAddStoreDialog : null,
                    tooltip: 'Ajouter un nouveau magasin',
                    padding: const EdgeInsets.only(top: 8),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _managerNameController,
                decoration: InputDecoration(
                  labelText: 'Nom du Gérant/Contact',
                  border: defaultBorder,
                  focusedBorder: focusedBorder,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                v == null || v.isEmpty ? 'Entrer le nom' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _managerEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email du Gérant (Optionnel)',
                  hintText: 'pour recevoir le rapport PDF',
                  border: defaultBorder,
                  focusedBorder: focusedBorder,
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // ✅ 2. Add the Selector Widget: Dropdown for Ticket Type
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTicketType,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                    items: const [
                      DropdownMenuItem(
                        value: 'standard',
                        child: Row(
                          children: [
                            Icon(Icons.build_circle, color: Colors.orange),
                            SizedBox(width: 12),
                            Text('Réparation Standard (Atelier)'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'removal',
                        child: Row(
                          children: [
                            Icon(Icons.remove_circle, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Dépose Matériel (Laissé sur site)'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedTicketType = value);
                      }
                    },
                  ),
                ),
              ),

              const Divider(height: 40),
              const Text('Détails de la Récupération',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor)),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date de récupération',
                    border: defaultBorder,
                    focusedBorder: focusedBorder,
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(_pickupDate == null
                      ? 'Sélectionner une date'
                      : DateFormat('dd MMMM yyyy', 'fr_FR')
                      .format(_pickupDate!)),
                ),
              ),
              const SizedBox(height: 16),
              MultiSelectDialogField<UserViewModel>(
                items: _availableTechnicians
                    .map((u) => MultiSelectItem<UserViewModel>(u, u.name))
                    .toList(),
                title: const Text('Techniciens'),
                buttonText: _isLoadingTechnicians
                    ? const Text('Chargement...')
                    : const Text('Assigner techniciens'),
                onConfirm: (results) =>
                    setState(() => _selectedTechnicians = results),
                chipDisplay: MultiSelectChipDisplay(
                  chipColor: primaryColor.withOpacity(0.1),
                  textStyle: const TextStyle(color: primaryColor),
                ),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12)),
                validator: (vals) =>
                vals == null || vals.isEmpty ? 'Assigner au moins un' : null,
              ),

              const Divider(height: 40),

              // --- ✅ NEW ITEMS LIST SECTION ---
              if (_addedItems.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Appareils à récupérer',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue)),
                    Chip(
                      label: Text('${_addedItems.length}',
                          style: const TextStyle(color: Colors.white)),
                      backgroundColor: Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _addedItems.length,
                  itemBuilder: (context, index) {
                    final item = _addedItems[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(Icons.devices, color: Colors.blue),
                        ),
                        title: Text(item.productName,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'S/N: ${item.serialNumber}\nPanne: ${item.problemDescription}'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _removeItemFromList(index),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 30),
              ],

              // --- ✅ ENTRY FORM FOR NEW ITEM ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Form(
                  key: _itemFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ajouter un Appareil',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedMainCategory,
                        items: _mainCategories
                            .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedMainCategory = v;
                              _fetchCategoriesForMainSection(v);
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Section Principale',
                          border: defaultBorder,
                          focusedBorder: focusedBorder,
                          prefixIcon: const Icon(Icons.category_outlined),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (v) =>
                        v == null ? 'Requis' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedSubCategory,
                        items: _subCategories
                            .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: _selectedMainCategory == null ||
                            _isLoadingSubCategories
                            ? null
                            : (v) {
                          if (v != null) {
                            setState(() {
                              _selectedSubCategory = v;
                              _fetchProductsForSubCategory(v);
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Catégorie',
                          border: defaultBorder,
                          focusedBorder: focusedBorder,
                          prefixIcon: _isLoadingSubCategories
                              ? const Padding(
                            padding: EdgeInsets.all(8),
                            child:
                            CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.dashboard_customize_outlined),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (v) =>
                        v == null ? 'Requis' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedProductId,
                        items: _products
                            .map((doc) => DropdownMenuItem(
                          value: doc.id,
                          child: Text(doc['nom']),
                        ))
                            .toList(),
                        onChanged:
                        _selectedSubCategory == null || _isLoadingProducts
                            ? null
                            : (v) => setState(() => _selectedProductId = v),
                        decoration: InputDecoration(
                          labelText: 'Produit',
                          border: defaultBorder,
                          focusedBorder: focusedBorder,
                          prefixIcon: _isLoadingProducts
                              ? const Padding(
                            padding: EdgeInsets.all(8),
                            child:
                            CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.inventory_2_outlined),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (v) =>
                        v == null ? 'Requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _serialNumberController,
                        decoration: InputDecoration(
                          labelText: 'Numéro de Série',
                          border: defaultBorder,
                          focusedBorder: focusedBorder,
                          prefixIcon: const Icon(Icons.qr_code_2_outlined),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: _openScanner,
                            color: primaryColor,
                          ),
                        ),
                        validator: (v) =>
                        v == null || v.isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _problemDescriptionController,
                        decoration: InputDecoration(
                            labelText: 'Description du Problème',
                            border: defaultBorder,
                            focusedBorder: focusedBorder,
                            prefixIcon: const Icon(Icons.report_problem_outlined),
                            alignLabelWithHint: true),
                        maxLines: 2,
                        validator: (v) =>
                        v == null || v.isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addItemToList,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.grey.shade400)),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter cet appareil à la liste'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 40),
              OutlinedButton.icon(
                onPressed: _pickMediaFiles,
                icon: const Icon(Icons.perm_media_outlined),
                label: Text(
                    'Ajouter Photos/Vidéos (Lot complet) (${_pickedMediaFiles.length})'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: const BorderSide(color: primaryColor),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              if (_pickedMediaFiles.isNotEmpty)
                Container(
                  height: 100,
                  margin: const EdgeInsets.only(top: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pickedMediaFiles.length,
                    itemBuilder: (context, index) {
                      final file = _pickedMediaFiles[index];
                      final isVideo = _isVideoPath(file.path);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: isVideo
                                ? FutureBuilder<Uint8List?>(
                              future: VideoThumbnail.thumbnailData(
                                video: file.path,
                                imageFormat: ImageFormat.JPEG,
                                maxWidth: 100,
                                quality: 30,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                if (snapshot.hasData &&
                                    snapshot.data != null) {
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(snapshot.data!,
                                          fit: BoxFit.cover),
                                      const Center(
                                          child: Icon(
                                              Icons
                                                  .play_circle_fill_outlined,
                                              color: Colors.white70,
                                              size: 30)),
                                    ],
                                  );
                                }
                                return const Center(
                                    child: Icon(Icons.videocam_outlined,
                                        size: 40, color: Colors.black54));
                              },
                            )
                                : Image.file(file, fit: BoxFit.cover),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const Divider(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Signature du Gérant/Contact',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor)),
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
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isLoading
                      ? Container()
                      : const Icon(Icons.save_alt_outlined),
                  label: _isLoading
                      ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ))
                      : Text(
                      'Créer ${_addedItems.isEmpty ? "" : _addedItems.length} Tickets SAV'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
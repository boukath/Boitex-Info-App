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
import 'package:video_thumbnail/video_thumbnail.dart'; // ✅ ADDED for video thumbnails

class UserViewModel {
  final String id;
  final String name;
  UserViewModel({required this.id, required this.name});
}

class AddSavTicketPage extends StatefulWidget {
  final String serviceType;
  const AddSavTicketPage({super.key, required this.serviceType});

  @override
  State createState() => _AddSavTicketPageState();
}

class _AddSavTicketPageState extends State<AddSavTicketPage> {
  final _formKey = GlobalKey<FormState>();

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
  final _problemDescriptionController = TextEditingController();
  DateTime? _pickupDate;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  // ✅ RENAMED variable to hold media files
  List<File> _pickedMediaFiles = [];
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

  // Helper function for checking video type by path extension
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

  Future<void> _openScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScannerPage(
          onScan: (result) {
            setState(() {
              _serialNumberController.text = result;
            });
            Navigator.of(context).pop(result);
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

  // ✅ MODIFIED picker function
  Future<void> _pickMediaFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media, // Changed from FileType.image to FileType.media
      allowMultiple: true,
    );
    if (result != null) {
      // Basic size check (e.g., 50MB per file) - adjust as needed
      const maxFileSize = 50 * 1024 * 1024;
      final validFiles = result.files.where((file) {
        if (file.path != null && File(file.path!).existsSync()) {
          return File(file.path!).lengthSync() <= maxFileSize;
        }
        return false;
      }).toList();

      final rejectedCount = result.files.length - validFiles.length;

      setState(() {
        _pickedMediaFiles = // Use the renamed state variable
        validFiles.map((f) => File(f.path!)).toList();
      });

      if (rejectedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$rejectedCount fichier(s) dépassent la limite de 50 Mo.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _saveTicket() async {
    if (!_formKey.currentState!.validate()) return;
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature requise.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    // Capture context before async gaps
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final year = DateTime.now().year;
      final counterRef = FirebaseFirestore.instance
          .collection('counters')
          .doc('sav_tickets_$year');
      final newCode = await FirebaseFirestore.instance.runTransaction(
            (tx) async {
          final snap = await tx.get(counterRef);
          final current = (snap.data()?['count'] as int?) ?? 0;
          final next = current + 1;
          tx.set(counterRef, {'count': next}, SetOptions(merge: true));
          return 'SAV-$next/$year';
        },
      );

      final Uint8List? sigData = await _signatureController.toPngBytes();
      if (sigData == null) throw Exception("Impossible de générer la signature.");
      final sigRef = FirebaseStorage.instance
          .ref('sav_signatures/$newCode.png');
      await sigRef.putData(sigData);
      final sigUrl = await sigRef.getDownloadURL();

      // ✅ RENAMED variable for clarity
      List<String> mediaUrls = [];
      // ✅ Use the renamed state variable
      for (var file in _pickedMediaFiles) {
        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
        final ref =
        FirebaseStorage.instance.ref('sav_items/$newCode/$filename');
        await ref.putFile(file);
        mediaUrls.add(await ref.getDownloadURL());
      }

      final clientDoc = _clients
          .firstWhere((doc) => doc.id == _selectedClientId);
      final prodDoc = _products
          .firstWhere((doc) => doc.id == _selectedProductId);

      String? storeName;
      if (_selectedStoreId != null) {
        final storeDoc = _stores
            .firstWhere((doc) => doc.id == _selectedStoreId);
        storeName = '${storeDoc['name']} - ${storeDoc['location']}';
      }

      final ticket = SavTicket(
        serviceType: widget.serviceType,
        savCode: newCode,
        clientId: _selectedClientId!,
        clientName: clientDoc['name'],
        storeId: _selectedStoreId,
        storeName: storeName,
        pickupDate: _pickupDate ?? DateTime.now(),
        pickupTechnicianIds:
        _selectedTechnicians.map((u) => u.id).toList(),
        pickupTechnicianNames:
        _selectedTechnicians.map((u) => u.name).toList(),
        productName: prodDoc['nom'],
        serialNumber: _serialNumberController.text,
        problemDescription: _problemDescriptionController.text,
        // ✅ Use mediaUrls here. IMPORTANT: The SavTicket model still expects 'itemPhotoUrls'.
        // Ideally, you should rename the field in the SavTicket model to 'itemMediaUrls'.
        // For now, we are assigning mediaUrls to the existing field name.
        itemPhotoUrls: mediaUrls,
        storeManagerName: _managerNameController.text,
        storeManagerSignatureUrl: sigUrl,
        status: 'Nouveau',
        createdBy: 'Current User', // TODO: Replace with actual user name/ID
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('sav_tickets')
          .add(ticket.toJson());

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Ticket créé!')),
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
              const Text('Informations Client',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
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
                validator: (v) => v == null ? 'Sélectionner un client' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStoreId,
                items: _stores
                    .map((doc) => DropdownMenuItem(
                  value: doc.id,
                  child: Text('${doc['name']} - ${doc['location']}'),
                ))
                    .toList(),
                onChanged: _selectedClientId == null
                    ? null
                    : (v) => setState(() => _selectedStoreId = v),
                decoration: InputDecoration(
                  labelText: 'Magasin (Optionnel)',
                  border: defaultBorder,
                  focusedBorder: focusedBorder,
                  prefixIcon: _isLoadingStores
                      ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.store_outlined),
                ),
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
                      : DateFormat('dd MMMM yyyy', 'fr_FR').format(_pickupDate!)),
                ),
              ),
              const SizedBox(height: 16),
              MultiSelectDialogField<UserViewModel>( // ✅ CORRECTED - REMOVED buttonIcon
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
              const Text('Informations Produit',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedMainCategory,
                items: _mainCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
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
                ),
                validator: (v) =>
                v == null ? 'Sélectionner une section' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSubCategory,
                items: _subCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: _selectedMainCategory == null || _isLoadingSubCategories
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.dashboard_customize_outlined),
                ),
                validator: (v) => v == null ? 'Sélectionner une catégorie' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedProductId,
                items: _products
                    .map((doc) => DropdownMenuItem(
                  value: doc.id,
                  child: Text(doc['nom']),
                ))
                    .toList(),
                onChanged: _selectedSubCategory == null || _isLoadingProducts
                    ? null
                    : (v) => setState(() => _selectedProductId = v),
                decoration: InputDecoration(
                  labelText: 'Produit',
                  border: defaultBorder,
                  focusedBorder: focusedBorder,
                  prefixIcon: _isLoadingProducts
                      ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.inventory_2_outlined),
                ),
                hint: !_isLoadingProducts &&
                    _selectedSubCategory != null &&
                    _products.isEmpty
                    ? const Text('Aucun produit')
                    : null,
                validator: (v) => v == null ? 'Sélectionner un produit' : null,
              ),

              const SizedBox(height: 16),
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
                validator: (v) => v == null || v.isEmpty
                    ? 'Entrer le numéro de série'
                    : null,
              ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _problemDescriptionController,
                decoration: InputDecoration(
                    labelText: 'Description du Problème',
                    border: defaultBorder,
                    focusedBorder: focusedBorder,
                    prefixIcon: const Icon(Icons.report_problem_outlined),
                    alignLabelWithHint: true),
                maxLines: 4,
                validator: (v) =>
                v == null || v.isEmpty ? 'Décrire le problème' : null,
              ),

              const SizedBox(height: 16),
              OutlinedButton.icon(
                // ✅ UPDATED picker function call
                onPressed: _pickMediaFiles,
                icon: const Icon(Icons.perm_media_outlined),
                // ✅ UPDATED button text and count variable
                label:
                Text('Ajouter Photos/Vidéos (${_pickedMediaFiles.length})'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: const BorderSide(color: primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              // ✅ UPDATED media list view
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
                            // Video Thumbnail
                                ? FutureBuilder<Uint8List?>(
                              future: VideoThumbnail.thumbnailData(
                                video: file.path,
                                imageFormat: ImageFormat.JPEG,
                                maxWidth: 100,
                                quality: 30,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                if (snapshot.hasData && snapshot.data != null) {
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(snapshot.data!, fit: BoxFit.cover),
                                      const Center(child: Icon(Icons.play_circle_fill_outlined, color: Colors.white70, size: 30)),
                                    ],
                                  );
                                }
                                // Fallback icon for video if thumbnail fails
                                return const Center(child: Icon(Icons.videocam_outlined, size: 40, color: Colors.black54));
                              },
                            )
                            // Image File
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isLoading ? Container() : const Icon(Icons.save_alt_outlined),
                  label: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
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
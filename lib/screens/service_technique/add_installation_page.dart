// lib/screens/service_technique/add_installation_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boitex_info_app/utils/user_roles.dart';

// Product Selection Imports
import 'package:boitex_info_app/models/selection_models.dart';
// ✅ Global Search Page
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';

// Technician Multi-Select Import
import 'package:multi_select_flutter/multi_select_flutter.dart';

// ✅ B2 IMPORTS & HTTP
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';

// --- Reusable data models ---
class Client {
  final String id;
  final String name;
  Client({required this.id, required this.name});

  @override
  bool operator ==(Object other) => other is Client && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ✅ UPDATED STORE MODEL: Added Lat/Lng
class Store {
  final String id;
  final String name;
  final String location;
  final double? latitude;
  final double? longitude;

  Store({
    required this.id,
    required this.name,
    required this.location,
    this.latitude,
    this.longitude,
  });

  @override
  bool operator ==(Object other) => other is Store && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class AppUser {
  final String uid;
  final String displayName;
  AppUser({required this.uid, required this.displayName});
  @override
  bool operator ==(Object other) => other is AppUser && other.uid == uid;
  @override
  int get hashCode => uid.hashCode;
}
// --- End data models ---

class AddInstallationPage extends StatefulWidget {
  final String userRole;
  final String serviceType;
  // 👇 Added to support Editing
  final DocumentSnapshot? installationToEdit;

  const AddInstallationPage({
    super.key,
    required this.userRole,
    required this.serviceType,
    this.installationToEdit,
  });

  @override
  State<AddInstallationPage> createState() => _AddInstallationPageState();
}

class _AddInstallationPageState extends State<AddInstallationPage> {
  final _formKey = GlobalKey<FormState>();
  final _requestController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _clientEmailController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _clientSearchController = TextEditingController();
  final _storeSearchController = TextEditingController();

  // ✅ GPS Link Controller
  final _gpsLinkController = TextEditingController();

  final _newClientNameController = TextEditingController();
  final _newStoreNameController = TextEditingController();
  final _newStoreLocationController = TextEditingController();

  Client? _selectedClient;
  Store? _selectedStore;

  // ✅ GPS Parsed State
  double? _parsedLat;
  double? _parsedLng;
  bool _isResolvingLink = false;

  // Mode flag
  bool _isEditing = false;

  List<Client> _clients = [];
  List<Store> _stores = [];
  bool _isLoading = false;
  bool _isFetchingClients = false;
  bool _isFetchingStores = false;

  // Product Selection State
  List<ProductSelection> _selectedProducts = [];

  // State variables for technicians
  List<AppUser> _allTechnicians = [];
  List<AppUser> _selectedTechnicians = [];
  bool _isFetchingTechnicians = false;

  // State for file attachment
  File? _pickedFile;
  String? _pickedFileName;
  bool _isUploadingFile = false;
  // Keep track of existing file url if editing
  String? _existingFileUrl;

  // ✅ Prevents double dialogs
  bool _isDialogShowing = false;

  static const Color primaryColor = Colors.green;

  // ✅ B2 CONSTANT
  static const String _b2UploadCredentialUrl =
      "https://europe-west1-your-firebase-project.cloudfunctions.net/b2GetUploadCredentials";

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _fetchTechnicians();

    // ✅ CHECK FOR EDIT MODE
    if (widget.installationToEdit != null) {
      _isEditing = true;
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    final data = widget.installationToEdit!.data() as Map<String, dynamic>;

    // 1. Text Fields
    _requestController.text = data['initialRequest'] ?? '';
    _clientPhoneController.text = data['clientPhone'] ?? '';
    _clientEmailController.text = data['clientEmail'] ?? '';
    _contactNameController.text = data['contactName'] ?? '';

    // 2. Client
    if (data['clientId'] != null) {
      _selectedClient =
          Client(id: data['clientId'], name: data['clientName'] ?? '');
      _clientSearchController.text = data['clientName'] ?? '';
      _fetchStores(data['clientId']);
    }

    // 3. Store & GPS
    if (data['storeId'] != null) {
      double? lat = data['storeLatitude'];
      double? lng = data['storeLongitude'];

      _selectedStore = Store(
        id: data['storeId'],
        name: data['storeName'] ?? '',
        location: data['storeLocation'] ?? '',
        latitude: lat,
        longitude: lng,
      );
      _storeSearchController.text =
      '${data['storeName']} (${data['storeLocation']})';
    }

    // 4. Products
    if (data['orderedProducts'] != null) {
      var list = List<Map<String, dynamic>>.from(data['orderedProducts']);
      _selectedProducts = list
          .map((p) => ProductSelection(
        productId: p['productId'],
        productName: p['productName'],
        quantity: p['quantity'],
        partNumber: p['reference'] ?? '',
        marque: p['marque'] ?? '',
      ))
          .toList();
    }

    // 5. Technicians
    if (data['assignedTechnicians'] != null) {
      var list = List<Map<String, dynamic>>.from(data['assignedTechnicians']);
      _selectedTechnicians = list
          .map((t) => AppUser(
        uid: t['uid'],
        displayName: t['displayName'] ?? '',
      ))
          .toList();
    }

    // 6. File
    if (data['preliminaryFileUrl'] != null) {
      _existingFileUrl = data['preliminaryFileUrl'];
      _pickedFileName = data['preliminaryFileName'];
    }
  }

  @override
  void dispose() {
    _requestController.dispose();
    _clientPhoneController.dispose();
    _clientEmailController.dispose();
    _contactNameController.dispose();
    _clientSearchController.dispose();
    _storeSearchController.dispose();
    _newClientNameController.dispose();
    _newStoreNameController.dispose();
    _newStoreLocationController.dispose();
    _gpsLinkController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // 🔗 GPS LINK PARSER LOGIC
  // ----------------------------------------------------------------------
  Future<void> _extractCoordinatesFromLink() async {
    String url = _gpsLinkController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isResolvingLink = true);

    try {
      if (url.contains('goo.gl') ||
          url.contains('maps.app.goo.gl') ||
          url.contains('bit.ly')) {
        final client = http.Client();
        var request = http.Request('HEAD', Uri.parse(url));
        request.followRedirects = false;
        var response = await client.send(request);
        if (response.headers['location'] != null) {
          url = response.headers['location']!;
        }
      }

      RegExp regExp = RegExp(r'(@|q=)([-+]?\d{1,2}\.\d+),([-+]?\d{1,3}\.\d+)');
      Match? match = regExp.firstMatch(url);

      if (match != null && match.groupCount >= 3) {
        setState(() {
          _parsedLat = double.parse(match.group(2)!);
          _parsedLng = double.parse(match.group(3)!);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Coordonnées extraites !"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("❌ Impossible de trouver les coordonnées."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de l'analyse : $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResolvingLink = false);
    }
  }

  Future<void> _fetchClients() async {
    setState(() => _isFetchingClients = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .orderBy('name')
          .get();
      _clients = snapshot.docs
          .map((doc) => Client(id: doc.id, name: doc.data()['name'] ?? 'N/A'))
          .toList();
    } catch (e) {
      print('Error fetching clients: $e');
    } finally {
      if (mounted) setState(() => _isFetchingClients = false);
    }
  }

  Future<void> _fetchStores(String clientId) async {
    setState(() {
      _isFetchingStores = true;
      if (!_isEditing) {
        _selectedStore = null;
        _parsedLat = null;
        _parsedLng = null;
        _gpsLinkController.clear();
        _storeSearchController.clear();
      }
      _stores = [];
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .orderBy('name')
          .get();
      _stores = snapshot.docs.map((doc) {
        final data = doc.data();
        double? lat;
        double? lng;
        if (data['latitude'] != null) lat = (data['latitude'] as num).toDouble();
        if (data['longitude'] != null)
          lng = (data['longitude'] as num).toDouble();

        return Store(
          id: doc.id,
          name: data['name'] ?? 'N/A',
          location: data['location'] ?? 'N/A',
          latitude: lat,
          longitude: lng,
        );
      }).toList();
    } catch (e) {
      print('Error fetching stores: $e');
    } finally {
      if (mounted) setState(() => _isFetchingStores = false);
    }
  }

  Future<void> _fetchTechnicians() async {
    setState(() => _isFetchingTechnicians = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: [
        UserRoles.admin,
        UserRoles.responsableAdministratif,
        UserRoles.responsableCommercial,
        UserRoles.responsableTechnique,
        UserRoles.responsableIT,
        UserRoles.chefDeProjet,
        UserRoles.technicienST,
        UserRoles.technicienIT
      ]).get();

      final allTechnicians = snapshot.docs
          .map((doc) => AppUser(
          uid: doc.id,
          displayName: doc.data()['displayName'] as String? ??
              'Utilisateur Inconnu'))
          .toList();
      if (mounted) setState(() => _allTechnicians = allTechnicians);
    } catch (e) {
      print("Error fetching technicians: $e");
    } finally {
      if (mounted) setState(() => _isFetchingTechnicians = false);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedFile = File(result.files.single.path!);
        _pickedFileName = result.files.single.name;
        _existingFileUrl = null;
      });
    }
  }

  Future<String?> _uploadFileToB2(String installationCodeOrTempId) async {
    if (_pickedFile == null) return _existingFileUrl;

    setState(() => _isUploadingFile = true);

    try {
      final authResponse = await http.get(Uri.parse(_b2UploadCredentialUrl));

      if (authResponse.statusCode != 200) {
        throw Exception('Failed to get B2 credentials');
      }

      final authData = jsonDecode(authResponse.body);
      final uploadUrl = authData['uploadUrl'] as String;
      final authorizationToken = authData['authorizationToken'] as String;

      final fileBytes = await _pickedFile!.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final fileMimeType = _pickedFileName!.endsWith('.pdf')
          ? 'application/pdf'
          : 'image/jpeg';
      final fileName =
          'installation_files/${installationCodeOrTempId}_${DateTime.now().millisecondsSinceEpoch}_${_pickedFileName}';

      final uploadResponse = await http.post(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': authorizationToken,
          'X-Bz-File-Name': fileName,
          'Content-Type': fileMimeType,
          'X-Bz-Content-Sha1': sha1Hash,
        },
        body: fileBytes,
      );

      if (uploadResponse.statusCode == 200) {
        final uploadData = jsonDecode(uploadResponse.body);
        return uploadData['fileId'] != null
            ? "https://f005.backblazeb2.com/file/boitex-bucket/${fileName}"
            : null;
      } else {
        throw Exception('B2 Upload failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Échec de l\'envoi du fichier: $e'),
              backgroundColor: Colors.red),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  // -----------------------------------------------------------------
  // 🛍️ NEW: GLOBAL PRODUCT SEARCH INTEGRATION (CONTINUOUS SELECTION)
  // -----------------------------------------------------------------

  /// Opens the Global Search Page in Selection Mode
  void _openGlobalProductSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GlobalProductSearchPage(
          isSelectionMode: true,
          // ✅ CONTINUOUS SELECTION LOGIC:
          // The Search Page STAYS OPEN. It calls this function every time
          // the user picks a product. We show the qty dialog ON TOP of the search page.
          onProductSelected: (productData) {
            // Check for double taps
            if (_isDialogShowing) return;
            _isDialogShowing = true;

            _showQuantityDialog(productData).then((_) {
              _isDialogShowing = false;
            });
          },
        ),
      ),
    );
  }

  /// Shows a dialog to ask for quantity, then adds to list
  Future<void> _showQuantityDialog(Map<String, dynamic> productData) async {
    final TextEditingController qtyController =
    TextEditingController(text: '1');

    // ✅ ROBUST NAME CHECK
    final String productName = productData['nom'] ??
        productData['name'] ??
        productData['productName'] ??
        'Produit Inconnu';

    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental close
      builder: (ctx) => AlertDialog(
        title: Text("Quantité: $productName"),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Nombre d'unités",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              final int qty = int.tryParse(qtyController.text) ?? 1;
              _addProductToList(productData, qty);
              Navigator.of(ctx).pop();
            },
            child: const Text("Ajouter"),
          )
        ],
      ),
    );
  }

  /// Helper to map Firestore Map -> ProductSelection Model
  void _addProductToList(Map<String, dynamic> data, int quantity) {
    // Note: Ensure 'id' is in the map.
    final productId = data['id'] ?? data['productId'] ?? 'unknown_id';

    // ✅ ROBUST FIELD MAPPING
    final String productName =
        data['nom'] ?? data['name'] ?? data['productName'] ?? 'Produit Inconnu';
    final String partNumber =
        data['reference'] ?? data['partNumber'] ?? data['ref'] ?? '';
    final String marque = data['marque'] ?? data['brand'] ?? '';

    final newProduct = ProductSelection(
      productId: productId,
      productName: productName,
      quantity: quantity,
      partNumber: partNumber,
      marque: marque,
    );

    setState(() {
      _selectedProducts.add(newProduct);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
        Text("${newProduct.quantity}x ${newProduct.productName} ajouté!"),
        duration: const Duration(milliseconds: 800), // Short duration for rapid adding
        backgroundColor: Colors.green,
      ),
    );
  }

  // -----------------------------------------------------------------
  // 💾 SAVE INSTALLATION
  // -----------------------------------------------------------------
  Future<void> _saveInstallation() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClient == null || _selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez choisir un client et un magasin'),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (_gpsLinkController.text.trim().isNotEmpty && _parsedLat == null) {
      await _extractCoordinatesFromLink();
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Erreur: Utilisateur non trouvé')));
      setState(() => _isLoading = false);
      return;
    }

    final currentYear = DateTime.now().year.toString();
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('installation_counter_$currentYear');

    final DocumentReference installationRef = _isEditing
        ? widget.installationToEdit!.reference
        : FirebaseFirestore.instance.collection('installations').doc();

    final storeRef = FirebaseFirestore.instance
        .collection('clients')
        .doc(_selectedClient!.id)
        .collection('stores')
        .doc(_selectedStore!.id);

    try {
      String? fileUrl;
      String? fileName;
      final tempId = _isEditing
          ? widget.installationToEdit!.id
          : DateTime.now().millisecondsSinceEpoch.toString();

      if (_pickedFile != null) {
        fileUrl = await _uploadFileToB2(tempId);
        fileName = _pickedFileName;
      } else {
        fileUrl = _existingFileUrl;
        fileName = _pickedFileName;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final createdByName = userDoc.data()?['displayName'] ?? 'N/A';

      List<Map<String, dynamic>> enrichedProducts = [];
      for (var p in _selectedProducts) {
        String category = 'Autre';
        String? imageUrl;
        String reference = p.partNumber;
        String brand = p.marque;

        enrichedProducts.add({
          'productId': p.productId,
          'productName': p.productName,
          'reference': reference,
          'marque': brand,
          'category': category,
          'image': imageUrl,
          'quantity': p.quantity,
          'serialNumbers': [],
        });
      }

      final systems = enrichedProducts.map((p) {
        return {
          'id': p['productId'],
          'name': p['productName'],
          'reference': p['reference'],
          'marque': p['marque'],
          'category': p['category'],
          'image': p['image'],
          'quantity': p['quantity'],
          'serialNumbers': List<String>.filled(p['quantity'] as int, ''),
        };
      }).toList();

      final techniciansToSave = _selectedTechnicians
          .map((user) => {'uid': user.uid, 'displayName': user.displayName})
          .toList();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        String installationCode;

        if (_isEditing) {
          installationCode = widget.installationToEdit!.get('installationCode');
        } else {
          final counterDoc = await transaction.get(counterRef);
          int newCount = 1;
          if (counterDoc.exists) {
            final data = counterDoc.data();
            if (data != null && data.containsKey('count')) {
              newCount = data['count'] + 1;
            }
          }
          installationCode = 'INST-$newCount/$currentYear';
          transaction.set(
              counterRef, {'count': newCount}, SetOptions(merge: true));
        }

        final double? finalLat = _parsedLat ?? _selectedStore!.latitude;
        final double? finalLng = _parsedLng ?? _selectedStore!.longitude;

        if (_parsedLat != null && _parsedLng != null) {
          transaction.update(storeRef, {
            'latitude': _parsedLat,
            'longitude': _parsedLng,
          });
        }

        final Map<String, dynamic> dataToSave = {
          'installationCode': installationCode,
          'clientName': _selectedClient!.name,
          'clientId': _selectedClient!.id,
          'clientPhone': _clientPhoneController.text.trim(),
          'clientEmail': _clientEmailController.text.trim(),
          'contactName': _contactNameController.text.trim(),
          'storeName': _selectedStore!.name,
          'storeId': _selectedStore!.id,
          'storeLocation': _selectedStore!.location,
          'storeLatitude': finalLat,
          'storeLongitude': finalLng,
          'initialRequest': _requestController.text.trim(),
          'serviceType': widget.serviceType,
          'preliminaryFileUrl': fileUrl,
          'preliminaryFileName': fileName,
          'assignedTechnicians': techniciansToSave,
          'orderedProducts': enrichedProducts,
          'systems': systems,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (!_isEditing) {
          dataToSave['status'] = 'À Planifier';
          dataToSave['createdAt'] = FieldValue.serverTimestamp();
          dataToSave['createdById'] = user.uid;
          dataToSave['createdByName'] = createdByName;
          dataToSave['mediaUrls'] = [];
          dataToSave['technicalEvaluation'] = [];
          dataToSave['itEvaluation'] = [];
          transaction.set(installationRef, dataToSave);
        } else {
          transaction.update(installationRef, dataToSave);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isEditing
                  ? 'Modification enregistrée!'
                  : 'Installation créée!'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Client Dialog ---
  Future<void> _showAddClientDialog() async {
    _newClientNameController.clear();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Ajouter un Nouveau Client'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: _newClientNameController,
                decoration: const InputDecoration(labelText: 'Nom du Client'),
                validator: (value) =>
                value == null || value.isEmpty ? 'Nom requis' : null,
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler')),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                  if (formKey.currentState!.validate()) {
                    setDialogState(() => isSaving = true);
                    try {
                      final docRef = await FirebaseFirestore.instance
                          .collection('clients')
                          .add({
                        'name': _newClientNameController.text.trim(),
                        'createdAt': Timestamp.now(),
                      });
                      final newClient = Client(
                          id: docRef.id,
                          name: _newClientNameController.text.trim());
                      await _fetchClients();
                      setState(() {
                        _selectedClient = newClient;
                        _clientSearchController.text = newClient.name;
                        _fetchStores(newClient.id);
                      });
                      Navigator.of(dialogContext).pop();
                    } catch (e) {
                      print(e);
                    }
                  }
                },
                child: isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Store Dialog ---
  Future<void> _showAddStoreDialog() async {
    if (_selectedClient == null) return;
    _newStoreNameController.clear();
    _newStoreLocationController.clear();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text('Ajouter Magasin pour\n${_selectedClient!.name}'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _newStoreNameController,
                    decoration:
                    const InputDecoration(labelText: 'Nom du Magasin'),
                    validator: (value) => value!.isEmpty ? 'Nom requis' : null,
                  ),
                  TextFormField(
                    controller: _newStoreLocationController,
                    decoration: const InputDecoration(
                        labelText: 'Localisation (Ville)'),
                    validator: (value) => value!.isEmpty ? 'Requis' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler')),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                  if (formKey.currentState!.validate()) {
                    setDialogState(() => isSaving = true);
                    try {
                      final docRef = await FirebaseFirestore.instance
                          .collection('clients')
                          .doc(_selectedClient!.id)
                          .collection('stores')
                          .add({
                        'name': _newStoreNameController.text.trim(),
                        'location':
                        _newStoreLocationController.text.trim(),
                        'createdAt': Timestamp.now(),
                      });
                      final newStore = Store(
                          id: docRef.id,
                          name: _newStoreNameController.text.trim(),
                          location:
                          _newStoreLocationController.text.trim());
                      await _fetchStores(_selectedClient!.id);
                      setState(() {
                        _selectedStore = newStore;
                        _storeSearchController.text =
                        '${newStore.name} (${newStore.location})';
                      });
                      Navigator.of(dialogContext).pop();
                    } catch (e) {
                      print(e);
                    }
                  }
                },
                child: isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
    );
    final focusedBorder = defaultBorder.copyWith(
      borderSide: const BorderSide(color: primaryColor, width: 2.0),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? 'Modifier Installation'
            : 'Créer Installation Directe'),
        backgroundColor: primaryColor,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Client Selection
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownMenu<Client>(
                      controller: _clientSearchController,
                      requestFocusOnTap: true,
                      label: const Text('Client'),
                      hintText: 'Rechercher un client...',
                      expandedInsets: EdgeInsets.zero,
                      leadingIcon: _isFetchingClients
                          ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.person_outline),
                      dropdownMenuEntries: _clients
                          .map((client) => DropdownMenuEntry<Client>(
                          value: client, label: client.name))
                          .toList(),
                      onSelected: (Client? client) {
                        setState(() {
                          _selectedClient = client;
                          if (client != null) _fetchStores(client.id);
                        });
                      },
                      inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: defaultBorder,
                          focusedBorder: focusedBorder),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_business_outlined,
                        color: primaryColor),
                    onPressed: _showAddClientDialog,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Store Selection
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownMenu<Store>(
                      controller: _storeSearchController,
                      requestFocusOnTap: true,
                      label: const Text('Magasin'),
                      hintText: 'Rechercher un magasin...',
                      enabled: _selectedClient != null && !_isFetchingStores,
                      expandedInsets: EdgeInsets.zero,
                      leadingIcon: _isFetchingStores
                          ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.store_outlined),
                      dropdownMenuEntries: _stores
                          .map((store) => DropdownMenuEntry<Store>(
                          value: store,
                          label: '${store.name} (${store.location})'))
                          .toList(),
                      onSelected: (Store? store) {
                        setState(() {
                          _selectedStore = store;
                          _parsedLat = null;
                          _parsedLng = null;
                          _gpsLinkController.clear();
                        });
                      },
                      inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: defaultBorder,
                          focusedBorder: focusedBorder),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_shopping_cart_outlined,
                        color: primaryColor),
                    onPressed: (_selectedClient == null || _isFetchingStores)
                        ? null
                        : _showAddStoreDialog,
                  ),
                ],
              ),

              // GPS Section
              if (_selectedStore != null)
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueGrey.shade100),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            (_selectedStore!.latitude != null ||
                                _parsedLat != null)
                                ? Icons.check_circle
                                : Icons.warning_amber_rounded,
                            color: (_selectedStore!.latitude != null ||
                                _parsedLat != null)
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (_selectedStore!.latitude != null)
                                  ? "Position Magasin Synchronisée"
                                  : (_parsedLat != null)
                                  ? "Position prête à être sauvegardée"
                                  : "Position GPS manquante",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: (_selectedStore!.latitude != null ||
                                    _parsedLat != null)
                                    ? Colors.green.shade700
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedStore!.latitude == null ||
                          _parsedLat != null) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _gpsLinkController,
                                decoration: const InputDecoration(
                                  labelText: 'Coller un lien Google Maps ici',
                                  hintText: 'https://goo.gl/maps/...',
                                  prefixIcon: Icon(Icons.link),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isResolvingLink
                                  ? null
                                  : _extractCoordinatesFromLink,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16)),
                              child: _isResolvingLink
                                  ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.search),
                            ),
                          ],
                        ),
                        if (_parsedLat != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                                "📍 Coordonnées détectées : $_parsedLat, $_parsedLng",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.teal)),
                          ),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Other Fields
              TextFormField(
                controller: _clientPhoneController,
                decoration: InputDecoration(
                    labelText: 'Téléphone (Client/Magasin)',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    enabledBorder: defaultBorder,
                    focusedBorder: focusedBorder),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _clientEmailController,
                decoration: InputDecoration(
                    labelText: 'Email Client',
                    prefixIcon: const Icon(Icons.alternate_email),
                    enabledBorder: defaultBorder,
                    focusedBorder: focusedBorder),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _contactNameController,
                decoration: InputDecoration(
                    labelText: 'Nom du Contact (sur site)',
                    prefixIcon: const Icon(Icons.person_pin_outlined),
                    enabledBorder: defaultBorder,
                    focusedBorder: focusedBorder),
              ),
              const SizedBox(height: 20),

              // File
              Text('Fichier Préliminaire (Optionnel)',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploadingFile ? null : _pickFile,
                      icon: Icon(
                          _pickedFile == null
                              ? Icons.attach_file
                              : Icons.file_present,
                          color: primaryColor),
                      label: Text(
                        _pickedFile == null
                            ? (_existingFileUrl != null
                            ? 'Fichier existant (Toucher pour changer)'
                            : 'Joindre un fichier (PDF/Image)')
                            : _pickedFileName!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: primaryColor),
                      ),
                      style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: primaryColor.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  if (_pickedFile != null && !_isUploadingFile) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _pickedFile = null;
                          _pickedFileName = null;
                        });
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _requestController,
                decoration: InputDecoration(
                    labelText: 'Description de la Demande',
                    enabledBorder: defaultBorder,
                    focusedBorder: focusedBorder,
                    alignLabelWithHint: true),
                maxLines: 5,
                validator: (value) =>
                value == null || value.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 20),

              MultiSelectDialogField<AppUser>(
                items: _allTechnicians
                    .map((user) =>
                    MultiSelectItem<AppUser>(user, user.displayName))
                    .toList(),
                initialValue: _selectedTechnicians,
                title: const Text("Sélectionner Techniciens"),
                buttonText: Text("Assigner à",
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12)),
                onConfirm: (results) {
                  setState(() {
                    _selectedTechnicians = results.cast<AppUser>();
                  });
                },
              ),
              const SizedBox(height: 20),

              // ✅ NEW PRODUCT LIST SECTION
              _buildProductList(),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                  (_isLoading || _isUploadingFile) ? null : _saveInstallation,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0))),
                  child: (_isLoading || _isUploadingFile)
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isEditing
                      ? 'Modifier l\'Installation'
                      : 'Créer l\'Installation'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ UPDATED: Product List with Delete Button & Global Search Trigger
  Widget _buildProductList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Produits à Installer',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12.0),
          ),
          height: _selectedProducts.isEmpty ? 80 : 150,
          child: _selectedProducts.isEmpty
              ? const Center(
              child: Text('Aucun produit sélectionné.',
                  style: TextStyle(color: Colors.grey)))
              : ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: _selectedProducts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = _selectedProducts[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.inventory_2_outlined,
                    color: primaryColor),
                title: Text(product.productName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text("Ref: ${product.partNumber}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Qté: ${product.quantity}',
                        style:
                        const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 20),
                      onPressed: () {
                        setState(() {
                          _selectedProducts.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton.icon(
            // ✅ Calls the new Global Search method
            onPressed: _openGlobalProductSearch,
            icon: const Icon(Icons.add_circle_outline, color: primaryColor),
            label: Text(
                _selectedProducts.isEmpty
                    ? 'Ajouter des Produits'
                    : 'Ajouter un autre Produit',
                style: const TextStyle(color: primaryColor)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primaryColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }
}
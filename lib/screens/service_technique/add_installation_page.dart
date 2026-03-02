// lib/screens/service_technique/add_installation_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ PREMIUM UI ADDITION

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

// ----------------------------------------------------------------------
// 📦 LOCAL DATA MODELS
// ----------------------------------------------------------------------

class InstallationProduct {
  final String productId;
  final String productName;
  final int quantity;
  final String partNumber;
  final String marque;
  bool isClientSupply;

  InstallationProduct({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.partNumber,
    required this.marque,
    this.isClientSupply = false,
  });
}

class Client {
  final String id;
  final String name;
  Client({required this.id, required this.name});
  @override
  bool operator ==(Object other) => other is Client && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

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

// ----------------------------------------------------------------------
// 🎨 THEME CONSTANTS (4K Premium 2026 Vibe)
// ----------------------------------------------------------------------
const Color kPrimaryColor = Color(0xFF10B981); // Emerald 500
const Color kPrimaryDark = Color(0xFF047857); // Emerald 700
const Color kProjectColor = Color(0xFF4F46E5); // Indigo for Projects
const Color kClientSupplyColor = Color(0xFFF59E0B); // Amber 500
const Color kBackgroundColor = Color(0xFFF5F7FA); // Modern Slate 50
const Color kSurfaceColor = Colors.white;
const Color kTextPrimary = Color(0xFF1E293B); // Slate 800
const Color kTextSecondary = Color(0xFF64748B); // Slate 500
const double kRadius = 24.0; // Premium 24px radius

class AddInstallationPage extends StatefulWidget {
  final String userRole;
  final String serviceType;
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

  // Controllers
  final _requestController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _clientEmailController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _clientSearchController = TextEditingController();
  final _storeSearchController = TextEditingController();
  final _gpsLinkController = TextEditingController();
  final _newClientNameController = TextEditingController();
  final _newStoreNameController = TextEditingController();
  final _newStoreLocationController = TextEditingController();

  // Data State
  Client? _selectedClient;
  Store? _selectedStore;
  List<Client> _clients = [];
  List<Store> _stores = [];
  List<InstallationProduct> _selectedProducts = [];
  List<AppUser> _allTechnicians = [];
  List<AppUser> _selectedTechnicians = [];

  // ✅ NEW: Project Linking State
  String? _selectedProjectId;
  String? _selectedProjectName;

  // GPS State
  double? _parsedLat;
  double? _parsedLng;
  bool _isResolvingLink = false;

  // UI State
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isFetchingClients = false;
  bool _isFetchingStores = false;
  bool _isFetchingTechnicians = false;

  // File State
  File? _pickedFile;
  String? _pickedFileName;
  bool _isUploadingFile = false;
  String? _existingFileUrl;

  static const String _b2UploadCredentialUrl =
      "https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl"; // Updated to real endpoint format generally used

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _fetchTechnicians();

    if (widget.installationToEdit != null) {
      _isEditing = true;
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    final data = widget.installationToEdit!.data() as Map<String, dynamic>;

    _requestController.text = data['initialRequest'] ?? '';
    _clientPhoneController.text = data['clientPhone'] ?? '';
    _clientEmailController.text = data['clientEmail'] ?? '';
    _contactNameController.text = data['contactName'] ?? '';

    // Load Project Link if exists
    if (data['projectId'] != null) {
      _selectedProjectId = data['projectId'];
      _selectedProjectName = data['clientName'] ?? 'Projet Lié'; // Approximation fallback
    }

    if (data['clientId'] != null) {
      _selectedClient = Client(id: data['clientId'], name: data['clientName'] ?? '');
      _clientSearchController.text = data['clientName'] ?? '';
      _fetchStores(data['clientId']);
    }

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
      _storeSearchController.text = '${data['storeName']} (${data['storeLocation']})';
    }

    if (data['orderedProducts'] != null) {
      var list = List<Map<String, dynamic>>.from(data['orderedProducts']);
      _selectedProducts = list.map((p) {
        bool isClient = p['source'] == 'client_supply';
        return InstallationProduct(
          productId: p['productId'],
          productName: p['productName'],
          quantity: p['quantity'],
          partNumber: p['reference'] ?? '',
          marque: p['marque'] ?? '',
          isClientSupply: isClient,
        );
      }).toList();
    }

    if (data['assignedTechnicians'] != null) {
      var list = List<Map<String, dynamic>>.from(data['assignedTechnicians']);
      _selectedTechnicians = list.map((t) => AppUser(
        uid: t['uid'],
        displayName: t['displayName'] ?? '',
      )).toList();
    }

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
  // ⚙️ LOGIC METHODS (PRESERVED)
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
        if (mounted) _showSnack("✅ Coordonnées extraites !", kPrimaryColor);
      } else {
        if (mounted) _showSnack("❌ Impossible de trouver les coordonnées.", Colors.orange);
      }
    } catch (e) {
      if (mounted) _showSnack("Erreur lors de l'analyse : $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isResolvingLink = false);
    }
  }

  Future<void> _fetchClients() async {
    setState(() => _isFetchingClients = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('clients').orderBy('name').get();
      _clients = snapshot.docs.map((doc) => Client(id: doc.id, name: doc.data()['name'] ?? 'N/A')).toList();
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
      final snapshot = await FirebaseFirestore.instance.collection('clients').doc(clientId).collection('stores').orderBy('name').get();
      _stores = snapshot.docs.map((doc) {
        final data = doc.data();
        return Store(
          id: doc.id,
          name: data['name'] ?? 'N/A',
          location: data['location'] ?? 'N/A',
          latitude: (data['latitude'] as num?)?.toDouble(),
          longitude: (data['longitude'] as num?)?.toDouble(),
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
      final snapshot = await FirebaseFirestore.instance.collection('users').where('role', whereIn: [
        UserRoles.admin,
        UserRoles.responsableAdministratif,
        UserRoles.responsableCommercial,
        UserRoles.responsableTechnique,
        UserRoles.responsableIT,
        UserRoles.chefDeProjet,
        UserRoles.technicienST,
        UserRoles.technicienIT
      ]).get();

      final allTechnicians = snapshot.docs.map((doc) => AppUser(
          uid: doc.id,
          displayName: doc.data()['displayName'] as String? ?? 'Utilisateur Inconnu')).toList();
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
      if (authResponse.statusCode != 200) throw Exception('Failed to get B2 credentials');

      final authData = jsonDecode(authResponse.body);
      final uploadUrl = authData['uploadUrl'] as String;
      final authorizationToken = authData['authorizationToken'] as String;

      final fileBytes = await _pickedFile!.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final fileMimeType = _pickedFileName!.endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
      final fileName = 'installation_files/${installationCodeOrTempId}_${DateTime.now().millisecondsSinceEpoch}_${_pickedFileName}';

      final uploadResponse = await http.post(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': authorizationToken,
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': fileMimeType,
          'X-Bz-Content-Sha1': sha1Hash,
        },
        body: fileBytes,
      );

      if (uploadResponse.statusCode == 200) {
        final uploadData = jsonDecode(uploadResponse.body);
        final downloadUrlPrefix = authData['downloadUrlPrefix'] as String;
        final encodedPath = (uploadData['fileName'] as String).split('/').map(Uri.encodeComponent).join('/');
        return downloadUrlPrefix + encodedPath;
      } else {
        throw Exception('B2 Upload failed');
      }
    } catch (e) {
      if (mounted) _showSnack('Échec de l\'envoi du fichier: $e', Colors.redAccent);
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  void _openGlobalProductSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GlobalProductSearchPage(
          isSelectionMode: true,
          onProductSelected: (productData) {
            final int qty = productData['quantity'] ?? 1;
            _addProductToList(productData, qty);
          },
        ),
      ),
    );
  }

  void _addProductToList(Map<String, dynamic> data, int quantity) {
    final newProduct = InstallationProduct(
      productId: data['id'] ?? data['productId'] ?? 'unknown_id',
      productName: data['nom'] ?? data['name'] ?? data['productName'] ?? 'Produit Inconnu',
      quantity: quantity,
      partNumber: data['reference'] ?? data['partNumber'] ?? data['ref'] ?? '',
      marque: data['marque'] ?? data['brand'] ?? '',
      isClientSupply: false,
    );

    setState(() => _selectedProducts.add(newProduct));
    _showSnack("${newProduct.quantity}x ${newProduct.productName} ajouté!", kPrimaryColor);
  }

  // ✅ PROJECT LINKING HELPER
  Future<void> _showProjectSelector() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('projects')
        .where('status', whereIn: ['Nouvelle Demande', 'En Cours d\'Évaluation', 'Évaluation Terminée', 'Finalisation de la Commande', 'À Planifier'])
        .get();

    final projects = snapshot.docs;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('Lier à un Projet Existant', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
              const SizedBox(height: 16),
              Expanded(
                child: projects.isEmpty
                    ? Center(child: Text("Aucun projet actif trouvé.", style: GoogleFonts.inter(color: kTextSecondary)))
                    : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final doc = projects[index];
                    final data = doc.data();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: kBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: kProjectColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.rocket_launch_rounded, color: kProjectColor, size: 20),
                        ),
                        title: Text(data['clientName'] ?? 'Projet Inconnu', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextPrimary)),
                        subtitle: Text(data['status'] ?? '', style: GoogleFonts.inter(color: kTextSecondary, fontSize: 13)),
                        onTap: () {
                          setState(() {
                            _selectedProjectId = doc.id;
                            _selectedProjectName = data['clientName'];
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveInstallation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClient == null || _selectedStore == null) {
      _showSnack('Veuillez choisir un client et un magasin', Colors.redAccent);
      return;
    }
    if (_gpsLinkController.text.trim().isNotEmpty && _parsedLat == null) {
      await _extractCoordinatesFromLink();
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Erreur: Utilisateur non trouvé', Colors.redAccent);
      setState(() => _isLoading = false);
      return;
    }

    final DocumentReference installationRef = _isEditing
        ? widget.installationToEdit!.reference
        : FirebaseFirestore.instance.collection('installations').doc();
    final storeRef = FirebaseFirestore.instance.collection('clients').doc(_selectedClient!.id).collection('stores').doc(_selectedStore!.id);

    try {
      String? fileUrl;
      String? fileName;
      final tempId = _isEditing ? widget.installationToEdit!.id : DateTime.now().millisecondsSinceEpoch.toString();

      if (_pickedFile != null) {
        fileUrl = await _uploadFileToB2(tempId);
        fileName = _pickedFileName;
      } else {
        fileUrl = _existingFileUrl;
        fileName = _pickedFileName;
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final createdByName = userDoc.data()?['displayName'] ?? 'N/A';

      List<Map<String, dynamic>> enrichedProducts = _selectedProducts.map((p) => {
        'productId': p.productId,
        'productName': p.productName,
        'reference': p.partNumber,
        'marque': p.marque,
        'category': 'Autre',
        'image': null,
        'quantity': p.quantity,
        'source': p.isClientSupply ? 'client_supply' : 'stock_interne',
        'serialNumbers': [],
      }).toList();

      final systems = enrichedProducts.map((p) => {
        'id': p['productId'],
        'name': p['productName'],
        'reference': p['reference'],
        'marque': p['marque'],
        'category': p['category'],
        'image': p['image'],
        'quantity': p['quantity'],
        'source': p['source'],
        'serialNumbers': List<String>.filled(p['quantity'] as int, ''),
      }).toList();

      final techniciansToSave = _selectedTechnicians.map((u) => {'uid': u.uid, 'displayName': u.displayName}).toList();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        String? installationCode;

        if (_isEditing) {
          final existingData = widget.installationToEdit!.data() as Map<String, dynamic>;
          installationCode = existingData['installationCode'] ?? 'Brouillon';
        } else {
          installationCode = 'En attente de clôture';
        }

        final double? finalLat = _parsedLat ?? _selectedStore!.latitude;
        final double? finalLng = _parsedLng ?? _selectedStore!.longitude;

        if (_parsedLat != null && _parsedLng != null) {
          transaction.update(storeRef, {'latitude': _parsedLat, 'longitude': _parsedLng});
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
          'projectId': _selectedProjectId, // ✅ Linked Project ID
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

          // ✅ MAGIC HAPPENS HERE: Update linked project status
          if (_selectedProjectId != null) {
            final projectRef = FirebaseFirestore.instance.collection('projects').doc(_selectedProjectId);
            transaction.update(projectRef, {
              'status': 'Transféré à l\'Installation',
              'installations': {
                'installationId': installationRef.id,
              }
            });
          }
        } else {
          transaction.update(installationRef, dataToSave);
        }
      });

      if (mounted) {
        _showSnack(_isEditing ? 'Modification enregistrée!' : 'Installation créée!', kPrimaryColor);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- Client Dialog ---
  Future<void> _showAddClientDialog() async {
    _newClientNameController.clear();
    await _showGenericDialog("Ajouter un Client", "Nom du Client", _newClientNameController, () async {
      final docRef = await FirebaseFirestore.instance.collection('clients').add({
        'name': _newClientNameController.text.trim(),
        'createdAt': Timestamp.now(),
      });
      final newClient = Client(id: docRef.id, name: _newClientNameController.text.trim());
      await _fetchClients();
      setState(() {
        _selectedClient = newClient;
        _clientSearchController.text = newClient.name;
        _fetchStores(newClient.id);
      });
    });
  }

  Future<void> _showAddStoreDialog() async {
    if (_selectedClient == null) return;
    _newStoreNameController.clear();
    _newStoreLocationController.clear();

    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
          title: Text("Ajouter Magasin", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newStoreNameController,
                decoration: _inputDecoration("Nom", Icons.storefront_rounded),
                style: GoogleFonts.inter(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newStoreLocationController,
                decoration: _inputDecoration("Ville", Icons.location_city_rounded),
                style: GoogleFonts.inter(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Annuler", style: GoogleFonts.inter(color: kTextSecondary))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () async {
                  if(_newStoreNameController.text.isEmpty) return;
                  await FirebaseFirestore.instance.collection('clients').doc(_selectedClient!.id).collection('stores').add({
                    'name': _newStoreNameController.text.trim(),
                    'location': _newStoreLocationController.text.trim(),
                    'createdAt': Timestamp.now(),
                  });
                  await _fetchStores(_selectedClient!.id);
                  Navigator.pop(ctx);
                }, child: Text("Enregistrer", style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
          ],
        )
    );
  }

  Future<void> _showGenericDialog(String title, String label, TextEditingController controller, Function onSave) async {
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            style: GoogleFonts.inter(),
            decoration: _inputDecoration(label, Icons.edit_rounded),
            validator: (v) => v!.isEmpty ? 'Requis' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Annuler', style: GoogleFonts.inter(color: kTextSecondary))),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await onSave();
                Navigator.of(ctx).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Enregistrer', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------
  // 🖥️ UI BUILDER
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kSurfaceColor,
        foregroundColor: kTextPrimary,
        centerTitle: true,
        title: Text(
          _isEditing ? 'Modifier Installation' : 'Nouvelle Installation',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black.withOpacity(0.05), height: 1),
        ),
        actions: [
          if (_isLoading)
            const Padding(padding: EdgeInsets.only(right: 16), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ✅ PREMIUM PROJECT LINKER
              if (!_isEditing) _buildProjectLinker(),

              _buildSectionTitle("Informations Client", Icons.business_rounded),
              _buildClientCard(),

              const SizedBox(height: 24),
              _buildSectionTitle("Localisation & Site", Icons.map_rounded),
              _buildLocationCard(),

              const SizedBox(height: 24),
              _buildSectionTitle("Détails de l'Intervention", Icons.assignment_rounded),
              _buildDetailsCard(),

              const SizedBox(height: 24),
              _buildSectionTitle("Équipe Technique", Icons.engineering_rounded),
              _buildTechnicianCard(),

              const SizedBox(height: 24),
              _buildSectionTitle("Inventaire Matériel", Icons.inventory_2_rounded),
              _buildProductList(),

              const SizedBox(height: 40),
              _buildSaveButton(),
              const SizedBox(height: 60), // Extra scroll space
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  // ✅ NEW: Premium Project Linker UI
  Widget _buildProjectLinker() {
    final bool isLinked = _selectedProjectId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: isLinked ? kProjectColor.withOpacity(0.05) : kSurfaceColor,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: isLinked ? kProjectColor.withOpacity(0.3) : Colors.black.withOpacity(0.05)),
        boxShadow: isLinked ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: _showProjectSelector,
        borderRadius: BorderRadius.circular(kRadius),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLinked ? kProjectColor.withOpacity(0.1) : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.rocket_launch_rounded, color: isLinked ? kProjectColor : kTextSecondary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lier à un Projet (Recommandé)', style: GoogleFonts.inter(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(isLinked ? _selectedProjectName ?? 'Projet Lié' : 'Sélectionner le projet source',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: isLinked ? kProjectColor : kTextPrimary)),
                  ],
                ),
              ),
              if (isLinked)
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                  onPressed: () => setState(() {
                    _selectedProjectId = null;
                    _selectedProjectName = null;
                  }),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: Colors.grey)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 8),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryColor, size: 20),
          const SizedBox(width: 10),
          Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
        ],
      ),
    );
  }

  Widget _buildClientCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildModernSelect<Client>(
            label: "Client",
            hint: "Rechercher un client...",
            items: _clients,
            selectedItem: _selectedClient,
            isLoading: _isFetchingClients,
            onSelected: (c) {
              setState(() {
                _selectedClient = c;
                _clientSearchController.text = c.name;
                _fetchStores(c.id);
              });
            },
            onAdd: _showAddClientDialog,
            itemLabel: (c) => c.name,
          ),

          const SizedBox(height: 20),

          _buildModernSelect<Store>(
            label: "Magasin",
            hint: "Sélectionner un magasin...",
            items: _stores,
            selectedItem: _selectedStore,
            isLoading: _isFetchingStores,
            enabled: _selectedClient != null,
            onSelected: (s) {
              setState(() {
                _selectedStore = s;
                _parsedLat = null;
                _parsedLng = null;
                _gpsLinkController.clear();
              });
            },
            onAdd: _showAddStoreDialog,
            itemLabel: (s) => "${s.name} (${s.location})",
          ),
        ],
      ),
    );
  }

  Widget _buildModernSelect<T>({
    required String label,
    required String hint,
    required List<T> items,
    required T? selectedItem,
    required Function(T) onSelected,
    required Function() onAdd,
    required String Function(T) itemLabel,
    bool isLoading = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: (enabled && !isLoading) ? () {
                  _showSearchableBottomSheet(
                    title: "Sélectionner $label",
                    items: items,
                    itemLabel: itemLabel,
                    onSelected: onSelected,
                  );
                } : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.04)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          label == "Client" ? Icons.business_rounded : Icons.storefront_rounded,
                          color: enabled ? kTextSecondary : Colors.grey.shade400,
                          size: 20
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          selectedItem != null ? itemLabel(selectedItem) : hint,
                          style: GoogleFonts.inter(
                              color: selectedItem != null ? kTextPrimary : kTextSecondary,
                              fontWeight: selectedItem != null ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 15
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLoading)
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Icon(Icons.keyboard_arrow_down_rounded, color: enabled ? kTextSecondary : Colors.grey.shade300),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: enabled ? onAdd : null,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: enabled ? kPrimaryColor.withOpacity(0.1) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.add_rounded, color: enabled ? kPrimaryColor : Colors.grey, size: 22),
              ),
            )
          ],
        ),
      ],
    );
  }

  Future<void> _showSearchableBottomSheet<T>({
    required String title,
    required List<T> items,
    required String Function(T) itemLabel,
    required Function(T) onSelected,
  }) {
    return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return _SearchableListSheet<T>(
              title: title,
              items: items,
              itemLabel: itemLabel,
              onSelected: onSelected
          );
        }
    );
  }

  Widget _buildLocationCard() {
    bool hasGps = (_selectedStore?.latitude != null || _parsedLat != null);

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: hasGps ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: hasGps ? Colors.green.shade200 : Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(hasGps ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: hasGps ? Colors.green : Colors.orange, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasGps ? "Position GPS Synchronisée" : "Position GPS manquante",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: hasGps ? Colors.green.shade800 : Colors.orange.shade800, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          if (!hasGps || _parsedLat != null) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.black.withOpacity(0.04)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _gpsLinkController,
                    style: GoogleFonts.inter(),
                    decoration: _inputDecoration("Lien Google Maps", Icons.link_rounded).copyWith(
                        hintText: "https://goo.gl/maps/..."
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isResolvingLink ? null : _extractCoordinatesFromLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isResolvingLink
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                ),
              ],
            ),
            if (_parsedLat != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 4),
                child: Text("📍 $_parsedLat, $_parsedLng", style: GoogleFonts.inter(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField(_clientPhoneController, "Téléphone", Icons.phone_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField(_clientEmailController, "Email", Icons.alternate_email_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(_contactNameController, "Contact sur site", Icons.person_pin_circle_rounded),
          const SizedBox(height: 16),

          InkWell(
            onTap: _isUploadingFile ? null : _pickFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  Icon(
                      _pickedFile != null ? Icons.file_present_rounded : Icons.attach_file_rounded,
                      color: _pickedFile != null ? kPrimaryColor : kTextSecondary,
                      size: 22
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _pickedFile != null ? _pickedFileName! : (_existingFileUrl != null ? "Fichier existant (Modifier)" : "Joindre un fichier (PDF/Image)"),
                      style: GoogleFonts.inter(color: _pickedFile != null ? kPrimaryColor : kTextSecondary, fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                  ),
                  if (_pickedFile != null)
                    IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() { _pickedFile = null; _pickedFileName = null; })
                    )
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          TextFormField(
            controller: _requestController,
            maxLines: 4,
            style: GoogleFonts.inter(height: 1.5),
            decoration: _inputDecoration("Description de la demande", Icons.description_rounded).copyWith(
              alignLabelWithHint: true,
            ),
            validator: (v) => v!.isEmpty ? 'Description requise' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicianCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(8),
      child: MultiSelectDialogField<AppUser>(
        items: _allTechnicians.map((u) => MultiSelectItem(u, u.displayName)).toList(),
        initialValue: _selectedTechnicians,
        title: Text("Techniciens", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        buttonText: Text("Assigner à...", style: GoogleFonts.inter(color: kTextSecondary, fontSize: 15)),
        buttonIcon: const Icon(Icons.group_add_rounded, color: kTextSecondary),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent),
        ),
        chipDisplay: MultiSelectChipDisplay(
          chipColor: kPrimaryColor.withOpacity(0.1),
          textStyle: GoogleFonts.inter(color: kPrimaryDark, fontWeight: FontWeight.bold, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onConfirm: (results) => setState(() => _selectedTechnicians = results),
      ),
    );
  }

  Widget _buildProductList() {
    return Column(
      children: [
        if (_selectedProducts.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedProducts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final product = _selectedProducts[index];
              final isClient = product.isClientSupply;
              final color = isClient ? kClientSupplyColor : kPrimaryColor;

              return Container(
                decoration: BoxDecoration(
                  color: kSurfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                  border: Border.all(color: color.withOpacity(0.2), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(isClient ? Icons.person_rounded : Icons.inventory_2_rounded, color: color, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.productName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary)),
                            const SizedBox(height: 4),
                            Text("Ref: ${product.partNumber}", style: GoogleFonts.inter(color: kTextSecondary, fontSize: 13)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8)
                              ),
                              child: Text(isClient ? "Fourniture Client" : "Stock Boitex", style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text("Qté: ", style: GoogleFonts.inter(color: kTextSecondary, fontSize: 13)),
                              Text("${product.quantity}", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: kTextPrimary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 24,
                            child: Switch(
                              value: product.isClientSupply,
                              activeColor: kClientSupplyColor,
                              onChanged: (val) => setState(() => product.isClientSupply = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () => setState(() => _selectedProducts.removeAt(index)),
                      )
                    ],
                  ),
                ),
              );
            },
          ),

        const SizedBox(height: 20),

        InkWell(
          onTap: _openGlobalProductSearch,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              border: Border.all(color: kPrimaryColor.withOpacity(0.5), width: 1.5),
              borderRadius: BorderRadius.circular(20),
              color: kPrimaryColor.withOpacity(0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline_rounded, color: kPrimaryColor, size: 24),
                const SizedBox(width: 10),
                Text("Ajouter un Produit", style: GoogleFonts.inter(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: (_isLoading || _isUploadingFile) ? null : _saveInstallation,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          shadowColor: kPrimaryColor.withOpacity(0.4),
        ),
        child: (_isLoading || _isUploadingFile)
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Text(
          _isEditing ? "Enregistrer les modifications" : "Créer l'installation",
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // --- STYLING HELPERS ---

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: kSurfaceColor,
      borderRadius: BorderRadius.circular(kRadius),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8)),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.inter(),
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kTextSecondary, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: kPrimaryColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      labelStyle: GoogleFonts.inter(color: kTextSecondary),
    );
  }
}

// ----------------------------------------------------------------------
// 🔎 SEARCHABLE SHEET WIDGET (Premium Restyle)
// ----------------------------------------------------------------------

class _SearchableListSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) itemLabel;
  final Function(T) onSelected;

  const _SearchableListSheet({
    required this.title,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
  });

  @override
  State<_SearchableListSheet<T>> createState() => _SearchableListSheetState<T>();
}

class _SearchableListSheetState<T> extends State<_SearchableListSheet<T>> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.items.where((item) {
      final label = widget.itemLabel(item).toLowerCase();
      return label.contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7, // 70% height
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Handle Bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Text(widget.title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary)),
          const SizedBox(height: 24),

          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: GoogleFonts.inter(),
            decoration: InputDecoration(
              hintText: "Rechercher...",
              hintStyle: GoogleFonts.inter(color: kTextSecondary),
              prefixIcon: const Icon(Icons.search_rounded, color: kTextSecondary),
              filled: true,
              fillColor: kBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),

          // List
          Expanded(
            child: filteredItems.isEmpty
                ? Center(child: Text("Aucun résultat", style: GoogleFonts.inter(color: kTextSecondary)))
                : ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: filteredItems.length,
              separatorBuilder: (_,__) => Divider(height: 1, color: Colors.black.withOpacity(0.05)),
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return ListTile(
                  title: Text(widget.itemLabel(item), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextPrimary)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onTap: () {
                    widget.onSelected(item);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
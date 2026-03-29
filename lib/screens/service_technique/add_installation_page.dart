// lib/screens/service_technique/add_installation_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // 🚀 REQUIRED FOR IOS WIDGETS
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:google_fonts/google_fonts.dart';

// ✅ Global Search Page
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';

// 🚀 IMPORT THE OMNIBAR
import 'package:boitex_info_app/widgets/intervention_omnibar.dart';

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

// --- GLASSMORPHISM HELPER WIDGET ---
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double opacity;

  const GlassCard({
    Key? key,
    required this.child,
    this.padding,
    this.borderRadius = 24.0,
    this.opacity = 0.6,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                spreadRadius: -5,
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

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

class _AddInstallationPageState extends State<AddInstallationPage> with SingleTickerProviderStateMixin {
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

  // Background Animation
  late AnimationController _bgAnimationController;

  static const String _b2UploadCredentialUrl =
      "https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl";

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _fetchTechnicians();

    if (widget.installationToEdit != null) {
      _isEditing = true;
      _loadExistingData();
    }

    _bgAnimationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);
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
    _bgAnimationController.dispose();
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
          'projectId': _selectedProjectId,
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
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // 🚀 IOS FULL-SCREEN SEARCH SHEET (Matches SAV & Intervention)
  // ----------------------------------------------------------------------
  void _openIOSSearchSheet<T>({
    required String title,
    required List<T> items,
    required String Function(T) getLabel,
    String? Function(T)? getSubtitle,
    required Function(T) onSelected,
    required VoidCallback onAddPressed,
    required String addButtonLabel,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setStateSB) {
            final filteredItems = items.where((item) {
              final nameLower = getLabel(item).toLowerCase();
              final queryLower = searchQuery.toLowerCase();
              return nameLower.contains(queryLower);
            }).toList();

            return FractionallySizedBox(
              heightFactor: 0.88,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: CupertinoSearchTextField(
                            placeholder: 'Rechercher...',
                            onChanged: (val) => setStateSB(() => searchQuery = val),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredItems.length + 1,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                            itemBuilder: (context, index) {
                              if (index == filteredItems.length) {
                                return ListTile(
                                  leading: const Icon(CupertinoIcons.add_circled_solid, color: kPrimaryColor),
                                  title: Text(addButtonLabel, style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    onAddPressed();
                                  },
                                );
                              }
                              final item = filteredItems[index];
                              final subtitle = getSubtitle != null ? getSubtitle(item) : null;
                              return ListTile(
                                title: Text(getLabel(item), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                                subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.black54)) : null,
                                trailing: const Icon(CupertinoIcons.chevron_forward, color: Colors.black26, size: 18),
                                onTap: () {
                                  onSelected(item);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🚀 IOS TECHNICIAN SELECTOR
  void _openIOSTechnicianSelector() {
    List<AppUser> tempSelected = List.from(_selectedTechnicians);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return FractionallySizedBox(
              heightFactor: 0.75,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Annuler', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                              ),
                              const Text('Techniciens', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                              TextButton(
                                onPressed: () {
                                  setState(() => _selectedTechnicians = tempSelected);
                                  Navigator.pop(context);
                                },
                                child: const Text('Valider', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _allTechnicians.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                            itemBuilder: (context, index) {
                              final tech = _allTechnicians[index];
                              final isSelected = tempSelected.any((t) => t.uid == tech.uid);

                              return ListTile(
                                title: Text(tech.displayName, style: TextStyle(color: isSelected ? kPrimaryColor : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                trailing: isSelected ? const Icon(CupertinoIcons.checkmark_alt, color: kPrimaryColor) : null,
                                onTap: () {
                                  setStateSB(() {
                                    if (isSelected) {
                                      tempSelected.removeWhere((t) => t.uid == tech.uid);
                                    } else {
                                      tempSelected.add(tech);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ✅ PROJECT LINKING SHEET (IOS STYLE)
  Future<void> _showProjectSelector() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('projects')
        .where('status', whereIn: ['Nouvelle Demande', 'En Cours d\'Évaluation', 'Évaluation Terminée', 'Finalisation de la Commande', 'À Planifier'])
        .get();

    final projects = snapshot.docs;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.65,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40, height: 5,
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Lier à un Projet Existant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                    Expanded(
                      child: projects.isEmpty
                          ? const Center(child: Text("Aucun projet actif trouvé.", style: TextStyle(color: Colors.black54)))
                          : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: projects.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                        itemBuilder: (context, index) {
                          final doc = projects[index];
                          final data = doc.data();
                          return ListTile(
                            leading: const Icon(Icons.rocket_launch_rounded, color: kProjectColor),
                            title: Text(data['clientName'] ?? 'Projet Inconnu', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                            subtitle: Text(data['status'] ?? '', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                            trailing: const Icon(CupertinoIcons.chevron_forward, color: Colors.black26, size: 18),
                            onTap: () {
                              setState(() {
                                _selectedProjectId = doc.id;
                                _selectedProjectName = data['clientName'];
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Client & Store Add Dialogs (Kept logic, styled slightly) ---
  Future<void> _showAddClientDialog() async {
    _newClientNameController.clear();
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: Text("Ajouter un Client", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: _newClientNameController,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: "Nom du Client",
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            validator: (v) => v!.isEmpty ? 'Requis' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler', style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
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
                Navigator.of(ctx).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddStoreDialog() async {
    if (_selectedClient == null) return;
    _newStoreNameController.clear();
    _newStoreLocationController.clear();

    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
          title: Text("Ajouter Magasin", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newStoreNameController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(labelText: "Nom", filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newStoreLocationController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(labelText: "Ville", filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler", style: TextStyle(color: Colors.black54))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if(_newStoreNameController.text.isEmpty) return;
                  await FirebaseFirestore.instance.collection('clients').doc(_selectedClient!.id).collection('stores').add({
                    'name': _newStoreNameController.text.trim(),
                    'location': _newStoreLocationController.text.trim(),
                    'createdAt': Timestamp.now(),
                  });
                  await _fetchStores(_selectedClient!.id);
                  Navigator.pop(ctx);
                }, child: const Text("Enregistrer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ],
        )
    );
  }

  // ----------------------------------------------------------------------
  // 🖥️ UI BUILDER
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withOpacity(0.4)),
          ),
        ),
        foregroundColor: kTextPrimary,
        centerTitle: true,
        title: Text(
          _isEditing ? 'Modifier Installation' : 'Nouvelle Installation',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.5),
        ),
        actions: [
          if (_isLoading)
            const Padding(padding: EdgeInsets.only(right: 16), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
        ],
      ),
      body: Stack(
        children: [
          // 🚀 ANIMATED GRADIENT BACKGROUND
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(const Color(0xFFF3F4F6), const Color(0xFFE8F5E9), _bgAnimationController.value)!,
                      Color.lerp(const Color(0xFFE8F5E9), const Color(0xFFE0F2F1), _bgAnimationController.value)!,
                      Color.lerp(const Color(0xFFE0F2F1), const Color(0xFFF5F7FA), _bgAnimationController.value)!,
                    ],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Form(
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
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildProjectLinker() {
    final bool isLinked = _selectedProjectId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: GlassCard(
        opacity: isLinked ? 0.8 : 0.6,
        padding: EdgeInsets.zero,
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
                    color: isLinked ? kProjectColor.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
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
                    icon: const Icon(CupertinoIcons.clear_thick_circled, color: Colors.redAccent),
                    onPressed: () => setState(() {
                      _selectedProjectId = null;
                      _selectedProjectName = null;
                    }),
                  )
                else
                  const Icon(CupertinoIcons.chevron_forward, color: Colors.black26)
              ],
            ),
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
          Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
        ],
      ),
    );
  }

  Widget _buildClientCard() {
    return GlassCard(
      child: Column(
        children: [
          // 🚀 THE OMNIBAR FOR CLIENT SELECTION
          Row(
            children: [
              Expanded(
                child: InterventionOmnibar(
                  onItemSelected: (result) {
                    setState(() {
                      _selectedClient = Client(id: result.id, name: result.title);
                      _selectedStore = null;
                      _stores = [];
                    });
                    _fetchStores(result.id);
                  },
                  onClear: () {
                    setState(() {
                      _selectedClient = null;
                      _selectedStore = null;
                      _stores = [];
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                ),
                child: IconButton(
                  icon: const Icon(CupertinoIcons.add, color: Colors.white, size: 26),
                  tooltip: 'Nouveau Client',
                  onPressed: _showAddClientDialog,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildSearchableDropdown(
            label: "Magasin / Agence (Optionnel)",
            valueText: _selectedStore != null ? "${_selectedStore!.name} (${_selectedStore!.location})" : "",
            icon: Icons.store_mall_directory_rounded,
            onClear: () => setState(() {
              _selectedStore = null;
              _parsedLat = null;
              _parsedLng = null;
              _gpsLinkController.clear();
            }),
            onTap: () {
              if (_selectedClient == null) {
                _showSnack("Sélectionnez un client d'abord", Colors.orange);
                return;
              }
              _openIOSSearchSheet<Store>(
                title: 'Rechercher un Magasin',
                items: _stores,
                getLabel: (s) => s.name,
                getSubtitle: (s) => s.location,
                onSelected: (item) => setState(() {
                  _selectedStore = item;
                  _parsedLat = null;
                  _parsedLng = null;
                  _gpsLinkController.clear();
                }),
                onAddPressed: _showAddStoreDialog,
                addButtonLabel: 'Nouveau Magasin',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchableDropdown({
    required String label,
    required String valueText,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AbsorbPointer(
          child: TextFormField(
            controller: TextEditingController(text: valueText),
            style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.black54),
              prefixIcon: Icon(icon, color: Colors.black54),
              suffixIcon: (valueText.isNotEmpty && onClear != null)
                  ? IconButton(icon: const Icon(Icons.clear, color: Colors.redAccent), onPressed: onClear)
                  : const Icon(CupertinoIcons.chevron_down, color: Colors.black54),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    bool hasGps = (_selectedStore?.latitude != null || _parsedLat != null);

    return GlassCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: hasGps ? Colors.green.shade50.withOpacity(0.8) : Colors.orange.shade50.withOpacity(0.8),
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
                  child: _buildGlassTextField(
                    controller: _gpsLinkController,
                    labelText: "Lien Google Maps (Optionnel)",
                    icon: Icons.link_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: _isResolvingLink
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                    onPressed: _isResolvingLink ? null : _extractCoordinatesFromLink,
                  ),
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
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildGlassTextField(controller: _clientPhoneController, labelText: "Téléphone", icon: Icons.phone_rounded, keyboardType: TextInputType.phone)),
              const SizedBox(width: 16),
              Expanded(child: _buildGlassTextField(controller: _clientEmailController, labelText: "Email", icon: Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress)),
            ],
          ),
          const SizedBox(height: 16),
          _buildGlassTextField(controller: _contactNameController, labelText: "Contact sur site", icon: Icons.person_pin_circle_rounded),
          const SizedBox(height: 16),

          InkWell(
            onTap: _isUploadingFile ? null : _pickFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.5),
              ),
              child: Row(
                children: [
                  Icon(
                      _pickedFile != null ? CupertinoIcons.doc_fill : CupertinoIcons.paperclip,
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
                        icon: const Icon(CupertinoIcons.clear_thick_circled, color: Colors.redAccent, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() { _pickedFile = null; _pickedFileName = null; })
                    )
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextFormField(
              controller: _requestController,
              maxLines: 4,
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              decoration: InputDecoration(
                labelText: "Description de la demande",
                labelStyle: const TextStyle(color: Colors.black54),
                prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 50), child: Icon(Icons.description_rounded, color: Colors.black54)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                alignLabelWithHint: true,
              ),
              validator: (v) => v!.isEmpty ? 'Requis' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicianCard() {
    return GlassCard(
      child: GestureDetector(
        onTap: _openIOSTechnicianSelector,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              const Icon(CupertinoIcons.person_3_fill, color: Colors.black54),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _selectedTechnicians.isEmpty
                      ? 'Assigner les Techniciens'
                      : _selectedTechnicians.map((t) => t.displayName).join(', '),
                  style: TextStyle(
                      color: _selectedTechnicians.isEmpty ? Colors.black54 : kPrimaryColor,
                      fontSize: 16,
                      fontWeight: _selectedTechnicians.isEmpty ? FontWeight.normal : FontWeight.bold
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(CupertinoIcons.chevron_down, color: Colors.black54, size: 18),
            ],
          ),
        ),
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

              return GlassCard(
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
                          // 🚀 NATIVE IOS SWITCH
                          child: CupertinoSwitch(
                            value: product.isClientSupply,
                            activeColor: kClientSupplyColor,
                            onChanged: (val) => setState(() => product.isClientSupply = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(CupertinoIcons.minus_circle_fill, color: Colors.redAccent, size: 26),
                      onPressed: () => setState(() => _selectedProducts.removeAt(index)),
                    )
                  ],
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
                const Icon(CupertinoIcons.add_circled, color: kPrimaryColor, size: 24),
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
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF34D399), Color(0xFF10B981), Color(0xFF059669)], // Glowing Emerald
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(color: kPrimaryColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: (_isLoading || _isUploadingFile) ? null : _saveInstallation,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        icon: (_isLoading || _isUploadingFile) ? const SizedBox.shrink() : const Icon(CupertinoIcons.check_mark_circled_solid, size: 28, color: Colors.white),
        label: (_isLoading || _isUploadingFile)
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Flexible(
          child: Text(
            _isEditing ? "ENREGISTRER LES MODIFICATIONS" : "CRÉER L'INSTALLATION",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: const TextStyle(color: Colors.black54),
          prefixIcon: Icon(icon, color: Colors.black54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }
}
// lib/screens/service_technique/add_installation_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boitex_info_app/utils/user_roles.dart';

// Product Selection Imports
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/widgets/product_selector_dialog.dart';

// Technician Multi-Select Import
import 'package:multi_select_flutter/multi_select_flutter.dart';

// ✅ 1. B2 IMPORTS
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

class Store {
  final String id;
  final String name;
  final String location;
  Store({required this.id, required this.name, required this.location});

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

  const AddInstallationPage({
    super.key,
    required this.userRole,
    required this.serviceType,
  });

  @override
  State<AddInstallationPage> createState() => _AddInstallationPageState();
}

class _AddInstallationPageState extends State<AddInstallationPage> {
  final _formKey = GlobalKey<FormState>();
  final _requestController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _clientSearchController = TextEditingController();
  final _storeSearchController = TextEditingController();

  final _newClientNameController = TextEditingController();
  final _newStoreNameController = TextEditingController();
  final _newStoreLocationController = TextEditingController();

  Client? _selectedClient;
  Store? _selectedStore;

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

  static const Color primaryColor = Colors.green; // Match your details page

  // ✅ 2. B2 CONSTANT - MUST BE UPDATED BY USER
  static const String _b2UploadCredentialUrl =
      "https://europe-west1-your-firebase-project.cloudfunctions.net/b2GetUploadCredentials";

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _fetchTechnicians();
  }

  @override
  void dispose() {
    _requestController.dispose();
    _clientPhoneController.dispose();
    _contactNameController.dispose();
    _clientSearchController.dispose();
    _storeSearchController.dispose();
    _newClientNameController.dispose();
    _newStoreNameController.dispose();
    _newStoreLocationController.dispose();
    super.dispose();
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
      _selectedStore = null;
      _storeSearchController.clear();
      _stores = [];
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .orderBy('name')
          .get();
      _stores = snapshot.docs
          .map((doc) => Store(
        id: doc.id,
        name: doc.data()['name'] ?? 'N/A',
        location: doc.data()['location'] ?? 'N/A',
      ))
          .toList();
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
          displayName:
          doc.data()['displayName'] as String? ?? 'Utilisateur Inconnu'))
          .toList();
      if (mounted) setState(() => _allTechnicians = allTechnicians);
    } catch (e) {
      print("Error fetching technicians: $e");
    } finally {
      if (mounted) setState(() => _isFetchingTechnicians = false);
    }
  }

  String _generateInstallationCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final uniquePart = timestamp.substring(timestamp.length - 6).toUpperCase();
    return 'INS-$uniquePart';
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
      });
    } else {
      // User canceled the picker
    }
  }

  // -----------------------------------------------------------------
  // ✅ 3. REPLACED: B2 Upload Logic
  // -----------------------------------------------------------------
  Future<String?> _uploadFileToB2(String installationCode) async {
    if (_pickedFile == null) return null;

    setState(() => _isUploadingFile = true);

    try {
      // --- STEP 1: Get Upload Credentials from Cloud Function ---
      final authResponse = await http.get(Uri.parse(_b2UploadCredentialUrl));

      if (authResponse.statusCode != 200) {
        throw Exception(
            'Failed to get B2 credentials: ${authResponse.body}');
      }

      final authData = jsonDecode(authResponse.body);
      final uploadUrl = authData['uploadUrl'] as String;
      final authorizationToken = authData['authorizationToken'] as String;

      // --- STEP 2: Prepare File Data ---
      final fileBytes = await _pickedFile!.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final fileMimeType = _pickedFileName!.endsWith('.pdf')
          ? 'application/pdf'
          : 'image/jpeg';
      final fileName =
          'installation_files/${installationCode}_${DateTime.now().millisecondsSinceEpoch}_${_pickedFileName}';

      // --- STEP 3: Upload Directly to B2 ---
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
            ? "https://f005.backblazeb2.com/file/boitex-bucket/${fileName}" // Using the common B2 URL pattern (adjust bucket/domain if needed)
            : null;
      } else {
        throw Exception(
            'B2 Upload failed: ${uploadResponse.body}');
      }
    } catch (e) {
      print('Error during B2 upload process: $e');
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
  // VVV THIS FUNCTION IS MODIFIED VVV
  // -----------------------------------------------------------------
  Future<void> _saveInstallation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez choisir un client'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez choisir un magasin'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur: Utilisateur non trouvé')),
      );
      setState(() => _isLoading = false);
      return;
    }

    String? preliminaryFileUrl;
    String? preliminaryFileName;

    try {
      final installationCode = _generateInstallationCode();

      // ✅ USE NEW B2 UPLOAD METHOD
      if (_pickedFile != null) {
        preliminaryFileUrl = await _uploadFileToB2(installationCode);
        if (preliminaryFileUrl != null) {
          preliminaryFileName = _pickedFileName;
        } else {
          // Stop save process if upload failed
          setState(() => _isLoading = false);
          return;
        }
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final createdByName = userDoc.data()?['displayName'] ?? 'N/A';

      final productsToSave = _selectedProducts.map((p) {
        return {
          'productName': p.productName,
          'productId': p.productId,
          'quantity': p.quantity,
          'serialNumbers': [],
        };
      }).toList();

      final techniciansToSave = _selectedTechnicians
          .map((user) => {'uid': user.uid, 'displayName': user.displayName})
          .toList();

      await FirebaseFirestore.instance.collection('installations').add({
        // Key Info
        'installationCode': installationCode,
        'clientName': _selectedClient!.name,
        'clientId': _selectedClient!.id,
        'clientPhone': _clientPhoneController.text.trim(),
        'contactName': _contactNameController.text.trim(),
        'storeName': _selectedStore!.name,
        'storeId': _selectedStore!.id,
        'storeLocation': _selectedStore!.location,
        'initialRequest': _requestController.text.trim(),
        'serviceType': widget.serviceType,

        // Preliminary file details
        'preliminaryFileUrl': preliminaryFileUrl,
        'preliminaryFileName': preliminaryFileName,

        // Status & Timestamps
        'status': 'À Planifier', // Default status
        'createdAt': Timestamp.now(),
        'createdById': user.uid,
        'createdByName': createdByName,

        // Default empty fields
        'installationDate': null,
        'assignedTechnicians': techniciansToSave,
        'orderedProducts': productsToSave,
        'mediaUrls': [],
        'technicalEvaluation': [],
        'itEvaluation': [],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nouvelle installation créée avec succès.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  // -----------------------------------------------------------------
  // ^^^ THIS FUNCTION IS MODIFIED ^^^
  // -----------------------------------------------------------------

  /// Shows a dialog to add a new client
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
                child: const Text('Annuler'),
              ),
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
                        name: _newClientNameController.text.trim(),
                      );

                      await _fetchClients();
                      setState(() {
                        _selectedClient = newClient;
                        _clientSearchController.text = newClient.name;
                        _fetchStores(newClient.id);
                      });

                      Navigator.of(dialogContext).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setDialogState(() => isSaving = false);
                      }
                    }
                  }
                },
                child: isSaving
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Shows a dialog to add a new store for the selected client
  Future<void> _showAddStoreDialog() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord sélectionner un client.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Nom requis' : null,
                  ),
                  TextFormField(
                    controller: _newStoreLocationController,
                    decoration:
                    const InputDecoration(labelText: 'Localisation (Ville)'),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Localisation requise'
                        : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
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
                        'location': _newStoreLocationController.text.trim(),
                        'createdAt': Timestamp.now(),
                      });

                      final newStore = Store(
                        id: docRef.id,
                        name: _newStoreNameController.text.trim(),
                        location: _newStoreLocationController.text.trim(),
                      );

                      await _fetchStores(_selectedClient!.id);
                      setState(() {
                        _selectedStore = newStore;
                        _storeSearchController.text =
                        '${newStore.name} (${newStore.location})';
                      });

                      Navigator.of(dialogContext).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setDialogState(() => isSaving = false);
                      }
                    }
                  }
                },
                child: isSaving
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Shows the product selection dialog
  Future<void> _showProductSelector() async {
    final List<ProductSelection>? results = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return ProductSelectorDialog(
          initialProducts: _selectedProducts.map((p) => p.copy()).toList(),
        );
      },
    );

    if (results != null) {
      setState(() {
        _selectedProducts = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define border styles
    final defaultBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
    );
    final focusedBorder = defaultBorder.copyWith(
      borderSide: const BorderSide(color: primaryColor, width: 2.0),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer Installation Directe'),
        backgroundColor: primaryColor,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Client Dropdown ---
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
                        value: client,
                        label: client.name,
                      ))
                          .toList(),
                      onSelected: (Client? client) {
                        setState(() {
                          _selectedClient = client;
                          if (client != null) {
                            _fetchStores(client.id);
                          }
                        });
                      },
                      inputDecorationTheme: InputDecorationTheme(
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: defaultBorder,
                        focusedBorder: focusedBorder,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon:
                    Icon(Icons.add_business_outlined, color: primaryColor),
                    onPressed: _showAddClientDialog,
                    tooltip: 'Ajouter un nouveau client',
                    padding: const EdgeInsets.all(12),
                    splashRadius: 24,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // --- Store Dropdown (dependent on Client) ---
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
                        label: '${store.name} (${store.location})',
                      ))
                          .toList(),
                      onSelected: (Store? store) {
                        setState(() => _selectedStore = store);
                      },
                      inputDecorationTheme: InputDecorationTheme(
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: defaultBorder,
                        focusedBorder: focusedBorder,
                        disabledBorder: defaultBorder.copyWith(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.add_shopping_cart_outlined,
                        color: primaryColor),
                    onPressed: (_selectedClient == null || _isFetchingStores)
                        ? null
                        : _showAddStoreDialog,
                    tooltip: 'Ajouter un nouveau magasin',
                    padding: const EdgeInsets.all(12),
                    splashRadius: 24,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // --- Client Phone ---
              TextFormField(
                controller: _clientPhoneController,
                decoration: InputDecoration(
                  labelText: 'Téléphone (Client/Magasin)',
                  hintText: 'Numéro de contact...',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  enabledBorder: defaultBorder,
                  focusedBorder: focusedBorder,
                  floatingLabelStyle: const TextStyle(color: primaryColor),
                ),
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 20),

              // --- Contact Name Field ---
              TextFormField(
                controller: _contactNameController,
                decoration: InputDecoration(
                  labelText: 'Nom du Contact (sur site)',
                  hintText: 'Nom de la personne à contacter...',
                  prefixIcon: const Icon(Icons.person_pin_outlined),
                  enabledBorder: defaultBorder,
                  focusedBorder: focusedBorder,
                  floatingLabelStyle: const TextStyle(color: primaryColor),
                ),
                keyboardType: TextInputType.text,
              ),

              const SizedBox(height: 20),

              // --- Preliminary File Attachment ---
              Text(
                'Fichier Préliminaire (Optionnel)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                        color: primaryColor,
                      ),
                      label: Text(
                        _pickedFile == null
                            ? 'Joindre un fichier (PDF/Image)'
                            : _pickedFileName!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: primaryColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primaryColor.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (_pickedFile != null && !_isUploadingFile) ...[
                    const SizedBox(width: 8),
                    // Clear file button
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _pickedFile = null;
                          _pickedFileName = null;
                        });
                      },
                    ),
                  ] else if (_isUploadingFile) ...[
                    const SizedBox(width: 8),
                    // Upload spinner
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 20),

              // --- Initial Request ---
              TextFormField(
                controller: _requestController,
                decoration: InputDecoration(
                  labelText: 'Description de la Demande',
                  hintText: 'Matériel à installer, problème...',
                  enabledBorder: defaultBorder,
                  focusedBorder: focusedBorder,
                  floatingLabelStyle: const TextStyle(color: primaryColor),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) => value == null || value.isEmpty
                    ? 'Veuillez décrire la demande'
                    : null,
              ),

              const SizedBox(height: 20),

              // --- Technician Multi-Select ---
              Text(
                'Assigner des Techniciens (Optionnel)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              MultiSelectDialogField<AppUser>(
                items: _allTechnicians
                    .map(
                        (user) => MultiSelectItem<AppUser>(user, user.displayName))
                    .toList(),
                initialValue: _selectedTechnicians,
                title: const Text("Sélectionner Techniciens"),
                buttonText: Text(
                  "Assigner à",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                ),

                buttonIcon: Icon(
                  _isFetchingTechnicians
                      ? Icons.hourglass_top_outlined
                      : Icons.engineering_outlined,
                  color: Colors.grey.shade700,
                ),

                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                chipDisplay: MultiSelectChipDisplay<AppUser>(),
                onConfirm: (results) {
                  setState(() {
                    _selectedTechnicians = results.cast<AppUser>();
                  });
                },
              ),

              const SizedBox(height: 20),

              // --- Product List Display ---
              _buildProductList(),

              const SizedBox(height: 32),

              // --- Submit Button ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || _isUploadingFile) ? null : _saveInstallation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0)),
                  ),
                  child: (_isLoading || _isUploadingFile)
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Créer l\'Installation'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget to display the selected product list
  Widget _buildProductList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Produits à Installer',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12.0),
          ),
          // Adjust height based on content
          height: _selectedProducts.isEmpty ? 80 : 150,
          child: _selectedProducts.isEmpty
              ? const Center(
            child: Text(
              'Aucun produit sélectionné.',
              style: TextStyle(color: Colors.grey),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: _selectedProducts.length,
            itemBuilder: (context, index) {
              final product = _selectedProducts[index];
              return ListTile(
                leading: Icon(Icons.inventory_2_outlined,
                    color: primaryColor),
                title: Text(product.productName),
                trailing: Text(
                  'Qté: ${product.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton.icon(
            onPressed: _showProductSelector,
            icon: Icon(Icons.add, color: primaryColor),
            label: Text(
              _selectedProducts.isEmpty
                  ? 'Ajouter des Produits'
                  : 'Modifier les Produits',
              style: TextStyle(color: primaryColor),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primaryColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
// lib/screens/administration/add_livraison_page.dart

import 'dart:typed_data';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/widgets/product_selector_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart'; // ❌ REMOVED
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// ✅ ADDED for B2
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:developer'; // for debugPrint

class AddLivraisonPage extends StatefulWidget {
  final String? serviceType;
  final String? livraisonId;

  const AddLivraisonPage({super.key, this.serviceType, this.livraisonId});

  @override
  State createState() => _AddLivraisonPageState();
}

class _AddLivraisonPageState extends State<AddLivraisonPage> {
  final _formKey = GlobalKey<FormState>();
  String _deliveryMethod = 'Livraison Interne';
  SelectableItem? _selectedClient;
  SelectableItem? _selectedStore;
  List<ProductSelection> _selectedProducts = [];
  String? _selectedServiceType;
  SelectableItem? _selectedTechnician;
  final _externalCarrierNameController = TextEditingController();
  final _trackingNumberController = TextEditingController();

  List<SelectableItem> _clients = [];
  List<SelectableItem> _stores = [];
  List<SelectableItem> _technicians = [];

  bool _isLoadingClients = true;
  bool _isLoadingStores = false;
  bool _isLoadingTechnicians = true;
  bool _isLoadingPage = false;
  String? _clientError;

  FilePickerResult? _pickedFile;
  String? _existingFileUrl;
  String? _existingFileName;
  bool _isUploading = false;

  bool get _isEditMode => widget.livraisonId != null;

  // ✅ ADDED B2 Cloud Function URL constant
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';

  @override
  void initState() {
    super.initState();
    _selectedServiceType = widget.serviceType;
    if (_isEditMode) {
      _loadLivraisonData();
    }
    _fetchClients();
    _fetchTechnicians();
  }

  @override
  void dispose() {
    _externalCarrierNameController.dispose();
    _trackingNumberController.dispose();
    super.dispose();
  }

  // --- DATA FETCHING & LOGIC ---
  Future<void> _loadLivraisonData() async {
    setState(() => _isLoadingPage = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('livraisons')
          .doc(widget.livraisonId!)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Erreur: Livraison non trouvée.'),
            backgroundColor: Colors.red,
          ));
          Navigator.pop(context);
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      _selectedServiceType = data['serviceType'];
      _deliveryMethod = data['deliveryMethod'] ?? 'Livraison Interne';
      _externalCarrierNameController.text = data['externalCarrierName'] ?? '';
      _trackingNumberController.text = data['trackingNumber'] ?? '';

      if (data['clientId'] != null && data['clientName'] != null) {
        _selectedClient =
            SelectableItem(id: data['clientId'], name: data['clientName']);
        await _fetchStores(data['clientId']);
      }

      if (data['storeId'] != null) {
        final storeExists =
        _stores.any((store) => store.id == data['storeId']);
        if (storeExists) {
          _selectedStore =
              _stores.firstWhere((store) => store.id == data['storeId']);
        }
      }

      if (data['technicianId'] != null && data['technicianName'] != null) {
        _selectedTechnician = SelectableItem(
            id: data['technicianId'], name: data['technicianName']);
      }

      if (data['products'] is List) {
        _selectedProducts = (data['products'] as List)
            .map((p) => ProductSelection.fromJson(p))
            .toList();
      }

      _existingFileUrl = data['externalBonUrl'];
      _existingFileName = data['externalBonFileName'];

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur de chargement: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoadingPage = false);
    }
  }

  Future<void> _fetchClients() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (mounted) {
        setState(() => _clientError = "Erreur: Utilisateur non connecté.");
      }
      return;
    }
    setState(() => _isLoadingClients = true);
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('clients').get();
      final clients = snapshot.docs
          .map((doc) => SelectableItem(id: doc.id, name: doc['name'] as String))
          .toList();
      clients.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() => _clients = clients);
    } catch (e) {
      if (mounted) setState(() => _clientError = "Erreur: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoadingClients = false);
    }
  }

  Future<void> _fetchStores(String clientId) async {
    setState(() {
      _isLoadingStores = true;
      _selectedStore = null;
      _stores = [];
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .get();
      final stores = snapshot.docs.map((doc) {
        final data = doc.data();
        final location = data.containsKey('location') ? data['location'] : '';
        return SelectableItem(
          id: doc.id,
          name: data['name'] as String,
          data: {'location': location},
        );
      }).toList();
      if (mounted) setState(() => _stores = stores);
    } catch (e) {
      print('Error fetching stores: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStores = false);
    }
  }

  Future<void> _fetchTechnicians() async {
    setState(() => _isLoadingTechnicians = true);
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('users').get();
      final technicians = snapshot.docs
          .map((doc) => SelectableItem(
          id: doc.id, name: doc['displayName'] as String? ?? doc.id))
          .toList();
      if (mounted) setState(() => _technicians = technicians);
    } catch (e) {
      print('Error fetching technicians: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTechnicians = false);
    }
  }

  // ✅ --- START: ADDED B2 HELPER FUNCTIONS ---
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

  Future<Map<String, String>?> _uploadFileToB2(
      PlatformFile file, Map<String, dynamic> b2Creds) async {
    try {
      final fileBytes = file.bytes;
      if (fileBytes == null) {
        debugPrint('File bytes are null for ${file.name}');
        return null;
      }
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final fileName = file.name;

      // Determine mime type
      String? mimeType;
      if (fileName.toLowerCase().endsWith('.jpg') ||
          fileName.toLowerCase().endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (fileName.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (fileName.toLowerCase().endsWith('.pdf')) {
        mimeType = 'application/pdf';
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
        // Correctly encode each part of the path
        final encodedPath = (body['fileName'] as String)
            .split('/')
            .map(Uri.encodeComponent)
            .join('/');
        final downloadUrl =
            (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
        return {'url': downloadUrl, 'name': fileName};
      } else {
        debugPrint('Failed to upload to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file to B2: $e');
      return null;
    }
  }
  // ✅ --- END: ADDED B2 HELPER FUNCTIONS ---

  Future<String> _getNextBonLivraisonCode() async {
    final year = DateTime.now().year;
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('livraison_counter_$year');

    final nextNumber =
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      if (!snapshot.exists) {
        transaction.set(counterRef, {'count': 1});
        return 1;
      } else {
        final data = snapshot.data();
        final count = data?['count'];
        final lastNumber = (count is num) ? count.toInt() : 0;
        final newNumber = lastNumber + 1;
        transaction.set(counterRef, {'count': newNumber});
        return newNumber;
      }
    });
    return 'BL-$nextNumber/$year';
  }

  void _showProductSelectorDialog() async {
    final List<ProductSelection>? result = await showDialog(
        context: context,
        builder: (context) =>
            ProductSelectorDialog(initialProducts: _selectedProducts));
    if (result != null) {
      setState(() => _selectedProducts = result);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true, // ✅ IMPORTANT: Need bytes in memory for B2
    );

    if (result != null) {
      setState(() {
        _pickedFile = result;
        _existingFileUrl = null;
        _existingFileName = null;
      });
    }
  }

  // ❌ REMOVED Firebase Storage upload function
  /*
  Future<Map<String, String>?> _uploadFile(String livraisonId) async {
    if (_pickedFile == null) return null;

    final fileBytes = _pickedFile!.files.first.bytes;
    final fileName = _pickedFile!.files.first.name;
    if (fileBytes == null) return null;

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('bons_de_livraison/$livraisonId/$fileName');

    final uploadTask = storageRef.putData(fileBytes);
    final snapshot = await uploadTask.whenComplete(() => {});
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return {'url': downloadUrl, 'name': fileName};
  }
  */

  Future<void> _saveLivraison() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez ajouter au moins un produit.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      final livraisonsCollection =
      FirebaseFirestore.instance.collection('livraisons');
      final docRef = _isEditMode
          ? livraisonsCollection.doc(widget.livraisonId!)
          : livraisonsCollection.doc();

      // ✅ --- START: MODIFIED B2 UPLOAD LOGIC ---
      Map<String, String>? uploadedFileInfo;
      if (_pickedFile != null) {
        // 1. Get B2 credentials
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) {
          throw Exception('Impossible de récupérer les accès B2.');
        }
        // 2. Upload to B2
        uploadedFileInfo =
        await _uploadFileToB2(_pickedFile!.files.first, b2Credentials);
        if (uploadedFileInfo == null) {
          throw Exception('Échec de l\'upload du fichier sur B2.');
        }
      }
      // ✅ --- END: MODIFIED B2 UPLOAD LOGIC ---

      final deliveryData = <String, dynamic>{
        'clientId': _selectedClient!.id,
        'clientName': _selectedClient!.name,
        'storeId': _selectedStore?.id,
        'storeName': _selectedStore?.name,
        'deliveryAddress': _selectedStore?.data?['location'] ?? 'N/A',
        'contactPerson': '',
        'contactPhone': '',
        'products': _selectedProducts.map((p) => p.toJson()).toList(),
        'status': 'À Préparer',
        'deliveryMethod': _deliveryMethod,
        'technicianId':
        _deliveryMethod == 'Livraison Interne' ? _selectedTechnician?.id : null,
        'technicianName': _deliveryMethod == 'Livraison Interne'
            ? _selectedTechnician?.name
            : null,
        'externalCarrierName': _deliveryMethod == 'Livraison Externe'
            ? _externalCarrierNameController.text
            : null,
        'trackingNumber': _deliveryMethod == 'Livraison Externe'
            ? _trackingNumberController.text
            : null,
        'serviceType': _selectedServiceType,
        'lastModifiedBy': user.displayName ?? user.email,
        'lastModifiedAt': FieldValue.serverTimestamp(),
        // ✅ Use new B2 upload info or existing info
        'externalBonUrl': uploadedFileInfo?['url'] ?? _existingFileUrl,
        'externalBonFileName': uploadedFileInfo?['name'] ?? _existingFileName,
      };

      if (_isEditMode) {
        await docRef.update(deliveryData);
      } else {
        final bonLivraisonCode = await _getNextBonLivraisonCode();
        final createData = {
          ...deliveryData,
          'bonLivraisonCode': bonLivraisonCode,
          'createdBy': user.displayName ?? user.email,
          'createdById': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await docRef.set(createData);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de la sauvegarde: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- WIDGETS (No Changes) ---

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light grey background
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          _isEditMode ? 'Modifier la Livraison' : 'Créer une Livraison',
          style: textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
      ),
      body: _isLoadingPage
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionCard(
                  title: 'Informations Livraison',
                  icon: Icons.info_outline,
                  children: [
                    if (widget.serviceType == null) ...[
                      _buildDropdownField(
                        label: 'Choisir le Service',
                        value: _selectedServiceType,
                        items: [
                          'Service Technique',
                          'Service IT',
                          'Les Deux'
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedServiceType = value;
                            _technicians = [];
                            _selectedTechnician = null;
                          });
                          _fetchTechnicians();
                        },
                        icon: Icons.business_center,
                        validator: (value) => value == null
                            ? 'Veuillez sélectionner un service'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildDropdownField(
                      label: 'Méthode de livraison',
                      value: _deliveryMethod,
                      items: ['Livraison Interne', 'Livraison Externe'],
                      onChanged: (value) {
                        setState(() {
                          _deliveryMethod = value!;
                          if (_deliveryMethod != 'Livraison Interne') {
                            _selectedTechnician = null;
                          }
                        });
                      },
                      icon: Icons.local_shipping,
                    ),
                    const SizedBox(height: 16),
                    if (_deliveryMethod == 'Livraison Interne')
                      _buildSelectableDropdown(
                        label: 'Assigner à un Technicien',
                        value: _selectedTechnician,
                        items: _technicians,
                        onChanged: _isLoadingTechnicians
                            ? null
                            : (value) =>
                            setState(() => _selectedTechnician = value),
                        icon: Icons.person_outline,
                        validator: (value) => value == null
                            ? 'Veuillez sélectionner un technicien'
                            : null,
                      )
                    else ...[
                      _buildTextField(
                        controller: _externalCarrierNameController,
                        label: 'Nom du transporteur',
                        icon: Icons.business,
                        validator: (value) =>
                        value == null || value.isEmpty
                            ? 'Veuillez entrer le nom du transporteur'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _trackingNumberController,
                        label: 'Numéro de suivi (Optionnel)',
                        icon: Icons.qr_code_scanner,
                      ),
                    ],
                  ]),
              const SizedBox(height: 24),
              _buildSectionCard(
                  title: 'Destination',
                  icon: Icons.location_on_outlined,
                  children: [
                    _buildSelectableDropdown(
                      label: 'Client',
                      value: _selectedClient,
                      items: _clients,
                      onChanged: _isLoadingClients || _clients.isEmpty
                          ? null
                          : (value) {
                        setState(() {
                          _selectedClient = value;
                          _selectedStore = null;
                          _stores = [];
                        });
                        if (value != null) {
                          _fetchStores(value.id);
                        }
                      },
                      isLoading: _isLoadingClients,
                      icon: Icons.business_center,
                      validator: (value) => value == null
                          ? 'Veuillez sélectionner un client'
                          : null,
                    ),
                    if (_selectedClient != null) ...[
                      const SizedBox(height: 16),
                      _buildSelectableDropdown(
                        label: 'Magasin / Destination',
                        value: _selectedStore,
                        items: _stores,
                        // ✅ FIX: Added TextOverflow.ellipsis to prevent overflow
                        itemBuilder: (store) => Text(
                          '${store.name} - ${store.data?['location'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: _isLoadingStores || _stores.isEmpty
                            ? null
                            : (value) =>
                            setState(() => _selectedStore = value),
                        isLoading: _isLoadingStores,
                        icon: Icons.store,
                      )
                    ]
                  ]),
              const SizedBox(height: 24),
              _buildSectionCard(
                  title: 'Produits à Livrer',
                  icon: Icons.inventory_2_outlined,
                  children: [
                    if (_selectedProducts.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Aucun produit ajouté.'),
                        ),
                      )
                    else
                      ..._selectedProducts
                          .map((product) => ListTile(
                        leading: const Icon(
                            Icons.check_box_outline_blank,
                            color: Color(0xFF1976D2)),
                        title: Text(product.productName,
                            style: textTheme.bodyMedium),
                        trailing: Text('Qté: ${product.quantity}',
                            style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold)),
                      ))
                          .toList(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showProductSelectorDialog,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Ajouter/Modifier Produits'),
                        style: OutlinedButton.styleFrom(
                          padding:
                          const EdgeInsets.symmetric(vertical: 12),
                          side:
                          const BorderSide(color: Color(0xFFFFC107)),
                          foregroundColor: const Color(0xFFFFC107),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),
              const SizedBox(height: 24),
              _buildSectionCard(
                  title: 'Bon de Livraison',
                  icon: Icons.attach_file,
                  children: [
                    if (_pickedFile == null && _existingFileUrl == null)
                      _buildFileUploadBox(),
                    if (_pickedFile != null)
                      _buildFileInfo(
                        fileName: _pickedFile!.files.first.name,
                        icon: Icons.file_present_rounded,
                        iconColor: const Color(0xFF20C997),
                        onClear: () => setState(() => _pickedFile = null),
                      ),
                    if (_existingFileUrl != null)
                      _buildFileInfo(
                        fileName: _existingFileName ?? 'Fichier existant',
                        icon: Icons.description,
                        iconColor: const Color(0xFF1976D2),
                        onTap: () async {
                          final url = Uri.parse(_existingFileUrl!);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        },
                        onClear: () => setState(() {
                          _existingFileUrl = null;
                          _existingFileName = null;
                        }),
                      ),
                  ]),
              const SizedBox(height: 40),
              if (_isUploading)
                const Center(child: CircularProgressIndicator())
              else
                _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title,
        required IconData icon,
        required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue[800], size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    required IconData icon,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem(
        value: item,
        child: Text(item.toString(),
            style: GoogleFonts.poppins(fontSize: 16)),
      ))
          .toList(),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSelectableDropdown({
    required String label,
    required SelectableItem? value,
    required List<SelectableItem> items,
    required void Function(SelectableItem?)? onChanged,
    required IconData icon,
    bool isLoading = false,
    Widget Function(SelectableItem)? itemBuilder,
    String? Function(SelectableItem?)? validator,
  }) {
    return DropdownButtonFormField<SelectableItem>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem<SelectableItem>(
        value: item,
        child: itemBuilder != null
            ? itemBuilder(item)
            : Text(item.name,
            style: GoogleFonts.poppins(fontSize: 16)),
      ))
          .toList(),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        suffixIcon: isLoading
            ? const Padding(
            padding: EdgeInsets.all(12.0),
            child: CircularProgressIndicator(strokeWidth: 2))
            : null,
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFileUploadBox() {
    return InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber, width: 2),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.upload_file_rounded,
                  color: Colors.amber, size: 40),
              const SizedBox(height: 12),
              Text(
                'Choisir un Fichier',
                style: GoogleFonts.poppins(
                  color: Colors.amber[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'PDF, JPG, PNG',
                style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileInfo({
    required String fileName,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onClear,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: iconColor, size: 30),
        title: Text(fileName,
            style: GoogleFonts.poppins(), overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: Icon(Icons.clear, color: Colors.red[400]),
          tooltip: 'Supprimer le fichier',
          onPressed: onClear,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ]),
      child: ElevatedButton.icon(
        onPressed: _saveLivraison,
        icon: Icon(_isEditMode ? Icons.save_alt_rounded : Icons.send_rounded,
            color: Colors.white),
        label: Text(
          _isEditMode
              ? 'Enregistrer les Modifications'
              : 'Créer le Bon de Livraison',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
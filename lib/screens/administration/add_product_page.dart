// lib/screens/administration/add_product_page.dart

import 'dart:io'; // Needed for mobile File access
import 'package:flutter/foundation.dart'; // ✅ ADDED: For kIsWeb check
import 'dart:typed_data'; // ✅ ADDED: For Uint8List
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:boitex_info_app/screens/administration/barcode_scanner_page.dart';
// ✅ ADDED: file_picker for picking PDFs
import 'package:file_picker/file_picker.dart';
// ✅ ADDED: Imports for B2 upload helpers
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path; // Use 'as path' to avoid conflicts
import 'package:firebase_auth/firebase_auth.dart';

class AddProductPage extends StatefulWidget {
  final DocumentSnapshot? productDoc;

  const AddProductPage({super.key, this.productDoc});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  // ... (Keep existing controllers) ...
  final _nomController = TextEditingController();
  final _marqueController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();
  final _origineController = TextEditingController();
  final _tagsController = TextEditingController();

  bool _isLoading = false;
  String? _mainCategory;
  String? _selectedSubcategory;

  // Image related state
  // ✅ MODIFIED: Use XFile for cross-platform compatibility (Web & Mobile)
  final List<XFile> _selectedImages = [];
  final List<String> _existingImageUrls = [];
  final ImagePicker _picker = ImagePicker();

  // ✅ MODIFIED: Use PlatformFile for cross-platform PDF handling
  final List<PlatformFile> _selectedPdfs = [];
  final List<Map<String, String>> _existingPdfData = []; // Store name and URL

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl';

  final List<Map<String, dynamic>> _mainCategories = [
    {'name': 'Antivol', 'icon': Icons.shield_rounded, 'color': const Color(0xFF6366F1)},
    {'name': 'TPV', 'icon': Icons.point_of_sale_rounded, 'color': const Color(0xFFEC4899)},
    {'name': 'Compteur Client', 'icon': Icons.people_rounded, 'color': const Color(0xFF10B981)},
  ];

  bool get _isEditing => widget.productDoc != null;

  @override
  void initState() {
    super.initState();
    // ... (Keep existing initState logic for animations and editing) ...
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    if (_isEditing) {
      final data = widget.productDoc!.data() as Map<String, dynamic>;
      _nomController.text = data['nom'] ?? '';
      _mainCategory = data['mainCategory'];
      _selectedSubcategory = data['categorie'];
      _marqueController.text = data['marque'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _referenceController.text = data['reference'] ?? '';
      _origineController.text = data['origine'] ?? '';

      final tagsList = data['tags'] as List<dynamic>?;
      if (tagsList != null) {
        _tagsController.text = tagsList.join(', ');
      }

      final imageUrls = data['imageUrls'] as List<dynamic>?;
      if (imageUrls != null) {
        _existingImageUrls.addAll(imageUrls.cast<String>());
      }

      // ✅ ADDED: Load existing PDF data
      final pdfDataList = data['manualFiles'] as List<dynamic>?;
      if (pdfDataList != null) {
        _existingPdfData.addAll(pdfDataList.cast<Map<String, dynamic>>().map((map) => {
          'fileName': map['fileName']?.toString() ?? 'Document.pdf', // Provide default
          'fileUrl': map['fileUrl']?.toString() ?? '',
        }).where((map) => map['fileUrl']!.isNotEmpty)); // Filter out invalid entries
      }
    }
  }

  @override
  void dispose() {
    // ... (Keep existing dispose logic) ...
    _animationController.dispose();
    _nomController.dispose();
    _marqueController.dispose();
    _descriptionController.dispose();
    _referenceController.dispose();
    _origineController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  // --- Image Picking (Updated for Web) ---
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo != null) {
        // ✅ WEB FIX: Use asynchronous length() method
        final length = await photo.length();
        const maxFileSize = 50 * 1024 * 1024; // 50 MB
        if (length <= maxFileSize) {
          setState(() {
            _selectedImages.add(photo); // Add XFile directly
          });
        } else if (mounted) {
          _showErrorSnackBar('L\'image dépasse la limite de 50 Mo.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (images.isNotEmpty) {
        const maxFileSize = 50 * 1024 * 1024; // 50 MB
        final validFiles = <XFile>[]; // Store XFiles
        int rejectedCount = 0;

        for (var xFile in images) {
          // ✅ WEB FIX: Use asynchronous length() method
          final length = await xFile.length();
          if (length <= maxFileSize) {
            validFiles.add(xFile);
          } else {
            rejectedCount++;
          }
        }

        setState(() {
          _selectedImages.addAll(validFiles);
        });

        if (rejectedCount > 0 && mounted) {
          _showErrorSnackBar('$rejectedCount image(s) dépassent la limite de 50 Mo.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  void _showImagePickerOptions() { /* ... Keep existing ... */
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildImagePickerOption(
                icon: Icons.photo_camera_rounded,
                title: 'Prendre une photo',
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),
              _buildImagePickerOption(
                icon: Icons.photo_library_rounded,
                title: 'Choisir depuis la galerie',
                gradient: const LinearGradient(
                  colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({ /* ... Keep existing ... */
    required IconData icon,
    required String title,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- ✅ MODIFIED: PDF Picking Logic (Web Compatible) ---
  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true, // Important for Web to populate 'bytes'
      );

      if (result != null && result.files.isNotEmpty) {
        const maxFileSize = 50 * 1024 * 1024; // 50 MB
        final validFiles = <PlatformFile>[];
        int rejectedCount = 0;

        for (var platformFile in result.files) {
          // Use 'size' property which exists on PlatformFile
          if (platformFile.size <= maxFileSize) {
            validFiles.add(platformFile);
          } else {
            rejectedCount++;
          }
        }

        setState(() {
          _selectedPdfs.addAll(validFiles);
        });

        if (rejectedCount > 0 && mounted) {
          _showErrorSnackBar('$rejectedCount PDF(s) dépassent la limite de 50 Mo ou sont invalides.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erreur lors de la sélection du PDF: $e');
      }
    }
  }

  // --- B2 Helper Functions ---
  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response = await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
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


  // ✅ MODIFIED: Generalized B2 Upload Helper to use Bytes (Web Compatible)
  Future<String?> _uploadSingleFileToB2({
    required Uint8List fileBytes, // Pass bytes directly
    required String fileName,     // Pass filename directly
    required Map<String, dynamic> b2Creds,
    required String b2FileName,
  }) async {
    try {
      final sha1Hash = sha1.convert(fileBytes).toString();

      // Determine mime type
      String mimeType = 'b2/x-auto'; // Default
      final String extension = path.extension(fileName).toLowerCase();
      if (extension == '.jpg' || extension == '.jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == '.png') {
        mimeType = 'image/png';
      } else if (extension == '.pdf') {
        mimeType = 'application/pdf';
      }

      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(b2FileName),
          'Content-Type': mimeType,
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final encodedPath = (body['fileName'] as String).split('/').map(Uri.encodeComponent).join('/');
        return (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
      } else {
        debugPrint('Failed to upload file ($fileName) to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file ($fileName) to B2: $e');
      return null;
    }
  }


  // ✅ MODIFIED: Logic to handle XFile upload (Web & Mobile)
  Future<List<String>> _uploadImagesToB2(String productId, Map<String, dynamic> b2Credentials) async {
    final List<String> uploadedUrls = [];
    if (_selectedImages.isEmpty) return uploadedUrls;

    try {
      for (int i = 0; i < _selectedImages.length; i++) {
        final xfile = _selectedImages[i];
        // Get bytes safely on all platforms
        final fileBytes = await xfile.readAsBytes();
        final originalFileName = xfile.name; // Use .name property of XFile

        // Use 'images' subfolder
        final String b2FileName = 'products/$productId/images/${DateTime.now().millisecondsSinceEpoch}_$i\_$originalFileName';

        final downloadUrl = await _uploadSingleFileToB2(
          fileBytes: fileBytes,
          fileName: originalFileName,
          b2Creds: b2Credentials,
          b2FileName: b2FileName,
        );

        if (downloadUrl != null) {
          uploadedUrls.add(downloadUrl);
        } else {
          debugPrint('Failed to upload image: $originalFileName');
        }
      }
      return uploadedUrls;
    } catch (e) {
      debugPrint('Error uploading images to B2: $e');
      throw Exception('Erreur lors de l\'upload des images.');
    }
  }

  // ✅ MODIFIED: Logic to handle PlatformFile upload (Web & Mobile)
  Future<List<Map<String, String>>> _uploadPdfsToB2(String productId, Map<String, dynamic> b2Credentials) async {
    final List<Map<String, String>> uploadedPdfData = [];
    if (_selectedPdfs.isEmpty) return uploadedPdfData;

    try {
      for (int i = 0; i < _selectedPdfs.length; i++) {
        final platformFile = _selectedPdfs[i];
        final originalFileName = platformFile.name;

        // Extract bytes depending on platform
        Uint8List? fileBytes;
        if (kIsWeb) {
          fileBytes = platformFile.bytes; // Bytes are populated on Web
        } else {
          // On Mobile, read from path
          if (platformFile.path != null) {
            fileBytes = await File(platformFile.path!).readAsBytes();
          }
        }

        if (fileBytes == null) {
          debugPrint('Error: Could not read bytes for PDF $originalFileName');
          continue;
        }

        // Use 'manuals' subfolder
        final String b2FileName = 'products/$productId/manuals/${DateTime.now().millisecondsSinceEpoch}_$i\_$originalFileName';

        final downloadUrl = await _uploadSingleFileToB2(
          fileBytes: fileBytes,
          fileName: originalFileName,
          b2Creds: b2Credentials,
          b2FileName: b2FileName,
        );

        if (downloadUrl != null) {
          uploadedPdfData.add({
            'fileName': originalFileName,
            'fileUrl': downloadUrl,
          });
        } else {
          debugPrint('Failed to upload PDF: $originalFileName');
        }
      }
      return uploadedPdfData;
    } catch (e) {
      debugPrint('Error uploading PDFs to B2: $e');
      throw Exception('Erreur lors de l\'upload des PDFs.');
    }
  }

  // --- Remove Functions ---
  void _removeImage(int index, {bool isExisting = false}) {
    setState(() {
      if (isExisting) {
        _existingImageUrls.removeAt(index);
      } else {
        _selectedImages.removeAt(index);
      }
    });
  }

  void _removePdf(int index, {bool isExisting = false}) {
    setState(() {
      if (isExisting) {
        _existingPdfData.removeAt(index);
      } else {
        _selectedPdfs.removeAt(index);
      }
    });
  }

  // --- Barcode Scan ---
  Future<void> _scanBarcode() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerPage()),
    );
    if (scannedCode != null) {
      _referenceController.text = scannedCode;
    }
  }


  // --- Category Extraction ---
  List<String> _extractUniqueCategories(QuerySnapshot snapshot, String mainCat) {
    final categories = <String>{};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final productMainCat = data['mainCategory'] as String?;
      final categorie = data['categorie'] as String?;

      if (productMainCat == mainCat && categorie != null && categorie.isNotEmpty) {
        categories.add(categorie);
      }
    }

    final list = categories.toList()..sort();
    return list;
  }

  // --- Snackbars ---
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ✅ MODIFIED: _saveProduct to use new upload functions
  // ✅ MODIFIED: _saveProduct with User Signature Fix
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mainCategory == null) {
      _showErrorSnackBar('Veuillez sélectionner une catégorie principale');
      return;
    }
    if (_selectedSubcategory == null) {
      _showErrorSnackBar('Veuillez sélectionner une catégorie');
      return;
    }
    // Keep image check if images are mandatory
    if (_existingImageUrls.isEmpty && _selectedImages.isEmpty) {
      _showErrorSnackBar('Veuillez ajouter au moins une image du produit');
      return;
    }

    setState(() => _isLoading = true);

    String productId;
    if (_isEditing) {
      productId = widget.productDoc!.id;
    } else {
      final docRef = FirebaseFirestore.instance.collection('produits').doc();
      productId = docRef.id;
    }

    // Get B2 Credentials ONCE
    final b2Credentials = await _getB2UploadCredentials();
    if (b2Credentials == null) {
      _showErrorSnackBar('Erreur: Impossible de contacter le service d\'upload.');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final tagsInput = _tagsController.text.trim();
      final tagsList = tagsInput.isEmpty
          ? <String>[]
          : tagsInput.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      // Upload Images and PDFs in parallel
      final imageUploadFuture = _uploadImagesToB2(productId, b2Credentials);
      final pdfUploadFuture = _uploadPdfsToB2(productId, b2Credentials);

      // Wait for both uploads to complete
      final List<String> newImageUrls = await imageUploadFuture;
      final List<Map<String, String>> newPdfData = await pdfUploadFuture;

      // Combine existing files with newly uploaded ones
      final allImageUrls = [..._existingImageUrls, ...newImageUrls];
      final allPdfData = [..._existingPdfData, ...newPdfData];

      // ✅ GET CURRENT USER IDENTITY (Fix for "Système" user)
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserName = currentUser?.displayName ?? 'Inconnu';

      // Prepare product data for Firestore
      final productData = {
        'nom': _nomController.text.trim(),
        'mainCategory': _mainCategory,
        'categorie': _selectedSubcategory,
        'marque': _marqueController.text.trim(),
        'description': _descriptionController.text.trim(),
        'reference': _referenceController.text.trim(),
        'origine': _origineController.text.trim(),
        'tags': tagsList,
        'imageUrls': allImageUrls,
        'manualFiles': allPdfData,

        // 👇 THIS IS THE FIX: Explicitly sign the update
        'lastModifiedBy': currentUserName,
      };

      if (_isEditing) {
        productData['updatedAt'] = FieldValue.serverTimestamp();
        await widget.productDoc!.reference.update(productData);
        _showSuccessSnackBar('Produit mis à jour avec succès');
      } else {
        productData['createdAt'] = FieldValue.serverTimestamp();
        productData['quantiteEnStock'] = 0; // Set initial stock ONLY for new products
        await FirebaseFirestore.instance.collection('produits').doc(productId).set(productData);
        _showSuccessSnackBar('Produit ajouté avec succès');
      }

      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      _showErrorSnackBar('Erreur lors de l\'enregistrement: ${e.toString()}');
      debugPrint('Error saving product: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
              Colors.pink.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : FadeTransition(
                  opacity: _fadeAnimation,
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildMainCategorySection(),
                        const SizedBox(height: 20),
                        _buildSubcategorySection(),
                        const SizedBox(height: 20),
                        _buildPhotosSection(), // Existing Photos section
                        const SizedBox(height: 20),
                        _buildManualsSection(), // ✅ ADDED: New Manuals section
                        const SizedBox(height: 20),
                        // ... (Keep existing TextFields) ...
                        _buildTextField(
                          controller: _nomController,
                          label: 'Nom du produit',
                          icon: Icons.shopping_bag_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          ),
                          validator: (value) => value?.isEmpty ?? true ? 'Requis' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _marqueController,
                          label: 'Marque',
                          icon: Icons.business_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _referenceController,
                          label: 'Référence',
                          icon: Icons.qr_code_2_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            onPressed: _scanBarcode,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _origineController,
                          label: 'Produit origine',
                          icon: Icons.public_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _descriptionController,
                          label: 'Description',
                          icon: Icons.description_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFA709A), Color(0xFFFEE140)],
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _tagsController,
                          label: 'Tags (séparés par une virgule)',
                          icon: Icons.local_offer_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF30CFD0), Color(0xFF330867)],
                          ),
                          hint: 'ex: gps, tracker, antivol',
                        ),
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Keep existing build methods for AppBar, LoadingState, Category Sections, TextField, SaveButton ---
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667EEA),
            const Color(0xFF764BA2),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Modifier' : 'Ajouter',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Produit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade200.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Enregistrement en cours...',
            style: TextStyle(
              color: Color(0xFF667EEA),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildMainCategorySection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.category_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Catégorie Principale',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _mainCategories.map((category) {
                final isSelected = _mainCategory == category['name'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _mainCategory = category['name'] as String;
                      _selectedSubcategory = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                        colors: [
                          category['color'] as Color,
                          (category['color'] as Color).withOpacity(0.7),
                        ],
                      )
                          : LinearGradient(
                        colors: [
                          Colors.grey.shade100,
                          Colors.grey.shade50,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: (category['color'] as Color).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          category['icon'] as IconData,
                          color: isSelected ? Colors.white : Colors.grey.shade600,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          category['name'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSubcategorySection() {
    if (_mainCategory == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100.withOpacity(0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade200, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.info_rounded, color: Colors.blue.shade700, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Sélectionnez d\'abord une catégorie principale',
                style: TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('produits').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Erreur de chargement'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = _extractUniqueCategories(snapshot.data!, _mainCategory!);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.9),
                Colors.white.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Catégorie',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (categories.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_rounded, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Aucune catégorie disponible',
                          style: TextStyle(color: Color(0xFF1F2937)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: categories.map((category) {
                    final isSelected = _selectedSubcategory == category;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedSubcategory = category;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                            colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
                          )
                              : LinearGradient(
                            colors: [Colors.grey.shade100, Colors.grey.shade50],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected
                              ? [
                            BoxShadow(
                              color: const Color(0xFFF093FB).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                              : [],
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Gradient gradient,
    String? hint,
    int? maxLines,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines ?? 1,
        validator: validator,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1F2937),
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: gradient.colors.first,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
    );
  }
  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _saveProduct,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  _isEditing ? 'Mettre à jour le Produit' : 'Enregistrer le Produit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Photos Section ---
  Widget _buildPhotosSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Photos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showImagePickerOptions,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: const [
                          Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Ajouter',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_existingImageUrls.isEmpty && _selectedImages.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 2, strokeAlign: BorderSide.strokeAlignInside),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Aucune photo ajoutée',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_existingImageUrls.isNotEmpty) ...[
                  Text(
                    'Images existantes',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(_existingImageUrls.length, (index) {
                      return _buildImageThumbnail(
                        imageUrl: _existingImageUrls[index],
                        onRemove: () => _removeImage(index, isExisting: true),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_selectedImages.isNotEmpty) ...[
                  Text(
                    'Nouvelles images',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(_selectedImages.length, (index) {
                      return _buildImageThumbnail(
                        imageFile: _selectedImages[index],
                        onRemove: () => _removeImage(index),
                      );
                    }),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // ✅ MODIFIED: Updated thumbnail to handle XFile correctly on Web
  Widget _buildImageThumbnail({
    String? imageUrl,
    XFile? imageFile, // Changed from File to XFile
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageUrl != null
                ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.error_outline),
                );
              },
            )
            // ✅ WEB FIX: Handle XFile display safely
                : (kIsWeb
                ? Image.network(imageFile!.path, fit: BoxFit.cover)
                : Image.file(File(imageFile!.path), fit: BoxFit.cover)),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ --- NEW WIDGETS FOR MANUALS SECTION ---
  Widget _buildManualsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF97316), Color(0xFFEA580C)], // Orange gradient for manuals
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'PDF',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF97316).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickPdf, // Call the PDF picker function
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: const [
                          Icon(Icons.attach_file_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Ajouter',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_existingPdfData.isEmpty && _selectedPdfs.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 2, strokeAlign: BorderSide.strokeAlignInside),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.file_copy_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Aucun fichier PDF ajouté',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_existingPdfData.isNotEmpty) ...[
                  Text(
                    'Fichiers PDF existants',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(_existingPdfData.length, (index) {
                      final pdfInfo = _existingPdfData[index];
                      return _buildPdfChip(
                        fileName: pdfInfo['fileName']!,
                        onRemove: () => _removePdf(index, isExisting: true),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_selectedPdfs.isNotEmpty) ...[
                  Text(
                    'Nouveaux fichiers PDF',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(_selectedPdfs.length, (index) {
                      return _buildPdfChip(
                        fileName: path.basename(_selectedPdfs[index].name), // use .name for PlatformFile
                        onRemove: () => _removePdf(index),
                      );
                    }),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPdfChip({
    required String fileName,
    required VoidCallback onRemove,
  }) {
    return Chip(
      avatar: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFB91C1C), size: 18),
      label: Text(
        fileName,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF1F2937),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
      onDeleted: onRemove,
      backgroundColor: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.red.shade100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
// ✅ --- END: NEW WIDGETS FOR MANUALS SECTION ---
}
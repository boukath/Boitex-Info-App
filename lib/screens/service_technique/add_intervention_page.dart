// lib/screens/service_technique/add_intervention_page.dart

import 'dart:ui' as ui; // for ImageFilter.blur in BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Haptic feedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ✅ NEW IMPORTS FOR B2 & MEDIA HANDLING
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart'; // For camera/video access
import 'package:video_thumbnail/video_thumbnail.dart'; // For displaying video thumbnails


// Simple data model for a Client
class Client {
  final String id;
  final String name;
  Client({required this.id, required this.name});

  @override
  bool operator ==(Object other) => other is Client && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// Simple data model for a Store
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

class AddInterventionPage extends StatefulWidget {
  final String serviceType;
  const AddInterventionPage({super.key, required this.serviceType});

  @override
  State createState() => _AddInterventionPageState();
}

class _AddInterventionPageState extends State<AddInterventionPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ✅ NEW: B2 Cloud Function URL (Copied from mission_details_page)
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';

  // Existing Controllers
  final _clientPhoneController = TextEditingController();
  final _requestController = TextEditingController();

  // Search Controllers for Autocomplete
  final _clientSearchController = TextEditingController();
  final _storeSearchController = TextEditingController();

  bool _isLoading = false;

  // Existing State
  String? _selectedInterventionType;
  String? _selectedInterventionPriority;
  Client? _selectedClient;
  Store? _selectedStore;

  // Data and Loading States
  List<Client> _clients = [];
  List<Store> _stores = [];
  bool _isLoadingClients = true;
  bool _isLoadingStores = false;

  // ✅ NEW: State for Media Upload
  List<File> _localFilesToUpload = [];
  List<String> _uploadedMediaUrls = [];
  bool _isUploadingMedia = false;

  // Creamy light + sunlit pastels background (sorbet gradient, luminous neutrals)
  final List<Color> gradientColors = const [
    Color(0xFFFDF4F0), // pastel peach (porcelain base)
    Color(0xFFE8F5E8), // muted mint pastel (luminous neutral)
    Color(0xFFF3E8FF), // soft lavender (sorbet accent)
  ];

  // Jewel-tone accents and duotone glow (color tokens)
  static const Color kJewelAccent = Color(0xFF6B7280); // slate jewel
  static const Color kDuotoneGlow = Color(0xFF10B981); // emerald glow

  // Adaptive themes: creamy light mode / velvet dark mode
  bool _isDarkMode = false;

  late AnimationController _animationController;
  late Animation<double> _parallaxAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    _parallaxAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchClients();
  }

  @override
  void dispose() {
    _clientPhoneController.dispose();
    _requestController.dispose();
    _clientSearchController.dispose();
    _storeSearchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // --- B2 HELPER FUNCTIONS (COPIED/ADAPTED FROM mission_details_page) ---

  // Gets credentials from the cloud function
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

  // Uploads a single file to B2
  Future<String?> _uploadFileToB2(
      File file, Map<String, dynamic> b2Creds) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final fileName = path.basename(file.path);

      String? mimeType;
      // Simple MIME type detection for common media
      final extension = path.extension(fileName).toLowerCase();
      if (extension == '.jpg' || extension == '.jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == '.png') {
        mimeType = 'image/png';
      } else if (extension == '.mp4' || extension == '.mov') {
        mimeType = 'video/mp4';
      } else if (extension == '.pdf') {
        mimeType = 'application/pdf';
      } else {
        mimeType = 'b2/x-auto';
      }

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': mimeType,
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final encodedPath =
        (body['fileName'] as String).split('/').map(Uri.encodeComponent).join('/');
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

  // --- NEW MEDIA PICKER LOGIC ---

  // Handles picking multiple files (photos, videos, docs)
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        final newFiles = result.paths
            .where((p) => p != null)
            .map((p) => File(p!))
            .toList();
        _localFilesToUpload.addAll(newFiles);
      });
    }
  }

  // Handles capturing a single photo from the camera
  Future<void> _capturePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xFile = await picker.pickImage(source: ImageSource.camera);

    if (xFile != null) {
      setState(() {
        _localFilesToUpload.add(File(xFile.path));
      });
    }
  }

  // Handles capturing a single video from the camera
  Future<void> _captureVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xFile = await picker.pickVideo(source: ImageSource.camera);

    if (xFile != null) {
      setState(() {
        _localFilesToUpload.add(File(xFile.path));
      });
    }
  }

  // Data Fetching Logic
  Future<void> _fetchClients() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .orderBy('name')
          .get();
      final clients = snapshot.docs.map((doc) {
        return Client(id: doc.id, name: doc.data()['name']);
      }).toList();
      if (mounted) {
        setState(() {
          _clients = clients;
          _isLoadingClients = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingClients = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des clients: $e')),
        );
      }
    }
  }

  Future<void> _fetchStores(String clientId) async {
    setState(() {
      _isLoadingStores = true;
      _stores = [];
      _selectedStore = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .orderBy('name')
          .get();
      final stores = snapshot.docs.map((doc) {
        final data = doc.data();
        return Store(
          id: doc.id,
          name: data['name'],
          location: data['location'],
        );
      }).toList();
      if (mounted) {
        setState(() {
          _stores = stores;
          _isLoadingStores = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStores = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des magasins: $e')),
        );
      }
    }
  }

  // Quick-Add Dialogs
  Future<Client?> _showAddClientDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Client>(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: gradientColors[0],
            brightness: _isDarkMode ? Brightness.dark : Brightness.light,
          ),
        ),
        child: AlertDialog(
          backgroundColor: _isDarkMode
              ? const Color(0xFF1F2937).withOpacity(0.9) // velvet dark
              : Colors.white.withOpacity(0.95), // porcelain white space
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Ajouter un Nouveau Client',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600, // elegant serif feel
              fontSize: 20,
              height: 1.1,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Nom du Client *',
                    labelStyle: const TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      const BorderSide(color: kJewelAccent, width: 0.6),
                    ),
                    filled: true,
                    fillColor: _isDarkMode
                        ? const Color(0xFF374151).withOpacity(0.8)
                        : Colors.white.withOpacity(0.9),
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Téléphone (Optionnel)',
                    labelStyle: const TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      const BorderSide(color: kJewelAccent, width: 0.6),
                    ),
                    filled: true,
                    fillColor: _isDarkMode
                        ? const Color(0xFF374151).withOpacity(0.8)
                        : Colors.white.withOpacity(0.9),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Annuler',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white70 : kJewelAccent,
                ),
              ),
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
                      'createdVia': 'intervention_quick_add',
                    });
                    final newClient = Client(
                      id: docRef.id,
                      name: nameController.text.trim(),
                    );
                    Navigator.pop(context, newClient);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kDuotoneGlow,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _clients.add(result);
        _selectedClient = result;
        _clientSearchController.text = result.name;
      });
      _fetchStores(result.id);
    }
    return result;
  }

  Future<Store?> _showAddStoreDialog() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord sélectionner un client')),
      );
      return null;
    }
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Store>(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: gradientColors[1],
            brightness: _isDarkMode ? Brightness.dark : Brightness.light,
          ),
        ),
        child: AlertDialog(
          backgroundColor: _isDarkMode
              ? const Color(0xFF1F2937).withOpacity(0.9)
              : Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Ajouter un Nouveau Magasin',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 20,
              height: 1.1,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Nom du Magasin *',
                    labelStyle: const TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      const BorderSide(color: kJewelAccent, width: 0.6),
                    ),
                    filled: true,
                    fillColor: _isDarkMode
                        ? const Color(0xFF374151).withOpacity(0.8)
                        : Colors.white.withOpacity(0.9),
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: locationController,
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Emplacement *',
                    labelStyle: const TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      const BorderSide(color: kJewelAccent, width: 0.6),
                    ),
                    filled: true,
                    fillColor: _isDarkMode
                        ? const Color(0xFF374151).withOpacity(0.8)
                        : Colors.white.withOpacity(0.9),
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
              child: Text(
                'Annuler',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white70 : kJewelAccent,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final docRef = await FirebaseFirestore.instance
                        .collection('clients')
                        .doc(_selectedClient!.id)
                        .collection('stores')
                        .add({
                      'name': nameController.text.trim(),
                      'location': locationController.text.trim(),
                      'createdAt': Timestamp.now(),
                      'createdVia': 'intervention_quick_add',
                    });
                    final newStore = Store(
                      id: docRef.id,
                      name: nameController.text.trim(),
                      location: locationController.text.trim(),
                    );
                    Navigator.pop(context, newStore);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kDuotoneGlow,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _stores.add(result);
        _selectedStore = result;
        _storeSearchController.text = '${result.name} - ${result.location}';
      });
    }
    return result;
  }

  // --- ✅ NEW: Sequential Code Generation Logic ---
  Future<String> _generateSequentialInterventionCode() async {
    final now = DateTime.now();
    final currentYear = DateFormat('yyyy').format(now);

    // 1. Find the intervention with the highest code for the current year.
    final latestInterventionQuery = await FirebaseFirestore.instance
        .collection('interventions')
        .where('interventionCode', isGreaterThanOrEqualTo: 'INT-00/$currentYear') // Start of range
        .where('interventionCode', isLessThan: 'INT-a/$currentYear') // Use 'a' as an upper bound (string sort)
        .orderBy('interventionCode', descending: true)
        .limit(1)
        .get();

    int nextCounter = 1;
    String codePrefix = 'INT-';

    if (latestInterventionQuery.docs.isNotEmpty) {
      final latestCode = latestInterventionQuery.docs.first.data()['interventionCode'] as String? ?? '';

      // Expected format: INT-XX/YYYY
      try {
        final parts = latestCode.split('-'); // ["INT", "XX/YYYY"]
        if (parts.length > 1) {
          final counterPart = parts.last.split('/').first; // "XX"
          nextCounter = int.parse(counterPart) + 1;
        } else {
          nextCounter = 1; // Fallback if format is unexpected
        }
      } catch (e) {
        // Fallback if parsing fails for any reason
        debugPrint('Error parsing latest code: $latestCode, resetting counter to 1. Error: $e');
        nextCounter = 1;
      }
    }

    // 2. Format the new code (e.g., 'INT-01/2025' or 'INT-34/2025' or 'INT-123/2025')
    // This will format 1 as "01", 34 as "34", and 123 as "123".
    final newCounterString = nextCounter.toString().padLeft(2, '0');

    return '$codePrefix$newCounterString/$currentYear';
  }
  // --- End of new helper function ---


  // Save Intervention Function (MODIFIED FOR B2 UPLOAD & SEQUENTIAL CODE)
  Future<void> _saveIntervention() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    if (_selectedClient == null || _selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un client et un magasin.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploadingMedia = true;
      _uploadedMediaUrls = []; // Reset uploaded URLs list
    });

    // --- STEP 1: UPLOAD MEDIA TO B2 ---
    try {
      if (_localFilesToUpload.isNotEmpty) {
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) {
          throw Exception('Impossible de récupérer les accès B2 pour le téléchargement.');
        }

        final List<String> urls = [];
        for (var file in _localFilesToUpload) {
          final url = await _uploadFileToB2(file, b2Credentials);
          if (url != null) {
            urls.add(url);
          } else {
            // Log failure but continue with other files
            debugPrint('Failed to upload file: ${file.path}');
          }
        }
        _uploadedMediaUrls = urls;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'upload média: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
      return; // Stop submission if media upload fails critically
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }

    // --- STEP 2: SAVE INTERVENTION DATA TO FIRESTORE ---
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final creatorName = userDoc.data()?['displayName'] ?? 'Utilisateur inconnu';

      // ✅ NEW: Generate the sequential code
      final interventionCode = await _generateSequentialInterventionCode();
      final interventionRef = FirebaseFirestore.instance.collection('interventions');

      final interventionData = {
        'interventionCode': interventionCode,
        'serviceType': widget.serviceType,
        'clientId': _selectedClient!.id,
        'clientName': _selectedClient!.name,
        'clientPhone': _clientPhoneController.text.trim(),
        'storeId': _selectedStore!.id,
        'storeName': '${_selectedStore!.name} - ${_selectedStore!.location}',
        'requestDescription': _requestController.text.trim(),
        'interventionType': _selectedInterventionType,
        'priority': _selectedInterventionPriority,
        'status': 'Nouvelle Demande',
        'createdAt': Timestamp.now(),
        'createdByUid': user.uid,
        'createdByName': creatorName,
        // ✅ NEW: Save the list of B2 media URLs
        'mediaUrls': _uploadedMediaUrls,
      };

      await interventionRef.add(interventionData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Intervention créée avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Subtle glassmorphism frosted card (depth layering, soft shadows)
  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)), // satin sheen
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode
              ? [
            const Color(0xFF1F2937).withOpacity(0.85), // velvet dark
            const Color(0xFF111827).withOpacity(0.85),
          ]
              : [
            Colors.white.withOpacity(0.85), // porcelain white space
            Colors.white.withOpacity(0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: kDuotoneGlow.withOpacity(0.18), // duotone glow
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: child,
      ),
    );
  }

  // Magnetic buttons with microinteractions (glistening highlights)
  Widget _buildMagneticButton({
    required VoidCallback onPressed,
    required Widget child,
    bool isLoading = false,
    Color? backgroundColor,
    // ✅ NEW: Added isUploadingMedia check
    bool isUploadingMedia = false,
  }) {
    final buttonColor = backgroundColor ?? kDuotoneGlow;

    // Disable if loading OR uploading media
    final isDisabled = isLoading || isUploadingMedia;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact(); // haptic cues
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isDisabled
              ? null // No gradient if disabled
              : LinearGradient(
            colors: [
              buttonColor,
              buttonColor.withOpacity(0.85),
            ],
          ),
          color: isDisabled ? Colors.grey : buttonColor, // Grey if disabled
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDisabled)
              BoxShadow(
                color: kDuotoneGlow.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            if (!isDisabled)
              BoxShadow(
                color: Colors.white.withOpacity(0.18),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isDisabled ? null : onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: isLoading || isUploadingMedia
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
                  : child,
            ),
          ),
        ),
      ),
    );
  }

  // --- NEW MEDIA UI BUILDERS ---

  Widget _buildMediaSection() {
    final textColor = _isDarkMode ? Colors.white : Colors.black87;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FICHIERS & MÉDIAS DE SUPPORT (${_localFilesToUpload.length})',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
        ),
        const Divider(color: kJewelAccent),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMediaActionButton(
              icon: Icons.photo_camera,
              label: 'Photo',
              onPressed: _capturePhoto,
              color: Colors.blue.shade700,
            ),
            _buildMediaActionButton(
              icon: Icons.videocam,
              label: 'Vidéo',
              onPressed: _captureVideo,
              color: Colors.purple.shade700,
            ),
            _buildMediaActionButton(
              icon: Icons.attach_file,
              label: 'PDF',
              onPressed: _pickFiles,
              color: Colors.orange.shade700,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_localFilesToUpload.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (_isDarkMode ? Colors.white10 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fichiers locaux à envoyer:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                ..._localFilesToUpload.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return ListTile(
                    leading: FutureBuilder<Widget>(
                      future: _getLeadingIcon(file.path),
                      builder: (context, snapshot) {
                        return snapshot.data ??
                            const Icon(Icons.file_present, color: kJewelAccent);
                      },
                    ),
                    title: Text(path.basename(file.path),
                        style: TextStyle(color: textColor),
                        overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(
                              () => _localFilesToUpload.removeAt(index)),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMediaActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: _isUploadingMedia ? null : onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<Widget> _getLeadingIcon(String filePath) async {
    final extension = path.extension(filePath).toLowerCase();
    if (extension == '.jpg' || extension == '.jpeg' || extension == '.png') {
      return const Icon(Icons.image, color: Colors.green);
    } else if (extension == '.mp4' || extension == '.mov') {
      // Generate thumbnail for videos
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: filePath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 64,
        quality: 50,
      );
      if (thumbPath != null) {
        return Image.file(File(thumbPath), width: 40, height: 40, fit: BoxFit.cover);
      }
      return const Icon(Icons.videocam, color: Colors.purple);
    } else if (extension == '.pdf') {
      return const Icon(Icons.picture_as_pdf, color: Colors.red);
    }
    return const Icon(Icons.insert_drive_file, color: Colors.blue);
  }

  // --- MAIN BUILD & DISPOSE ---

  @override
  Widget build(BuildContext context) {
    final textColor = _isDarkMode ? Colors.white : Colors.black87;
    final backgroundColor =
    _isDarkMode ? const Color(0xFF111827) : const Color(0xFFFAFAF9);

    final OutlineInputBorder focusedBorder = OutlineInputBorder(
      borderSide: const BorderSide(color: kDuotoneGlow, width: 2.0),
      borderRadius: BorderRadius.circular(16.0),
    );
    final OutlineInputBorder defaultBorder = OutlineInputBorder(
      borderSide: BorderSide(color: gradientColors[0].withOpacity(0.4)),
      borderRadius: BorderRadius.circular(16.0),
    );

    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Oversized hero with feathered motion (parallax-lite)
          AnimatedBuilder(
            animation: _parallaxAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _parallaxAnimation.value * 10),
                child: Text(
                  'Nouvelle Intervention',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        color: kDuotoneGlow.withOpacity(0.28),
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // Adaptive theme toggle (floating nav feel)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () {
                  setState(() => _isDarkMode = !_isDarkMode);
                },
                icon: Icon(
                  _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  color: kJewelAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Client Autocomplete + Add (card stacks feel via spacing)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: _isLoadingClients
                      ? Center(
                    child: CircularProgressIndicator(color: kDuotoneGlow),
                  )
                      : Autocomplete<Client>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return _clients;
                      }
                      return _clients.where((client) => client.name
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()));
                    },
                    displayStringForOption: (client) => client.name,
                    onSelected: (client) {
                      setState(() => _selectedClient = client);
                      _fetchStores(client.id);
                    },
                    fieldViewBuilder: (context, controller, focusNode,
                        onFieldSubmitted) {
                      _clientSearchController.text = controller.text;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        style: TextStyle(color: textColor, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Nom du Client *',
                          labelStyle:
                          TextStyle(color: textColor.withOpacity(0.7)),
                          enabledBorder: defaultBorder,
                          focusedBorder: focusedBorder,
                          filled: true,
                          fillColor: backgroundColor.withOpacity(0.9),
                          suffixIcon: const Icon(
                            Icons.arrow_drop_down,
                            color: kJewelAccent,
                          ),
                        ),
                        validator: (value) => _selectedClient == null
                            ? 'Veuillez sélectionner un client'
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _buildMagneticButton(
                  onPressed: () {
                    _showAddClientDialog();
                  },
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                  backgroundColor: kDuotoneGlow,
                  isLoading: _isLoading, // Use general loading state for client add
                  isUploadingMedia: _isUploadingMedia,
                ),
              ],
            ),
          ),

          // Store Autocomplete + Add
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: _isLoadingStores
                      ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child:
                      CircularProgressIndicator(color: kDuotoneGlow),
                    ),
                  )
                      : Autocomplete<Store>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return _stores;
                      }
                      return _stores.where((store) =>
                      store.name
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()) ||
                          store.location
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase()));
                    },
                    displayStringForOption: (store) =>
                    '${store.name} - ${store.location}',
                    onSelected: (store) {
                      setState(() => _selectedStore = store);
                    },
                    fieldViewBuilder: (context, controller, focusNode,
                        onFieldSubmitted) {
                      _storeSearchController.text = controller.text;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: _selectedClient != null,
                        style: TextStyle(
                          color: _selectedClient != null
                              ? textColor
                              : textColor.withOpacity(0.5),
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Magasin *',
                          labelStyle:
                          TextStyle(color: textColor.withOpacity(0.7)),
                          enabledBorder: defaultBorder,
                          focusedBorder: focusedBorder,
                          filled: true,
                          fillColor: backgroundColor.withOpacity(0.9),
                          suffixIcon: const Icon(
                            Icons.arrow_drop_down,
                            color: kJewelAccent,
                          ),
                        ),
                        validator: (value) => _selectedStore == null
                            ? 'Veuillez sélectionner un magasin'
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _buildMagneticButton(
                  onPressed: () {
                    if (_selectedClient != null) {
                      _showAddStoreDialog();
                    }
                  },
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                  backgroundColor:
                  _selectedClient == null ? Colors.grey : kDuotoneGlow,
                  isLoading: _isLoading, // Use general loading state for store add
                  isUploadingMedia: _isUploadingMedia,
                ),
              ],
            ),
          ),

          // Type Dropdown
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<String>(
              value: _selectedInterventionType,
              dropdownColor: backgroundColor.withOpacity(0.95),
              style: TextStyle(color: textColor, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Type d\'Intervention *',
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                enabledBorder: defaultBorder,
                focusedBorder: focusedBorder,
                filled: true,
                fillColor: backgroundColor.withOpacity(0.9),
              ),
              items: ['Maintenance', 'Formation', 'Mise à Jour', 'Autre']
                  .map((String value) => DropdownMenuItem(
                value: value,
                child: Text(value, style: TextStyle(color: textColor)),
              ))
                  .toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedInterventionType = newValue;
                });
              },
              validator: (value) =>
              value == null ? 'Veuillez choisir un type' : null,
            ),
          ),

          // Priority Dropdown
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<String>(
              value: _selectedInterventionPriority,
              dropdownColor: backgroundColor.withOpacity(0.95),
              style: TextStyle(color: textColor, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Priorité *',
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                enabledBorder: defaultBorder,
                focusedBorder: focusedBorder,
                filled: true,
                fillColor: backgroundColor.withOpacity(0.9),
              ),
              items: ['Haute', 'Moyenne', 'Basse']
                  .map((String value) => DropdownMenuItem(
                value: value,
                child: Text(value, style: TextStyle(color: textColor)),
              ))
                  .toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedInterventionPriority = newValue;
                });
              },
              validator: (value) =>
              value == null ? 'Veuillez choisir une priorité' : null,
            ),
          ),

          // Phone Field
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextFormField(
              controller: _clientPhoneController,
              style: TextStyle(color: textColor, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Numéro de Téléphone (Contact) *',
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                enabledBorder: defaultBorder,
                focusedBorder: focusedBorder,
                filled: true,
                fillColor: backgroundColor.withOpacity(0.9),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) =>
              value == null || value.isEmpty ? 'Veuillez entrer un numéro' : null,
            ),
          ),

          // Description Field
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: TextFormField(
              controller: _requestController,
              maxLines: 4,
              style: TextStyle(color: textColor, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Description de la Demande *',
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                enabledBorder: defaultBorder,
                focusedBorder: focusedBorder,
                filled: true,
                fillColor: backgroundColor.withOpacity(0.9),
              ),
              validator: (value) =>
              value == null || value.isEmpty ? 'Veuillez décrire la demande' : null,
            ),
          ),

          // ✅ NEW: Media Upload Section
          _buildMediaSection(),
          const SizedBox(height: 24),


          // Submit Button
          SizedBox(
            width: double.infinity,
            child: _buildMagneticButton(
              onPressed: () {
                _saveIntervention();
              },
              child: Text(
                _isUploadingMedia ? 'Téléchargement Média en cours...' : 'Créer Intervention',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              isLoading: _isLoading,
              isUploadingMedia: _isUploadingMedia, // Use the new flag
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true, // edge-to-edge imagery
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Nouvelle Intervention',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            shadows: [
              Shadow(
                color: kDuotoneGlow.withOpacity(0.22),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient( // sorbet gradients
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
          ),
        ),
        actions: [
          // AI-assisted personalization (placeholder)
          IconButton(
            icon: Icon(Icons.smart_toy, color: textColor),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI Suggestions Coming Soon!')),
              );
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors, // high-key brightness
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _buildGlassCard(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final maxWidth = kIsWeb ? 600.0 : constraints.maxWidth; // fluid grid for web/phone
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24), // airy spacing
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: formContent,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
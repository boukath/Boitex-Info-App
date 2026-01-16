// lib/screens/service_technique/add_intervention_page.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// ✅ ADDED: Import for AI Keyword Enhancement
import 'package:cloud_functions/cloud_functions.dart';

// ✅ STEP 5: Import Service Contracts
import 'package:boitex_info_app/models/service_contracts.dart';

// ✅ STEP 6: Import Administration Pages for Quick Add with Logic
import 'package:boitex_info_app/screens/administration/add_client_page.dart';
import 'package:boitex_info_app/screens/administration/add_store_page.dart';

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

// ✅ UPDATED STORE MODEL: Now includes Contract
class Store {
  final String id;
  final String name;
  final String location;
  final double? latitude;
  final double? longitude;
  final MaintenanceContract? contract; // 👈 Added Contract

  Store({
    required this.id,
    required this.name,
    required this.location,
    this.latitude,
    this.longitude,
    this.contract,
  });

  @override
  bool operator ==(Object other) => other is Store && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ✅ NEW EQUIPMENT MODEL (Local for this dropdown)
class Equipment {
  final String id;
  final String name;
  final String serial;
  final EquipmentWarranty? warranty; // 👈 Added Warranty

  Equipment({
    required this.id,
    required this.name,
    required this.serial,
    this.warranty,
  });

  @override
  bool operator ==(Object other) => other is Equipment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class AddInterventionPage extends StatefulWidget {
  final String serviceType;
  const AddInterventionPage({super.key, required this.serviceType});

  @override
  State<AddInterventionPage> createState() => _AddInterventionPageState();
}

class _AddInterventionPageState extends State<AddInterventionPage> {
  final _formKey = GlobalKey<FormState>();

  // ✅ NEW: B2 Cloud Function URL
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl';

  // Existing Controllers
  final _clientPhoneController = TextEditingController();
  final _requestController = TextEditingController();

  // ✅ NEW: GPS Link Controller
  final _gpsLinkController = TextEditingController();

  // Search Controllers for Autocomplete
  final _clientSearchController = TextEditingController();
  final _storeSearchController = TextEditingController();
  final _equipmentSearchController = TextEditingController(); // 👈 New

  bool _isLoading = false;

  // Existing State
  String? _selectedInterventionType;
  String? _selectedInterventionPriority;
  Client? _selectedClient;
  Store? _selectedStore;
  Equipment? _selectedEquipment; // 👈 New

  // ✅ NEW: Temporary storage for parsed coordinates
  double? _parsedLat;
  double? _parsedLng;
  bool _isResolvingLink = false;

  // Data and Loading States
  List<Client> _clients = [];
  List<Store> _stores = [];
  List<Equipment> _equipments = []; // 👈 New
  bool _isLoadingClients = true;
  bool _isLoadingStores = false;
  bool _isLoadingEquipments = false; // 👈 New

  // ✅ NEW: State for Media Upload
  List<File> _localFilesToUpload = [];
  List<String> _uploadedMediaUrls = [];
  bool _isUploadingMedia = false;

  // ✅ ADDED: State for AI Keyword Enhancement
  bool _isGeneratingAi = false;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  @override
  void dispose() {
    _clientPhoneController.dispose();
    _requestController.dispose();
    _clientSearchController.dispose();
    _storeSearchController.dispose();
    _equipmentSearchController.dispose(); // 👈 New
    _gpsLinkController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // 💰 BILLING LOGIC ENGINE (THE GATEKEEPER)
  // ----------------------------------------------------------------------
  Map<String, dynamic> _calculateBillingStatus() {
    // 1. Check Equipment Warranty (Highest Priority)
    if (_selectedEquipment != null && _selectedEquipment!.warranty != null) {
      if (_selectedEquipment!.warranty!.isValid) {
        return {
          'status': 'GRATUIT',
          'reason': 'Sous Garantie Constructeur',
          'color': Colors.green,
          'icon': Icons.verified_user,
        };
      }
    }

    // 2. Check Store Contract & Credits (Medium Priority)
    if (_selectedStore != null && _selectedStore!.contract != null) {
      final contract = _selectedStore!.contract!;

      if (contract.isValidNow) {
        // 🧠 DECIDE WHICH WALLET TO USE
        // If type is "Maintenance" -> Use Preventive Credit
        // If type is "Dépannage" (or anything else) -> Use Corrective Credit

        // You can adjust these strings to match your dropdown exactly
        bool isPreventive = _selectedInterventionType == 'Maintenance' ||
            _selectedInterventionType == 'Formation';

        if (isPreventive) {
          // CHECK PREVENTIVE WALLET
          if (contract.hasCreditPreventive) {
            return {
              'status': 'INCLUS',
              'reason': 'Crédit Maint.: ${contract.usedPreventive}/${contract.quotaPreventive} utilisés',
              'color': Colors.teal,
              'icon': Icons.shield,
            };
          } else {
            return {
              'status': 'HORS FORFAIT',
              'reason': 'Quota Maintenance Épuisé',
              'color': Colors.orange,
              'icon': Icons.warning_amber,
            };
          }
        } else {
          // CHECK CORRECTIVE WALLET (Default for repairs/other)
          if (contract.hasCreditCorrective) {
            return {
              'status': 'INCLUS',
              'reason': 'Crédit Dépannage: ${contract.usedCorrective}/${contract.quotaCorrective} utilisés',
              'color': Colors.teal,
              'icon': Icons.build_circle,
            };
          } else {
            return {
              'status': 'HORS FORFAIT',
              'reason': 'Quota Dépannage Épuisé',
              'color': Colors.orange,
              'icon': Icons.money_off,
            };
          }
        }

      } else {
        return {
          'status': 'FACTURABLE',
          'reason': 'Contrat Expiré',
          'color': Colors.redAccent,
          'icon': Icons.attach_money,
        };
      }
    }

    // 3. Default (Billable / No Contract)
    return {
      'status': 'FACTURABLE',
      'reason': 'Hors Garantie / Hors Contrat',
      'color': Colors.deepOrange,
      'icon': Icons.monetization_on_outlined,
    };
  }

  // ----------------------------------------------------------------------
  // 🔗 GPS LINK PARSER LOGIC
  // ----------------------------------------------------------------------
  Future<void> _extractCoordinatesFromLink() async {
    String url = _gpsLinkController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isResolvingLink = true);

    try {
      // 1. Resolve Short Links (e.g. goo.gl, bit.ly)
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

      // 2. Regex to find coordinates in the full URL
      // Matches patterns like @36.75,3.04 or q=36.75,3.04
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
              content: Text(
                  "✅ Coordonnées extraites ! Elles seront sauvegardées avec l'intervention."),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("❌ Impossible de trouver les coordonnées dans ce lien."),
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

  // ----------------------------------------------------------------------
  // Theme (Copied from InterventionDetailsPage)
  // ----------------------------------------------------------------------
  ThemeData _interventionTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withOpacity(0.95),
        elevation: 8,
        shadowColor: const Color(0xFF667EEA).withOpacity(0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: TextStyle(color: Colors.grey.shade700),
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF667EEA),
          foregroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
      ),
      dividerTheme:
      const DividerThemeData(color: Color(0xFFE5E7EB), thickness: 1),
    );
  }

  // --- ✅ AI FUNCTION ---
  Future<void> _generateReportFromKeywords() async {
    final rawNotes = _requestController.text;
    if (rawNotes.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord saisir des mots-clés.')),
      );
      return;
    }

    setState(() => _isGeneratingAi = true);
    FocusScope.of(context).unfocus();

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('generateReportFromNotes');

      final result = await callable.call<String>({
        'rawNotes': rawNotes,
        'context': 'problem_report',
      });

      setState(() {
        _requestController.text = result.data;
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de génération AI: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAi = false);
      }
    }
  }

  // --- B2 HELPER FUNCTIONS ---
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

  // --- MEDIA PICKER LOGIC ---
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

  Future<void> _capturePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xFile = await picker.pickImage(source: ImageSource.camera);
    if (xFile != null) {
      setState(() {
        _localFilesToUpload.add(File(xFile.path));
      });
    }
  }

  Future<void> _captureVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xFile = await picker.pickVideo(source: ImageSource.camera);
    if (xFile != null) {
      setState(() {
        _localFilesToUpload.add(File(xFile.path));
      });
    }
  }

  // --- DATA FETCHING ---
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
      _selectedEquipment = null; // Reset equipment
      _parsedLat = null;
      _parsedLng = null;
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

        // ✅ FETCH LAT/LNG IF EXISTS IN FIRESTORE
        double? lat;
        double? lng;
        if (data['latitude'] != null) lat = (data['latitude'] as num).toDouble();
        if (data['longitude'] != null) lng = (data['longitude'] as num).toDouble();

        // 🟢 Extract Contract Data
        MaintenanceContract? contract;
        if (data['maintenance_contract'] != null) {
          try {
            contract = MaintenanceContract.fromMap(data['maintenance_contract']);
          } catch (_) {}
        }

        return Store(
          id: doc.id,
          name: data['name'],
          location: data['location'],
          latitude: lat,
          longitude: lng,
          contract: contract, // 👈 Populate Contract
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

  // ✅ NEW: Fetch Equipment for Store
  Future<void> _fetchEquipments(String storeId) async {
    setState(() {
      _isLoadingEquipments = true;
      _equipments = [];
      _selectedEquipment = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .doc(_selectedClient!.id)
          .collection('stores')
          .doc(storeId)
          .collection('materiel_installe')
          .get();

      final equipments = snapshot.docs.map((doc) {
        final data = doc.data();

        // 🟢 Extract Warranty Data
        EquipmentWarranty? warranty;
        if (data['warranty'] != null) {
          try {
            warranty = EquipmentWarranty.fromMap(data['warranty']);
          } catch (_) {}
        }

        return Equipment(
          id: doc.id,
          name: data['nom'] ?? data['name'] ?? 'Inconnu',
          serial: data['serialNumber'] ?? data['serial'] ?? 'N/A',
          warranty: warranty,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _equipments = equipments;
          _isLoadingEquipments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEquipments = false);
        // Fail silently or show toast
      }
    }
  }

  // --- DIALOGS (REPLACED WITH PAGE NAVIGATION FOR CONTEXT LOGIC) ---
  Future<void> _showAddClientDialog() async {
    // Navigate to AddClientPage, passing the service type to auto-select
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddClientPage(
          preselectedServiceType: widget.serviceType, // 🌟 AUTO-SELECT SERVICE LOGIC
        ),
      ),
    );

    // Refresh list upon return
    _fetchClients();
  }

  Future<void> _showAddStoreDialog() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord sélectionner un client')),
      );
      return;
    }

    // Navigate to AddStorePage
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddStorePage(
          clientId: _selectedClient!.id,
        ),
      ),
    );

    // Refresh list upon return
    if (_selectedClient != null) {
      _fetchStores(_selectedClient!.id);
    }
  }

  // --- SAVE INTERVENTION FUNCTION ---
  Future<void> _saveIntervention() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    if (_selectedClient == null || _selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un client et un magasin.')),
      );
      return;
    }

    // ✅ FIX: Auto-extract coordinates if link provided but not parsed
    if (_gpsLinkController.text.trim().isNotEmpty && _parsedLat == null) {
      // We await the extraction to ensure _parsedLat is set before proceeding
      await _extractCoordinatesFromLink();
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
      return;
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

    final currentYear = DateFormat('yyyy').format(DateTime.now());
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('intervention_counter_$currentYear');
    final interventionRef =
    FirebaseFirestore.instance.collection('interventions').doc();

    // ✅ Reference to the store to allow dual-write
    final storeRef = FirebaseFirestore.instance
        .collection('clients')
        .doc(_selectedClient!.id)
        .collection('stores')
        .doc(_selectedStore!.id);

    try {
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final creatorName = userDoc.data()?['displayName'] ?? 'Utilisateur inconnu';

      String finalInterventionCode = '';
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterDoc = await transaction.get(counterRef);

        int newCount;
        if (counterDoc.exists) {
          final data = counterDoc.data() as Map<String, dynamic>;
          final lastResetYear = data['lastReset'] as String?;
          final currentCount = data['count'] as int? ?? 0;

          if (lastResetYear == currentYear) {
            newCount = currentCount + 1;
          } else {
            newCount = 1;
          }
        } else {
          newCount = 1;
        }

        finalInterventionCode = 'INT-$newCount/$currentYear';

        // ✅ Determine Coordinates Priority
        // 1. New parsed coordinates (User just added a link)
        // 2. Existing store coordinates
        final double? finalLat = _parsedLat ?? _selectedStore!.latitude;
        final double? finalLng = _parsedLng ?? _selectedStore!.longitude;

        // ✅ AUTO-UPDATE STORE if new coordinates were found
        if (_parsedLat != null && _parsedLng != null) {
          transaction.update(storeRef, {
            'latitude': _parsedLat,
            'longitude': _parsedLng,
          });
        }

        // 🟢 Calculate Billing Status
        final billingInfo = _calculateBillingStatus();

        final interventionData = {
          'interventionCode': finalInterventionCode,
          'serviceType': widget.serviceType,
          'clientId': _selectedClient!.id,
          'clientName': _selectedClient!.name,
          'clientPhone': _clientPhoneController.text.trim(),
          'storeId': _selectedStore!.id,
          'storeName': '${_selectedStore!.name} - ${_selectedStore!.location}',

          // ✅ New fields for Equipment and Billing
          'equipmentId': _selectedEquipment?.id,
          'equipmentName': _selectedEquipment?.name,
          'billingStatus': billingInfo['status'], // GRATUIT / FACTURABLE
          'billingReason': billingInfo['reason'],

          // ✅ Save coordinates in intervention snapshot
          'storeLatitude': finalLat,
          'storeLongitude': finalLng,
          'requestDescription': _requestController.text.trim(),
          'interventionType': _selectedInterventionType,
          'priority': _selectedInterventionPriority,
          'status': 'Nouvelle Demande',
          'createdAt': Timestamp.now(),
          'createdByUid': user.uid,
          'createdByName': creatorName,
          'mediaUrls': _uploadedMediaUrls,
        };

        transaction.set(interventionRef, interventionData);
        transaction.set(counterRef, {
          'count': newCount,
          'lastReset': currentYear,
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Intervention $finalInterventionCode créée et GPS mis à jour!'),
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

  // --- MEDIA UI BUILDER ---
  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FICHIERS & MÉDIAS DE SUPPORT',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUploadingMedia ? null : _capturePhoto,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Photo'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUploadingMedia ? null : _captureVideo,
                icon: const Icon(Icons.videocam),
                label: const Text('Vidéo'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUploadingMedia ? null : _pickFiles,
                icon: const Icon(Icons.attach_file),
                label: const Text('Fichier'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_localFilesToUpload.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fichiers locaux à envoyer:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Divider(),
                ..._localFilesToUpload.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return ListTile(
                    dense: true,
                    leading: FutureBuilder<Widget>(
                      future: _getLeadingIcon(file.path),
                      builder: (context, snapshot) {
                        return snapshot.data ??
                            const Icon(Icons.file_present);
                      },
                    ),
                    title: Text(path.basename(file.path),
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

  // --- MAIN BUILD ---

  @override
  Widget build(BuildContext context) {

    // 🟢 Prepare Billing Status Data
    final billingInfo = _calculateBillingStatus();

    // FORM CONTENT
    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client Autocomplete
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: _isLoadingClients
                      ? const Center(child: CircularProgressIndicator())
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
                        decoration: InputDecoration(
                          labelText: 'Nom du Client *',
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                          // Matches theme Automatically
                        ),
                        validator: (value) => _selectedClient == null
                            ? 'Veuillez sélectionner un client'
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _showAddClientDialog,
                  icon: const Icon(Icons.add_circle, size: 32, color: Color(0xFF667EEA)),
                  tooltip: "Nouveau Client",
                ),
              ],
            ),
          ),

          // Store Autocomplete
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: _isLoadingStores
                      ? const Center(child: CircularProgressIndicator())
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
                      setState(() {
                        _selectedStore = store;
                        _parsedLat = null;
                        _parsedLng = null;
                        _gpsLinkController.clear();
                      });
                      _fetchEquipments(store.id); // 👈 Fetch equipment on select
                    },
                    fieldViewBuilder: (context, controller, focusNode,
                        onFieldSubmitted) {
                      _storeSearchController.text = controller.text;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: _selectedClient != null,
                        decoration: InputDecoration(
                          labelText: 'Magasin *',
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                        ),
                        validator: (value) => _selectedStore == null
                            ? 'Veuillez sélectionner un magasin'
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _selectedClient != null ? _showAddStoreDialog : null,
                  icon: Icon(Icons.add_circle, size: 32, color: _selectedClient != null ? const Color(0xFF667EEA) : Colors.grey),
                  tooltip: "Nouveau Magasin",
                ),
              ],
            ),
          ),

          // 🟢 Equipment Autocomplete (New)
          if (_selectedStore != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _isLoadingEquipments
                  ? const LinearProgressIndicator()
                  : Autocomplete<Equipment>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _equipments;
                  }
                  return _equipments.where((eq) =>
                  eq.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                      eq.serial.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                displayStringForOption: (eq) => '${eq.name} (${eq.serial})',
                onSelected: (eq) {
                  setState(() => _selectedEquipment = eq);
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                  _equipmentSearchController.text = controller.text;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Machine / Équipement (Optionnel)',
                      prefixIcon: Icon(Icons.settings_input_component),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                  );
                },
              ),
            ),

          // 🟢 BILLING STATUS CARD (New)
          if (_selectedStore != null)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (billingInfo['color'] as Color).withOpacity(0.1),
                border: Border.all(color: billingInfo['color'] as Color),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: billingInfo['color'] as Color,
                    radius: 24,
                    child: Icon(billingInfo['icon'] as IconData, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          billingInfo['status'] as String,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: billingInfo['color'] as Color,
                          ),
                        ),
                        Text(
                          billingInfo['reason'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),


          // 🌟🌟 GPS LINK SECTION 🌟🌟
          if (_selectedStore != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey.shade100),
              ),
              child: Column(
                children: [
                  // Status Row
                  Row(
                    children: [
                      Icon(
                        (_selectedStore!.latitude != null || _parsedLat != null)
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: (_selectedStore!.latitude != null || _parsedLat != null)
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
                            color: (_selectedStore!.latitude != null || _parsedLat != null)
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Input Field (Visible if missing or wants update)
                  if (_selectedStore!.latitude == null || _parsedLat != null) ...[
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
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isResolvingLink ? null : _extractCoordinatesFromLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: _isResolvingLink
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.search),
                        ),
                      ],
                    ),
                    if (_parsedLat != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text("📍 Coordonnées détectées : $_parsedLat, $_parsedLng", style: const TextStyle(fontSize: 12, color: Colors.teal)),
                      ),
                  ],
                ],
              ),
            ),

          // Type Dropdown
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<String>(
              value: _selectedInterventionType,
              decoration: const InputDecoration(labelText: 'Type d\'Intervention *'),
              items: ['Maintenance', 'Formation', 'Mise à Jour', 'Autre']
                  .map((String value) => DropdownMenuItem(
                value: value,
                child: Text(value),
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
              decoration: const InputDecoration(labelText: 'Priorité *'),
              items: ['Haute', 'Moyenne', 'Basse']
                  .map((String value) => DropdownMenuItem(
                value: value,
                child: Text(value),
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
              decoration: const InputDecoration(labelText: 'Numéro de Téléphone (Contact) *'),
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
              decoration: InputDecoration(
                labelText: 'Description de la Demande *',
                alignLabelWithHint: true,
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: _isGeneratingAi
                      ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : IconButton(
                    icon: const Icon(Icons.auto_awesome),
                    color: Colors.grey.shade600,
                    tooltip: 'Améliorer le texte par IA',
                    onPressed: _generateReportFromKeywords,
                  ),
                ),
              ),
              validator: (value) =>
              value == null || value.isEmpty ? 'Veuillez décrire la demande' : null,
            ),
          ),

          // Media Section
          _buildMediaSection(),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isLoading || _isUploadingMedia) ? null : _saveIntervention,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                  : Text(
                _isUploadingMedia ? 'Téléchargement Média en cours...' : 'Créer Intervention',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );

    // SCAFFOLD
    return Theme(
      data: _interventionTheme(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nouvelle Intervention'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x33667EEA),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16), // Match detail page padding
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Card(
                    // Wrapping in a Card to match "Details" visual consistency
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: formContent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
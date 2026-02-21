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

// 🚀 IMPORT THE NEW OMNIBAR
import 'package:boitex_info_app/widgets/intervention_omnibar.dart';

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
      'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  // Existing Controllers
  final _clientPhoneController = TextEditingController();
  final _requestController = TextEditingController();

  // ✅ NEW: GPS Link Controller
  final _gpsLinkController = TextEditingController();

  // Search Controllers for Autocomplete
  final _storeSearchController = TextEditingController();
  final _equipmentSearchController = TextEditingController();

  bool _isLoading = false;

  // Existing State
  String? _selectedInterventionType;
  String? _selectedInterventionPriority;
  Client? _selectedClient;
  Store? _selectedStore;
  Equipment? _selectedEquipment;

  // ✅ NEW: Lock Mechanism for Preventive Interventions
  bool _isTypeLocked = false;

  // ✅ NEW: Scheduling State
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  // ✅ NEW: Temporary storage for parsed coordinates
  double? _parsedLat;
  double? _parsedLng;
  bool _isResolvingLink = false;

  // Data and Loading States
  // Note: _clients list removed as Omnibar handles it now
  List<Store> _stores = [];
  List<Equipment> _equipments = [];
  bool _isLoadingStores = false;
  bool _isLoadingEquipments = false;

  // ✅ NEW: State for Media Upload
  List<File> _localFilesToUpload = [];
  List<String> _uploadedMediaUrls = [];
  bool _isUploadingMedia = false;

  // ✅ ADDED: State for AI Keyword Enhancement
  bool _isGeneratingAi = false;

  @override
  void dispose() {
    _clientPhoneController.dispose();
    _requestController.dispose();
    _storeSearchController.dispose();
    _equipmentSearchController.dispose();
    _gpsLinkController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // 📅 SCHEDULING HELPERS
  // ----------------------------------------------------------------------
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now,
      firstDate: DateTime(2023), // Allow picking past dates for logging
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() => _scheduledTime = picked);
    }
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
        // If type is "Maintenance" or "Préventif" -> Use Preventive Credit
        // If type is "Dépannage" (or anything else) -> Use Corrective Credit

        // ✅ UPDATED LOGIC: Include 'Préventif'
        bool isPreventive = _selectedInterventionType == 'Maintenance' ||
            _selectedInterventionType == 'Préventif' || // 👈 Added this
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
  // ✨ SMART CONTRACT CHECK LOGIC (NEW FEATURE)
  // ----------------------------------------------------------------------
  Future<void> _checkContractAndSuggestMaintenance(Store store) async {
    final contract = store.contract;

    // Safety Checks
    if (contract == null || !contract.isValidNow) return;

    // We only interrupt if they have PREVENTIVE credits left
    if (contract.remainingPreventive > 0) {

      // Show the Dialog
      bool? isPreventive = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.star, color: Colors.teal),
              SizedBox(width: 8),
              Text("Contrat Détecté"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ce magasin dispose de ${contract.remainingPreventive} visite(s) préventive(s) restante(s) sur son contrat.",
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                "S'agit-il d'une visite de maintenance planifiée ?",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Non, Dépannage", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Oui, Maintenance"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

      // If user said YES, update the Type automatically AND LOCK IT
      if (isPreventive == true) {
        setState(() {
          _selectedInterventionType = 'Préventif'; // 👈 Auto-select 'Préventif'
          _isTypeLocked = true; // 🔒 LOCK THE FIELD
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Type verrouillé sur 'Préventif' (Crédit déduit)"),
              backgroundColor: Colors.teal,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
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

  // --- AI & UPLOAD FUNCTIONS (Preserved) ---
  Future<void> _generateReportFromKeywords() async {
    final rawNotes = _requestController.text;
    if (rawNotes.trim().isEmpty) return;

    setState(() => _isGeneratingAi = true);
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('generateReportFromNotes');
      final result = await callable.call<String>({
        'rawNotes': rawNotes,
        'context': 'problem_report',
      });
      setState(() => _requestController.text = result.data);
    } catch (e) {
      // Handle Error
    } finally {
      if (mounted) setState(() => _isGeneratingAi = false);
    }
  }

  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response = await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _uploadFileToB2(File file, Map<String, dynamic> b2Creds) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final fileName = path.basename(file.path);

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final encodedPath = (body['fileName'] as String).split('/').map(Uri.encodeComponent).join('/');
        return (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- MEDIA PICKER ---
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'pdf'],
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _localFilesToUpload.addAll(result.paths.where((p) => p != null).map((p) => File(p!)));
      });
    }
  }

  Future<void> _capturePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xFile = await picker.pickImage(source: ImageSource.camera);
    if (xFile != null) setState(() => _localFilesToUpload.add(File(xFile.path)));
  }

  Future<void> _captureVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xFile = await picker.pickVideo(source: ImageSource.camera);
    if (xFile != null) setState(() => _localFilesToUpload.add(File(xFile.path)));
  }

  // --- DATA FETCHING ---
  Future<void> _fetchStores(String clientId) async {
    setState(() {
      _isLoadingStores = true;
      _stores = [];
      _selectedStore = null;
      _selectedEquipment = null;
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
        double? lat;
        double? lng;
        if (data['latitude'] != null) lat = (data['latitude'] as num).toDouble();
        if (data['longitude'] != null) lng = (data['longitude'] as num).toDouble();

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
          contract: contract,
        );
      }).toList();
      if (mounted) {
        setState(() {
          _stores = stores;
          _isLoadingStores = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStores = false);
    }
  }

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
      if (mounted) setState(() => _isLoadingEquipments = false);
    }
  }

  // --- PAGE NAVIGATION ---
  Future<void> _showAddClientDialog() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddClientPage(
          preselectedServiceType: widget.serviceType,
        ),
      ),
    );
  }

  Future<void> _showAddStoreDialog() async {
    if (_selectedClient == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddStorePage(clientId: _selectedClient!.id),
      ),
    );
    _fetchStores(_selectedClient!.id);
  }

  // --- SAVE INTERVENTION ---
  Future<void> _saveIntervention() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    if (_selectedClient == null || _selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un client et un magasin.')),
      );
      return;
    }

    if (_gpsLinkController.text.trim().isNotEmpty && _parsedLat == null) {
      await _extractCoordinatesFromLink();
    }

    setState(() {
      _isLoading = true;
      _isUploadingMedia = true;
      _uploadedMediaUrls = [];
    });

    try {
      if (_localFilesToUpload.isNotEmpty) {
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials != null) {
          for (var file in _localFilesToUpload) {
            final url = await _uploadFileToB2(file, b2Credentials);
            if (url != null) _uploadedMediaUrls.add(url);
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final currentYear = DateFormat('yyyy').format(DateTime.now());
    final counterRef = FirebaseFirestore.instance.collection('counters').doc('intervention_counter_$currentYear');
    final interventionRef = FirebaseFirestore.instance.collection('interventions').doc();
    final storeRef = FirebaseFirestore.instance.collection('clients').doc(_selectedClient!.id).collection('stores').doc(_selectedStore!.id);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final creatorName = userDoc.data()?['displayName'] ?? 'Utilisateur inconnu';

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterDoc = await transaction.get(counterRef);
        int newCount = 1;
        if (counterDoc.exists) {
          final data = counterDoc.data() as Map<String, dynamic>;
          if (data['lastReset'] == currentYear) {
            newCount = (data['count'] as int? ?? 0) + 1;
          }
        }

        final finalInterventionCode = 'INT-$newCount/$currentYear';
        final double? finalLat = _parsedLat ?? _selectedStore!.latitude;
        final double? finalLng = _parsedLng ?? _selectedStore!.longitude;

        if (_parsedLat != null && _parsedLng != null) {
          transaction.update(storeRef, {'latitude': _parsedLat, 'longitude': _parsedLng});
        }

        final billingInfo = _calculateBillingStatus();

        // 📅 Calculate Scheduled Date & Time (if set)
        DateTime? scheduledFullDate;
        if (_scheduledDate != null) {
          final t = _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0); // Default to 9:00 AM
          scheduledFullDate = DateTime(
            _scheduledDate!.year,
            _scheduledDate!.month,
            _scheduledDate!.day,
            t.hour,
            t.minute,
          );
        }

        transaction.set(interventionRef, {
          'interventionCode': finalInterventionCode,
          'serviceType': widget.serviceType,
          'clientId': _selectedClient!.id,
          'clientName': _selectedClient!.name,
          'clientPhone': _clientPhoneController.text.trim(),
          'storeId': _selectedStore!.id,
          'storeName': '${_selectedStore!.name} - ${_selectedStore!.location}',
          'equipmentId': _selectedEquipment?.id,
          'equipmentName': _selectedEquipment?.name,
          'billingStatus': billingInfo['status'],
          'billingReason': billingInfo['reason'],
          'storeLatitude': finalLat,
          'storeLongitude': finalLng,
          'requestDescription': _requestController.text.trim(),
          'interventionType': _selectedInterventionType,
          'priority': _selectedInterventionPriority,
          'status': 'Nouvelle Demande',
          'createdAt': Timestamp.now(),
          'scheduledAt': scheduledFullDate != null ? Timestamp.fromDate(scheduledFullDate) : null,
          'createdByUid': user.uid,
          'createdByName': creatorName,
          'mediaUrls': _uploadedMediaUrls,
          'isExtended': false, // 👈 ADDED: Initialize as a Simple Intervention
        });

        transaction.set(counterRef, {'count': newCount, 'lastReset': currentYear});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intervention créée avec succès!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- THEME ---
  ThemeData _interventionTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withOpacity(0.95),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF667EEA),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // --- MEDIA WIDGET ---
  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FICHIERS & MÉDIAS DE SUPPORT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: ElevatedButton.icon(onPressed: _isUploadingMedia ? null : _capturePhoto, icon: const Icon(Icons.photo_camera), label: const Text('Photo'))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(onPressed: _isUploadingMedia ? null : _captureVideo, icon: const Icon(Icons.videocam), label: const Text('Vidéo'))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(onPressed: _isUploadingMedia ? null : _pickFiles, icon: const Icon(Icons.attach_file), label: const Text('Fichier'))),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final billingInfo = _calculateBillingStatus();
    List<String> interventionTypes = ['Maintenance', 'Formation', 'Mise à Jour', 'Autre'];
    if (_selectedInterventionType == 'Préventif') interventionTypes = ['Préventif'];

    return Theme(
      data: _interventionTheme(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nouvelle Intervention'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
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
              colors: [Colors.blue.shade50, Colors.purple.shade50, Colors.pink.shade50],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // 🚀 REPLACED: CLIENT AUTOCOMPLETE WITH OMNIBAR
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InterventionOmnibar(
                                      onItemSelected: (result) {
                                        // Handle Selection (Always Client for now)
                                        setState(() {
                                          _selectedClient = Client(id: result.id, name: result.title);
                                          // Reset Store when Client changes
                                          _selectedStore = null;
                                          _stores = [];
                                        });
                                        // Fetch stores for this client
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
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _showAddClientDialog,
                                    icon: const Icon(Icons.add_circle, size: 32, color: Color(0xFF667EEA)),
                                    tooltip: "Nouveau Client",
                                  ),
                                ],
                              ),
                            ),

                            // STORE SELECTION (Visible only after Client selected)
                            if (_selectedClient != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _isLoadingStores
                                          ? const Center(child: CircularProgressIndicator())
                                          : Autocomplete<Store>(
                                        optionsBuilder: (textEditingValue) {
                                          if (textEditingValue.text.isEmpty) return _stores;
                                          return _stores.where((store) => store.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                        },
                                        displayStringForOption: (store) => '${store.name} - ${store.location}',
                                        onSelected: (store) {
                                          setState(() {
                                            _selectedStore = store;
                                            _parsedLat = null;
                                            _parsedLng = null;
                                            _gpsLinkController.clear();
                                            _isTypeLocked = false;
                                            _selectedInterventionType = null;
                                          });
                                          _fetchEquipments(store.id);
                                          _checkContractAndSuggestMaintenance(store);
                                        },
                                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                          _storeSearchController.text = controller.text;
                                          return TextFormField(
                                            controller: controller,
                                            focusNode: focusNode,
                                            decoration: const InputDecoration(
                                              labelText: 'Magasin *',
                                              suffixIcon: Icon(Icons.arrow_drop_down),
                                            ),
                                            validator: (value) => _selectedStore == null ? 'Veuillez sélectionner un magasin' : null,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: _showAddStoreDialog,
                                      icon: const Icon(Icons.add_circle, size: 32, color: Color(0xFF667EEA)),
                                      tooltip: "Nouveau Magasin",
                                    ),
                                  ],
                                ),
                              ),

                            // EQUIPMENT SELECTION
                            if (_selectedStore != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _isLoadingEquipments
                                    ? const LinearProgressIndicator()
                                    : Autocomplete<Equipment>(
                                  optionsBuilder: (textEditingValue) {
                                    if (textEditingValue.text.isEmpty) return _equipments;
                                    return _equipments.where((eq) => eq.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                  },
                                  displayStringForOption: (eq) => '${eq.name} (${eq.serial})',
                                  onSelected: (eq) => setState(() => _selectedEquipment = eq),
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

                            // BILLING INFO
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
                                          Text(billingInfo['status'] as String, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: billingInfo['color'] as Color)),
                                          Text(billingInfo['reason'] as String, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // GPS SECTION
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
                                    Row(
                                      children: [
                                        Icon(
                                          (_selectedStore!.latitude != null || _parsedLat != null) ? Icons.check_circle : Icons.warning_amber_rounded,
                                          color: (_selectedStore!.latitude != null || _parsedLat != null) ? Colors.green : Colors.orange,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            (_selectedStore!.latitude != null) ? "Position Magasin Synchronisée" : (_parsedLat != null) ? "Position prête à être sauvegardée" : "Position GPS manquante",
                                            style: TextStyle(fontWeight: FontWeight.bold, color: (_selectedStore!.latitude != null || _parsedLat != null) ? Colors.green.shade700 : Colors.orange.shade800),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_selectedStore!.latitude == null || _parsedLat != null) ...[
                                      const SizedBox(height: 12),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _gpsLinkController,
                                              decoration: const InputDecoration(labelText: 'Coller un lien Google Maps ici', hintText: 'https://goo.gl/maps/...', prefixIcon: Icon(Icons.link)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: _isResolvingLink ? null : _extractCoordinatesFromLink,
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                            child: _isResolvingLink ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.search),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                            // INTERVENTION DETAILS
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: DropdownButtonFormField<String>(
                                value: _selectedInterventionType,
                                onChanged: _isTypeLocked ? null : (v) => setState(() => _selectedInterventionType = v),
                                decoration: InputDecoration(labelText: 'Type d\'Intervention *', suffixIcon: _isTypeLocked ? const Icon(Icons.lock, color: Colors.teal) : null),
                                items: interventionTypes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                                validator: (v) => v == null ? 'Requis' : null,
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: DropdownButtonFormField<String>(
                                value: _selectedInterventionPriority,
                                decoration: const InputDecoration(labelText: 'Priorité *'),
                                items: ['Haute', 'Moyenne', 'Basse'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                                onChanged: (v) => setState(() => _selectedInterventionPriority = v),
                                validator: (v) => v == null ? 'Requis' : null,
                              ),
                            ),

                            // ✅ 📅 NEW: Scheduled Date & Time Pickers
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: _pickDate,
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Date d\'Intervention',
                                          prefixIcon: Icon(Icons.calendar_today),
                                        ),
                                        child: Text(
                                          _scheduledDate != null
                                              ? DateFormat('dd/MM/yyyy').format(_scheduledDate!)
                                              : 'Sélectionner Date',
                                          style: TextStyle(
                                              color: _scheduledDate != null ? Colors.black87 : Colors.grey.shade600),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: InkWell(
                                      onTap: _pickTime,
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Heure',
                                          prefixIcon: Icon(Icons.access_time),
                                        ),
                                        child: Text(
                                          _scheduledTime != null
                                              ? _scheduledTime!.format(context)
                                              : '--:--',
                                          style: TextStyle(
                                              color: _scheduledTime != null ? Colors.black87 : Colors.grey.shade600),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: TextFormField(
                                controller: _clientPhoneController,
                                decoration: const InputDecoration(labelText: 'Numéro de Téléphone *'),
                                keyboardType: TextInputType.phone,
                                validator: (v) => v!.isEmpty ? 'Requis' : null,
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: TextFormField(
                                controller: _requestController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  labelText: 'Description de la Demande *',
                                  alignLabelWithHint: true,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.auto_awesome),
                                    color: Colors.grey.shade600,
                                    tooltip: 'IA: Améliorer le texte',
                                    onPressed: _generateReportFromKeywords,
                                  ),
                                ),
                                validator: (v) => v!.isEmpty ? 'Requis' : null,
                              ),
                            ),

                            _buildMediaSection(),
                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (_isLoading || _isUploadingMedia) ? null : _saveIntervention,
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text(_isUploadingMedia ? 'Envoi Média...' : 'Créer Intervention', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ),
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
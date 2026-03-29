// lib/screens/service_technique/add_intervention_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// ✅ NEW IMPORTS FOR B2 & MEDIA HANDLING
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/cupertino.dart'; // 🚀 REQUIRED FOR IOS DATE PICKERS
// ✅ ADDED: Import for AI Keyword Enhancement
import 'package:cloud_functions/cloud_functions.dart';

// ✅ STEP 5: Import Service Contracts
import 'package:boitex_info_app/models/service_contracts.dart';

// ✅ STEP 6: Import Administration Pages for Quick Add with Logic
import 'package:boitex_info_app/screens/administration/add_client_page.dart';
import 'package:boitex_info_app/screens/administration/add_store_page.dart';

// 🚀 IMPORT THE OMNIBAR BACK!
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

// ✅ UPDATED STORE MODEL: Now includes Contract AND logoUrl for Stories
class Store {
  final String id;
  final String name;
  final String location;
  final double? latitude;
  final double? longitude;
  final MaintenanceContract? contract;
  final String? logoUrl;

  Store({
    required this.id,
    required this.name,
    required this.location,
    this.latitude,
    this.longitude,
    this.contract,
    this.logoUrl,
  });

  @override
  bool operator ==(Object other) => other is Store && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ✅ NEW EQUIPMENT MODEL
class Equipment {
  final String id;
  final String name;
  final String serial;
  final EquipmentWarranty? warranty;

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

class _AddInterventionPageState extends State<AddInterventionPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // B2 Cloud Function URL
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  // Controllers
  final _clientPhoneController = TextEditingController();
  final _requestController = TextEditingController();
  final _gpsLinkController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingPage = false; // Initial load

  // State
  String? _selectedInterventionType;
  String? _selectedInterventionPriority;
  Client? _selectedClient;
  Store? _selectedStore;
  Equipment? _selectedEquipment;

  bool _isTypeLocked = false;

  // Scheduling State
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  // Link Parser State
  double? _parsedLat;
  double? _parsedLng;
  bool _isResolvingLink = false;

  // Data Lists
  List<Client> _clients = [];
  List<Store> _stores = [];
  List<Equipment> _equipments = [];
  bool _isLoadingClients = true;
  bool _isLoadingStores = false;
  bool _isLoadingEquipments = false;

  // Media
  List<PlatformFile> _localFilesToUpload = [];
  List<String> _uploadedMediaUrls = [];
  bool _isUploadingMedia = false;

  // AI
  bool _isGeneratingAi = false;

  // Animated Background
  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _bgAnimationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _clientPhoneController.dispose();
    _requestController.dispose();
    _gpsLinkController.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // DATA FETCHING
  // ----------------------------------------------------------------------

  Future<void> _fetchClients() async {
    setState(() => _isLoadingClients = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('clients').get();
      final clients = snapshot.docs.map((doc) => Client(id: doc.id, name: doc['name'] as String)).toList();
      clients.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() => _clients = clients);
    } catch (e) {
      debugPrint("Error fetching clients: $e");
    } finally {
      if (mounted) setState(() => _isLoadingClients = false);
    }
  }

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
          location: data['location'] ?? '',
          latitude: lat,
          longitude: lng,
          contract: contract,
          logoUrl: data['logoUrl'],
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
            final Map<String, dynamic> warrantyMap = Map<String, dynamic>.from(data['warranty'] as Map);
            warranty = EquipmentWarranty.fromMap(warrantyMap);
          } catch (e) {
            debugPrint('❌ Erreur de lecture de la garantie: $e');
          }
        }

        if (warranty == null) {
          final Timestamp? installTs = data['installationDate'] ?? data['installDate'] ?? data['createdAt'];
          if (installTs != null) {
            warranty = EquipmentWarranty.defaultOneYear(installTs.toDate());
          }
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

  // ----------------------------------------------------------------------
  // LOGIC & FEATURES
  // ----------------------------------------------------------------------

  Future<void> _pickDate() async {
    final now = DateTime.now();
    DateTime tempPickedDate = _scheduledDate ?? now;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext builder) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 320,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05), width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Annuler', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      Text('Date', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      TextButton(
                        onPressed: () {
                          setState(() => _scheduledDate = tempPickedDate);
                          Navigator.of(context).pop();
                        },
                        child: Text('Confirmer', style: GoogleFonts.inter(color: Colors.blueAccent.shade700, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: tempPickedDate,
                    minimumDate: DateTime(2023),
                    maximumDate: now.add(const Duration(days: 365)),
                    onDateTimeChanged: (DateTime newDate) {
                      tempPickedDate = newDate;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    DateTime tempPickedTime = _scheduledTime != null
        ? DateTime(now.year, now.month, now.day, _scheduledTime!.hour, _scheduledTime!.minute)
        : DateTime(now.year, now.month, now.day, 9, 0);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext builder) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 320,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05), width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Annuler', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      Text('Heure', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      TextButton(
                        onPressed: () {
                          setState(() => _scheduledTime = TimeOfDay.fromDateTime(tempPickedTime));
                          Navigator.of(context).pop();
                        },
                        child: Text('Confirmer', style: GoogleFonts.inter(color: Colors.blueAccent.shade700, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true, // Best for 24-hour European/French format!
                    initialDateTime: tempPickedTime,
                    onDateTimeChanged: (DateTime newTime) {
                      tempPickedTime = newTime;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _calculateBillingStatus() {
    if (_selectedEquipment != null && _selectedEquipment!.warranty != null) {
      if (_selectedEquipment!.warranty!.isValid) {
        return {'status': 'GRATUIT', 'reason': 'Sous Garantie Constructeur', 'color': Colors.greenAccent.shade700, 'icon': Icons.verified_user};
      }
    }

    if (_selectedStore != null && _selectedStore!.contract != null) {
      final contract = _selectedStore!.contract!;
      if (contract.isValidNow) {
        bool isPreventive = _selectedInterventionType == 'Maintenance' ||
            _selectedInterventionType == 'Préventif' ||
            _selectedInterventionType == 'Formation';

        if (isPreventive) {
          if (contract.hasCreditPreventive) {
            return {'status': 'INCLUS', 'reason': 'Crédit Maint.: ${contract.usedPreventive}/${contract.quotaPreventive} utilisés', 'color': Colors.teal, 'icon': Icons.shield};
          } else {
            return {'status': 'HORS FORFAIT', 'reason': 'Quota Maintenance Épuisé', 'color': Colors.orange, 'icon': Icons.warning_amber};
          }
        } else {
          if (contract.hasCreditCorrective) {
            return {'status': 'INCLUS', 'reason': 'Crédit Dépannage: ${contract.usedCorrective}/${contract.quotaCorrective} utilisés', 'color': Colors.teal, 'icon': Icons.build_circle};
          } else {
            return {'status': 'HORS FORFAIT', 'reason': 'Quota Dépannage Épuisé', 'color': Colors.orange, 'icon': Icons.money_off};
          }
        }
      } else {
        return {'status': 'FACTURABLE', 'reason': 'Contrat Expiré', 'color': Colors.redAccent, 'icon': Icons.attach_money};
      }
    }

    return {'status': 'FACTURABLE', 'reason': 'Hors Garantie / Hors Contrat', 'color': Colors.deepOrange, 'icon': Icons.monetization_on_outlined};
  }

  Future<void> _checkContractAndSuggestMaintenance(Store store) async {
    final contract = store.contract;
    if (contract == null || !contract.isValidNow) return;

    if (contract.remainingPreventive > 0) {
      bool? isPreventive = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [const Icon(Icons.star, color: Colors.teal), const SizedBox(width: 8), Text("Contrat Détecté", style: GoogleFonts.outfit(fontWeight: FontWeight.bold))],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Ce magasin dispose de ${contract.remainingPreventive} visite(s) préventive(s) restante(s).", style: GoogleFonts.inter(fontSize: 15)),
              const SizedBox(height: 12),
              Text("S'agit-il d'une visite de maintenance planifiée ?", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Non, Dépannage", style: GoogleFonts.inter(color: Colors.grey))),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_circle_outline),
              label: Text("Oui, Maintenance", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      );

      if (isPreventive == true) {
        setState(() {
          _selectedInterventionType = 'Préventif';
          _isTypeLocked = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("✅ Type verrouillé sur 'Préventif' (Crédit déduit)", style: GoogleFonts.inter()),
              backgroundColor: Colors.teal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          ));
        }
      }
    }
  }

  Future<void> _extractCoordinatesFromLink() async {
    String url = _gpsLinkController.text.trim();
    if (url.isEmpty) return;
    setState(() => _isResolvingLink = true);

    try {
      if (url.contains('goo.gl') || url.contains('maps.app.goo.gl') || url.contains('bit.ly')) {
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Coordonnées extraites !", style: GoogleFonts.inter()), backgroundColor: Colors.greenAccent.shade700, behavior: SnackBarBehavior.floating));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Lien invalide.", style: GoogleFonts.inter()), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e", style: GoogleFonts.inter()), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isResolvingLink = false);
    }
  }

  Future<void> _generateReportFromKeywords() async {
    final rawNotes = _requestController.text;
    if (rawNotes.trim().isEmpty) return;

    setState(() => _isGeneratingAi = true);
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('generateReportFromNotes');
      final result = await callable.call<String>({'rawNotes': rawNotes, 'context': 'problem_report'});
      setState(() => _requestController.text = result.data);
    } catch (e) {
      // Ignore
    } finally {
      if (mounted) setState(() => _isGeneratingAi = false);
    }
  }

  // --- UPLOAD ---
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

  Future<String?> _uploadFileToB2(PlatformFile file, Map<String, dynamic> b2Creds) async {
    try {
      final fileName = file.name;
      final int length = file.size;

      final Uint8List bytes;
      if (kIsWeb) {
        bytes = file.bytes!;
      } else {
        bytes = await File(file.path!).readAsBytes();
      }

      final sha1Hash = sha1.convert(bytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);

      var request = http.StreamedRequest('POST', uploadUri);
      request.headers.addAll({
        'Authorization': b2Creds['authorizationToken'] as String,
        'X-Bz-File-Name': Uri.encodeComponent(fileName),
        'Content-Type': 'b2/x-auto',
        'X-Bz-Content-Sha1': sha1Hash,
        'Content-Length': length.toString(),
      });

      request.sink.add(bytes);
      request.sink.close();

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final body = json.decode(respStr) as Map<String, dynamic>;
        final encodedPath = (body['fileName'] as String).split('/').map(Uri.encodeComponent).join('/');
        return (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'pdf'],
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result != null) {
      setState(() {
        _localFilesToUpload.addAll(result.files);
      });
    }
  }

  Future<void> _saveIntervention() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    if (_selectedClient == null || _selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veuillez sélectionner un client et un magasin.', style: GoogleFonts.inter()), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
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

      String? generatedCode;

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
        generatedCode = finalInterventionCode;

        final double? finalLat = _parsedLat ?? _selectedStore!.latitude;
        final double? finalLng = _parsedLng ?? _selectedStore!.longitude;

        if (_parsedLat != null && _parsedLng != null) {
          transaction.update(storeRef, {'latitude': _parsedLat, 'longitude': _parsedLng});
        }

        final billingInfo = _calculateBillingStatus();

        DateTime? scheduledFullDate;
        if (_scheduledDate != null) {
          final t = _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0);
          scheduledFullDate = DateTime(_scheduledDate!.year, _scheduledDate!.month, _scheduledDate!.day, t.hour, t.minute);
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
          'isExtended': false,
        });

        transaction.set(counterRef, {'count': newCount, 'lastReset': currentYear});
      });

      // CREATE STORY
      try {
        final newStory = {
          'userId': user.uid,
          'userName': creatorName,
          'storeName': '${_selectedStore!.name} - ${_selectedStore!.location}',
          'storeLogoUrl': _selectedStore!.logoUrl,
          'location': _selectedStore!.location,
          'description': _requestController.text.trim(),
          'badgeText': generatedCode ?? 'Nouvelle Demande',
          'mediaUrls': _uploadedMediaUrls,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'intervention',
          'viewedBy': [user.uid],
        };
        await FirebaseFirestore.instance.collection('daily_stories').add(newStory);
      } catch (storyError) {
        debugPrint("Story failed: $storyError");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Intervention créée avec succès!', style: GoogleFonts.inter()), backgroundColor: Colors.greenAccent.shade700, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e', style: GoogleFonts.inter()), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // 🌟 ULTRA PREMIUM 4K UI / DIALOGS
  // ===========================================================================

  InputDecoration _dialogInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: Colors.black54),
      filled: true,
      fillColor: Colors.white.withOpacity(0.6),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
    );
  }

  Future<void> _openCustomSelectDialog<T>({
    required String title,
    required List<T> items,
    required T? currentValue,
    required Function(T) onSelected,
  }) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 15))],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final isSelected = item == currentValue;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    onSelected(item);
                                    Navigator.pop(context);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.toString(),
                                            style: GoogleFonts.inter(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              fontSize: 16,
                                              color: isSelected ? Colors.blueAccent.shade700 : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(Icons.check_circle_rounded, color: Colors.blueAccent, size: 24),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: Colors.white.withOpacity(0.6),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text("Annuler", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 16)),
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

  void _openSearchDialog<T>({
    required String title,
    required List<T> items,
    required String Function(T) getLabel,
    String? Function(T)? getSubtitle,
    required Function(T) onSelected,
    VoidCallback? onAddPressed,
    String? addButtonLabel,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setStateSB) {
            final filteredItems = items.where((item) {
              final nameLower = getLabel(item).toLowerCase();
              final queryLower = searchQuery.toLowerCase();
              return nameLower.contains(queryLower);
            }).toList();

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 15))],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        TextField(
                          autofocus: true,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Rechercher...',
                            hintStyle: GoogleFonts.inter(color: Colors.black45),
                            prefixIcon: const Icon(Icons.search_rounded, color: Colors.blueAccent),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          ),
                          onChanged: (val) => setStateSB(() => searchQuery = val),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: filteredItems.length + (onAddPressed != null ? 1 : 0),
                                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                                itemBuilder: (context, index) {
                                  if (onAddPressed != null && index == filteredItems.length) {
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () { Navigator.pop(context); onAddPressed(); },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.add_circle_rounded, color: Colors.blueAccent, size: 24),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(addButtonLabel ?? 'Ajouter', style: GoogleFonts.inter(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final item = filteredItems[index];
                                  final label = getLabel(item);
                                  final subtitle = getSubtitle != null ? getSubtitle(item) : null;
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () { onSelected(item); Navigator.pop(context); },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
                                            if (subtitle != null && subtitle.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.location_on, size: 14, color: Colors.black45),
                                                  const SizedBox(width: 4),
                                                  Expanded(child: Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: Colors.black54))),
                                                ],
                                              ),
                                            ]
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              backgroundColor: Colors.white.withOpacity(0.6),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text("Fermer", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16)),
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

  Widget _buildGlassSection({required String title, required IconData icon, required List<Widget> children}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.45),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 24,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                    ),
                    child: Icon(icon, color: Colors.blueAccent.shade700, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1, thickness: 1.5, color: Colors.white70),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: maxLines > 1,
        labelStyle: GoogleFonts.inter(color: Colors.black54),
        prefixIcon: maxLines > 1 ? Padding(padding: const EdgeInsets.only(bottom: 50), child: Icon(icon, color: Colors.blueAccent.shade400)) : Icon(icon, color: Colors.blueAccent.shade400),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildClickableField({
    required String label,
    required String valueText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: valueText),
          style: GoogleFonts.inter(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.inter(color: Colors.black54),
            prefixIcon: Icon(icon, color: Colors.blueAccent.shade400),
            filled: true,
            fillColor: Colors.white.withOpacity(0.6),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDropdownField<T>({
    required String label,
    required T? value,
    required IconData icon,
    required VoidCallback onTap,
    bool locked = false,
  }) {
    return GestureDetector(
      onTap: locked ? null : onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: value?.toString() ?? ''),
          style: GoogleFonts.inter(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.inter(color: Colors.black54),
            prefixIcon: Icon(icon, color: Colors.blueAccent.shade400),
            suffixIcon: Icon(locked ? Icons.lock : Icons.keyboard_arrow_down_rounded, color: locked ? Colors.teal : Colors.blueAccent.shade400),
            filled: true,
            fillColor: Colors.white.withOpacity(0.6),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
            ),
          ),
          validator: (val) => (value == null || value.toString().isEmpty) ? 'Requis' : null,
        ),
      ),
    );
  }

  Widget _buildSearchableDropdown({
    required String label,
    required String valueText,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
    String? Function(String?)? validator,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: valueText),
          style: GoogleFonts.inter(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.inter(color: Colors.black54),
            prefixIcon: Icon(icon, color: Colors.blueAccent.shade400),
            suffixIcon: (valueText.isNotEmpty && onClear != null)
                ? IconButton(icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent), onPressed: onClear)
                : Icon(Icons.search_rounded, color: Colors.blueAccent.shade400),
            filled: true,
            fillColor: Colors.white.withOpacity(0.6),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
            ),
          ),
          validator: (val) => validator != null ? validator(valueText) : null,
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fichiers & Médias de Support', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 12),

        if (_localFilesToUpload.isNotEmpty) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _localFilesToUpload.map((file) {
              final isVid = file.name.toLowerCase().endsWith('.mp4') || file.name.toLowerCase().endsWith('.mov');
              final isPdf = file.name.toLowerCase().endsWith('.pdf');

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 2),
                        color: Colors.white.withOpacity(0.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: isPdf ? const Icon(Icons.picture_as_pdf, size: 40, color: Colors.red) : isVid ? const Icon(Icons.videocam, size: 40, color: Colors.blue) : (kIsWeb ? Image.memory(file.bytes!, fit: BoxFit.cover) : Image.file(File(file.path!), fit: BoxFit.cover)),
                    ),
                  ),
                  Positioned(
                    right: -8,
                    top: -8,
                    child: GestureDetector(
                      onTap: () => setState(() => _localFilesToUpload.remove(file)),
                      child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: const Icon(Icons.cancel, color: Colors.redAccent, size: 24)),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isUploadingMedia ? null : _pickFiles,
            icon: const Icon(Icons.attach_file),
            label: Text('Sélectionner des fichiers', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.white.withOpacity(0.6),
              foregroundColor: Colors.blueAccent,
              side: const BorderSide(color: Colors.blueAccent, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF1E88E5), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: (_isLoading || _isUploadingMedia) ? null : _saveIntervention,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isUploadingMedia ? Icons.cloud_upload : Icons.rocket_launch_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    _isUploadingMedia ? 'Envoi Média...' : 'Créer Intervention',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MAIN BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final billingInfo = _calculateBillingStatus();
    List<String> interventionTypes = ['Maintenance', 'Formation', 'Mise à Jour', 'Autre'];
    if (_selectedInterventionType == 'Préventif') interventionTypes = ['Préventif'];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.1),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.white.withOpacity(0.1)),
          ),
        ),
        title: Text(
          'Nouvelle Intervention',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(const Color(0xFFE2E2FF), const Color(0xFFF0E5FF), _bgAnimationController.value)!,
                      Color.lerp(const Color(0xFFF0E5FF), const Color(0xFFEAF5FF), _bgAnimationController.value)!,
                      Color.lerp(const Color(0xFFEAF5FF), const Color(0xFFE2E2FF), _bgAnimationController.value)!,
                    ],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: _isLoadingPage || _isLoadingClients
                ? Center(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(24)),
                  child: const CircularProgressIndicator(color: Colors.blueAccent),
                ),
              ),
            )
                : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  physics: const BouncingScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildGlassSection(
                          title: 'Destination',
                          icon: Icons.location_on_outlined,
                          children: [

                            // 🚀 THE OMNIBAR IS BACK! STYLED TO MATCH THE PREMIUM UI
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
                                  height: 56, // Matches standard text field height
                                  width: 56,
                                  decoration: BoxDecoration(
                                      color: Colors.blueAccent.shade400,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                                      ]
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.add_business_rounded, color: Colors.white, size: 26),
                                    tooltip: 'Créer un Client',
                                    onPressed: () async {
                                      await Navigator.push(context, MaterialPageRoute(builder: (_) => AddClientPage(preselectedServiceType: widget.serviceType)));
                                      _fetchClients();
                                    },
                                  ),
                                ),
                              ],
                            ),

                            if (_selectedClient != null) ...[
                              const SizedBox(height: 20),
                              _isLoadingStores
                                  ? const Center(child: LinearProgressIndicator())
                                  : _buildSearchableDropdown(
                                label: 'Magasin / Agence *',
                                valueText: _selectedStore != null ? '${_selectedStore!.name} - ${_selectedStore!.location}' : '',
                                icon: Icons.storefront_outlined,
                                onClear: () {
                                  setState(() {
                                    _selectedStore = null;
                                    _parsedLat = null;
                                    _parsedLng = null;
                                    _gpsLinkController.clear();
                                    _isTypeLocked = false;
                                    _selectedInterventionType = null;
                                  });
                                },
                                onTap: () => _openSearchDialog<Store>(
                                  title: 'Rechercher un Magasin',
                                  items: _stores,
                                  getLabel: (s) => s.name,
                                  getSubtitle: (s) => s.location,
                                  onSelected: (item) {
                                    setState(() {
                                      _selectedStore = item;
                                      _parsedLat = null;
                                      _parsedLng = null;
                                      _gpsLinkController.clear();
                                      _isTypeLocked = false;
                                      _selectedInterventionType = null;
                                    });
                                    _fetchEquipments(item.id);
                                    _checkContractAndSuggestMaintenance(item);
                                  },
                                  onAddPressed: () async {
                                    await Navigator.push(context, MaterialPageRoute(builder: (_) => AddStorePage(clientId: _selectedClient!.id)));
                                    _fetchStores(_selectedClient!.id);
                                  },
                                  addButtonLabel: 'Créer une Agence',
                                ),
                                validator: (val) => val == null || val.isEmpty ? 'Requis' : null,
                              ),
                            ],
                            if (_selectedStore != null) ...[
                              const SizedBox(height: 20),
                              _isLoadingEquipments
                                  ? const Center(child: LinearProgressIndicator())
                                  : _buildSearchableDropdown(
                                label: 'Équipement (Optionnel)',
                                valueText: _selectedEquipment != null ? '${_selectedEquipment!.name} (${_selectedEquipment!.serial})' : '',
                                icon: Icons.settings_input_component_outlined,
                                onClear: () => setState(() => _selectedEquipment = null),
                                onTap: () => _openSearchDialog<Equipment>(
                                  title: 'Sélectionner un Équipement',
                                  items: _equipments,
                                  getLabel: (e) => e.name,
                                  getSubtitle: (e) => 'S/N: ${e.serial}',
                                  onSelected: (item) => setState(() => _selectedEquipment = item),
                                ),
                              ),
                            ],
                          ],
                        ),

                        if (_selectedStore != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: (billingInfo['color'] as Color).withOpacity(0.1), border: Border.all(color: billingInfo['color'] as Color, width: 1.5), borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              children: [
                                CircleAvatar(backgroundColor: billingInfo['color'] as Color, radius: 24, child: Icon(billingInfo['icon'] as IconData, color: Colors.white, size: 28)),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(billingInfo['status'] as String, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: billingInfo['color'] as Color)),
                                      Text(billingInfo['reason'] as String, style: GoogleFonts.inter(fontSize: 14, color: Colors.black87)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (_selectedStore != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 1.5)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon((_selectedStore!.latitude != null || _parsedLat != null) ? Icons.check_circle : Icons.warning_amber_rounded, color: (_selectedStore!.latitude != null || _parsedLat != null) ? Colors.greenAccent.shade700 : Colors.orangeAccent.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text((_selectedStore!.latitude != null) ? "Position Magasin Synchronisée" : (_parsedLat != null) ? "Position prête à être sauvegardée" : "Position GPS manquante", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: (_selectedStore!.latitude != null || _parsedLat != null) ? Colors.green.shade800 : Colors.orange.shade900))),
                                  ],
                                ),
                                if (_selectedStore!.latitude == null || _parsedLat != null) ...[
                                  const SizedBox(height: 12),
                                  const Divider(color: Colors.black12),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: _buildTextField(controller: _gpsLinkController, label: 'Lien Google Maps (Optionnel)', icon: Icons.link)),
                                      const SizedBox(width: 8),
                                      Container(
                                        height: 55,
                                        width: 55,
                                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.blueAccent),
                                        child: IconButton(
                                          icon: _isResolvingLink ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.search, color: Colors.white),
                                          onPressed: _isResolvingLink ? null : _extractCoordinatesFromLink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        _buildGlassSection(
                          title: 'Détails Intervention',
                          icon: Icons.assignment_outlined,
                          children: [
                            _buildCustomDropdownField<String>(
                              label: 'Type d\'Intervention *',
                              value: _selectedInterventionType,
                              icon: Icons.category_outlined,
                              locked: _isTypeLocked,
                              onTap: () => _openCustomSelectDialog<String>(
                                title: 'Sélectionner le Type',
                                items: interventionTypes,
                                currentValue: _selectedInterventionType,
                                onSelected: (value) => setState(() => _selectedInterventionType = value),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildCustomDropdownField<String>(
                              label: 'Priorité *',
                              value: _selectedInterventionPriority,
                              icon: Icons.flag_outlined,
                              onTap: () => _openCustomSelectDialog<String>(
                                title: 'Sélectionner la Priorité',
                                items: ['Haute', 'Moyenne', 'Basse'],
                                currentValue: _selectedInterventionPriority,
                                onSelected: (value) => setState(() => _selectedInterventionPriority = value),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildClickableField(
                                    label: 'Date',
                                    valueText: _scheduledDate != null ? DateFormat('dd/MM/yyyy').format(_scheduledDate!) : '',
                                    icon: Icons.calendar_today,
                                    onTap: _pickDate,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildClickableField(
                                    label: 'Heure',
                                    valueText: _scheduledTime != null ? _scheduledTime!.format(context) : '',
                                    icon: Icons.access_time,
                                    onTap: _pickTime,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _clientPhoneController,
                              label: 'Numéro Contact (Optionnel)',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _requestController,
                              label: 'Description de la Demande *',
                              icon: Icons.description_outlined,
                              maxLines: 4,
                              validator: (val) => val == null || val.isEmpty ? 'Requis' : null,
                              suffixIcon: IconButton(icon: _isGeneratingAi ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, color: Colors.amber), onPressed: _generateReportFromKeywords),
                            ),
                            const SizedBox(height: 20),
                            _buildMediaSection(),
                          ],
                        ),
                        const SizedBox(height: 32),
                        _buildSubmitButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
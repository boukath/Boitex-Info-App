// lib/screens/service_technique/intervention_details_page.dart

import 'dart:async'; // ✅ Added for Stream/Completer
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';

// ✅ In‑app media viewers
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';

// ✅ Video Thumbnails
import 'package:video_thumbnail/video_thumbnail.dart';

// ✅ Cloud Functions
import 'package:cloud_functions/cloud_functions.dart';

// ✅ PDF & Sharing
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_saver/file_saver.dart';
import 'package:printing/printing.dart';

// ✅ Global Search Page for System Selection
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';
// ✅ Product Scanner Page
import 'package:boitex_info_app/screens/administration/product_scanner_page.dart';

// ----------------------------------------------------------------------
// Data model
// ----------------------------------------------------------------------
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
// Page
// ----------------------------------------------------------------------
class InterventionDetailsPage extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> interventionDoc;
  const InterventionDetailsPage({super.key, required this.interventionDoc});

  @override
  State<InterventionDetailsPage> createState() =>
      _InterventionDetailsPageState();
}

class _InterventionDetailsPageState extends State<InterventionDetailsPage> {
  // Controllers
  late final TextEditingController _managerNameController;
  late final TextEditingController _managerPhoneController;
  late final TextEditingController _managerEmailController;
  late final TextEditingController _diagnosticController;
  late final TextEditingController _workDoneController;
  late final SignatureController _signatureController;

  // State
  String? _signatureImageUrl;
  String _currentStatus = 'Nouveau';
  List<AppUser> _allTechnicians = [];
  List<AppUser> _selectedTechnicians = [];
  bool _isLoading = false;

  // ✅ NEW: Edit Mode Toggle
  bool _isEditing = false;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _mediaFilesToUpload = [];
  List<String> _existingMediaUrls = [];

  // ✅ UPGRADED: List of Selected Systems (Multi-Product Support)
  List<Map<String, dynamic>> _selectedSystems = [];

  // ✅ NEW: Suggested Systems List (from History)
  List<Map<String, dynamic>>? _suggestedSystemsFromHistory;

  // AI State
  bool _isGeneratingDiagnostic = false;
  bool _isGeneratingWorkDone = false;

  // ✅ NEW: Store GPS Coordinates
  double? _storeLat;
  double? _storeLng;
  bool _isLoadingGps = false;

  // ✅ NEW: Live Scheduled Date (Local State)
  DateTime? _scheduledAt;

  // Backblaze B2 helper function endpoint
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  // File size limit (50MB in bytes)
  static const int _maxFileSizeInBytes = 50 * 1024 * 1024;

  // Status options
  List<String> get statusOptions {
    final current =
        (widget.interventionDoc.data() ?? {})['status'] as String? ?? 'Nouveau';
    if (current == 'Clôturé' || current == 'Facturé') {
      return ['Clôturé', 'Facturé'];
    }

    List<String> baseOptions = [
      'Nouvelle Demande',
      'Nouveau',
      'En cours',
      'Terminé',
      'En attente'
    ];
    final Set<String> optionsSet = Set<String>.from(baseOptions);
    if (!optionsSet.contains(current)) {
      optionsSet.add(current);
    }
    return optionsSet.toList();
  }

  // ✅ UPDATED: Strictly Read-Only (Archived)
  bool get isArchived {
    final status =
        (widget.interventionDoc.data() ?? {})['status'] as String? ?? 'Nouveau';
    return ['Clôturé', 'Facturé'].contains(status);
  }

  @override
  void initState() {
    super.initState();
    final data = widget.interventionDoc.data() ?? {};
    _managerNameController =
        TextEditingController(text: data['managerName'] ?? '');
    _managerPhoneController =
        TextEditingController(text: data['managerPhone'] ?? '');
    _managerEmailController =
        TextEditingController(text: data['managerEmail'] ?? '');
    _diagnosticController =
        TextEditingController(text: data['diagnostic'] ?? '');
    _workDoneController = TextEditingController(text: data['workDone'] ?? '');

    _signatureController = SignatureController();
    _signatureImageUrl = data['signatureUrl'] as String?;
    _currentStatus = data['status'] ?? 'Nouveau';

    // ✅ Initialize Edit Mode
    _isEditing = ['Nouveau', 'Nouvelle Demande'].contains(_currentStatus);

    // ✅ Load Schedule
    if (data['scheduledAt'] != null) {
      _scheduledAt = (data['scheduledAt'] as Timestamp).toDate();
    }

    // ✅ DATA MIGRATION: Handle old single-product vs new multi-product-quantity
    if (data['systems'] != null) {
      _selectedSystems = List<Map<String, dynamic>>.from(data['systems']);
      for (var system in _selectedSystems) {
        if (system['quantity'] == null) system['quantity'] = 1;
        if (system['serialNumbers'] == null) {
          String? oldSn = system['serialNumber'];
          int qty = system['quantity'] ?? 1;
          List<String> snList = List.filled(qty, '');
          if (oldSn != null && oldSn.isNotEmpty) snList[0] = oldSn;
          system['serialNumbers'] = snList;
        }
      }
    } else if (data['systemId'] != null) {
      // Backward compatibility
      _selectedSystems.add({
        'id': data['systemId'],
        'name': data['systemName'],
        'reference': data['systemReference'],
        'marque': data['marque'],
        'category': data['category'],
        'image': data['systemImage'],
        'quantity': 1,
        'serialNumbers': [data['serialNumber'] ?? ''],
      });
    }

    final mediaList = data['mediaUrls'] as List?;
    _existingMediaUrls = mediaList != null ? List<String>.from(mediaList) : [];

    _fetchTechnicians().then((_) {
      final List<dynamic> assignedIds =
      List.from(data['assignedTechniciansIds'] ?? const []);
      _selectedTechnicians = _allTechnicians.where((tech) {
        return assignedIds.any((id) => (id is String && id == tech.uid));
      }).toList();
      if (mounted) setState(() {});
    });

    if (_selectedSystems.isEmpty) {
      _checkForPreviousSystem();
    }

    _fetchStoreData();
  }

  Future<void> _fetchStoreData() async {
    final data = widget.interventionDoc.data();
    if (data == null) return;

    final String? clientId = data['clientId'];
    final String? storeId = data['storeId'];

    if (clientId != null && storeId != null) {
      setState(() => _isLoadingGps = true);
      try {
        final storeDoc = await FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .collection('stores')
            .doc(storeId)
            .get();

        if (storeDoc.exists) {
          final storeData = storeDoc.data();
          if (storeData != null && mounted) {
            setState(() {
              if (storeData['latitude'] != null &&
                  storeData['longitude'] != null) {
                _storeLat = (storeData['latitude'] as num).toDouble();
                _storeLng = (storeData['longitude'] as num).toDouble();
              }
              if (_managerNameController.text.isEmpty) {
                _managerNameController.text = storeData['contactName'] ??
                    storeData['managerName'] ??
                    '';
              }
              if (_managerPhoneController.text.isEmpty) {
                _managerPhoneController.text = storeData['contactPhone'] ??
                    storeData['managerPhone'] ??
                    '';
              }
              if (_managerEmailController.text.isEmpty) {
                _managerEmailController.text = storeData['contactEmail'] ??
                    storeData['managerEmail'] ??
                    '';
              }
            });
          }
        }
      } catch (e) {
        debugPrint("Error fetching store data: $e");
      } finally {
        if (mounted) setState(() => _isLoadingGps = false);
      }
    }
  }

  Future<void> _launchMaps() async {
    if (_storeLat == null || _storeLng == null) return;
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$_storeLat,$_storeLng");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir la carte.")),
        );
      }
    }
  }

  Future<void> _editSchedule() async {
    final now = DateTime.now();
    final initialDate = _scheduledAt ?? now;
    final initialTime = _scheduledAt != null
        ? TimeOfDay.fromDateTime(_scheduledAt!)
        : const TimeOfDay(hour: 9, minute: 0);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2023),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null) return;

    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime == null) return;

    final newSchedule = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() => _isLoading = true);

    try {
      String flashNote =
          "📅 Rendez-vous reprogrammé au ${DateFormat('dd/MM HH:mm').format(newSchedule)}";
      if (_scheduledAt != null) {
        flashNote +=
        " (était: ${DateFormat('dd/MM HH:mm').format(_scheduledAt!)})";
      }

      await widget.interventionDoc.reference.update({
        'scheduledAt': Timestamp.fromDate(newSchedule),
        'lastFollowUpNote': flashNote,
        'lastFollowUpDate': FieldValue.serverTimestamp(),
      });

      setState(() {
        _scheduledAt = newSchedule;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Planning mis à jour avec succès!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _checkForPreviousSystem() async {
    final data = widget.interventionDoc.data();
    if (data == null) return;
    final String? storeId = data['storeId'];
    if (storeId == null) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('interventions')
          .where('storeId', isEqualTo: storeId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      for (var doc in query.docs) {
        if (doc.id == widget.interventionDoc.id) continue;
        final prevData = doc.data();
        List<Map<String, dynamic>> foundSystems = [];

        if (prevData['systems'] != null) {
          foundSystems = List<Map<String, dynamic>>.from(prevData['systems']);
        } else if (prevData['systemId'] != null) {
          foundSystems.add({
            'id': prevData['systemId'],
            'name': prevData['systemName'],
            'reference': prevData['systemReference'],
            'marque': prevData['marque'],
            'category': prevData['category'],
            'image': prevData['systemImage'],
            'quantity': 1,
            'serialNumbers': [prevData['serialNumber'] ?? ''],
          });
        }

        if (foundSystems.isNotEmpty) {
          if (mounted) {
            setState(() {
              _suggestedSystemsFromHistory = foundSystems;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('History check failed: $e');
    }
  }

  void _applySuggestion() {
    if (_suggestedSystemsFromHistory != null) {
      setState(() {
        _selectedSystems = _suggestedSystemsFromHistory!.map((s) {
          var newMap = Map<String, dynamic>.from(s);
          newMap['quantity'] = 1;
          newMap['serialNumbers'] = [''];
          return newMap;
        }).toList();
        _suggestedSystemsFromHistory = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Systèmes ajoutés. Veuillez vérifier les quantités.'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<int> _requestQuantity() async {
    int qty = 1;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Quantité",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Combien d'unités pour ce produit ?"),
            const SizedBox(height: 16),
            TextFormField(
              autofocus: true,
              initialValue: "1",
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667EEA)),
              decoration: InputDecoration(
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => qty = int.tryParse(v) ?? 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
    return qty > 0 ? qty : 1;
  }

  Future<void> _selectSystem() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const GlobalProductSearchPage(isSelectionMode: true),
      ),
    );

    if (result == null) return;

    String? id;
    String name = 'Produit sans nom';
    String reference = 'Ref: N/A';
    String? marque;
    String? category;
    String? image;
    int qty = 1;

    if (result is DocumentSnapshot) {
      final data = result.data() as Map<String, dynamic>;
      id = result.id;
      name = data['nom'] ?? name;
      reference = data['reference'] ?? reference;
      marque = data['marque'];
      category = data['categorie'] ?? data['category'];
      final images = (data['imageUrls'] as List?)?.cast<String>() ?? [];
      if (images.isNotEmpty) image = images.first;
      qty = await _requestQuantity();
    } else if (result is Map<String, dynamic>) {
      id = result['productId'] ?? result['id'];
      name = result['productName'] ?? result['nom'] ?? name;
      reference = result['partNumber'] ?? result['reference'] ?? reference;
      marque = result['marque'];
      category = result['categorie'] ?? result['category'];
      image = result['image'] ?? result['imageUrl'];

      if (result.containsKey('quantity')) {
        qty = result['quantity'] is int
            ? result['quantity']
            : (int.tryParse(result['quantity'].toString()) ?? 1);
      } else {
        qty = await _requestQuantity();
      }
    }

    setState(() {
      _selectedSystems.add({
        'id': id,
        'name': name,
        'reference': reference,
        'marque': marque,
        'category': category,
        'image': image,
        'quantity': qty,
        'serialNumbers': List<String>.filled(qty, ''),
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Produit ajouté depuis le catalogue !'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _scanSystem() async {
    final String? scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProductScannerPage()),
    );

    if (scannedCode == null) return;

    setState(() => _isLoading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('produits')
          .where('reference', isEqualTo: scannedCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aucun produit trouvé avec le code: $scannedCode'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();
      final images = (data['imageUrls'] as List?)?.cast<String>() ?? [];

      setState(() => _isLoading = false);

      int qty = await _requestQuantity();

      setState(() {
        _selectedSystems.add({
          'id': doc.id,
          'name': data['nom'] ?? 'Produit sans nom',
          'reference': data['reference'] ?? scannedCode,
          'marque': data['marque'],
          'category': data['categorie'],
          'image': images.isNotEmpty ? images.first : null,
          'quantity': qty,
          'serialNumbers': List<String>.filled(qty, ''),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${data['nom']} ajouté (x$qty)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur de scan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removeSystem(int index) {
    setState(() {
      _selectedSystems.removeAt(index);
    });
  }

  Future<void> _pickFromStoreInventory() async {
    final data = widget.interventionDoc.data();
    if (data == null) return;
    final String? clientId = data['clientId'];
    final String? storeId = data['storeId'];

    if (clientId == null || storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur: Données client/magasin manquantes.')));
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.store, color: Color(0xFF667EEA)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text("Inventaire du Magasin",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('clients')
                        .doc(clientId)
                        .collection('stores')
                        .doc(storeId)
                        .collection('materiel_installe')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text(
                                "Aucun équipement trouvé dans ce magasin.",
                                style: TextStyle(color: Colors.grey)));
                      }

                      final assets = snapshot.data!.docs;
                      assets.sort((a, b) {
                        final da = a.data() as Map<String, dynamic>;
                        final db = b.data() as Map<String, dynamic>;
                        final na = da['name'] ?? da['nom'] ?? 'Z';
                        final nb = db['name'] ?? db['nom'] ?? 'Z';
                        return na
                            .toString()
                            .toLowerCase()
                            .compareTo(nb.toString().toLowerCase());
                      });

                      return StatefulBuilder(
                        builder: (context, setStateList) {
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: assets.length,
                            itemBuilder: (context, index) {
                              final asset =
                              assets[index].data() as Map<String, dynamic>;
                              final String name =
                                  asset['name'] ?? asset['nom'] ?? 'Inconnu';
                              final String serial = asset['serialNumber'] ??
                                  asset['serial'] ??
                                  'N/A';
                              final String reference = asset['reference'] ?? '';
                              final String? image =
                                  asset['imageUrl'] ?? asset['image'];

                              return ListTile(
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: image != null
                                      ? ClipRRect(
                                      borderRadius:
                                      BorderRadius.circular(8),
                                      child: Image.network(image,
                                          fit: BoxFit.cover))
                                      : const Icon(Icons.inventory_2,
                                      size: 24, color: Colors.grey),
                                ),
                                title: Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    "S/N: $serial ${reference.isNotEmpty ? ' | $reference' : ''}",
                                    style: const TextStyle(fontSize: 12)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline,
                                      color: Color(0xFF667EEA)),
                                  onPressed: () {
                                    _addFromInventory(asset);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('$name ajouté'),
                                          duration:
                                          const Duration(milliseconds: 800),
                                          behavior: SnackBarBehavior.floating),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _addFromInventory(Map<String, dynamic> asset) {
    setState(() {
      final String reference = asset['reference'] ?? 'N/A';
      final String name = asset['name'] ?? asset['nom'] ?? 'Produit Inconnu';
      final String serial = asset['serialNumber'] ?? '';
      final String marque = asset['marque'] ?? 'Non spécifiée';
      final String category = asset['categorie'] ?? 'N/A';

      int existingIndex = _selectedSystems.indexWhere(
              (s) => s['name'] == name && s['reference'] == reference);

      if (existingIndex != -1) {
        var existing = _selectedSystems[existingIndex];
        int newQty = (existing['quantity'] ?? 1) + 1;
        List<String> serials =
        List<String>.from(existing['serialNumbers'] ?? []);

        if (serials.length < newQty) {
          serials.add(serial);
        } else {
          int emptyIndex = serials.indexOf('');
          if (emptyIndex != -1) {
            serials[emptyIndex] = serial;
          } else {
            serials.add(serial);
          }
        }
        _selectedSystems[existingIndex]['quantity'] = newQty;
        _selectedSystems[existingIndex]['serialNumbers'] = serials;
      } else {
        _selectedSystems.add({
          'id': null,
          'name': name,
          'reference': reference,
          'marque': marque,
          'category': category,
          'image': asset['imageUrl'] ?? asset['image'],
          'quantity': 1,
          'serialNumbers': [serial],
        });
      }
    });
  }

  Future<void> _manageSerialNumbers(int index) async {
    final system = _selectedSystems[index];
    final int qty = system['quantity'] ?? 1;
    List<String> currentSerials =
    List.from(system['serialNumbers'] ?? List.filled(qty, ''));

    if (currentSerials.length != qty) {
      if (currentSerials.length < qty) {
        currentSerials.addAll(List.filled(qty - currentSerials.length, ''));
      } else {
        currentSerials = currentSerials.sublist(0, qty);
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text("S/N ($qty articles)",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: Column(
                children: [
                  const Text(
                      "Scannez ou saisissez les numéros pour chaque unité.",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: qty,
                      itemBuilder: (context, i) {
                        final controller =
                        TextEditingController(text: currentSerials[i]);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Text("#${i + 1}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    hintText: "Numéro de série",
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (val) => currentSerials[i] = val,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.qr_code_scanner,
                                    color: Color(0xFF667EEA)),
                                onPressed: () async {
                                  final scanned = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                        const ProductScannerPage()),
                                  );
                                  if (scanned != null) {
                                    setStateDialog(() {
                                      currentSerials[i] = scanned;
                                      controller.text = scanned;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler"),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedSystems[index]['serialNumbers'] = currentSerials;
                  });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                ),
                child: const Text("Enregistrer"),
              ),
            ],
          );
        });
      },
    );
  }

  // ----------------------------------------------------------------------
  // Theme
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

  // ----------------------------------------------------------------------
  // AI Function
  // ----------------------------------------------------------------------
  Future<void> _generateAiText({
    required String aiContext,
    required TextEditingController controller,
  }) async {
    final rawNotes = controller.text;
    if (rawNotes.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez d\'abord saisir des mots-clés.')),
      );
      return;
    }

    setState(() {
      if (aiContext == 'diagnostic') {
        _isGeneratingDiagnostic = true;
      } else {
        _isGeneratingWorkDone = true;
      }
    });

    if (mounted) {
      FocusScope.of(context).unfocus();
    }

    try {
      final HttpsCallable callable =
      FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('generateReportFromNotes');

      final result = await callable.call<String>({
        'rawNotes': rawNotes,
        'context': aiContext,
      });

      controller.text = result.data;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de génération AI: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (aiContext == 'diagnostic') {
            _isGeneratingDiagnostic = false;
          } else {
            _isGeneratingWorkDone = false;
          }
        });
      }
    }
  }

  // ----------------------------------------------------------------------
  // Data helpers
  // ----------------------------------------------------------------------
  Future<void> _fetchTechnicians() async {
    try {
      final query = await FirebaseFirestore.instance.collection('users').get();
      _allTechnicians = query.docs
          .map((doc) => AppUser(
          uid: doc.id,
          displayName: (doc.data()['displayName'] ?? 'No Name') as String))
          .toList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement des techniciens: $e')),
      );
    }
  }

  bool _isVideoPath(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv');
  }

  Future<void> _pickMedia() async {
    final List<XFile> pickedFiles = await _picker.pickMultipleMedia();
    if (pickedFiles.isEmpty) return;
    final List<XFile> validFiles = [];
    final List<String> rejectedFiles = [];
    for (final file in pickedFiles) {
      final int fileSize = await file.length();
      final bool isVideo = _isVideoPath(file.name);
      if (isVideo && fileSize > _maxFileSizeInBytes) {
        rejectedFiles.add(
          '${file.name} (${(fileSize / 1024 / 1024).toStringAsFixed(1)} Mo)',
        );
      } else {
        validFiles.add(file);
      }
    }

    if (validFiles.isNotEmpty) {
      setState(() => _mediaFilesToUpload.addAll(validFiles));
    }

    if (rejectedFiles.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
          content: Text(
            'Fichiers suivants non ajoutés (limite 50 Mo):\n${rejectedFiles.join('\n')}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  // ----------------------------------------------------------------------
  // B2 Upload Logic
  // ----------------------------------------------------------------------
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

  // ✅ PREMIUM: Generic Upload with Progress Reporting
  Future<String?> _uploadStreamWithProgress({
    required Uri uploadUri,
    required Map<String, String> headers,
    required Stream<List<int>> stream,
    required int totalLength,
    required Function(double) onProgress,
  }) async {
    try {
      final request = http.StreamedRequest('POST', uploadUri);
      request.headers.addAll(headers);
      request.contentLength = totalLength;

      int bytesSent = 0;
      final completer = Completer<void>();

      stream.listen(
            (chunk) {
          request.sink.add(chunk);
          bytesSent += chunk.length;
          onProgress(bytesSent / totalLength);
        },
        onDone: () {
          request.sink.close();
          completer.complete();
        },
        onError: (e) {
          request.sink.addError(e);
          completer.completeError(e);
        },
        cancelOnError: true,
      );

      await completer.future;

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final responseBody = json.decode(respStr);
        return responseBody['fileName'];
      } else {
        print('B2 Upload Failed: ${response.statusCode} - $respStr');
        return null;
      }
    } catch (e) {
      print('Error streaming to B2: $e');
      return null;
    }
  }

  // Wrapper for File Upload (Media)
  Future<String?> _uploadFileToB2WithProgress(
      XFile file,
      Map<String, dynamic> b2Credentials,
      Function(double) onProgress,
      ) async {
    try {
      final int length = await file.length();
      final bytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(bytes).toString();

      final Uri uploadUri = Uri.parse(b2Credentials['uploadUrl']);
      final String fileName = file.name.split('/').last;

      // ✅ FIX: Explicit cast
      final headers = <String, String>{
        'Authorization': b2Credentials['authorizationToken'] as String,
        'X-Bz-File-Name': Uri.encodeComponent(fileName),
        'Content-Type': file.mimeType ?? 'b2/x-auto',
        'X-Bz-Content-Sha1': sha1Hash,
        'Content-Length': length.toString(),
      };

      final stream = Stream.value(bytes);

      final uploadedFileName = await _uploadStreamWithProgress(
        uploadUri: uploadUri,
        headers: headers,
        stream: stream,
        totalLength: length,
        onProgress: onProgress,
      );

      if (uploadedFileName != null) {
        return b2Credentials['downloadUrlPrefix'] +
            uploadedFileName.split('/').map(Uri.encodeComponent).join('/');
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Wrapper for Bytes Upload (Signature)
  Future<String?> _uploadBytesToB2WithProgress(
      Uint8List bytes,
      String fileName,
      Map<String, dynamic> b2Credentials,
      Function(double) onProgress,
      ) async {
    try {
      final sha1Hash = sha1.convert(bytes).toString();
      final Uri uploadUri = Uri.parse(b2Credentials['uploadUrl']);

      // ✅ FIX: Explicit cast
      final headers = <String, String>{
        'Authorization': b2Credentials['authorizationToken'] as String,
        'X-Bz-File-Name': Uri.encodeComponent(fileName),
        'Content-Type': 'image/png',
        'X-Bz-Content-Sha1': sha1Hash,
        'Content-Length': bytes.length.toString(),
      };

      final stream = Stream.value(bytes);

      final uploadedFileName = await _uploadStreamWithProgress(
        uploadUri: uploadUri,
        headers: headers,
        stream: stream,
        totalLength: bytes.length,
        onProgress: onProgress,
      );

      if (uploadedFileName != null) {
        return b2Credentials['downloadUrlPrefix'] +
            uploadedFileName.split('/').map(Uri.encodeComponent).join('/');
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateStoreInventory(String clientId, String storeId) async {
    final storeRef = FirebaseFirestore.instance
        .collection('clients')
        .doc(clientId)
        .collection('stores')
        .doc(storeId)
        .collection('materiel_installe');

    for (var system in _selectedSystems) {
      final String reference = system['reference'] ?? 'N/A';
      final String name = system['name'] ?? 'Produit Inconnu';
      final String? image = system['image'];
      final String? marque = system['marque'];
      final String? category = system['category'];
      final int quantityToAdd = system['quantity'] ?? 1;
      final List<String> newSerials =
      List<String>.from(system['serialNumbers'] ?? []);

      final query = await storeRef
          .where('reference', isEqualTo: reference)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final existingData = doc.data();
        int currentQty = existingData['quantity'] ?? 1;
        List<String> currentSerials =
        List<String>.from(existingData['serialNumbers'] ?? []);

        for (var sn in newSerials) {
          if (sn.isNotEmpty && !currentSerials.contains(sn)) {
            currentSerials.add(sn);
          }
        }

        await doc.reference.update({
          'quantity': currentQty + quantityToAdd,
          'serialNumbers': currentSerials,
          'lastInterventionDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          if (existingData['marque'] == null) 'marque': marque,
          if (existingData['category'] == null) 'category': category,
          if (existingData['imageUrl'] == null) 'imageUrl': image,
        });
      } else {
        await storeRef.add({
          'name': name,
          'reference': reference,
          'marque': marque ?? 'Non spécifié',
          'category': category ?? 'Autre',
          'imageUrl': image,
          'quantity': quantityToAdd,
          'serialNumbers': newSerials,
          'installedAt': FieldValue.serverTimestamp(),
          'lastInterventionDate': FieldValue.serverTimestamp(),
          'status': 'Opérationnel',
          'addedByInterventionId': widget.interventionDoc.id,
        });
      }
    }
  }

  // ----------------------------------------------------------------------
  // Save Report
  // ----------------------------------------------------------------------
  Future<void> _saveReport() async {
    if (_isLoading) return;

    if (_currentStatus == 'Terminé') {
      if (_selectedSystems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '⛔️ Impossible de terminer : Veuillez ajouter au moins un produit/système.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    // ✅ PREMIUM: Setup Progress Dialog Controller
    final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
    final ValueNotifier<String> statusNotifier =
    ValueNotifier("Préparation...");

    // Show Non-Dismissible Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const CircularProgressIndicator(strokeWidth: 2),
                const SizedBox(height: 20),
                ValueListenableBuilder<String>(
                  valueListenable: statusNotifier,
                  builder: (context, status, child) {
                    return Text(
                      status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    );
                  },
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (context, value, child) {
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF667EEA)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${(value * 100).toInt()}%",
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      // 1. Signature
      String? newSignatureUrl = _signatureImageUrl;
      if (_signatureController.isNotEmpty) {
        statusNotifier.value = "Envoi de la signature...";
        progressNotifier.value = 0.0;

        final creds = await _getB2UploadCredentials();
        if (creds == null) {
          throw Exception('Impossible de récupérer les accès B2.');
        }

        final png = await _signatureController.toPngBytes();
        if (png != null) {
          final String fileName =
              'signatures/interventions/${widget.interventionDoc.id}_${DateTime.now().millisecondsSinceEpoch}.png';
          final url = await _uploadBytesToB2WithProgress(
            png,
            fileName,
            creds,
                (progress) {
              progressNotifier.value = progress;
            },
          );
          if (url != null) {
            newSignatureUrl = url;
          } else {
            throw Exception('Échec du téléchargement de la signature sur B2.');
          }
        }
      }

      // 2. Media Files
      final List<String> uploaded = List<String>.from(_existingMediaUrls);
      int currentFile = 0;
      int totalFiles = _mediaFilesToUpload.length;

      for (final file in _mediaFilesToUpload) {
        currentFile++;
        statusNotifier.value = "Envoi fichier $currentFile / $totalFiles...";
        progressNotifier.value = 0.0;

        final creds = await _getB2UploadCredentials();
        if (creds == null) continue;

        final url = await _uploadFileToB2WithProgress(
          file,
          creds,
              (progress) {
            progressNotifier.value = progress;
          },
        );

        if (url != null) {
          uploaded.add(url);
        } else {
          debugPrint('Skipping file due to upload failure: ${file.name}');
        }
      }

      statusNotifier.value = "Finalisation...";
      progressNotifier.value = 1.0;

      final Map<String, dynamic> reportData = {
        'managerName': _managerNameController.text.trim(),
        'managerPhone': _managerPhoneController.text.trim(),
        'managerEmail': _managerEmailController.text.trim(),
        'diagnostic': _diagnosticController.text.trim(),
        'workDone': _workDoneController.text.trim(),
        'signatureUrl': newSignatureUrl,
        'status': _currentStatus,
        'systems': _selectedSystems,
        'systemId':
        _selectedSystems.isNotEmpty ? _selectedSystems.first['id'] : null,
        'systemName':
        _selectedSystems.isNotEmpty ? _selectedSystems.first['name'] : null,
        'systemReference': _selectedSystems.isNotEmpty
            ? _selectedSystems.first['reference']
            : null,
        'systemImage': _selectedSystems.isNotEmpty
            ? _selectedSystems.first['image']
            : null,
        'assignedTechnicians':
        _selectedTechnicians.map((t) => t.displayName).toList(),
        'assignedTechniciansIds':
        _selectedTechnicians.map((t) => t.uid).toList(),
        'mediaUrls': uploaded,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final prevStatus = (widget.interventionDoc.data() ?? {})['status'];
      if (_currentStatus == 'Clôturé' && prevStatus != 'Clôturé') {
        reportData['closedAt'] = FieldValue.serverTimestamp();
      }

      await widget.interventionDoc.reference.update(reportData);

      final String? clientId =
      (widget.interventionDoc.data() ?? {})['clientId'];
      final String? storeId = (widget.interventionDoc.data() ?? {})['storeId'];

      if (clientId != null && storeId != null) {
        await FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .collection('stores')
            .doc(storeId)
            .set({
          'contactName': _managerNameController.text.trim(),
          'contactPhone': _managerPhoneController.text.trim(),
          'contactEmail': _managerEmailController.text.trim(),
          'managerName': _managerNameController.text.trim(),
          'managerPhone': _managerPhoneController.text.trim(),
          'managerEmail': _managerEmailController.text.trim(),
        }, SetOptions(merge: true));

        if (_currentStatus == 'Terminé') {
          await _updateStoreInventory(clientId, storeId);
        }
      }

      // Close Progress Dialog
      if (mounted) Navigator.of(context).pop();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapport enregistré avec succès!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      // Close Dialog on Error
      if (mounted && _isLoading) Navigator.of(context).pop();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'enregistrement: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ----------------------------------------------------------------------
  // Download & PDF Logic
  // ----------------------------------------------------------------------
  Future<void> _downloadMedia(String? url) async {
    if (url == null || url.isEmpty) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Téléchargement en cours...')),
    );

    try {
      final String fileName = url.split('/').last.split('?').first;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Échec du téléchargement: ${response.statusCode}');
      }
      final Uint8List fileBytes = response.bodyBytes;

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: fileBytes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fichier enregistré: $fileName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de téléchargement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Uint8List?> _fetchPdfFromBackend() async {
    if (_isLoading) return null;
    setState(() => _isLoading = true);

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('exportInterventionPdf');

      final response = await callable.call<Map<String, dynamic>>(
        {'interventionId': widget.interventionDoc.id},
      );

      final String base64String = response.data['pdfBase64'];
      final Uint8List pdfBytes = base64.decode(base64String);
      return pdfBytes;
    } catch (e) {
      if (!mounted) return null;
      print('Error fetching PDF from backend: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la génération du PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, String> _generateShareContent() {
    final data = widget.interventionDoc.data() ?? {};
    final code = data['interventionCode'] ?? 'N/A';
    final clientName = data['clientName'] ?? 'Client';
    final date = DateFormat('dd MMMM yyyy', 'fr_FR').format(DateTime.now());

    return {
      'subject': '✅ Rapport d\'Intervention $code - $clientName',
      'body': '''Bonjour,
Veuillez trouver ci-joint le rapport détaillé de l'intervention technique $code.
- Client: $clientName
- Date: $date
Cordialement,
L'équipe BOITEX INFO'''
    };
  }

  Future<void> _generateAndSharePdf() async {
    final Uint8List? pdfBytes = await _fetchPdfFromBackend();
    if (pdfBytes == null || !mounted) return;

    final data = widget.interventionDoc.data() ?? {};
    final baseFileName = 'Rapport-${data['interventionCode'] ?? 'N-A'}';

    if (kIsWeb) {
      try {
        await FileSaver.instance.saveFile(
          name: baseFileName,
          bytes: pdfBytes,
          ext: 'pdf',
          mimeType: MimeType.pdf,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF téléchargé avec succès!')),
          );
        }
      } catch (e) {
        print('Web Download Error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de téléchargement: $e')),
          );
        }
      }
      return;
    }

    final fileName = '$baseFileName.pdf';
    final content = _generateShareContent();
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: content['subject'],
      text: content['body'],
    );
  }

  Future<void> _generateAndShowPdfViewer() async {
    final Uint8List? pdfBytes = await _fetchPdfFromBackend();
    if (pdfBytes == null || !mounted) return;

    final data = widget.interventionDoc.data() ?? {};
    final title = data['interventionCode'] ?? 'Aperçu';

    if (kIsWeb) {
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'Rapport-$title.pdf',
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          pdfBytes: pdfBytes,
          title: title,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    _managerEmailController.dispose();
    _diagnosticController.dispose();
    _workDoneController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // UI
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final data = widget.interventionDoc.data() ?? {};
    final createdAtTimestamp = data['createdAt'] as Timestamp?;
    final createdAt = createdAtTimestamp?.toDate() ?? DateTime.now();

    final String billingStatus = data['billingStatus'] ?? 'INCONNU';
    final String billingReason = data['billingReason'] ?? 'Non spécifié';

    Color billingColor;
    IconData billingIcon;

    if (billingStatus == 'GRATUIT') {
      billingColor = Colors.green;
      billingIcon = Icons.verified_user;
    } else if (billingStatus == 'INCLUS') {
      billingColor = Colors.teal;
      billingIcon = Icons.assignment_turned_in;
    } else if (billingStatus == 'FACTURABLE') {
      billingColor = Colors.redAccent;
      billingIcon = Icons.attach_money;
    } else {
      billingColor = Colors.grey;
      billingIcon = Icons.help_outline;
    }

    // ✅ Logic to disable editing controls
    bool disableInputs = !_isEditing || _isLoading || isArchived;

    return Theme(
      data: _interventionTheme(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "${data['interventionCode'] ?? 'Détails'} - ${data['storeName'] ?? ''}",
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            // ✅ TOGGLE: Edit / Save Mode
            if (!isArchived)
              IconButton(
                icon: Icon(_isEditing ? Icons.check : Icons.edit),
                tooltip: _isEditing ? 'Sauvegarder' : 'Modifier',
                onPressed: () {
                  if (_isEditing) {
                    _saveReport(); // Save on check
                  }
                  setState(() {
                    _isEditing = !_isEditing; // Toggle mode
                  });
                },
              ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Aperçu PDF',
              onPressed: _isLoading ? null : _generateAndShowPdfViewer,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Partager PDF',
              onPressed: _isLoading ? null : _generateAndSharePdf,
            ),
          ],
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
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (billingStatus != 'INCONNU')
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: billingColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: billingColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(billingIcon, color: Colors.white, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  billingStatus,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  billingReason,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          radius: 20,
                          child: Icon(Icons.calendar_month,
                              color: Colors.blue.shade800),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Rendez-vous planifié",
                                style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _scheduledAt != null
                                    ? DateFormat('EEEE d MMMM à HH:mm', 'fr_FR')
                                    .format(_scheduledAt!)
                                    : "Aucune date définie",
                                style: TextStyle(
                                    color: Colors.blue.shade700, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (!isArchived)
                          IconButton(
                            icon: const Icon(Icons.edit_calendar,
                                color: Color(0xFF667EEA)),
                            onPressed: _editSchedule,
                            tooltip: "Modifier le planning",
                          ),
                      ],
                    ),
                  ),

                  if (_suggestedSystemsFromHistory != null &&
                      _selectedSystems.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history, color: Color(0xFF10B981)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Systèmes détectés (Historique)",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                                Text(
                                  "${_suggestedSystemsFromHistory!.length} produit(s) trouvés",
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _applySuggestion,
                            child: const Text(
                              "IMPORTER",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857)),
                            ),
                          ),
                        ],
                      ),
                    ),

                  _buildSummaryCard(data, createdAt),
                  const SizedBox(height: 24),
                  _buildReportForm(context, disableInputs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> data, DateTime createdAt) {
    final String? clientPhone = data['clientPhone'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demandé par ${data['createdByName'] ?? 'Inconnu'}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Client: ${data['clientName'] ?? 'N/A'} - Magasin: ${data['storeName'] ?? 'N/A'}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                if (_storeLat != null && _storeLng != null)
                  IconButton(
                    icon: const Icon(Icons.directions,
                        color: Color(0xFF667EEA), size: 32),
                    tooltip: "Y aller (GPS)",
                    onPressed: _launchMaps,
                  )
                else if (_isLoadingGps)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Date de création: ${DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR').format(createdAt)}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Description du Problème:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(data['requestDescription'] ?? 'Non spécifié'),

            const SizedBox(height: 12),
            const Text('Type d\'Intervention:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(data['interventionType'] ?? 'Non spécifié'),

            if (data['equipmentName'] != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.settings_input_component,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text("Équipement: ${data['equipmentName']}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],

            if (clientPhone != null && clientPhone.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Tél Client:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              InkWell(
                onTap: () async {
                  final Uri launchUri = Uri(
                    scheme: 'tel',
                    path: clientPhone,
                  );
                  if (await canLaunchUrl(launchUri)) {
                    await launchUrl(launchUri);
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone, size: 18, color: Color(0xFF667EEA)),
                    const SizedBox(width: 8),
                    Text(
                      clientPhone,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF667EEA),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemSection() {
    // Determine if we can edit systems
    bool canEditSystems = _isEditing && !isArchived;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Systèmes / Équipements",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            if (canEditSystems)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  "${_selectedSystems.length} ajouté(s)",
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF667EEA),
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_selectedSystems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text("Aucun système sélectionné",
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ..._selectedSystems.asMap().entries.map((entry) {
            final index = entry.key;
            final system = entry.value;
            final int qty = system['quantity'] ?? 1;
            final List<String> serials =
            List<String>.from(system['serialNumbers'] ?? []);
            final int scannedCount = serials.where((s) => s.isNotEmpty).length;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(8),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: system['image'] != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      system['image'],
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(
                          Icons.inventory_2,
                          color: Colors.grey),
                    ),
                  )
                      : const Icon(Icons.inventory_2, color: Color(0xFF667EEA)),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        system['name'] ?? 'Système',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        "x$qty",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      system['reference'] ?? '',
                      style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: !canEditSystems
                          ? null
                          : () => _manageSerialNumbers(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code,
                                size: 14, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Text(
                              qty > 1
                                  ? "S/N: $scannedCount/$qty scannés"
                                  : (scannedCount > 0
                                  ? "S/N: ${serials[0]}"
                                  : "Ajouter S/N"),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: !canEditSystems
                    ? null
                    : IconButton(
                  icon:
                  const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeSystem(index),
                ),
              ),
            );
          }).toList(),

        const SizedBox(height: 8),

        if (canEditSystems)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.store),
                  label: const Text("Inventaire Magasin"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _pickFromStoreInventory,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.search_rounded),
                  label: const Text("Catalogue"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF667EEA)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _selectSystem,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  side: const BorderSide(color: Colors.black87),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _scanSystem,
                child: const Icon(Icons.qr_code_scanner_rounded),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildReportForm(BuildContext context, bool disableInputs) {
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Rapport d'Intervention",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

          const SizedBox(height: 16),
          _buildSystemSection(),

          const SizedBox(height: 16),
          TextFormField(
            controller: _managerNameController,
            readOnly: disableInputs,
            decoration:
            const InputDecoration(labelText: 'Nom du contact sur site'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _managerPhoneController,
            readOnly: disableInputs,
            keyboardType: TextInputType.phone,
            decoration:
            const InputDecoration(labelText: 'Téléphone du contact'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _managerEmailController,
            readOnly: disableInputs,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email du contact',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          MultiSelectDialogField<AppUser>(
            items: _allTechnicians
                .map((t) => MultiSelectItem(t, t.displayName))
                .toList(),
            title: const Text('Techniciens'),
            selectedColor: const Color(0xFF667EEA),
            buttonText: const Text('Techniciens Assignés'),
            onConfirm: (results) {
              if (!disableInputs) {
                setState(() => _selectedTechnicians = results);
              }
            },
            initialValue: _selectedTechnicians,
            chipDisplay: MultiSelectChipDisplay(
              onTap: (value) {
                if (!disableInputs) {
                  setState(() => _selectedTechnicians.remove(value));
                }
              },
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              borderRadius: BorderRadius.circular(20),
            ),
            dialogWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          const SizedBox(height: 16),

          // 🚀 DIAGNOSTIC SECTION: Switchable between ExpandableText and TextFormField
          disableInputs
              ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diagnostique / Panne Signalée',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                _ExpandableText(
                    text: _diagnosticController.text.isNotEmpty
                        ? _diagnosticController.text
                        : "Non spécifié"),
              ],
            ),
          )
              : TextFormField(
            controller: _diagnosticController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Diagnostique / Panne Signalée',
              alignLabelWithHint: true,
              suffixIcon: Padding(
                padding: const EdgeInsets.all(4.0),
                child: _isGeneratingDiagnostic
                    ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : IconButton(
                  icon: Icon(
                    Icons.auto_awesome,
                    color: Colors.grey.shade600,
                  ),
                  tooltip: 'Améliorer le texte par IA',
                  onPressed: () => _generateAiText(
                    aiContext: 'diagnostic',
                    controller: _diagnosticController,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 🚀 TRAVAUX EFFECTUES SECTION: Switchable between ExpandableText and TextFormField
          disableInputs
              ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Travaux Effectués',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                _ExpandableText(
                    text: _workDoneController.text.isNotEmpty
                        ? _workDoneController.text
                        : "Non spécifié"),
              ],
            ),
          )
              : TextFormField(
            controller: _workDoneController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Travaux Effectués',
              alignLabelWithHint: true,
              suffixIcon: Padding(
                padding: const EdgeInsets.all(4.0),
                child: _isGeneratingWorkDone
                    ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : IconButton(
                  icon: Icon(
                    Icons.auto_awesome,
                    color: Colors.grey.shade600,
                  ),
                  tooltip: 'Améliorer le texte par IA',
                  onPressed: () => _generateAiText(
                    aiContext: 'workDone',
                    controller: _workDoneController,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          _buildMediaSection(disableInputs),
          const SizedBox(height: 24),
          const Text('Signature du Client',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_signatureImageUrl != null && _signatureController.isEmpty)
            Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFFF1F5F9),
              ),
              child: Center(
                  child:
                  Image.network(_signatureImageUrl!, fit: BoxFit.contain)),
            )
          else if (!disableInputs)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Signature(
                controller: _signatureController,
                height: 150,
                backgroundColor: const Color(0xFFF1F5F9),
              ),
            ),
          if (!disableInputs)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _signatureController.clear();
                  setState(() => _signatureImageUrl = null);
                },
                child: const Text('Effacer la signature'),
              ),
            ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _currentStatus,
            items: statusOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged:
            disableInputs ? null : (v) => setState(() => _currentStatus = v!),
            decoration:
            const InputDecoration(labelText: "Statut de l'intervention"),
          ),
          const SizedBox(height: 24),
          if (!disableInputs)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveReport,
                child: _isLoading
                    ? const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3)
                    : const Text('Enregistrer le Rapport'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaSection(bool disableInputs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photos & Vidéos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_existingMediaUrls.isEmpty && _mediaFilesToUpload.isEmpty)
          const Text('Aucun fichier ajouté.',
              style: TextStyle(color: Colors.grey)),
        // Existing
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _existingMediaUrls
              .map((url) =>
              _buildMediaThumbnail(url: url, canRemove: !disableInputs))
              .toList(),
        ),
        // Pending
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _mediaFilesToUpload
              .map((file) =>
              _buildMediaThumbnail(file: file, canRemove: !disableInputs))
              .toList(),
        ),
        const SizedBox(height: 16),
        if (!disableInputs)
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Ajouter Photos/Vidéos'),
              onPressed: _pickMedia,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF667EEA),
                side: const BorderSide(color: Color(0xFF667EEA)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaThumbnail(
      {String? url, XFile? file, required bool canRemove}) {
    final bool isVideo = (url != null && _isVideoPath(url)) ||
        (file != null && _isVideoPath(file.path));
    final bool isPdf = (url != null && url.toLowerCase().endsWith('.pdf')) ||
        (file != null && file.path.toLowerCase().endsWith('.pdf'));

    Widget content;
    if (file != null) {
      if (isVideo) {
        content = FutureBuilder<Uint8List?>(
          future: VideoThumbnail.thumbnailData(
            video: file.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 100,
            quality: 30,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasData && snapshot.data != null) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(snapshot.data!,
                    width: 100, height: 100, fit: BoxFit.cover),
              );
            }
            return const Center(
                child: Icon(Icons.videocam, size: 40, color: Colors.black54));
          },
        );
      } else {
        content = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isPdf
              ? const Icon(Icons.picture_as_pdf, size: 40, color: Colors.red)
              : Image.file(
            File(file.path),
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => const Icon(Icons.insert_drive_file,
                size: 40, color: Colors.blue),
          ),
        );
      }
    } else if (url != null && url.isNotEmpty) {
      if (isPdf) {
        content = const Center(
            child: Icon(Icons.picture_as_pdf, size: 40, color: Colors.red));
      } else if (isVideo) {
        content = FutureBuilder<Uint8List?>(
          future: VideoThumbnail.thumbnailData(
            video: url,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 100,
            quality: 30,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasData && snapshot.data != null) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(snapshot.data!,
                    width: 100, height: 100, fit: BoxFit.cover),
              );
            }
            return const Center(
                child: Icon(Icons.videocam, size: 40, color: Colors.black54));
          },
        );
      } else {
        content = Hero(
          tag: url,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              loadingBuilder: (c, child, prog) => prog == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (c, e, s) =>
              const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
      }
    } else {
      content = const Icon(Icons.image_not_supported, color: Colors.grey);
    }

    return GestureDetector(
      onTap: () async {
        if (url == null || url.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Veuillez d\'abord enregistrer pour voir ce fichier.')),
          );
          return;
        }
        if (isPdf) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else if (isVideo) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => VideoPlayerPage(videoUrl: url)));
        } else {
          final images = _existingMediaUrls
              .where(
                  (u) => !_isVideoPath(u) && !u.toLowerCase().endsWith('.pdf'))
              .toList();
          if (images.isEmpty) return;
          final initial = images.indexOf(url);
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ImageGalleryPage(
                imageUrls: images, initialIndex: initial != -1 ? initial : 0),
          ));
        }
      },
      onLongPress: (file != null) ? null : () => _downloadMedia(url),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          color: const Color(0xFFF1F5F9),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: content),
            if (isVideo && !isPdf)
              const Center(
                  child: Icon(Icons.play_circle_fill,
                      color: Colors.white, size: 30)),
            if (canRemove && file != null)
              Positioned(
                top: -10,
                right: -10,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  onPressed: () =>
                      setState(() => _mediaFilesToUpload.remove(file)),
                ),
              ),
            if (canRemove && url != null)
              Positioned(
                top: -10,
                right: -10,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  onPressed: () =>
                      setState(() => _existingMediaUrls.remove(url)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 🚀 WIDGET: EXPANDABLE TEXT ("READ MORE")
// =============================================================================
class _ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;

  const _ExpandableText({
    // ignore: unused_element
    super.key,
    required this.text,
    this.maxLines = 4, // Default to 4 lines
  });

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(
          text: widget.text,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        );

        final tp = TextPainter(
          text: span,
          textDirection: ui.TextDirection.ltr,
          maxLines: widget.maxLines,
        );

        tp.layout(maxWidth: constraints.maxWidth);

        if (!tp.didExceedMaxLines) {
          return Text(
            widget.text,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedCrossFade(
              firstChild: Text(
                widget.text,
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              secondChild: Text(
                widget.text,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Text(
                _isExpanded ? "Voir moins" : "Voir plus...",
                style: const TextStyle(
                  color: Color(0xFF667EEA),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
// lib/screens/service_technique/installation_report_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'package:url_launcher/url_launcher.dart';
// ✅ ADDED: Import for MultiSelect
import 'package:multi_select_flutter/multi_select_flutter.dart';

// Imports for B2 Upload
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import 'package:video_thumbnail/video_thumbnail.dart';

// Imports for product search & scan
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';
import 'package:boitex_info_app/screens/administration/product_scanner_page.dart';

class InstallationReportPage extends StatefulWidget {
  final String installationId;
  const InstallationReportPage({super.key, required this.installationId});

  @override
  State<InstallationReportPage> createState() => _InstallationReportPageState();
}

class _InstallationReportPageState extends State<InstallationReportPage> {
  DocumentSnapshot? _installationDoc;
  bool _isLoadingData = true;
  bool _isSaving = false;

  // ✅ NEW: Service Type State
  String _serviceType = 'Service Technique';

  final _notesController = TextEditingController();
  final _emailController = TextEditingController();
  final _signatoryNameController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<XFile> _mediaFilesToUpload = [];
  List<String> _existingMediaUrls = [];

  // Fulfillment State
  List<Map<String, dynamic>> _installedSystems = [];

  // State for Technicians Selection
  List<Map<String, dynamic>> _availableTechnicians = [];
  List<String> _selectedTechnicianIds = [];

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  static const int _maxFileSizeInBytes = 50 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _fetchTechnicians();
    _fetchInstallationDetails();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _emailController.dispose();
    _signatoryNameController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _fetchTechnicians() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();

      final techs = snapshot.docs.map((doc) {
        final data = doc.data();
        String name = data['displayName'] ?? '';
        if (name.isEmpty && data['firstName'] != null && data['lastName'] != null) {
          name = "${data['firstName']} ${data['lastName']}";
        }
        if (name.isEmpty) name = data['name'] ?? '';
        if (name.isEmpty) name = data['email'] ?? 'Inconnu';

        return {
          'id': doc.id,
          'name': name,
          'role': data['role'] ?? '',
        };
      }).where((t) {
        final role = t['role'] as String;
        return role != 'PDG';
      }).toList();

      if (mounted) {
        setState(() {
          _availableTechnicians = techs;
        });
      }
    } catch (e) {
      print("Error fetching technicians: $e");
    }
  }

  Future<void> _fetchInstallationDetails() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('installations')
          .doc(widget.installationId)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;

        // ✅ FETCH SERVICE TYPE
        final String type = data['serviceType'] ?? 'Service Technique';

        List<Map<String, dynamic>> initialSystems = [];

        if (data['systems'] != null && (data['systems'] as List).isNotEmpty) {
          initialSystems = List<Map<String, dynamic>>.from(data['systems']);
        } else if (data['orderedProducts'] != null) {
          final orders = List<Map<String, dynamic>>.from(data['orderedProducts']);

          initialSystems = orders.map((o) {
            final int qty = o['quantity'] is int ? o['quantity'] : int.tryParse(o['quantity'].toString()) ?? 1;
            return {
              'id': o['productId'] ?? o['id'] ?? '',
              'name': o['productName'] ?? o['name'] ?? 'Produit Inconnu',
              'reference': o['reference'] ?? 'N/A',
              'marque': o['brand'] ?? o['marque'] ?? 'N/A',
              'category': o['category'] ?? 'N/A',
              'image': o['imageUrl'] ?? o['image'],
              'quantity': qty,
              'serialNumbers': List<String>.filled(qty, ''),

              // ✅ NEW: Initialize IT fields if needed
              'ipAddresses': List<String>.filled(qty, ''),
              'macAddresses': List<String>.filled(qty, ''),
              'portNumbers': List<String>.filled(qty, ''),
            };
          }).toList();
        }

        List<String> loadedTechIds = [];
        if (data['assignedTechnicians'] != null) {
          final rawTechs = data['assignedTechnicians'] as List;
          if (rawTechs.isNotEmpty) {
            if (rawTechs.first is Map) {
              loadedTechIds = rawTechs.map((t) => t['uid'] as String).toList();
            } else if (rawTechs.first is String) {
              loadedTechIds = List<String>.from(rawTechs);
            }
          }
        }

        setState(() {
          _installationDoc = snapshot;
          _serviceType = type; // ✅ Set Service Type
          _notesController.text = data['notes'] ?? '';
          _emailController.text = data['clientEmail'] ?? '';
          _signatoryNameController.text = data['signatoryName'] ?? data['contactName'] ?? '';
          _existingMediaUrls =
          List<String>.from(data['mediaUrls'] ?? data['photoUrls'] ?? []);
          _installedSystems = initialSystems;
          _selectedTechnicianIds = loadedTechIds;
          _isLoadingData = false;
        });
      } else {
        setState(() => _isLoadingData = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Installation non trouvée.')));
      }
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  // ------------------------------------------------------------------------
  // SECTION: PRODUCT & SERIAL NUMBER LOGIC
  // ------------------------------------------------------------------------

  Future<int> _requestQuantity() async {
    int qty = 1;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Quantité Installée"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Combien d'unités avez-vous installé ?"),
            const SizedBox(height: 16),
            TextFormField(
              autofocus: true,
              initialValue: "1",
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF667EEA)),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => qty = int.tryParse(v) ?? 1,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
        ],
      ),
    );
    return qty > 0 ? qty : 1;
  }

  Future<void> _addProduct(bool isScan) async {
    Map<String, dynamic>? productData;
    String? productId;

    if (isScan) {
      final code = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductScannerPage()));
      if (code == null) return;

      final query = await FirebaseFirestore.instance.collection('produits').where('reference', isEqualTo: code).limit(1).get();
      if (query.docs.isNotEmpty) {
        productData = query.docs.first.data();
        productId = query.docs.first.id;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Produit introuvable: $code")));
        return;
      }
    } else {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalProductSearchPage(isSelectionMode: true)));
      if (result != null && result is DocumentSnapshot) {
        productData = result.data() as Map<String, dynamic>;
        productId = result.id;
      }
    }

    if (productData != null && mounted) {
      int qty = await _requestQuantity();
      final images = (productData['imageUrls'] as List?)?.cast<String>() ?? [];

      setState(() {
        _installedSystems.add({
          'id': productId,
          'name': productData!['nom'] ?? 'Produit',
          'reference': productData['reference'] ?? 'N/A',
          'marque': productData['marque'],
          'category': productData['categorie'],
          'image': images.isNotEmpty ? images.first : null,
          'quantity': qty,
          'serialNumbers': List<String>.filled(qty, ''),
          // ✅ Initialize IT fields
          'ipAddresses': List<String>.filled(qty, ''),
          'macAddresses': List<String>.filled(qty, ''),
          'portNumbers': List<String>.filled(qty, ''),
        });
      });
    }
  }

  // ✅ UPDATED: Edit Logic to support IT Fields
  Future<void> _manageSystemDetails(int index) async {
    final system = _installedSystems[index];
    final int qty = system['quantity'] ?? 1;
    final bool isIT = _serviceType == 'Service IT';

    // Helper to resize lists safely
    List<String> resizeList(List<dynamic>? input, int size) {
      final list = input != null ? List<String>.from(input) : <String>[];
      if (list.length < size) {
        list.addAll(List.filled(size - list.length, ''));
      } else {
        return list.sublist(0, size);
      }
      return list;
    }

    // Load current values
    List<String> serials = resizeList(system['serialNumbers'], qty);
    List<String> ips = resizeList(system['ipAddresses'], qty);
    List<String> macs = resizeList(system['macAddresses'], qty);
    List<String> ports = resizeList(system['portNumbers'], qty);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(isIT ? "Config IT (${system['name']})" : "S/N (${system['name']})"),
            content: SizedBox(
              width: double.maxFinite,
              height: 400, // Taller dialog for IT
              child: Column(
                children: [
                  Text(isIT
                      ? "Saisissez les adresses IP, MAC et Ports."
                      : "Saisissez ou scannez les numéros de série.",
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: qty,
                      itemBuilder: (context, i) {
                        return Card(
                          elevation: 0,
                          color: Colors.grey.shade50,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Unité #${i + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                const SizedBox(height: 8),

                                // SERIAL NUMBER (Common)
                                TextFormField(
                                  initialValue: serials[i],
                                  decoration: InputDecoration(
                                    labelText: "Numéro de Série",
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                                      onPressed: () async {
                                        final scanned = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductScannerPage()));
                                        if (scanned != null) {
                                          setStateDialog(() => serials[i] = scanned);
                                        }
                                      },
                                    ),
                                  ),
                                  onChanged: (val) => serials[i] = val,
                                ),

                                // ✅ IT SPECIFIC FIELDS
                                if (isIT) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: ips[i],
                                          decoration: const InputDecoration(labelText: "IP (ex: 192.168.1.10)", isDense: true, border: OutlineInputBorder()),
                                          onChanged: (val) => ips[i] = val,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: ports[i],
                                          decoration: const InputDecoration(labelText: "Port (ex: 8080)", isDense: true, border: OutlineInputBorder()),
                                          onChanged: (val) => ports[i] = val,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: macs[i],
                                    decoration: const InputDecoration(labelText: "Adresse MAC", isDense: true, border: OutlineInputBorder()),
                                    onChanged: (val) => macs[i] = val,
                                  ),
                                ]
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _installedSystems[index]['serialNumbers'] = serials;
                    if (isIT) {
                      _installedSystems[index]['ipAddresses'] = ips;
                      _installedSystems[index]['macAddresses'] = macs;
                      _installedSystems[index]['portNumbers'] = ports;
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: const Text("Valider"),
              ),
            ],
          );
        });
      },
    );
  }

  // Pick media with file size check
  Future<void> _pickMedia() async {
    final List<XFile> pickedFiles = await _picker.pickMultipleMedia();
    if (pickedFiles.isEmpty) return;

    final List<XFile> validFiles = [];
    final List<String> rejectedFiles = [];

    for (final file in pickedFiles) {
      final int fileSize = await file.length();
      final bool isVideo = _isVideoUrl(file.name);

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

  // --- B2 UPLOAD LOGIC (Unchanged) ---
  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response =
      await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to get B2 credentials: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error calling Cloud Function: $e');
      return null;
    }
  }

  Future<String?> _uploadFileToB2(
      XFile file, Map<String, dynamic> b2Credentials) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final Uri uploadUri = Uri.parse(b2Credentials['uploadUrl']);
      final String fileName = file.name.split('/').last;

      final response = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Credentials['authorizationToken'],
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': file.mimeType ?? 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        return b2Credentials['downloadUrlPrefix'] +
            (responseBody['fileName'] as String)
                .split('/')
                .map(Uri.encodeComponent)
                .join('/');
      } else {
        print('Failed to upload to B2: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading file to B2: $e');
      return null;
    }
  }
  // --- END B2 UPLOAD ---

  Future<void> _saveReport() async {
    if (_isSaving) return;

    if (_installedSystems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez ajouter au moins un équipement installé."), backgroundColor: Colors.red));
      return;
    }

    if (_signatoryNameController.text.trim().isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nom Requis'),
          content: const Text(
              'Veuillez indiquer le nom de la personne responsable (signataire) sur site.'
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Email Obligatoire'),
          content: const Text(
              'L\'email du client est requis pour l\'envoi automatique du rapport PDF.\n\nVeuillez demander l\'email au responsable sur site.'
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('OK, je vais le remplir'),
            ),
          ],
        ),
      );
      return;
    }

    if (!_emailController.text.contains('@') || !_emailController.text.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Format d'email invalide."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      String? signatureUrl;

      if (signatureBytes != null) {
        final storageRef = FirebaseStorage.instance.ref().child(
            'signatures/installations/${widget.installationId}_${DateTime.now().millisecondsSinceEpoch}.png');
        final uploadTask = storageRef.putData(signatureBytes);
        final snapshot = await uploadTask.whenComplete(() => {});
        signatureUrl = await snapshot.ref.getDownloadURL();
      }

      List<String> uploadedMediaUrls = List.from(_existingMediaUrls);
      for (XFile file in _mediaFilesToUpload) {
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) {
          throw Exception('Could not get B2 upload credentials.');
        }
        final downloadUrl = await _uploadFileToB2(file, b2Credentials);
        if (downloadUrl != null) {
          uploadedMediaUrls.add(downloadUrl);
        } else {
          print('Skipping file due to upload failure: ${file.name}');
        }
      }

      final selectedNames = _availableTechnicians
          .where((t) => _selectedTechnicianIds.contains(t['id']))
          .map((t) => t['name'] as String)
          .toList();

      await FirebaseFirestore.instance
          .collection('installations')
          .doc(widget.installationId)
          .update({
        'status': 'Terminée',
        'notes': _notesController.text,
        'clientEmail': _emailController.text.trim(),
        'signatoryName': _signatoryNameController.text.trim(),
        'contactName': _signatoryNameController.text.trim(),
        'signatureUrl': signatureUrl,
        'mediaUrls': uploadedMediaUrls,
        'photoUrls': FieldValue.delete(),
        'systems': _installedSystems,
        'assignedTechnicians': _selectedTechnicianIds,
        'assignedTechnicianNames': selectedNames,
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rapport enregistré et inventaire mis à jour !')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
          appBar: AppBar(title: const Text('Rapport d\'Installation')),
          body: const Center(child: CircularProgressIndicator()));
    }

    final data = _installationDoc?.data() as Map<String, dynamic>?;
    final clientName = data?['clientName'] ?? 'N/A';
    final storeName = data?['storeName'] ?? 'N/A';
    final storeLocation = data?['storeLocation'] ?? 'Localisation inconnue';
    final bool isReadOnly = data?['status'] == 'Terminée';

    String technicianNames = "Non assigné";
    final techs = data?['assignedTechnicians'];
    if (techs != null && techs is List && techs.isNotEmpty) {
      if (techs.first is Map) {
        technicianNames = techs.map((t) => t['displayName']).join(", ");
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport d\'Installation'),
        backgroundColor: const Color(0xFF667EEA),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.business, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          clientName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.store, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(storeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(storeLocation, style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.people, color: Colors.teal, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Techs: $technicianNames",
                          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.teal),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text("Correction / Ajout Techniciens :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            AbsorbPointer(
              absorbing: isReadOnly,
              child: MultiSelectDialogField(
                items: _availableTechnicians.map((e) => MultiSelectItem(e['id'], e['name'])).toList(),
                title: const Text("Sélectionner Techniciens"),
                selectedColor: Colors.blue,
                decoration: BoxDecoration(
                  color: isReadOnly ? Colors.grey.shade100 : Colors.blue.withOpacity(0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(color: isReadOnly ? Colors.grey : Colors.blue, width: 2),
                ),
                buttonIcon: Icon(Icons.group_add, color: isReadOnly ? Colors.grey : Colors.blue),
                buttonText: Text(
                  _selectedTechnicianIds.isEmpty
                      ? "Choisir les techniciens..."
                      : "${_selectedTechnicianIds.length} Technicien(s) sélectionné(s)",
                  style: TextStyle(
                    color: isReadOnly ? Colors.grey[600] : Colors.blue[800],
                    fontSize: 16,
                  ),
                ),
                initialValue: _selectedTechnicianIds,
                onConfirm: (results) {
                  setState(() {
                    _selectedTechnicianIds = results.cast<String>();
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            _buildSystemsList(isReadOnly),

            const SizedBox(height: 24),
            TextField(
              controller: _notesController,
              readOnly: isReadOnly,
              decoration: const InputDecoration(
                labelText: 'Notes d\'installation',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 24),

            _buildMediaSection(isReadOnly),

            const SizedBox(height: 24),

            TextField(
              controller: _signatoryNameController,
              readOnly: isReadOnly,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nom du Responsable / Signataire *',
                hintText: 'Personne présente sur site',
                prefixIcon: const Icon(Icons.person_pin_circle_outlined, color: Colors.blue),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 1.5),
                ),
                suffixIcon: isReadOnly
                    ? null
                    : const Tooltip(
                  message: "Le nom de la personne qui signe le rapport.",
                  child: Icon(Icons.info_outline, color: Colors.orange),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _emailController,
              readOnly: isReadOnly,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email du Client * (Obligatoire)',
                hintText: 'Pour l\'envoi automatique du PDF',
                prefixIcon: const Icon(Icons.email, color: Colors.blue),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 1.5),
                ),
                suffixIcon: isReadOnly
                    ? null
                    : const Tooltip(
                  message: "Ce champ est requis pour envoyer le rapport.",
                  child: Icon(Icons.info_outline, color: Colors.orange),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Signature du Client',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (!isReadOnly)
                  TextButton(
                      child: const Text('Effacer'),
                      onPressed: () => _signatureController.clear())
              ],
            ),
            const SizedBox(height: 8),

            _buildSignatureSection(isReadOnly, data?['signatureUrl']),

            const SizedBox(height: 32),
            if (_isSaving)
              const Center(child: CircularProgressIndicator())
            else if (!isReadOnly)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveReport,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Terminer l\'Installation'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemsList(bool isReadOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ✅ Display context-aware title
            Text(_serviceType == 'Service IT' ? "Config IT & Matériel" : "Matériel Installé", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (!isReadOnly)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.black87),
                    onPressed: () => _addProduct(true),
                    tooltip: "Scanner produit",
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF667EEA)),
                    onPressed: () => _addProduct(false),
                    tooltip: "Chercher catalogue",
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_installedSystems.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 40, color: Colors.blue),
                const SizedBox(height: 8),
                const Text("Liste vide.", style: TextStyle(color: Colors.blue)),
                if (!isReadOnly)
                  const Text("Ajoutez des produits ou vérifiez la commande.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          )
        else
          ..._installedSystems.asMap().entries.map((entry) {
            final index = entry.key;
            final system = entry.value;
            final qty = system['quantity'];

            // Check completeness based on service type
            final serials = (system['serialNumbers'] as List).where((s) => s.toString().isNotEmpty).length;
            bool isComplete = serials == qty;

            // For IT, also check IP if needed (simplified check)
            if (_serviceType == 'Service IT') {
              // You can add stricter checks here for IP validity
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: isComplete ? Colors.green.shade100 : Colors.orange.shade100,
                  child: Icon(isComplete ? Icons.check : (_serviceType == 'Service IT' ? Icons.settings_ethernet : Icons.qr_code), color: isComplete ? Colors.green : Colors.orange),
                ),
                title: Text(system['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Reference: ${system['reference'] ?? 'N/A'}"),
                    const SizedBox(height: 4),
                    Text("Qté: $qty | Config: $serials/$qty", style: TextStyle(color: isComplete ? Colors.green : Colors.black87)),
                    if (!isComplete)
                      Text(_serviceType == 'Service IT' ? "Touchez pour configurer IP/Port" : "Touchez pour scanner les S/N", style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: isReadOnly ? null : IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: () => setState(() => _installedSystems.removeAt(index))),
                // ✅ UPDATED: Call new management dialog
                onTap: isReadOnly ? null : () => _manageSystemDetails(index),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildMediaSection(bool isReadOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photos & Vidéos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_existingMediaUrls.isEmpty && _mediaFilesToUpload.isEmpty)
          const Text('Aucun fichier ajouté.',
              style: TextStyle(color: Colors.grey)),

        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: _existingMediaUrls
              .asMap()
              .map((index, url) => MapEntry(
            index,
            _buildMediaThumbnail(
              url: url,
              isReadOnly: isReadOnly,
              onTap: () => _openMedia(url),
            ),
          ))
              .values
              .toList(),
        ),

        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: _mediaFilesToUpload
              .map((file) => _buildMediaThumbnail(
            file: file,
            isReadOnly: isReadOnly,
          ))
              .toList(),
        ),

        const SizedBox(height: 16),
        if (!isReadOnly)
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Ajouter Photos/Vidéos'),
              onPressed: _pickMedia,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }

  bool _isVideoUrl(String path) {
    final lowercasePath = path.toLowerCase();
    return lowercasePath.endsWith('.mp4') ||
        lowercasePath.endsWith('.mov') ||
        lowercasePath.endsWith('.avi') ||
        lowercasePath.endsWith('.mkv');
  }

  void _openMedia(String url) {
    if (_isVideoUrl(url)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(videoUrl: url),
        ),
      );
    } else {
      final List<String> imageLinks =
      _existingMediaUrls.where((link) => !_isVideoUrl(link)).toList();
      final int initialIndex = imageLinks.indexOf(url);
      if (imageLinks.isEmpty) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImageGalleryPage(
            imageUrls: imageLinks,
            initialIndex: (initialIndex != -1) ? initialIndex : 0,
          ),
        ),
      );
    }
  }

  Widget _buildMediaThumbnail({
    String? url,
    XFile? file,
    required bool isReadOnly,
    VoidCallback? onTap,
  }) {
    bool isVideo = (url != null && _isVideoUrl(url)) || (file != null && _isVideoUrl(file.path));
    Widget mediaContent;

    if (file != null) {
      if (isVideo) {
        mediaContent = FutureBuilder<Uint8List?>(
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
                borderRadius: BorderRadius.circular(11),
                child: Image.memory(
                  snapshot.data!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              );
            }
            return const Center(
                child: Icon(Icons.videocam, size: 40, color: Colors.black54));
          },
        );
      } else {
        mediaContent = ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.file(File(file.path),
              width: 100, height: 100, fit: BoxFit.cover),
        );
      }
    } else if (url != null && url.isNotEmpty) {
      if (isVideo) {
        mediaContent = FutureBuilder<Uint8List?>(
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
                borderRadius: BorderRadius.circular(11),
                child: Image.memory(
                  snapshot.data!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              );
            }
            return const Center(
                child: Icon(Icons.videocam, size: 40, color: Colors.black54));
          },
        );
      } else {
        mediaContent = Hero(
          tag: url,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.network(
              url,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
              progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
      }
    } else {
      mediaContent = const Icon(Icons.image_not_supported, color: Colors.grey);
    }

    return GestureDetector(
      onTap: (onTap != null)
          ? onTap
          : () {
        if (file != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Veuillez d\'abord enregistrer pour voir ce fichier.')),
          );
        }
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade200,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            mediaContent,
            if (!isReadOnly && file != null)
              Positioned(
                top: -10,
                right: -10,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  onPressed: () {
                    setState(() {
                      _mediaFilesToUpload.remove(file);
                    });
                  },
                ),
              ),
            if (!isReadOnly && url != null)
              Positioned(
                top: -10,
                right: -10,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  onPressed: () {
                    setState(() {
                      _existingMediaUrls.remove(url);
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureSection(bool isReadOnly, String? signatureUrl) {
    if (isReadOnly && signatureUrl != null) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Image.network(
            signatureUrl,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (context, error, stackTrace) =>
            const Text('Impossible de charger la signature'),
          ),
        ),
      );
    } else {
      return Container(
        height: 150,
        decoration:
        BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
        child: Signature(
            controller: _signatureController,
            backgroundColor: Colors.grey[200]!),
      );
    }
  }
}
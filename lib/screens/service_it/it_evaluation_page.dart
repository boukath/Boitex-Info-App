// lib/screens/service_it/it_evaluation_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:boitex_info_app/models/it_evaluation_data.dart';
import 'package:flutter/services.dart'; // Needed for number input
import 'package:path/path.dart' as path;

// ✅ ADDED: Imports for Backblaze B2 upload
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ItEvaluationPage extends StatefulWidget {
  final String projectId;
  const ItEvaluationPage({super.key, required this.projectId});

  @override
  State<ItEvaluationPage> createState() => _ItEvaluationPageState();
}

class _ItEvaluationPageState extends State<ItEvaluationPage> {
  // Use our new data model
  final ItEvaluationData _evaluationData = ItEvaluationData();
  bool _isLoading = false;
  static const Color primaryColor = Colors.blue; // IT Service theme color
  final OutlineInputBorder defaultBorder = OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12.0));

  // ✅ ADDED: B2 Cloud Function URL constant (cloned from technical_evaluation_page.dart)
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl';

  @override
  void dispose() {
    _evaluationData.dispose();
    super.dispose();
  }

  // ✅ --- START: Endpoint list helpers ---
  void _addTpv() {
    setState(() {
      _evaluationData.tpvList.add(
          EndpointData(name: 'TPV #${_evaluationData.tpvList.length + 1}')
      );
    });
  }
  void _removeTpv(int index) {
    _evaluationData.tpvList[index].dispose();
    setState(() {
      _evaluationData.tpvList.removeAt(index);
    });
  }
  void _addPrinter() {
    setState(() {
      _evaluationData.printerList.add(
          EndpointData(name: 'Imprimante #${_evaluationData.printerList.length + 1}')
      );
    });
  }
  void _removePrinter(int index) {
    _evaluationData.printerList[index].dispose();
    setState(() {
      _evaluationData.printerList.removeAt(index);
    });
  }
  void _addKiosk() {
    setState(() {
      _evaluationData.kioskList.add(
          EndpointData(name: 'Borne #${_evaluationData.kioskList.length + 1}')
      );
    });
  }
  void _removeKiosk(int index) {
    _evaluationData.kioskList[index].dispose();
    setState(() {
      _evaluationData.kioskList.removeAt(index);
    });
  }
  void _addScreen() {
    setState(() {
      _evaluationData.screenList.add(
          EndpointData(name: 'Écran #${_evaluationData.screenList.length + 1}')
      );
    });
  }
  void _removeScreen(int index) {
    _evaluationData.screenList[index].dispose();
    setState(() {
      _evaluationData.screenList.removeAt(index);
    });
  }
  // ✅ --- END: Endpoint list helpers ---

  // ✅ --- START: New Client Hardware list helpers ---
  void _addClientDevice() {
    setState(() {
      _evaluationData.clientDeviceList.add(ClientDeviceData());
    });
  }
  void _removeClientDevice(int index) {
    _evaluationData.clientDeviceList[index].dispose();
    setState(() {
      _evaluationData.clientDeviceList.removeAt(index);
    });
  }
  // ✅ --- END: New Client Hardware list helpers ---


  // ✅ --- START: ADDED B2 HELPER FUNCTIONS (cloned from technical_evaluation_page.dart) ---

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

  // ✅ MODIFIED: This version is adapted for it_evaluation
  Future<String?> _uploadFileToB2(
      File file,
      Map<String, dynamic> b2Creds, {
        required String projectId,
      }) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();

      // --- Start: Logic from original it_evaluation_data.dart ---
      final originalFileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';

      // This is the B2-compatible file name (which is the full path)
      // This path is based on your *original* Firebase Storage path
      final String b2FileName =
          'it_evaluations/$projectId/$originalFileName';
      // --- End: Logic from original it_evaluation_data.dart ---

      // Determine mime type
      final String extension = path.extension(file.path).toLowerCase();
      String mimeType = 'b2/x-auto'; // Default
      if (extension == '.jpg' || extension == '.jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == '.png') {
        mimeType = 'image/png';
      }

      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(b2FileName), // Use the full path
          'Content-Type': mimeType,
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
  // ✅ --- END: ADDED B2 HELPER FUNCTIONS ---


  // ✅ CHANGED: Added file size check
  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null) {
      // ✅ ADDED: File size check
      const maxFileSize = 50 * 1024 * 1024; // 50 MB
      final validFiles = result.files.where((file) {
        if (file.path != null && File(file.path!).existsSync()) {
          return File(file.path!).lengthSync() <= maxFileSize;
        }
        return false;
      }).toList();

      final rejectedCount = result.files.length - validFiles.length;

      setState(() {
        _evaluationData.photos.addAll(
          validFiles.map((f) => File(f.path!)).toList(),
        );
      });

      if (rejectedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$rejectedCount image(s) dépassent la limite de 50 Mo.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // ✅ CHANGED: This function now orchestrates the B2 upload
  Future<void> _saveEvaluation() async {
    setState(() { _isLoading = true; });

    // ✅ ADDED: Get B2 credentials ONCE.
    final b2Credentials = await _getB2UploadCredentials();
    if (b2Credentials == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Impossible de contacter le service d\'upload.'), backgroundColor: Colors.red),
        );
        setState(() { _isLoading = false; });
      }
      return;
    }

    try {
      // 1. Get the non-file data from the model
      final evaluationMap = _evaluationData.getDataMap();

      // 2. Upload photos for this evaluation to B2
      final List<String> photoUrls = [];
      for (final file in _evaluationData.photos) {
        final String? downloadUrl = await _uploadFileToB2(
          file,
          b2Credentials,
          projectId: widget.projectId,
        );
        if (downloadUrl != null) {
          photoUrls.add(downloadUrl);
        } else {
          debugPrint('Failed to upload file: ${path.basename(file.path)}');
          // Optionally throw an error or show a snackbar for the failed file
        }
      }

      // 3. Add the uploaded URLs to the map
      evaluationMap['photos'] = photoUrls;

      // 4. Save the final map to Firestore
      await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
        'it_evaluation': evaluationMap,
        'status': 'Évaluation IT Terminé',
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Évaluation IT'),
        backgroundColor: primaryColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildFormCard(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0,-4))],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveEvaluation,
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Enregistrer l\'Évaluation IT'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Relevé Site IT', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
            const Divider(height: 24),

            // Section: Réseau Existant
            _buildExpansionSection(
              title: 'Réseau Existant',
              icon: Icons.network_check,
              child: Column(
                children: [
                  _buildYesNoQuestion(
                    question: 'Un réseau est-il déjà installé ?',
                    value: _evaluationData.networkExists,
                    onChanged: (val) => setState(() => _evaluationData.networkExists = val),
                  ),
                  if (_evaluationData.networkExists == true)
                    _buildYesNoQuestion(
                      question: 'Installation multi-étages ?',
                      value: _evaluationData.isMultiFloor,
                      onChanged: (val) => setState(() => _evaluationData.isMultiFloor = val),
                    ),
                  _buildConditionalTextField(
                    controller: _evaluationData.networkNotesController,
                    labelText: 'Notes sur le réseau (type, âge...)',
                  ),
                ],
              ),
            ),

            // Section: Environnement
            _buildExpansionSection(
              title: 'Environnement',
              icon: Icons.warning_amber_rounded,
              child: Column(
                children: [
                  _buildYesNoQuestion(
                    question: 'Courant haute tension à proximité ?',
                    value: _evaluationData.hasHighVoltage,
                    onChanged: (val) => setState(() => _evaluationData.hasHighVoltage = val),
                  ),
                  _buildConditionalTextField(
                      controller: _evaluationData.highVoltageNotesController,
                      labelText: 'Décrire (moteurs, lignes...)'
                  ),
                ],
              ),
            ),

            // Section: Baie de Brassage
            _buildExpansionSection(
              title: 'Baie de Brassage / Local Tech.',
              icon: Icons.dns,
              child: Column(
                children: [
                  _buildYesNoQuestion(
                    question: 'Baie de brassage présente ?',
                    value: _evaluationData.hasNetworkRack,
                    onChanged: (val) => setState(() => _evaluationData.hasNetworkRack = val),
                  ),
                  if (_evaluationData.hasNetworkRack == true) ...[
                    _buildConditionalTextField(
                        controller: _evaluationData.rackLocationController,
                        labelText: 'Emplacement de la baie'
                    ),
                    _buildYesNoQuestion(
                      question: 'Espace disponible dans la baie ?',
                      value: _evaluationData.hasRackSpace,
                      onChanged: (val) => setState(() => _evaluationData.hasRackSpace = val),
                    ),
                    _buildYesNoQuestion(
                      question: 'Onduleur (UPS) présent ?',
                      value: _evaluationData.hasUPS,
                      onChanged: (val) => setState(() => _evaluationData.hasUPS = val),
                    ),
                  ]
                ],
              ),
            ),

            // Section: Accès Internet
            _buildExpansionSection(
              title: 'Accès Internet',
              icon: Icons.public,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _evaluationData.internetAccessType,
                    hint: const Text('Type de Connexion'),
                    decoration: InputDecoration(border: defaultBorder),
                    items: ['Fibre Optique', 'ADSL', '4G/5G', 'Satellite', 'Aucune'].map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: (value) => setState(() => _evaluationData.internetAccessType = value),
                  ),
                  const SizedBox(height: 16),
                  _buildConditionalTextField(
                      controller: _evaluationData.internetProviderController,
                      labelText: 'Fournisseur d\'accès (FAI)'
                  ),
                  _buildConditionalTextField(
                      controller: _evaluationData.modemLocationController,
                      labelText: 'Emplacement du Modem/Routeur'
                  ),
                ],
              ),
            ),

            // Section: Câblage
            _buildExpansionSection(
              title: 'Câblage',
              icon: Icons.settings_ethernet,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _evaluationData.cableShieldType,
                    hint: const Text('Type de Blindage'),
                    decoration: InputDecoration(border: defaultBorder),
                    items: ['UTP', 'FTP', 'STP'].map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: (value) => setState(() => _evaluationData.cableShieldType = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _evaluationData.cableCategoryType,
                    hint: const Text('Catégorie de Câble'),
                    decoration: InputDecoration(border: defaultBorder),
                    items: ['CAT 5e', 'CAT 6', 'CAT 6a'].map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: (value) => setState(() => _evaluationData.cableCategoryType = value),
                  ),
                  const SizedBox(height: 16),
                  _buildYesNoQuestion(
                    question: 'Chemins de câbles (goulottes) ?',
                    value: _evaluationData.hasCablePaths,
                    onChanged: (val) => setState(() => _evaluationData.hasCablePaths = val),
                  ),
                  _buildConditionalTextField(
                      controller: _evaluationData.cableDistanceController,
                      labelText: 'Distance max. estimée (m)'
                  ),
                ],
              ),
            ),

            // Section: Endpoints (Planning)
            _buildExpansionSection(
              title: 'Points d\'Accès (Planning)',
              icon: Icons.power,
              child: Column(
                children: [
                  _buildEndpointList(
                    title: 'TPV',
                    endpointList: _evaluationData.tpvList,
                    onAddItem: _addTpv,
                    onRemoveItem: (index) => _removeTpv(index),
                  ),
                  const Divider(height: 24),
                  _buildEndpointList(
                    title: 'Imprimante',
                    endpointList: _evaluationData.printerList,
                    onAddItem: _addPrinter,
                    onRemoveItem: (index) => _removePrinter(index),
                  ),
                  const Divider(height: 24),
                  _buildEndpointList(
                    title: 'Borne',
                    endpointList: _evaluationData.kioskList,
                    onAddItem: _addKiosk,
                    onRemoveItem: (index) => _removeKiosk(index),
                  ),
                  const Divider(height: 24),
                  _buildEndpointList(
                    title: 'Écran Pub',
                    endpointList: _evaluationData.screenList,
                    onAddItem: _addScreen,
                    onRemoveItem: (index) => _removeScreen(index),
                  ),
                ],
              ),
            ),

            // Section: Inventaire Matériel Client
            _buildExpansionSection(
              title: 'Inventaire Matériel Client',
              icon: Icons.devices,
              initiallyExpanded: true,
              child: _buildClientHardwareList(),
            ),

            // Section: Photos
            _buildExpansionSection(
              title: 'Photos et Notes',
              icon: Icons.camera_alt_outlined,
              child: Column(
                children: [
                  if (_evaluationData.photos.isNotEmpty)
                    Container(
                      height: 100,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _evaluationData.photos.length,
                        itemBuilder: (context, photoIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Image.file(_evaluationData.photos[photoIndex], width: 100, height: 100, fit: BoxFit.cover),
                          );
                        },
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickPhotos,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Ajouter des Photos'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Re-usable Helper Widgets ---

  Widget _buildExpansionSection({
    required String title,
    required IconData icon,
    required Widget child,
    bool initiallyExpanded = false
  }) {
    return ExpansionTile(
      leading: Icon(icon, color: primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      initiallyExpanded: initiallyExpanded,
      children: [child],
    );
  }

  Widget _buildYesNoQuestion({required String question, required bool? value, required ValueChanged<bool> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        ToggleButtons(
          isSelected: [value == true, value == false],
          onPressed: (index) {
            onChanged(index == 0);
          },
          borderRadius: BorderRadius.circular(8),
          selectedColor: Colors.white,
          fillColor: primaryColor,
          children: const [
            Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('Oui')),
            Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('Non')),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildConditionalTextField({required TextEditingController controller, required String labelText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: defaultBorder,
          focusedBorder: defaultBorder.copyWith(borderSide: const BorderSide(color: primaryColor)),
        ),
        maxLines: 2,
      ),
    );
  }

  // --- Helper Widgets for Endpoints (Planning) ---

  Widget _buildEndpointList({
    required String title,
    required List<EndpointData> endpointList,
    required VoidCallback onAddItem,
    required ValueChanged<int> onRemoveItem,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
        if (endpointList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text('Aucun $title ajouté.', style: const TextStyle(color: Colors.grey)),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: endpointList.length,
          itemBuilder: (context, index) {
            final item = endpointList[index];
            return _buildEndpointItem(
              item: item,
              onRemove: () => onRemoveItem(index),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAddItem,
          icon: const Icon(Icons.add),
          label: Text('Ajouter $title'),
        ),
      ],
    );
  }

  Widget _buildEndpointItem({
    required EndpointData item,
    required VoidCallback onRemove,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)
      ),
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              onPressed: onRemove,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                _buildSocketRow(
                  label: 'Prise Électrique',
                  value: item.hasPriseElectrique,
                  controller: item.quantityPriseElectriqueController,
                  onChanged: (val) => setState(() => item.hasPriseElectrique = val ?? false),
                ),
                _buildSocketRow(
                  label: 'Prise RJ45',
                  value: item.hasPriseRJ45,
                  controller: item.quantityPriseRJ45Controller,
                  onChanged: (val) => setState(() => item.hasPriseRJ45 = val ?? false),
                ),
                TextFormField(
                  controller: item.notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes (emplacement, etc.)',
                    border: defaultBorder,
                    focusedBorder: defaultBorder.copyWith(borderSide: const BorderSide(color: primaryColor)),
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocketRow({
    required String label,
    required bool value,
    required TextEditingController controller,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      children: [
        Checkbox(value: value, onChanged: onChanged),
        Expanded(child: Text(label)),
        const Text('Qté:'),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: TextFormField(
            controller: controller,
            enabled: value, // Only enable if checkbox is checked
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
                border: defaultBorder,
                contentPadding: const EdgeInsets.symmetric(vertical: 8)
            ),
          ),
        ),
      ],
    );
  }


  // --- Helper Widgets for Client Hardware ---

  /// Builds the whole "Client Hardware" list section
  Widget _buildClientHardwareList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_evaluationData.clientDeviceList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text('Aucun appareil client ajouté.', style: const TextStyle(color: Colors.grey)),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _evaluationData.clientDeviceList.length,
          itemBuilder: (context, index) {
            final item = _evaluationData.clientDeviceList[index];
            return _buildClientHardwareItem(
              item: item,
              index: index,
              onRemove: () => _removeClientDevice(index),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addClientDevice,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un appareil'),
        ),
      ],
    );
  }

  /// Builds the card for a single client device (PC, Printer, etc.)
  Widget _buildClientHardwareItem({
    required ClientDeviceData item,
    required int index,
    required VoidCallback onRemove,
  }) {
    bool showOS = item.deviceType == 'PC' || item.deviceType == 'TPV';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)
      ),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Appareil #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: item.deviceType,
              hint: const Text('Type d\'appareil'),
              decoration: InputDecoration(border: defaultBorder),
              items: ['PC', 'TPV', 'Imprimante Ticket', 'Imprimante A4', 'Scanner', 'Afficheur Client', 'Autre']
                  .map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (value) => setState(() => item.deviceType = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.brandController,
                    decoration: InputDecoration(
                      labelText: 'Marque',
                      border: defaultBorder,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: item.modelController,
                    decoration: InputDecoration(
                      labelText: 'Modèle',
                      border: defaultBorder,
                    ),
                  ),
                ),
              ],
            ),
            if (showOS) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: item.osType,
                hint: const Text('Système d\'exploitation (OS)'),
                decoration: InputDecoration(border: defaultBorder),
                items: ['Windows 11', 'Windows 10', 'Windows 7/8', 'Android', 'Linux', 'Aucun / N/A']
                    .map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (value) => setState(() => item.osType = value),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: item.notesController,
              decoration: InputDecoration(
                labelText: 'Notes (RAM, Connexion, etc.)',
                border: defaultBorder,
                focusedBorder: defaultBorder.copyWith(borderSide: const BorderSide(color: primaryColor)),
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
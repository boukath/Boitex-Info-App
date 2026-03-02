// lib/screens/service_it/it_evaluation_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:boitex_info_app/models/it_evaluation_data.dart';
import 'package:flutter/services.dart'; // Needed for number input
import 'package:path/path.dart' as path;
import 'package:google_fonts/google_fonts.dart'; // ✅ PREMIUM UI ADDITION

// ✅ Imports for Backblaze B2 upload
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';

// -----------------------------------------------------------------------------
// 🎨 THEME CONSTANTS (Apple iOS 2026 Vibe - IT Service Edition)
// -----------------------------------------------------------------------------
const Color kBgColor = Color(0xFFF2F2F7); // iOS System Background
const Color kSurfaceColor = Colors.white;
const Color kPrimaryColor = Color(0xFF0EA5E9); // Modern Sky Blue (IT Service)
const Color kTextDark = Color(0xFF1C1C1E); // iOS Label Color
const Color kTextLight = Color(0xFF8E8E93); // iOS Secondary Label
const Color kBorderColor = Color(0xFFE5E5EA); // iOS Separator
const double kRadius = 24.0;

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

  // B2 Cloud Function URL constant
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  // Local variables for specific question photos
  File? networkExistMedia;
  File? highVoltageMedia;
  File? rackMedia;
  File? upsMedia;
  File? modemMedia;
  File? cablingPathMedia;

  // Maps to store temporary photos for list items (Key: Index, Value: File)
  Map<int, File> tpvPhotos = {};
  Map<int, File> printerPhotos = {};
  Map<int, File> kioskPhotos = {};
  Map<int, File> screenPhotos = {};
  Map<int, File> clientDevicePhotos = {};

  @override
  void dispose() {
    _evaluationData.dispose();
    super.dispose();
  }

  // --- START: Endpoint list helpers ---
  void _addTpv() {
    setState(() {
      _evaluationData.tpvList.add(EndpointData(name: 'TPV #${_evaluationData.tpvList.length + 1}'));
    });
  }
  void _removeTpv(int index) {
    _evaluationData.tpvList[index].dispose();
    setState(() {
      _evaluationData.tpvList.removeAt(index);
      tpvPhotos.remove(index); // Clean up photo
    });
  }
  void _addPrinter() {
    setState(() {
      _evaluationData.printerList.add(EndpointData(name: 'Imprimante #${_evaluationData.printerList.length + 1}'));
    });
  }
  void _removePrinter(int index) {
    _evaluationData.printerList[index].dispose();
    setState(() {
      _evaluationData.printerList.removeAt(index);
      printerPhotos.remove(index);
    });
  }
  void _addKiosk() {
    setState(() {
      _evaluationData.kioskList.add(EndpointData(name: 'Borne #${_evaluationData.kioskList.length + 1}'));
    });
  }
  void _removeKiosk(int index) {
    _evaluationData.kioskList[index].dispose();
    setState(() {
      _evaluationData.kioskList.removeAt(index);
      kioskPhotos.remove(index);
    });
  }
  void _addScreen() {
    setState(() {
      _evaluationData.screenList.add(EndpointData(name: 'Écran #${_evaluationData.screenList.length + 1}'));
    });
  }
  void _removeScreen(int index) {
    _evaluationData.screenList[index].dispose();
    setState(() {
      _evaluationData.screenList.removeAt(index);
      screenPhotos.remove(index);
    });
  }
  // --- END: Endpoint list helpers ---

  // --- START: New Client Hardware list helpers ---
  void _addClientDevice() {
    setState(() {
      _evaluationData.clientDeviceList.add(ClientDeviceData());
    });
  }
  void _removeClientDevice(int index) {
    _evaluationData.clientDeviceList[index].dispose();
    setState(() {
      _evaluationData.clientDeviceList.removeAt(index);
      clientDevicePhotos.remove(index);
    });
  }
  // --- END: New Client Hardware list helpers ---

  // --- START: B2 HELPER FUNCTIONS ---

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
      File file,
      Map<String, dynamic> b2Creds, {
        required String projectId,
        String? subFolder,
      }) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final originalFileName = path.basename(file.path);

      final String folder = subFolder ?? 'general';
      final String b2FileName = 'it_evaluations/$projectId/$folder/${DateTime.now().millisecondsSinceEpoch}_$originalFileName';

      final String extension = path.extension(file.path).toLowerCase();
      String mimeType = 'b2/x-auto';
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
          'X-Bz-File-Name': Uri.encodeComponent(b2FileName),
          'Content-Type': mimeType,
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
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

  Future<void> _pickSinglePhoto(ValueChanged<File?> onPicked) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result != null && result.files.isNotEmpty) {
      final file = File(result.files.single.path!);
      if (file.lengthSync() <= 50 * 1024 * 1024) {
        onPicked(file);
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fichier trop lourd (>50Mo)', style: GoogleFonts.inter())));
      }
    }
  }

  void _openMediaPreview(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(file),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null) {
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
            content: Text('$rejectedCount image(s) dépassent la limite de 50 Mo.', style: GoogleFonts.inter()),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _saveEvaluation() async {
    setState(() { _isLoading = true; });

    final b2Credentials = await _getB2UploadCredentials();
    if (b2Credentials == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: Impossible de contacter le service d\'upload.', style: GoogleFonts.inter()), backgroundColor: Colors.red),
        );
        setState(() { _isLoading = false; });
      }
      return;
    }

    try {
      final evaluationMap = _evaluationData.getDataMap();

      Future<void> uploadAndSet(File? file, String folder, String key) async {
        if (file != null) {
          String? url = await _uploadFileToB2(file, b2Credentials, projectId: widget.projectId, subFolder: folder);
          if (url != null) evaluationMap[key] = url;
        }
      }

      await uploadAndSet(networkExistMedia, 'network', 'networkPhotoUrl');
      await uploadAndSet(highVoltageMedia, 'environment', 'highVoltagePhotoUrl');
      await uploadAndSet(rackMedia, 'rack', 'rackPhotoUrl');
      await uploadAndSet(upsMedia, 'rack', 'upsPhotoUrl');
      await uploadAndSet(modemMedia, 'internet', 'modemPhotoUrl');
      await uploadAndSet(cablingPathMedia, 'cabling', 'cablingPathPhotoUrl');

      Future<void> processList(List<dynamic> listMap, Map<int, File> photoMap, String folder) async {
        for (int i = 0; i < listMap.length; i++) {
          if (photoMap.containsKey(i)) {
            String? url = await _uploadFileToB2(photoMap[i]!, b2Credentials, projectId: widget.projectId, subFolder: folder);
            if (url != null) listMap[i]['photoUrl'] = url;
          }
        }
      }

      await processList(evaluationMap['tpvList'], tpvPhotos, 'endpoints_tpv');
      await processList(evaluationMap['printerList'], printerPhotos, 'endpoints_printers');
      await processList(evaluationMap['kioskList'], kioskPhotos, 'endpoints_kiosk');
      await processList(evaluationMap['screenList'], screenPhotos, 'endpoints_screens');
      await processList(evaluationMap['clientDeviceList'], clientDevicePhotos, 'client_hardware');

      final List<String> photoUrls = [];
      for (final file in _evaluationData.photos) {
        final String? downloadUrl = await _uploadFileToB2(
            file,
            b2Credentials,
            projectId: widget.projectId,
            subFolder: 'gallery'
        );
        if (downloadUrl != null) photoUrls.add(downloadUrl);
      }
      evaluationMap['photos'] = photoUrls;

      await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
        'it_evaluation': evaluationMap,
        'status': 'Évaluation IT Terminé',
      });

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}', style: GoogleFonts.inter()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  // ---------------------------------------------------------------------------
  // 🎨 APPLE / IOS UI BUILDERS
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kBgColor,
        iconTheme: const IconThemeData(color: kTextDark),
        centerTitle: true,
        title: Text(
          'Évaluation IT',
          style: GoogleFonts.inter(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _buildExpansionSection(
            title: 'Réseau Existant',
            icon: Icons.network_check_rounded,
            initiallyExpanded: true,
            child: Column(
              children: [
                _buildFormRow(
                  label: "Un réseau est-il déjà installé ?",
                  input: _buildPremiumSegmentedControl(["Oui", "Non"], _evaluationData.networkExists == true ? 0 : (_evaluationData.networkExists == false ? 1 : -1), (idx) => setState(() => _evaluationData.networkExists = idx == 0)),
                  imagePicker: _buildPremiumImagePicker(networkExistMedia, (f) => setState(() => networkExistMedia = f)),
                ),
                if (_evaluationData.networkExists == true) ...[
                  const SizedBox(height: 16),
                  _buildFormRow(
                    label: "Installation multi-étages ?",
                    input: _buildPremiumSegmentedControl(["Oui", "Non"], _evaluationData.isMultiFloor == true ? 0 : (_evaluationData.isMultiFloor == false ? 1 : -1), (idx) => setState(() => _evaluationData.isMultiFloor = idx == 0)),
                  ),
                ],
                const SizedBox(height: 16),
                _buildPremiumTextField(controller: _evaluationData.networkNotesController, label: "Notes sur le réseau (type, âge...)"),
              ],
            ),
          ),

          _buildExpansionSection(
            title: 'Environnement',
            icon: Icons.warning_amber_rounded,
            child: Column(
              children: [
                _buildFormRow(
                  label: "Courant haute tension à proximité ?",
                  input: _buildPremiumSegmentedControl(["Oui", "Non"], _evaluationData.hasHighVoltage == true ? 0 : (_evaluationData.hasHighVoltage == false ? 1 : -1), (idx) => setState(() => _evaluationData.hasHighVoltage = idx == 0)),
                  imagePicker: _buildPremiumImagePicker(highVoltageMedia, (f) => setState(() => highVoltageMedia = f)),
                ),
                const SizedBox(height: 16),
                _buildPremiumTextField(controller: _evaluationData.highVoltageNotesController, label: "Décrire (moteurs, lignes...)"),
              ],
            ),
          ),

          _buildExpansionSection(
            title: 'Baie de Brassage / Local Tech.',
            icon: Icons.dns_rounded,
            child: Column(
              children: [
                _buildFormRow(
                  label: "Baie de brassage présente ?",
                  input: _buildPremiumSegmentedControl(["Oui", "Non"], _evaluationData.hasNetworkRack == true ? 0 : (_evaluationData.hasNetworkRack == false ? 1 : -1), (idx) => setState(() => _evaluationData.hasNetworkRack = idx == 0)),
                  imagePicker: _buildPremiumImagePicker(rackMedia, (f) => setState(() => rackMedia = f)),
                ),
                if (_evaluationData.hasNetworkRack == true) ...[
                  const SizedBox(height: 16),
                  _buildPremiumTextField(controller: _evaluationData.rackLocationController, label: "Emplacement de la baie"),
                  const SizedBox(height: 16),
                  _buildFormRow(
                    label: "Espace disponible dans la baie ?",
                    input: _buildPremiumSegmentedControl(["Oui", "Non"], _evaluationData.hasRackSpace == true ? 0 : (_evaluationData.hasRackSpace == false ? 1 : -1), (idx) => setState(() => _evaluationData.hasRackSpace = idx == 0)),
                  ),
                  const SizedBox(height: 16),
                  _buildFormRow(
                    label: "Onduleur (UPS) présent ?",
                    input: _buildPremiumSegmentedControl(["Oui", "Non"], _evaluationData.hasUPS == true ? 0 : (_evaluationData.hasUPS == false ? 1 : -1), (idx) => setState(() => _evaluationData.hasUPS = idx == 0)),
                    imagePicker: _buildPremiumImagePicker(upsMedia, (f) => setState(() => upsMedia = f)),
                  ),
                ]
              ],
            ),
          ),

          _buildExpansionSection(
            title: 'Accès Internet',
            icon: Icons.public_rounded,
            child: Column(
              children: [
                _buildPremiumDropdown(
                  value: _evaluationData.internetAccessType,
                  items: ['Fibre Optique', 'ADSL', '4G/5G', 'Satellite', 'Aucune'],
                  hint: 'Type de Connexion',
                  onChanged: (val) => setState(() => _evaluationData.internetAccessType = val),
                ),
                const SizedBox(height: 16),
                _buildPremiumTextField(controller: _evaluationData.internetProviderController, label: "Fournisseur d'accès (FAI)"),
                const SizedBox(height: 16),
                _buildFormRow(
                  label: "Emplacement du Modem/Routeur",
                  input: _buildPremiumTextField(controller: _evaluationData.modemLocationController, label: "Ex: Bureau, RDC"),
                  imagePicker: _buildPremiumImagePicker(modemMedia, (f) => setState(() => modemMedia = f)),
                ),
              ],
            ),
          ),

          _buildExpansionSection(
            title: 'Câblage',
            icon: Icons.settings_ethernet_rounded,
            child: Column(
              children: [
                _buildPremiumDropdown(
                  value: _evaluationData.cableShieldType,
                  items: ['UTP', 'FTP', 'STP'],
                  hint: 'Type de Blindage',
                  onChanged: (val) => setState(() => _evaluationData.cableShieldType = val),
                ),
                const SizedBox(height: 16),
                _buildPremiumDropdown(
                  value: _evaluationData.cableCategoryType,
                  items: ['CAT 5e', 'CAT 6', 'CAT 6a'],
                  hint: 'Catégorie de Câble',
                  onChanged: (val) => setState(() => _evaluationData.cableCategoryType = val),
                ),
                const SizedBox(height: 16),
                _buildFormRow(
                  label: "Chemins de câbles (goulottes) ?",
                  input: _buildPremiumSegmentedControl(["Oui", "Non"], _evaluationData.hasCablePaths == true ? 0 : (_evaluationData.hasCablePaths == false ? 1 : -1), (idx) => setState(() => _evaluationData.hasCablePaths = idx == 0)),
                  imagePicker: _buildPremiumImagePicker(cablingPathMedia, (f) => setState(() => cablingPathMedia = f)),
                ),
                const SizedBox(height: 16),
                _buildPremiumTextField(controller: _evaluationData.cableDistanceController, label: "Distance max. estimée (m)", isNumber: true),
              ],
            ),
          ),

          _buildExpansionSection(
            title: 'Points d\'Accès (Planning)',
            icon: Icons.power_rounded,
            child: Column(
              children: [
                _buildEndpointList(title: 'TPV', endpointList: _evaluationData.tpvList, photoMap: tpvPhotos, onAddItem: _addTpv, onRemoveItem: _removeTpv),
                Divider(height: 32, color: kBorderColor),
                _buildEndpointList(title: 'Imprimante', endpointList: _evaluationData.printerList, photoMap: printerPhotos, onAddItem: _addPrinter, onRemoveItem: _removePrinter),
                Divider(height: 32, color: kBorderColor),
                _buildEndpointList(title: 'Borne', endpointList: _evaluationData.kioskList, photoMap: kioskPhotos, onAddItem: _addKiosk, onRemoveItem: _removeKiosk),
                Divider(height: 32, color: kBorderColor),
                _buildEndpointList(title: 'Écran Pub', endpointList: _evaluationData.screenList, photoMap: screenPhotos, onAddItem: _addScreen, onRemoveItem: _removeScreen),
              ],
            ),
          ),

          _buildExpansionSection(
            title: 'Inventaire Matériel Client',
            icon: Icons.devices_rounded,
            child: _buildClientHardwareList(),
          ),

          _buildExpansionSection(
            title: 'Photos Additionnelles',
            icon: Icons.photo_library_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_evaluationData.photos.isNotEmpty)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _evaluationData.photos.asMap().entries.map((entry) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(entry.value, width: 80, height: 80, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -6, right: -6,
                            child: GestureDetector(
                              onTap: () => setState(() => _evaluationData.photos.removeAt(entry.key)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickPhotos,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: kBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_rounded, color: kTextLight),
                        const SizedBox(width: 8),
                        Text("Ajouter des photos à la galerie", style: GoogleFonts.inter(color: kTextLight, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
          _buildSaveButton(),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🛠️ HELPER WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildExpansionSection({required String title, required IconData icon, required Widget child, bool initiallyExpanded = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: kPrimaryColor, size: 22),
          ),
          title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
          childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          children: [child],
        ),
      ),
    );
  }

  Widget _buildFormRow({required String label, required Widget input, Widget? imagePicker}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextDark, fontSize: 14)),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: input),
            if (imagePicker != null) ...[
              const SizedBox(width: 12),
              imagePicker,
            ]
          ],
        ),
      ],
    );
  }

  Widget _buildPremiumTextField({required TextEditingController controller, required String label, bool isNumber = false, TextAlign textAlign = TextAlign.start}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      textAlign: textAlign,
      style: GoogleFonts.inter(color: kTextDark),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: GoogleFonts.inter(color: kTextLight),
        filled: true,
        fillColor: kBgColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kPrimaryColor, width: 1.5)),
      ),
    );
  }

  Widget _buildPremiumDropdown({String? value, required List<String> items, required Function(String?) onChanged, String hint = ""}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: kBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: GoogleFonts.inter(color: kTextLight)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kTextLight),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: GoogleFonts.inter(color: kTextDark)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPremiumSegmentedControl(List<String> options, int selectedIndex, Function(int) onSelected) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: options.asMap().entries.map((entry) {
          final isSelected = entry.key == selectedIndex;
          final text = entry.value;

          final isOui = text.toLowerCase() == 'oui';
          final isNon = text.toLowerCase() == 'non';

          Color activeBgColor = kSurfaceColor;
          Color activeTextColor = kTextDark;
          Color shadowColor = Colors.black.withOpacity(0.05);
          IconData? icon;

          if (isOui) {
            activeBgColor = const Color(0xFF10B981);
            activeTextColor = Colors.white;
            shadowColor = activeBgColor.withOpacity(0.4);
            icon = Icons.check_circle_outline_rounded;
          } else if (isNon) {
            activeBgColor = const Color(0xFFEF4444);
            activeTextColor = Colors.white;
            shadowColor = activeBgColor.withOpacity(0.4);
            icon = Icons.highlight_off_rounded;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(entry.key),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? activeBgColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected ? [BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 4))] : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: isSelected ? activeTextColor : Colors.transparent),
                      if (isSelected) const SizedBox(width: 6),
                    ],
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      style: GoogleFonts.inter(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? activeTextColor : kTextLight,
                        fontSize: 14,
                      ),
                      child: Text(text),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPremiumImagePicker(File? currentFile, Function(File?) onChanged) {
    if (currentFile != null) {
      return GestureDetector(
        onTap: () => _openMediaPreview(context, currentFile),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3))],
                image: DecorationImage(image: FileImage(currentFile), fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: -6, right: -6,
              child: GestureDetector(
                onTap: () => onChanged(null),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 10, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return InkWell(
        onTap: () => _pickSinglePhoto(onChanged),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: kBgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorderColor),
          ),
          child: const Icon(Icons.camera_alt_rounded, color: kTextLight, size: 22),
        ),
      );
    }
  }

  // --- Endpoints Builders ---

  Widget _buildEndpointList({
    required String title,
    required List<EndpointData> endpointList,
    required Map<int, File> photoMap,
    required VoidCallback onAddItem,
    required ValueChanged<int> onRemoveItem,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: kTextLight, letterSpacing: 1.1)),
        const SizedBox(height: 12),
        if (endpointList.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text('Aucun $title ajouté.', style: GoogleFonts.inter(color: kTextLight, fontStyle: FontStyle.italic)),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: endpointList.length,
          itemBuilder: (context, index) {
            return _buildEndpointItem(
              item: endpointList[index],
              photo: photoMap[index],
              onPhotoChanged: (f) => setState(() => photoMap[index] = f!),
              onRemove: () => onRemoveItem(index),
            );
          },
        ),
        InkWell(
          onTap: onAddItem,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, color: kPrimaryColor, size: 20),
                const SizedBox(width: 8),
                Text('Ajouter $title', style: GoogleFonts.inter(color: kPrimaryColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEndpointItem({
    required EndpointData item,
    required File? photo,
    required ValueChanged<File?> onPhotoChanged,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
              Row(
                children: [
                  _buildPremiumImagePicker(photo, onPhotoChanged),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSocketRow(
            label: 'Prise Électrique',
            value: item.hasPriseElectrique,
            controller: item.quantityPriseElectriqueController,
            onChanged: (val) => setState(() => item.hasPriseElectrique = val),
          ),
          const SizedBox(height: 12),
          _buildSocketRow(
            label: 'Prise RJ45',
            value: item.hasPriseRJ45,
            controller: item.quantityPriseRJ45Controller,
            onChanged: (val) => setState(() => item.hasPriseRJ45 = val),
          ),
          const SizedBox(height: 16),
          _buildPremiumTextField(controller: item.notesController, label: 'Notes (emplacement, etc.)'),
        ],
      ),
    );
  }

  Widget _buildSocketRow({
    required String label,
    required bool value,
    required TextEditingController controller,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Switch(
          value: value,
          activeColor: kPrimaryColor,
          onChanged: onChanged,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: kTextDark))),
        if (value)
          SizedBox(
            width: 80,
            child: _buildPremiumTextField(
                controller: controller,
                label: "Qté",
                isNumber: true,
                textAlign: TextAlign.center
            ),
          ),
      ],
    );
  }

  // --- Client Hardware Builders ---

  Widget _buildClientHardwareList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_evaluationData.clientDeviceList.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text('Aucun appareil client ajouté.', style: GoogleFonts.inter(color: kTextLight, fontStyle: FontStyle.italic)),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _evaluationData.clientDeviceList.length,
          itemBuilder: (context, index) {
            return _buildClientHardwareItem(
              item: _evaluationData.clientDeviceList[index],
              index: index,
              photo: clientDevicePhotos[index],
              onPhotoChanged: (f) => setState(() => clientDevicePhotos[index] = f!),
              onRemove: () => _removeClientDevice(index),
            );
          },
        ),
        InkWell(
          onTap: _addClientDevice,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, color: kPrimaryColor, size: 20),
                const SizedBox(width: 8),
                Text('Ajouter un appareil', style: GoogleFonts.inter(color: kPrimaryColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClientHardwareItem({
    required ClientDeviceData item,
    required int index,
    required File? photo,
    required ValueChanged<File?> onPhotoChanged,
    required VoidCallback onRemove,
  }) {
    bool showOS = item.deviceType == 'PC' || item.deviceType == 'TPV';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Appareil #${index + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
              Row(
                children: [
                  _buildPremiumImagePicker(photo, onPhotoChanged),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPremiumDropdown(
            value: item.deviceType,
            items: ['PC', 'TPV', 'Imprimante Ticket', 'Imprimante A4', 'Scanner', 'Afficheur Client', 'Autre'],
            hint: 'Type d\'appareil',
            onChanged: (val) => setState(() => item.deviceType = val),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildPremiumTextField(controller: item.brandController, label: 'Marque')),
              const SizedBox(width: 12),
              Expanded(child: _buildPremiumTextField(controller: item.modelController, label: 'Modèle')),
            ],
          ),
          if (showOS) ...[
            const SizedBox(height: 12),
            _buildPremiumDropdown(
              value: item.osType,
              items: ['Windows 11', 'Windows 10', 'Windows 7/8', 'Android', 'Linux', 'Aucun / N/A'],
              hint: 'Système d\'exploitation (OS)',
              onChanged: (val) => setState(() => item.osType = val),
            ),
          ],
          const SizedBox(height: 12),
          _buildPremiumTextField(controller: item.notesController, label: 'Notes (RAM, Connexion, etc.)'),
        ],
      ),
    );
  }

  // --- Main Button ---

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _saveEvaluation,
        style: ElevatedButton.styleFrom(
          backgroundColor: kTextDark, // iOS Style primary black button
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text("Terminer l'évaluation", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
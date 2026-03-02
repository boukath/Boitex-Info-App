// lib/screens/administration/technical_evaluation_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:google_fonts/google_fonts.dart'; // ✅ PREMIUM UI ADDITION

// ✅ Imports for Backblaze B2 upload
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';

// -----------------------------------------------------------------------------
// 🎨 THEME CONSTANTS (Apple iOS 2026 Vibe)
// -----------------------------------------------------------------------------
const Color kBgColor = Color(0xFFF2F2F7); // iOS System Background
const Color kSurfaceColor = Colors.white;
const Color kPrimaryColor = Color(0xFF4F46E5); // Indigo (Antivol)
const Color kCountingColor = Color(0xFF10B981); // Emerald (Comptage)
const Color kTextDark = Color(0xFF1C1C1E); // iOS Label Color
const Color kTextLight = Color(0xFF8E8E93); // iOS Secondary Label
const Color kBorderColor = Color(0xFFE5E5EA); // iOS Separator
const double kRadius = 24.0;

// -----------------------------------------------------------------------------
// 📦 DATA MODELS
// -----------------------------------------------------------------------------

class CountingGlobalData {
  String? hostingDevice; // PC Desktop, Laptop, TPV
  File? hostingMedia;

  bool? hasPoeSwitch;
  File? poeMedia;

  bool? hasRackSpace; // For injector/switch
  File? rackSpaceMedia;

  Map<String, dynamic> getDataMap() {
    return {
      'hostingDevice': hostingDevice,
      'hasPoeSwitch': hasPoeSwitch,
      'hasRackSpace': hasRackSpace,
      // URLs added during save
    };
  }
}

class EntranceData {
  // --- MALL IDENTITY (CENTRE COMMERCIAL) ---
  final TextEditingController locationNameController = TextEditingController(); // e.g., "Porte Nord"
  final TextEditingController zoneNameController = TextEditingController();     // e.g., "RDC - Aile Est"
  String? flowType; // e.g., "Entrée Principale", "Couloir", "Escalator"

  // --- ANTIVOL DATA ---
  String? entranceType;
  String? doorType;
  final TextEditingController entranceWidthController = TextEditingController();

  bool isPowerAvailable = false;
  final TextEditingController powerNotesController = TextEditingController();

  bool isFloorFinalized = false;
  bool isConduitAvailable = false;
  bool canMakeTrench = false;

  bool hasObstacles = false;
  final TextEditingController obstacleNotesController = TextEditingController();

  bool hasMetalStructures = false;
  bool hasOtherSystems = false;

  // --- COUNTING DATA (Per Entrance) ---
  bool needsCountCamera = false;
  final TextEditingController cameraHeightController = TextEditingController();
  String? ceilingType;
  bool needsPoleSupport = false;
  bool hasCat6 = false;
  final TextEditingController cableDistanceController = TextEditingController();

  // --- MEDIA ---
  Map<String, File?> media = {};
  List<File> galleryMedia = []; // For generic "autres photos"

  void setMedia(String key, File? file) {
    media[key] = file;
  }

  Map<String, dynamic> getDataMap() {
    return {
      'locationName': locationNameController.text.trim(),
      'zoneName': zoneNameController.text.trim(),
      'flowType': flowType,
      'entranceType': entranceType,
      'doorType': doorType,
      'entranceWidth': entranceWidthController.text.trim(),
      'isPowerAvailable': isPowerAvailable,
      'powerNotes': powerNotesController.text.trim(),
      'isFloorFinalized': isFloorFinalized,
      'isConduitAvailable': isConduitAvailable,
      'canMakeTrench': canMakeTrench,
      'hasObstacles': hasObstacles,
      'obstacleNotes': obstacleNotesController.text.trim(),
      'hasMetalStructures': hasMetalStructures,
      'hasOtherSystems': hasOtherSystems,
      'needsCountCamera': needsCountCamera,
      'cameraHeight': cameraHeightController.text.trim(),
      'ceilingType': ceilingType,
      'needsPoleSupport': needsPoleSupport,
      'hasCat6': hasCat6,
      'cableDistance': cableDistanceController.text.trim(),
      // Media URLs will be injected during the save process
    };
  }

  void dispose() {
    locationNameController.dispose();
    zoneNameController.dispose();
    entranceWidthController.dispose();
    powerNotesController.dispose();
    obstacleNotesController.dispose();
    cameraHeightController.dispose();
    cableDistanceController.dispose();
  }
}

// -----------------------------------------------------------------------------
// 🖥️ MAIN PAGE
// -----------------------------------------------------------------------------

class TechnicalEvaluationPage extends StatefulWidget {
  final String projectId;
  const TechnicalEvaluationPage({super.key, required this.projectId});

  @override
  State<TechnicalEvaluationPage> createState() => _TechnicalEvaluationPageState();
}

class _TechnicalEvaluationPageState extends State<TechnicalEvaluationPage> {
  bool _isCountingStudy = false;
  bool _isMallMode = false;
  bool _isAntivolEvaluation = true; // Default
  bool _isSaving = false;

  final CountingGlobalData _globalData = CountingGlobalData();
  final List<EntranceData> _entrances = [EntranceData()]; // Start with 1 entrance

  final String _getB2UploadUrlCloudFunctionUrl = 'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    for (var e in _entrances) {
      e.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 💾 B2 UPLOAD & FIRESTORE LOGIC (PRESERVED EXACTLY)
  // ---------------------------------------------------------------------------

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

  Future<String?> _uploadFileToB2({required File file, required Map<String, dynamic> b2Creds, required String b2FileName}) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final String originalFileName = path.basename(file.path);

      String? mimeType;
      final String extension = path.extension(originalFileName).toLowerCase();
      if (extension == '.jpg' || extension == '.jpeg') mimeType = 'image/jpeg';
      else if (extension == '.png') mimeType = 'image/png';
      else if (extension == '.pdf') mimeType = 'application/pdf';

      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(b2FileName),
          'Content-Type': mimeType ?? 'b2/x-auto',
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
        debugPrint('Failed to upload file to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file to B2: $e');
      return null;
    }
  }

  Future<void> _uploadAllMedia(Map<String, dynamic> b2Creds, EntranceData entrance, Map<String, dynamic> entranceMap, int entranceIndex) async {
    final String basePath = 'projects/${widget.projectId}/technical_eval/entrance_$entranceIndex';

    for (var entry in entrance.media.entries) {
      if (entry.value != null) {
        final String fileName = '$basePath/${entry.key}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final url = await _uploadFileToB2(file: entry.value!, b2Creds: b2Creds, b2FileName: fileName);
        if (url != null) entranceMap['${entry.key}PhotoUrl'] = url;
      }
    }

    if (entrance.galleryMedia.isNotEmpty) {
      List<String> galleryUrls = [];
      for (int i = 0; i < entrance.galleryMedia.length; i++) {
        final String fileName = '$basePath/gallery_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final url = await _uploadFileToB2(file: entrance.galleryMedia[i], b2Creds: b2Creds, b2FileName: fileName);
        if (url != null) galleryUrls.add(url);
      }
      entranceMap['media'] = galleryUrls;
    }
  }

  Future<void> _uploadGlobalMedia(Map<String, dynamic> b2Creds, Map<String, dynamic> globalMap) async {
    final String basePath = 'projects/${widget.projectId}/technical_eval/global';

    if (_globalData.hostingMedia != null) {
      final url = await _uploadFileToB2(file: _globalData.hostingMedia!, b2Creds: b2Creds, b2FileName: '$basePath/hosting_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (url != null) globalMap['hostingUrl'] = url;
    }
    if (_globalData.poeMedia != null) {
      final url = await _uploadFileToB2(file: _globalData.poeMedia!, b2Creds: b2Creds, b2FileName: '$basePath/poe_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (url != null) globalMap['poe_switchUrl'] = url;
    }
    if (_globalData.rackSpaceMedia != null) {
      final url = await _uploadFileToB2(file: _globalData.rackSpaceMedia!, b2Creds: b2Creds, b2FileName: '$basePath/rack_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (url != null) globalMap['rack_spaceUrl'] = url;
    }
  }

  Future<void> _saveEvaluation() async {
    setState(() => _isSaving = true);
    try {
      final b2Creds = await _getB2UploadCredentials();
      if (b2Creds == null) throw Exception("Impossible d'obtenir les identifiants B2.");

      List<Map<String, dynamic>> savedEntrances = [];
      for (int i = 0; i < _entrances.length; i++) {
        var map = _entrances[i].getDataMap();
        await _uploadAllMedia(b2Creds, _entrances[i], map, i);
        savedEntrances.add(map);
      }

      Map<String, dynamic> globalDataMap = {};
      if (_isCountingStudy) {
        globalDataMap = _globalData.getDataMap();
        await _uploadGlobalMedia(b2Creds, globalDataMap);
      }

      await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
        'has_counting_study': _isCountingStudy,
        'has_antivol_evaluation': _isAntivolEvaluation,
        'is_mall_mode': _isMallMode,
        'counting_evaluation_global': _isCountingStudy ? globalDataMap : null,
        'technical_evaluation': savedEntrances,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Évaluation enregistrée avec succès', style: GoogleFonts.inter()), backgroundColor: kCountingColor));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e', style: GoogleFonts.inter()), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadExistingData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;

      setState(() {
        _isCountingStudy = data['has_counting_study'] ?? false;
        _isAntivolEvaluation = data['has_antivol_evaluation'] ?? true;
        _isMallMode = data['is_mall_mode'] ?? false;

        final globalData = data['counting_evaluation_global'];
        if (globalData != null) {
          _globalData.hostingDevice = globalData['hostingDevice'];
          _globalData.hasPoeSwitch = globalData['hasPoeSwitch'];
          _globalData.hasRackSpace = globalData['hasRackSpace'];
          // Note: Cannot easily load back images from B2 to File objects natively.
          // They would just be URLs. In a full system, you'd show network images.
          // For this form, they remain null (meaning no new upload unless changed).
        }

        final List<dynamic>? existingEvals = data['technical_evaluation'];
        if (existingEvals != null && existingEvals.isNotEmpty) {
          _entrances.clear();
          for (var eval in existingEvals) {
            final e = EntranceData();
            e.locationNameController.text = eval['locationName'] ?? '';
            e.zoneNameController.text = eval['zoneName'] ?? '';
            e.flowType = eval['flowType'];
            e.entranceType = eval['entranceType'];
            e.doorType = eval['doorType'];
            e.entranceWidthController.text = eval['entranceWidth'] ?? '';
            e.isPowerAvailable = eval['isPowerAvailable'] ?? false;
            e.powerNotesController.text = eval['powerNotes'] ?? '';
            e.isFloorFinalized = eval['isFloorFinalized'] ?? false;
            e.isConduitAvailable = eval['isConduitAvailable'] ?? false;
            e.canMakeTrench = eval['canMakeTrench'] ?? false;
            e.hasObstacles = eval['hasObstacles'] ?? false;
            e.obstacleNotesController.text = eval['obstacleNotes'] ?? '';
            e.hasMetalStructures = eval['hasMetalStructures'] ?? false;
            e.hasOtherSystems = eval['hasOtherSystems'] ?? false;
            e.needsCountCamera = eval['needsCountCamera'] ?? false;
            e.cameraHeightController.text = eval['cameraHeight'] ?? '';
            e.ceilingType = eval['ceilingType'];
            e.needsPoleSupport = eval['needsPoleSupport'] ?? false;
            e.hasCat6 = eval['hasCat6'] ?? false;
            e.cableDistanceController.text = eval['cableDistance'] ?? '';
            _entrances.add(e);
          }
        }
      });
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // 📸 MEDIA PICKERS
  // ---------------------------------------------------------------------------

  Future<void> _pickSingleFile(Function(File?) onSelected) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      onSelected(File(result.files.single.path!));
      setState(() {});
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
          'Évaluation Technique',
          style: GoogleFonts.inter(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _buildSectionHeader("Configuration Générale"),
          _buildSettingsGroup(),

          if (_isCountingStudy) ...[
            const SizedBox(height: 24),
            _buildSectionHeader("Serveur & Réseau (Comptage)"),
            _buildGlobalCountingCard(),
          ],

          const SizedBox(height: 32),
          _buildSectionHeader("Points d'Accès & Entrées"),

          ..._entrances.asMap().entries.map((entry) {
            return _buildEntranceCard(entry.value, entry.key);
          }),

          const SizedBox(height: 16),
          _buildAddEntranceButton(),

          const SizedBox(height: 48),
          _buildSaveButton(),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // --- UI: HEADERS & CARDS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextLight, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSettingsGroup() {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _buildToggleRow("Évaluation Antivol", Icons.security_rounded, kPrimaryColor, _isAntivolEvaluation, (val) => setState(() => _isAntivolEvaluation = val)),
          Divider(height: 1, color: kBorderColor, indent: 56),
          _buildToggleRow("Étude de Comptage & Flux", Icons.people_alt_rounded, kCountingColor, _isCountingStudy, (val) => setState(() => _isCountingStudy = val)),
          if (_isCountingStudy) ...[
            Divider(height: 1, color: kBorderColor, indent: 56),
            _buildToggleRow("Mode Centre Commercial", Icons.storefront_rounded, Colors.orange, _isMallMode, (val) => setState(() => _isMallMode = val)),
          ]
        ],
      ),
    );
  }

  Widget _buildToggleRow(String title, IconData icon, Color iconColor, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: kTextDark))),
          Switch(
            value: value,
            activeColor: iconColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // --- UI: GLOBAL COUNTING ---

  Widget _buildGlobalCountingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _buildFormRow(
            label: "Type de Serveur / Hôte",
            input: _buildPremiumDropdown(
              value: _globalData.hostingDevice,
              items: ["PC Desktop Fixe", "PC Portable", "TPV Existant", "À Fournir"],
              onChanged: (val) => setState(() => _globalData.hostingDevice = val),
            ),
            imagePicker: _buildPremiumImagePicker(_globalData.hostingMedia, (f) => setState(() => _globalData.hostingMedia = f)),
          ),
          const SizedBox(height: 20),
          _buildFormRow(
            label: "Switch PoE Présent ?",
            input: _buildPremiumSegmentedControl(["Oui", "Non"], _globalData.hasPoeSwitch == true ? 0 : 1, (idx) => setState(() => _globalData.hasPoeSwitch = idx == 0)),
            imagePicker: _buildPremiumImagePicker(_globalData.poeMedia, (f) => setState(() => _globalData.poeMedia = f)),
          ),
          const SizedBox(height: 20),
          _buildFormRow(
            label: "Espace dans la baie ?",
            input: _buildPremiumSegmentedControl(["Oui", "Non"], _globalData.hasRackSpace == true ? 0 : 1, (idx) => setState(() => _globalData.hasRackSpace = idx == 0)),
            imagePicker: _buildPremiumImagePicker(_globalData.rackSpaceMedia, (f) => setState(() => _globalData.rackSpaceMedia = f)),
          ),
        ],
      ),
    );
  }

  // --- UI: ENTRANCES ---

  Widget _buildEntranceCard(EntranceData entrance, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: kSurfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadius)),
              border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.03))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: kTextDark.withOpacity(0.05), shape: BoxShape.circle),
                  child: Text("${index + 1}", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextDark)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isMallMode && entrance.locationNameController.text.isNotEmpty
                        ? entrance.locationNameController.text
                        : "Entrée / Accès",
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark),
                  ),
                ),
                if (_entrances.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => setState(() => _entrances.removeAt(index)),
                  )
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isMallMode) ...[
                  Text("Identité de l'accès (Mall)", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextLight, fontSize: 13)),
                  const SizedBox(height: 12),
                  _buildPremiumTextField(controller: entrance.locationNameController, label: "Nom (ex: Porte Nord)"),
                  const SizedBox(height: 12),
                  _buildPremiumTextField(controller: entrance.zoneNameController, label: "Zone (ex: Aile Est)"),
                  const SizedBox(height: 12),
                  _buildPremiumDropdown(
                    value: entrance.flowType,
                    items: ["Entrée Principale", "Couloir / Allée", "Escalator / Ascenseur", "Accès Parking"],
                    onChanged: (v) => setState(() => entrance.flowType = v),
                    hint: "Type de Flux",
                  ),
                  const SizedBox(height: 32),
                ],

                if (_isAntivolEvaluation) ...[
                  Text("Configuration Antivol", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kPrimaryColor, fontSize: 14)),
                  const SizedBox(height: 16),

                  _buildPremiumDropdown(
                    value: entrance.entranceType,
                    items: ["Standard", "Ouverte", "Coulissante", "Battante"],
                    onChanged: (v) => setState(() => entrance.entranceType = v),
                    hint: "Type d'Entrée",
                  ),
                  const SizedBox(height: 12),
                  _buildPremiumDropdown(
                    value: entrance.doorType,
                    items: ["Verre", "Métal", "Bois", "Automatique", "Aucune"],
                    onChanged: (v) => setState(() => entrance.doorType = v),
                    hint: "Type de Porte",
                  ),
                  const SizedBox(height: 12),

                  _buildFormRow(
                    label: "Largeur (mètres)",
                    input: _buildPremiumTextField(controller: entrance.entranceWidthController, label: "Ex: 2.5", isNumber: true),
                    imagePicker: _buildMediaPicker(entrance, 'width'),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader("Alimentation & Câblage"),
                  _buildFormRow(
                    label: "Prise 220V (< 2m) ?",
                    input: _buildPremiumSegmentedControl(["Oui", "Non"], entrance.isPowerAvailable ? 0 : 1, (idx) => setState(() => entrance.isPowerAvailable = idx == 0)),
                    imagePicker: _buildMediaPicker(entrance, 'power'),
                  ),
                  if (entrance.isPowerAvailable) ...[
                    const SizedBox(height: 12),
                    _buildPremiumTextField(controller: entrance.powerNotesController, label: "Notes sur l'alimentation"),
                  ],
                  const SizedBox(height: 16),

                  _buildFormRow(
                    label: "Sol Finalisé ?",
                    input: _buildPremiumSegmentedControl(["Oui", "Non"], entrance.isFloorFinalized ? 0 : 1, (idx) => setState(() => entrance.isFloorFinalized = idx == 0)),
                    imagePicker: _buildMediaPicker(entrance, 'floor'),
                  ),
                  const SizedBox(height: 16),

                  _buildFormRow(
                    label: "Fourreau dispo ?",
                    input: _buildPremiumSegmentedControl(["Oui", "Non"], entrance.isConduitAvailable ? 0 : 1, (idx) => setState(() => entrance.isConduitAvailable = idx == 0)),
                    imagePicker: _buildMediaPicker(entrance, 'conduit'),
                  ),
                  const SizedBox(height: 16),

                  _buildFormRow(
                    label: "Saignée Autorisée ?",
                    input: _buildPremiumSegmentedControl(["Oui", "Non"], entrance.canMakeTrench ? 0 : 1, (idx) => setState(() => entrance.canMakeTrench = idx == 0)),
                    imagePicker: _buildMediaPicker(entrance, 'trench'),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader("Environnement"),
                  _buildFormRow(
                    label: "Obstacles Physiques ?",
                    input: _buildPremiumSegmentedControl(["Oui", "Non"], entrance.hasObstacles ? 0 : 1, (idx) => setState(() => entrance.hasObstacles = idx == 0)),
                    imagePicker: _buildMediaPicker(entrance, 'obstacle'),
                  ),
                  if (entrance.hasObstacles) ...[
                    const SizedBox(height: 12),
                    _buildPremiumTextField(controller: entrance.obstacleNotesController, label: "Description des obstacles"),
                  ],
                  const SizedBox(height: 16),

                  _buildFormRow(
                    label: "Structures Métalliques ?",
                    input: _buildPremiumSegmentedControl(["Oui", "Non"], entrance.hasMetalStructures ? 0 : 1, (idx) => setState(() => entrance.hasMetalStructures = idx == 0)),
                    imagePicker: _buildMediaPicker(entrance, 'metal'),
                  ),
                  const SizedBox(height: 16),

                  _buildFormRow(
                    label: "Autres Systèmes proches ?",
                    input: _buildPremiumSegmentedControl(["Oui", "Non"], entrance.hasOtherSystems ? 0 : 1, (idx) => setState(() => entrance.hasOtherSystems = idx == 0)),
                    imagePicker: _buildMediaPicker(entrance, 'otherSystems'),
                  ),
                  const SizedBox(height: 32),
                ],

                if (_isCountingStudy) ...[
                  Text("Configuration Comptage", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kCountingColor, fontSize: 14)),
                  const SizedBox(height: 16),

                  _buildToggleRow("Nécessite Caméra ?", Icons.videocam_rounded, kCountingColor, entrance.needsCountCamera, (val) => setState(() => entrance.needsCountCamera = val)),

                  if (entrance.needsCountCamera) ...[
                    const SizedBox(height: 16),
                    _buildFormRow(
                      label: "Hauteur Plafond (m)",
                      input: _buildPremiumTextField(controller: entrance.cameraHeightController, label: "Ex: 3.2", isNumber: true),
                      imagePicker: _buildMediaPicker(entrance, 'cameraHeight'),
                    ),
                    const SizedBox(height: 16),
                    _buildFormRow(
                      label: "Type de Plafond",
                      input: _buildPremiumDropdown(
                        value: entrance.ceilingType,
                        items: ["Placo", "Dalle Faux Plafond", "Béton Brut", "Métallique"],
                        onChanged: (v) => setState(() => entrance.ceilingType = v),
                        hint: "Sélectionner...",
                      ),
                      imagePicker: _buildMediaPicker(entrance, 'ceilingType'),
                    ),
                    const SizedBox(height: 16),
                    _buildFormRow(
                      label: "Besoin de Potence ?",
                      input: _buildPremiumSegmentedControl(["Oui", "Non"], entrance.needsPoleSupport ? 0 : 1, (idx) => setState(() => entrance.needsPoleSupport = idx == 0)),
                      imagePicker: _buildMediaPicker(entrance, 'pole'),
                    ),
                    const SizedBox(height: 16),
                    _buildFormRow(
                      label: "Câble Cat6 Disponible ?",
                      input: _buildPremiumSegmentedControl(["Oui", "Non"], entrance.hasCat6 ? 0 : 1, (idx) => setState(() => entrance.hasCat6 = idx == 0)),
                      imagePicker: _buildMediaPicker(entrance, 'cat6'),
                    ),
                    if (!entrance.hasCat6) ...[
                      const SizedBox(height: 16),
                      _buildFormRow(
                        label: "Distance Tirage (m)",
                        input: _buildPremiumTextField(controller: entrance.cableDistanceController, label: "Ex: 45", isNumber: true),
                        imagePicker: _buildMediaPicker(entrance, 'cableDistance'),
                      ),
                    ],
                  ]
                ],

                const SizedBox(height: 24),
                Text("Galerie Photos Additionnelles", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextDark, fontSize: 14)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ...entrance.galleryMedia.asMap().entries.map((g) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(g.value, width: 70, height: 70, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -6, right: -6,
                            child: GestureDetector(
                              onTap: () => setState(() => entrance.galleryMedia.removeAt(g.key)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      );
                    }),
                    InkWell(
                      onTap: () => _pickSingleFile((f) { if(f != null) setState(() => entrance.galleryMedia.add(f)); }),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          color: kBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBorderColor),
                        ),
                        child: const Icon(Icons.add_photo_alternate_rounded, color: kTextLight),
                      ),
                    )
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAddEntranceButton() {
    return InkWell(
      onTap: () => setState(() => _entrances.add(EntranceData())),
      borderRadius: BorderRadius.circular(kRadius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: kPrimaryColor.withOpacity(0.3), style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline_rounded, color: kPrimaryColor),
            const SizedBox(width: 8),
            Text("Ajouter une Entrée/Zone", style: GoogleFonts.inter(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

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

  // ---------------------------------------------------------------------------
  // 🛠️ HELPER WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildFormRow({required String label, required Widget input, Widget? imagePicker}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextDark, fontSize: 14)),
        const SizedBox(height: 8),
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

  Widget _buildPremiumTextField({required TextEditingController controller, required String label, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: GoogleFonts.inter(),
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
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: GoogleFonts.inter()))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPremiumSegmentedControl(List<String> options, int selectedIndex, Function(int) onSelected) {
    return Container(
      height: 52, // Slightly taller for a better touch target
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03), // Subtle inset shadow effect
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: options.asMap().entries.map((entry) {
          final isSelected = entry.key == selectedIndex;
          final text = entry.value;

          // Detect if it's a Yes/No option to apply colorful logic
          final isOui = text.toLowerCase() == 'oui';
          final isNon = text.toLowerCase() == 'non';

          // Default styling (if it's not Oui/Non)
          Color activeBgColor = kSurfaceColor;
          Color activeTextColor = kTextDark;
          Color shadowColor = Colors.black.withOpacity(0.05);
          IconData? icon;

          // Contextual Colorful Styling
          if (isOui) {
            activeBgColor = const Color(0xFF10B981); // Emerald Green
            activeTextColor = Colors.white;
            shadowColor = activeBgColor.withOpacity(0.4);
            icon = Icons.check_circle_outline_rounded;
          } else if (isNon) {
            activeBgColor = const Color(0xFFEF4444); // Rose Red
            activeTextColor = Colors.white;
            shadowColor = activeBgColor.withOpacity(0.4);
            icon = Icons.highlight_off_rounded;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(entry.key),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300), // Buttery smooth duration
                curve: Curves.easeOutCubic, // Apple-style deceleration curve
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? activeBgColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected ? [
                    BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 4))
                  ] : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected ? activeTextColor : Colors.transparent, // Hides icon when not selected
                      ),
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

  Widget _buildMediaPicker(EntranceData entrance, String mediaKey) {
    return _buildPremiumImagePicker(
      entrance.media[mediaKey],
          (file) => setState(() => entrance.setMedia(mediaKey, file)),
    );
  }

  Widget _buildPremiumImagePicker(File? currentFile, Function(File?) onChanged) {
    if (currentFile != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
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
      );
    } else {
      return InkWell(
        onTap: () => _pickSingleFile(onChanged),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: kBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderColor),
          ),
          child: const Icon(Icons.camera_alt_rounded, color: kTextLight, size: 20),
        ),
      );
    }
  }
}
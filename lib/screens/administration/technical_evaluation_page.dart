// lib/screens/administration/technical_evaluation_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

// ✅ Imports for Backblaze B2 upload
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';

// -----------------------------------------------------------------------------
// DATA MODELS
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
  String? flowType; // e.g., "Entrée Principale", "Escalator Montant"

  // --- STANDARD EVALUATION DATA ---
  String? entranceType;
  String? doorType;

  // --- STANDARD EVALUATION MEDIA ---
  File? powerMedia;
  File? floorMedia;
  File? conduitMedia;
  File? trenchMedia;
  File? obstacleMedia;
  File? widthMedia;
  File? metalMedia;
  File? otherSystemsMedia;

  bool? isPowerAvailable;
  final TextEditingController powerNotesController = TextEditingController();

  bool? isFloorFinalized;
  bool? isConduitAvailable;
  bool? canMakeTrench;

  bool? hasObstacles;
  final TextEditingController obstacleNotesController = TextEditingController();
  final TextEditingController entranceWidthController = TextEditingController();

  bool? hasMetalStructures;
  bool? hasOtherSystems;

  // --- NEW: COUNTING (COMPTAGE) DATA ---
  bool needsCountCamera = false; // Toggle per entrance

  final TextEditingController cameraHeightController = TextEditingController();
  File? cameraHeightMedia;

  String? ceilingType; // Dalle, Placo, Beton
  File? ceilingTypeMedia;

  bool? needsPoleSupport;
  File? poleMedia;

  bool? hasCat6;
  File? cat6Media;

  final TextEditingController cableDistanceController = TextEditingController();
  File? cableDistanceMedia;

  // Generic extras
  List<File> mediaFiles = [];

  void dispose() {
    locationNameController.dispose();
    zoneNameController.dispose();
    powerNotesController.dispose();
    obstacleNotesController.dispose();
    entranceWidthController.dispose();
    cameraHeightController.dispose();
    cableDistanceController.dispose();
  }

  Map<String, dynamic> getDataMap() {
    return {
      // Mall Specifics
      'locationName': locationNameController.text,
      'zoneName': zoneNameController.text,
      'flowType': flowType,

      // Standard
      'entranceType': entranceType,
      'doorType': doorType,
      'isPowerAvailable': isPowerAvailable,
      'powerNotes': powerNotesController.text,
      'isFloorFinalized': isFloorFinalized,
      'isConduitAvailable': isConduitAvailable,
      'canMakeTrench': canMakeTrench,
      'hasObstacles': hasObstacles,
      'obstacleNotes': obstacleNotesController.text,
      'entranceWidth': entranceWidthController.text,
      'hasMetalStructures': hasMetalStructures,
      'hasOtherSystems': hasOtherSystems,

      // Counting
      'needsCountCamera': needsCountCamera,
      'cameraHeight': cameraHeightController.text,
      'ceilingType': ceilingType,
      'needsPoleSupport': needsPoleSupport,
      'hasCat6': hasCat6,
      'cableDistance': cableDistanceController.text,
      // File URLs are added in _saveEvaluation
    };
  }
}

// -----------------------------------------------------------------------------
// MAIN PAGE WIDGET
// -----------------------------------------------------------------------------

class TechnicalEvaluationPage extends StatefulWidget {
  final String projectId;
  const TechnicalEvaluationPage({super.key, required this.projectId});

  @override
  State<TechnicalEvaluationPage> createState() =>
      _TechnicalEvaluationPageState();
}

class _TechnicalEvaluationPageState extends State<TechnicalEvaluationPage> {
  final List<EntranceData> _entrances = [];
  final CountingGlobalData _countingGlobal = CountingGlobalData();

  // --- MODE FLAGS ---
  bool _isMallMode = false;           // Default: Magasin (Store)
  bool _includeAntivolEvaluation = true; // Default: Include Antivol checks
  bool _includeCountingStudy = false;    // Default: No counting

  bool _isLoading = false;
  static const Color primaryColor = Colors.deepPurple;
  static const Color countingColor = Colors.teal;
  static const Color mallColor = Colors.indigo;

  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl';

  @override
  void initState() {
    super.initState();
    _addEntrance();
  }

  @override
  void dispose() {
    for (var entrance in _entrances) {
      entrance.dispose();
    }
    super.dispose();
  }

  // --- LOGIC: MODE SWITCHING ---
  void _setProjectMode(bool isMall) {
    setState(() {
      _isMallMode = isMall;
      if (_isMallMode) {
        // Mall Defaults: Hide Antivol, Show Counting
        _includeAntivolEvaluation = false;
        _includeCountingStudy = true;
      } else {
        // Store Defaults: Show Antivol, Hide Counting (user can toggle)
        _includeAntivolEvaluation = true;
        _includeCountingStudy = false;
      }
    });
  }

  // ✅ --- B2 HELPER FUNCTIONS ---

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
        required String subFolder,
        String? category,
      }) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();

      final String originalFileName = path.basename(file.path);
      final String extension = path.extension(originalFileName).toLowerCase();

      String folderName = category ?? 'misc';

      // Construct B2 File Name
      final String b2FileName =
          'technical_evaluations/$projectId/$subFolder/$folderName/$originalFileName';

      // Determine mime type
      String? mimeType;
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
          'Content-Type': mimeType ?? 'b2/x-auto',
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

  // --- UI ACTIONS ---

  void _addEntrance() {
    setState(() {
      final e = EntranceData();
      // Auto-enable camera if counting study is active
      if (_includeCountingStudy) e.needsCountCamera = true;
      _entrances.add(e);
    });
  }

  void _removeEntrance(int index) {
    _entrances[index].dispose();
    setState(() {
      _entrances.removeAt(index);
    });
  }

  Future<void> _pickSingleFile(ValueChanged<File?> onFilePicked) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = File(result.files.first.path!);
      onFilePicked(file);
    }
  }

  Future<void> _pickMedia(int entranceIndex) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _entrances[entranceIndex]
            .mediaFiles
            .addAll(result.files.map((f) => File(f.path!)).toList());
      });
    }
  }

  void _openMediaPreview(BuildContext context, File file) {
    final String extension = path.extension(file.path).toLowerCase();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: const CloseButton(color: Colors.black),
            ),
            if (['.jpg', '.jpeg', '.png'].contains(extension))
              Image.file(file)
            else
              const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("Prévisualisation non disponible")),
          ],
        ),
      ),
    );
  }

  // ✅ SAVE LOGIC
  Future<void> _saveEvaluation() async {
    setState(() {
      _isLoading = true;
    });

    final b2Credentials = await _getB2UploadCredentials();
    if (b2Credentials == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Erreur B2 Credentials'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      // 1. Save Global Counting Data
      Map<String, dynamic> globalCountingMap = {};
      if (_includeCountingStudy) {
        globalCountingMap = _countingGlobal.getDataMap();

        Future<void> upGlobal(File? f, String key) async {
          if (f != null) {
            String? url = await _uploadFileToB2(f, b2Credentials,
                projectId: widget.projectId, subFolder: 'global_counting', category: key);
            if (url != null) globalCountingMap['${key}Url'] = url;
          }
        }

        await upGlobal(_countingGlobal.hostingMedia, 'hosting');
        await upGlobal(_countingGlobal.poeMedia, 'poe_switch');
        await upGlobal(_countingGlobal.rackSpaceMedia, 'rack_space');
      }

      // 2. Save Entrances
      final List<Map<String, dynamic>> evaluationData = [];

      for (final entry in _entrances.asMap().entries) {
        final int index = entry.key;
        final EntranceData entrance = entry.value;
        final Map<String, dynamic> entranceMap = entrance.getDataMap();

        // Helper for Entrance Uploads
        Future<void> upEnt(File? f, String cat, String key) async {
          if (f != null) {
            String? url = await _uploadFileToB2(f, b2Credentials,
                projectId: widget.projectId,
                subFolder: 'entrance_$index',
                category: cat);
            if (url != null) entranceMap[key] = url;
          }
        }

        // Standard Uploads (Only if Antivol/Standard is enabled)
        if (_includeAntivolEvaluation) {
          await upEnt(entrance.powerMedia, 'power', 'powerPhotoUrl');
          await upEnt(entrance.floorMedia, 'floor', 'floorPhotoUrl');
          await upEnt(entrance.conduitMedia, 'conduit', 'conduitPhotoUrl');
          await upEnt(entrance.trenchMedia, 'trench', 'trenchPhotoUrl');
          await upEnt(entrance.obstacleMedia, 'obstacles', 'obstaclePhotoUrl');
          await upEnt(entrance.widthMedia, 'width', 'widthPhotoUrl');
          await upEnt(entrance.metalMedia, 'env', 'metalPhotoUrl');
          await upEnt(entrance.otherSystemsMedia, 'env', 'otherSystemsPhotoUrl');
        }

        // Counting Uploads (only if enabled)
        if (_includeCountingStudy && entrance.needsCountCamera) {
          await upEnt(entrance.cameraHeightMedia, 'counting', 'cameraHeightPhotoUrl');
          await upEnt(entrance.ceilingTypeMedia, 'counting', 'ceilingTypePhotoUrl');
          await upEnt(entrance.poleMedia, 'counting', 'polePhotoUrl');
          await upEnt(entrance.cat6Media, 'counting', 'cat6PhotoUrl');
          await upEnt(entrance.cableDistanceMedia, 'counting', 'cableDistancePhotoUrl');
        }

        // Generic
        final List<String> mediaUrls = [];
        for (final file in entrance.mediaFiles) {
          final String? u = await _uploadFileToB2(file, b2Credentials,
              projectId: widget.projectId, subFolder: 'entrance_$index');
          if (u != null) mediaUrls.add(u);
        }
        entranceMap['media'] = mediaUrls;

        evaluationData.add(entranceMap);
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({
        'technical_evaluation': evaluationData,
        'counting_evaluation_global': _includeCountingStudy ? globalCountingMap : null,
        'is_mall_mode': _isMallMode,
        'has_antivol_evaluation': _includeAntivolEvaluation,
        'has_counting_study': _includeCountingStudy,
        'status': 'Évaluation Technique Terminé',
      });

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur Save: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UI BUILDERS (Compact & Sliver)
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // 1. FLOATING APP BAR (Hides on scroll)
          SliverAppBar(
            title: const Text('Évaluation Technique'),
            backgroundColor: primaryColor,
            floating: true, // This allows the app bar to appear/disappear on scroll
            snap: true,
            pinned: false,
          ),

          // 2. COMPACT CONFIG HEADER (Scrolls away)
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  // Mode Row
                  Row(
                    children: [
                      Expanded(child: _buildModeSegment()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Compact Toggles
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCompactToggle(
                          label: "Antivol",
                          icon: Icons.security,
                          value: _includeAntivolEvaluation,
                          color: primaryColor,
                          onChanged: (v) => setState(() => _includeAntivolEvaluation = v),
                        ),
                        const SizedBox(width: 12),
                        _buildCompactToggle(
                          label: "Comptage",
                          icon: Icons.people_outline,
                          value: _includeCountingStudy,
                          color: countingColor,
                          onChanged: (v) => setState(() => _includeCountingStudy = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. GLOBAL COUNTING CARD (If enabled)
          if (_includeCountingStudy)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildGlobalCountingCard(),
              ),
            ),

          // 4. LIST OF ENTRANCES
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildEntranceCard(index),
                );
              },
              childCount: _entrances.length,
            ),
          ),

          // 5. ACTION BUTTONS (Bottom)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextButton.icon(
                    onPressed: _addEntrance,
                    icon: const Icon(Icons.add_circle_outline, size: 28),
                    label: Text(
                        _isMallMode ? 'Ajouter une Zone / Point de Flux' : 'Ajouter une Autre Entrée',
                        style: const TextStyle(fontSize: 16)
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveEvaluation,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0))),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Enregistrer l\'Évaluation'),
                    ),
                  ),
                  const SizedBox(height: 40), // Safe area at bottom
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ New Compact Chip Toggle
  Widget _buildCompactToggle({
    required String label,
    required IconData icon,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return FilterChip(
      label: Text(label),
      avatar: value ? Icon(Icons.check, size: 18, color: color) : Icon(icon, size: 18, color: Colors.grey),
      selected: value,
      onSelected: onChanged,
      checkmarkColor: color,
      selectedColor: color.withOpacity(0.1),
      labelStyle: TextStyle(
        color: value ? color : Colors.black87,
        fontWeight: value ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(color: value ? color : Colors.grey.shade300),
    );
  }

  Widget _buildModeSegment() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSegmentButton("Magasin", Icons.store, !_isMallMode, () => _setProjectMode(false))),
          Expanded(child: _buildSegmentButton("Centre C.", Icons.local_mall, _isMallMode, () => _setProjectMode(true))),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (_isMallMode ? mallColor : primaryColor) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 2)] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalCountingCard() {
    return Card(
      color: Colors.teal.shade50,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: countingColor.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.hub_outlined, color: countingColor),
                SizedBox(width: 8),
                Text('Infrastructure Comptage (Global)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: countingColor)),
              ],
            ),
            const Divider(color: countingColor),
            const SizedBox(height: 8),

            // Server Question
            const Text('Sur quel équipement installer le logiciel ?', style: TextStyle(fontWeight: FontWeight.w500)),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _countingGlobal.hostingDevice,
                    hint: const Text('PC / Laptop / TPV'),
                    items: ['PC Desktop', 'Laptop', 'TPV (Caisse)', 'Serveur Dédié'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _countingGlobal.hostingDevice = v),
                  ),
                ),
                const SizedBox(width: 8),
                _buildMiniMediaButton(
                  file: _countingGlobal.hostingMedia,
                  onChanged: (f) => setState(() => _countingGlobal.hostingMedia = f),
                )
              ],
            ),
            const SizedBox(height: 16),

            // PoE Question
            _buildYesNoQuestion(
              question: 'Switch PoE existant pour les caméras ?',
              value: _countingGlobal.hasPoeSwitch,
              onChanged: (v) => setState(() => _countingGlobal.hasPoeSwitch = v),
              mediaFile: _countingGlobal.poeMedia,
              onMediaChanged: (f) => setState(() => _countingGlobal.poeMedia = f),
            ),

            // Rack Space Question
            _buildYesNoQuestion(
              question: 'Espace disponible dans la baie/armoire ?',
              value: _countingGlobal.hasRackSpace,
              onChanged: (v) => setState(() => _countingGlobal.hasRackSpace = v),
              mediaFile: _countingGlobal.rackSpaceMedia,
              onMediaChanged: (f) => setState(() => _countingGlobal.rackSpaceMedia = f),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntranceCard(int index) {
    final entrance = _entrances[index];
    final OutlineInputBorder defaultBorder = OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12.0));

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    _isMallMode ? 'Point de Flux #${index + 1}' : 'Entrée #${index + 1}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold, color: _isMallMode ? mallColor : primaryColor)),
                if (_entrances.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeEntrance(index),
                  ),
              ],
            ),
            const Divider(height: 16),

            // ✅ MALL SPECIFIC: IDENTITY FIELDS
            if (_isMallMode) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: mallColor.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    TextFormField(
                      controller: entrance.locationNameController,
                      decoration: InputDecoration(
                          labelText: 'Nom de l\'emplacement (ex: Porte Nord)',
                          border: defaultBorder,
                          prefixIcon: const Icon(Icons.label_outline, color: mallColor)
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: entrance.zoneNameController,
                            decoration: InputDecoration(
                                labelText: 'Zone / Niveau (ex: RDC)',
                                border: defaultBorder
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: entrance.flowType,
                            hint: const Text('Type de Flux'),
                            decoration: InputDecoration(border: defaultBorder),
                            items: ['Entrée Extérieure', 'Flux Interne', 'Sortie Parking', 'Autre']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => entrance.flowType = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // BASIC INFO (Common)
            if (!_isMallMode) ...[
              DropdownButtonFormField<String>(
                value: entrance.entranceType,
                hint: const Text('Type d\'entrée'),
                decoration: InputDecoration(border: defaultBorder),
                items: ['Porte battante', 'Porte Automatique', 'Entree Libre']
                    .map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                onChanged: (value) => setState(() => entrance.entranceType = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: entrance.doorType,
                hint: const Text('Type de porte'),
                decoration: InputDecoration(border: defaultBorder),
                items: ['porte vitrée', 'porte metalique', 'sans porte']
                    .map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                onChanged: (value) => setState(() => entrance.doorType = value),
              ),
              const SizedBox(height: 16),
            ],

            // ✅ CONDITIONAL: ANTIVOL / TECHNICAL SECTIONS
            if (_includeAntivolEvaluation) ...[
              _buildExpansionSection(
                title: 'Alimentation Électrique',
                icon: Icons.power,
                child: Column(
                  children: [
                    _buildYesNoQuestion(
                      question: 'Prise 220V disponible à moins de 2m ?',
                      value: entrance.isPowerAvailable,
                      onChanged: (val) =>
                          setState(() => entrance.isPowerAvailable = val),
                      mediaFile: entrance.powerMedia,
                      onMediaChanged: (f) =>
                          setState(() => entrance.powerMedia = f),
                    ),
                    if (entrance.isPowerAvailable == false)
                      _buildConditionalTextField(
                        controller: entrance.powerNotesController,
                        labelText: 'Emplacement de la source la plus proche',
                      ),
                  ],
                ),
              ),
              _buildExpansionSection(
                title: 'Sol et Passage des Câbles',
                icon: Icons.electrical_services,
                child: Column(
                  children: [
                    _buildYesNoQuestion(
                      question: 'L\'état du sol est-il finalisé ?',
                      value: entrance.isFloorFinalized,
                      onChanged: (val) =>
                          setState(() => entrance.isFloorFinalized = val),
                      mediaFile: entrance.floorMedia,
                      onMediaChanged: (f) =>
                          setState(() => entrance.floorMedia = f),
                    ),
                    if (entrance.isFloorFinalized == true)
                      _buildYesNoQuestion(
                        question: 'Un fourreau vide est-il disponible ?',
                        value: entrance.isConduitAvailable,
                        onChanged: (val) =>
                            setState(() => entrance.isConduitAvailable = val),
                        mediaFile: entrance.conduitMedia,
                        onMediaChanged: (f) =>
                            setState(() => entrance.conduitMedia = f),
                      ),
                    if (entrance.isConduitAvailable == false)
                      _buildYesNoQuestion(
                        question: 'Le client autorise-t-il une saignée ?',
                        value: entrance.canMakeTrench,
                        onChanged: (val) =>
                            setState(() => entrance.canMakeTrench = val),
                        mediaFile: entrance.trenchMedia,
                        onMediaChanged: (f) =>
                            setState(() => entrance.trenchMedia = f),
                      ),
                  ],
                ),
              ),
              _buildExpansionSection(
                title: 'Zone d\'Installation et Obstacles',
                icon: Icons.warning_amber_rounded,
                child: Column(
                  children: [
                    _buildYesNoQuestion(
                      question: 'Y a-t-il des obstacles (portes, rideaux) ?',
                      value: entrance.hasObstacles,
                      onChanged: (val) =>
                          setState(() => entrance.hasObstacles = val),
                      mediaFile: entrance.obstacleMedia,
                      onMediaChanged: (f) =>
                          setState(() => entrance.obstacleMedia = f),
                    ),
                    if (entrance.hasObstacles == true)
                      _buildConditionalTextField(
                        controller: entrance.obstacleNotesController,
                        labelText: 'Veuillez les décrire',
                      ),
                    const SizedBox(height: 16),
                    _buildTextFieldWithPhoto(
                      controller: entrance.entranceWidthController,
                      label: "Largeur de l'entrée (m)",
                      media: entrance.widthMedia,
                      onMediaChanged: (f) => setState(() => entrance.widthMedia = f),
                      type: TextInputType.number,
                    ),
                  ],
                ),
              ),
              _buildExpansionSection(
                title: 'Environnement et Interférences',
                icon: Icons.wifi_tethering,
                child: Column(
                  children: [
                    _buildYesNoQuestion(
                      question: 'Grandes structures métalliques à proximité ?',
                      value: entrance.hasMetalStructures,
                      onChanged: (val) =>
                          setState(() => entrance.hasMetalStructures = val),
                      mediaFile: entrance.metalMedia,
                      onMediaChanged: (f) =>
                          setState(() => entrance.metalMedia = f),
                    ),
                    _buildYesNoQuestion(
                      question: 'Autres systèmes électroniques présents ?',
                      value: entrance.hasOtherSystems,
                      onChanged: (val) =>
                          setState(() => entrance.hasOtherSystems = val),
                      mediaFile: entrance.otherSystemsMedia,
                      onMediaChanged: (f) =>
                          setState(() => entrance.otherSystemsMedia = f),
                    ),
                  ],
                ),
              ),
            ],

            // ✅ COUNTING SECTION (Conditional)
            if (_includeCountingStudy)
              Container(
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: countingColor.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.teal.shade50.withOpacity(0.3),
                ),
                child: ExpansionTile(
                  initiallyExpanded: _isMallMode, // Auto-expand in Mall Mode
                  leading: const Icon(Icons.people, color: countingColor),
                  title: const Text('Étude Caméra Comptage', style: TextStyle(fontWeight: FontWeight.bold, color: countingColor)),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    // Enable Toggle for this specific entrance
                    SwitchListTile(
                      title: const Text('Installer une caméra ici ?'),
                      value: entrance.needsCountCamera,
                      activeColor: countingColor,
                      onChanged: (v) => setState(() => entrance.needsCountCamera = v),
                    ),

                    if (entrance.needsCountCamera) ...[
                      const Divider(),
                      // Height
                      _buildTextFieldWithPhoto(
                        controller: entrance.cameraHeightController,
                        label: 'Hauteur d\'installation (m)',
                        media: entrance.cameraHeightMedia,
                        onMediaChanged: (f) => setState(() => entrance.cameraHeightMedia = f),
                        type: TextInputType.number,
                      ),
                      const SizedBox(height: 12),

                      // Ceiling Type
                      const Text('Type de Plafond', style: TextStyle(fontSize: 12)),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: entrance.ceilingType,
                              hint: const Text('Selectionner'),
                              items: ['Dalle (Faux plafond)', 'Placo (Dur)', 'Béton', 'Aucun / Ouvert']
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) => setState(() => entrance.ceilingType = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildMiniMediaButton(
                            file: entrance.ceilingTypeMedia,
                            onChanged: (f) => setState(() => entrance.ceilingTypeMedia = f),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Pole Support
                      _buildYesNoQuestion(
                        question: 'Besoin d\'un support/perche ?',
                        value: entrance.needsPoleSupport,
                        onChanged: (v) => setState(() => entrance.needsPoleSupport = v),
                        mediaFile: entrance.poleMedia,
                        onMediaChanged: (f) => setState(() => entrance.poleMedia = f),
                      ),

                      // Cat6
                      _buildYesNoQuestion(
                        question: 'Câble Cat6 déjà disponible ?',
                        value: entrance.hasCat6,
                        onChanged: (v) => setState(() => entrance.hasCat6 = v),
                        mediaFile: entrance.cat6Media,
                        onMediaChanged: (f) => setState(() => entrance.cat6Media = f),
                      ),

                      // Distance to pull
                      if (entrance.hasCat6 == false)
                        _buildTextFieldWithPhoto(
                          controller: entrance.cableDistanceController,
                          label: 'Distance de tirage câble (m) vers Baie',
                          media: entrance.cableDistanceMedia,
                          onMediaChanged: (f) => setState(() => entrance.cableDistanceMedia = f),
                          type: TextInputType.number,
                        ),
                    ]
                  ],
                ),
              ),

            // EXTRA PHOTOS
            const SizedBox(height: 12),
            _buildExpansionSection(
              title: 'Galerie Photos (Extra)',
              icon: Icons.photo_library_outlined,
              child: Column(
                children: [
                  if (entrance.mediaFiles.isNotEmpty)
                    Container(
                      height: 100,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: entrance.mediaFiles.length,
                        itemBuilder: (context, mediaIndex) {
                          return _buildMediaThumbnail(
                              entrance.mediaFiles[mediaIndex]);
                        },
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickMedia(index),
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Ajouter photos en vrac'),
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

  // --- WIDGET HELPERS ---

  Widget _buildMediaThumbnail(File file) {
    String extension = path.extension(file.path).toLowerCase();
    Widget thumbnail;
    if (['.jpg', '.jpeg', '.png'].contains(extension)) {
      thumbnail = Image.file(file, width: 100, height: 100, fit: BoxFit.cover);
    } else {
      thumbnail = Container(
        width: 100,
        height: 100,
        color: Colors.grey.shade300,
        child: const Icon(Icons.insert_drive_file, size: 40, color: Colors.black54),
      );
    }
    return GestureDetector(
      onTap: () => _openMediaPreview(context, file),
      child: Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: thumbnail,
        ),
      ),
    );
  }

  Widget _buildExpansionSection(
      {required String title, required IconData icon, required Widget child}) {
    return ExpansionTile(
      leading: Icon(icon, color: primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [child],
    );
  }

  Widget _buildYesNoQuestion({
    required String question,
    required bool? value,
    required ValueChanged<bool> onChanged,
    File? mediaFile,
    ValueChanged<File?>? onMediaChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(question, style: const TextStyle(fontSize: 14))),
              if (onMediaChanged != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: _buildMiniMediaButton(
                      file: mediaFile, onChanged: onMediaChanged),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ToggleButtons(
            isSelected: [value == true, value == false],
            onPressed: (index) => onChanged(index == 0),
            borderRadius: BorderRadius.circular(8),
            selectedColor: Colors.white,
            fillColor: primaryColor,
            children: const [
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Oui')),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Non')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldWithPhoto({
    required TextEditingController controller,
    required String label,
    required File? media,
    required ValueChanged<File?> onMediaChanged,
    TextInputType type = TextInputType.text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: type,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildMiniMediaButton(file: media, onChanged: onMediaChanged),
      ],
    );
  }

  Widget _buildMiniMediaButton(
      {required File? file, required ValueChanged<File?> onChanged}) {
    if (file != null) {
      return GestureDetector(
        onTap: () => _openMediaPreview(context, file),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.file(file,
                    width: 48, height: 48, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () => onChanged(null),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close,
                      size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300)),
        child: IconButton(
          onPressed: () => _pickSingleFile(onChanged),
          icon: const Icon(Icons.camera_alt, color: Colors.blueGrey),
          tooltip: "Preuve photo",
        ),
      );
    }
  }

  Widget _buildConditionalTextField(
      {required TextEditingController controller, required String labelText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
        maxLines: 2,
      ),
    );
  }
}
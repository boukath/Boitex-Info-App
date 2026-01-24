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

class EntranceData {
  String? entranceType;
  String? doorType;

  // ✅ Specific media files for each question
  File? powerMedia;
  File? floorMedia;
  File? conduitMedia;
  File? trenchMedia;
  File? obstacleMedia;
  File? widthMedia;
  File? metalMedia;
  File? otherSystemsMedia;

  // Keep generic list for extra files
  List<File> mediaFiles = [];

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

  void dispose() {
    powerNotesController.dispose();
    obstacleNotesController.dispose();
    entranceWidthController.dispose();
  }

  Map<String, dynamic> getDataMap() {
    return {
      'entranceType': entranceType,
      'doorType': doorType,
      // Note: File URLs are added in _saveEvaluation
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
    };
  }
}

class TechnicalEvaluationPage extends StatefulWidget {
  final String projectId;
  const TechnicalEvaluationPage({super.key, required this.projectId});

  @override
  State<TechnicalEvaluationPage> createState() => _TechnicalEvaluationPageState();
}

class _TechnicalEvaluationPageState extends State<TechnicalEvaluationPage> {
  final List<EntranceData> _entrances = [];
  bool _isLoading = false;
  static const Color primaryColor = Colors.deepPurple;

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
        required int entranceIndex,
        String? category, // ✅ Added category for folder organization
      }) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();

      final String originalFileName = path.basename(file.path);
      final String extension = path.extension(originalFileName).toLowerCase();

      String folderName;
      if (category != null) {
        folderName = category;
      } else {
        // Fallback logic
        if (['.jpg', '.jpeg', '.png'].contains(extension)) {
          folderName = 'photos';
        } else if (['.mp4', '.mov', '.avi'].contains(extension)) {
          folderName = 'videos';
        } else if (extension == '.pdf') {
          folderName = 'pdfs';
        } else {
          folderName = 'other_files';
        }
      }

      // Construct B2 File Name
      final String b2FileName =
          'technical_evaluations/$projectId/entrance_$entranceIndex/$folderName/$originalFileName';

      // Determine mime type
      String? mimeType;
      if (extension == '.jpg' || extension == '.jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == '.png') {
        mimeType = 'image/png';
      } else if (extension == '.mp4') {
        mimeType = 'video/mp4';
      } else if (extension == '.mov') {
        mimeType = 'video/quicktime';
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

  void _addEntrance() {
    setState(() {
      _entrances.add(EntranceData());
    });
  }

  void _removeEntrance(int index) {
    _entrances[index].dispose();
    setState(() {
      _entrances.removeAt(index);
    });
  }

  // ✅ Generic File Picker for specific fields
  Future<void> _pickSingleFile(ValueChanged<File?> onFilePicked) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = File(result.files.first.path!);
      const maxFileSize = 50 * 1024 * 1024; // 50 MB
      if (file.lengthSync() <= maxFileSize) {
        onFilePicked(file);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Le fichier dépasse la limite de 50 Mo.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  // ✅ RESTORED: Bulk picker for generic/extra files
  Future<void> _pickMedia(int entranceIndex) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'pdf'],
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
        _entrances[entranceIndex].mediaFiles.addAll(
          validFiles.map((f) => File(f.path!)).toList(),
        );
      });

      if (rejectedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$rejectedCount fichier(s) dépassent la limite de 50 Mo.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // Helper to open photo
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
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.insert_drive_file, size: 60, color: Colors.grey),
                    const SizedBox(height: 10),
                    Text(path.basename(file.path)),
                    const Text("(Format non supporté pour la prévisualisation rapide)"),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ CHANGED: Saves all specific files
  Future<void> _saveEvaluation() async {
    setState(() { _isLoading = true; });

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
      final List<Map<String, dynamic>> evaluationData = [];

      for (final entry in _entrances.asMap().entries) {
        final int index = entry.key;
        final EntranceData entrance = entry.value;

        final Map<String, dynamic> entranceMap = entrance.getDataMap();

        // --- Upload Specific Files ---

        // Helper to upload and set key
        Future<void> uploadAndSet(File? file, String category, String keyName) async {
          if (file != null) {
            String? url = await _uploadFileToB2(
                file,
                b2Credentials,
                projectId: widget.projectId,
                entranceIndex: index,
                category: category
            );
            if (url != null) entranceMap[keyName] = url;
          }
        }

        await uploadAndSet(entrance.powerMedia, 'power', 'powerPhotoUrl');
        await uploadAndSet(entrance.floorMedia, 'floor', 'floorPhotoUrl');
        await uploadAndSet(entrance.conduitMedia, 'conduit', 'conduitPhotoUrl');
        await uploadAndSet(entrance.trenchMedia, 'trench', 'trenchPhotoUrl');
        await uploadAndSet(entrance.obstacleMedia, 'obstacles', 'obstaclePhotoUrl');
        await uploadAndSet(entrance.widthMedia, 'width', 'widthPhotoUrl');
        await uploadAndSet(entrance.metalMedia, 'environment', 'metalPhotoUrl');
        await uploadAndSet(entrance.otherSystemsMedia, 'environment', 'otherSystemsPhotoUrl');

        // --- Upload Generic Gallery Files ---
        final List<String> mediaUrls = [];
        for (final file in entrance.mediaFiles) {
          final String? downloadUrl = await _uploadFileToB2(
            file,
            b2Credentials,
            projectId: widget.projectId,
            entranceIndex: index,
            // No category means it uses extension-based folders (photos/videos)
          );
          if (downloadUrl != null) mediaUrls.add(downloadUrl);
        }
        entranceMap['media'] = mediaUrls;

        evaluationData.add(entranceMap);
      }

      await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
        'technical_evaluation': evaluationData,
        'status': 'Évaluation Technique Terminé',
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
        title: const Text('Évaluation Technique'),
        backgroundColor: primaryColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _entrances.length,
              itemBuilder: (context, index) {
                return _buildEntranceCard(index);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0,-4))],
            ),
            child: Column(
              children: [
                TextButton.icon(
                  onPressed: _addEntrance,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une Autre Entrée'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveEvaluation,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))
                    ),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Enregistrer l\'Évaluation'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntranceCard(int index) {
    final entrance = _entrances[index];
    final OutlineInputBorder defaultBorder = OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12.0));

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Entrée #${index + 1}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
                if (_entrances.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeEntrance(index),
                  ),
              ],
            ),
            const Divider(height: 24),

            DropdownButtonFormField<String>(
              value: entrance.entranceType,
              hint: const Text('Type d\'entrée'),
              decoration: InputDecoration(border: defaultBorder),
              items: ['Porte battante', 'Porte Automatique', 'Entree Libre'].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (value) => setState(() => entrance.entranceType = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: entrance.doorType,
              hint: const Text('Type de porte'),
              decoration: InputDecoration(border: defaultBorder),
              items: ['porte vitrée', 'porte metalique', 'sans porte'].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (value) => setState(() => entrance.doorType = value),
            ),
            const SizedBox(height: 16),

            // Accordion Sections
            _buildExpansionSection(
              title: 'Alimentation Électrique',
              icon: Icons.power,
              child: Column(
                children: [
                  _buildYesNoQuestion(
                    question: 'Prise 220V disponible à moins de 2m ?',
                    value: entrance.isPowerAvailable,
                    onChanged: (val) => setState(() => entrance.isPowerAvailable = val),
                    mediaFile: entrance.powerMedia,
                    onMediaChanged: (f) => setState(() => entrance.powerMedia = f),
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
                    onChanged: (val) => setState(() => entrance.isFloorFinalized = val),
                    mediaFile: entrance.floorMedia,
                    onMediaChanged: (f) => setState(() => entrance.floorMedia = f),
                  ),
                  if (entrance.isFloorFinalized == true)
                    _buildYesNoQuestion(
                      question: 'Un fourreau vide est-il disponible ?',
                      value: entrance.isConduitAvailable,
                      onChanged: (val) => setState(() => entrance.isConduitAvailable = val),
                      mediaFile: entrance.conduitMedia,
                      onMediaChanged: (f) => setState(() => entrance.conduitMedia = f),
                    ),
                  if (entrance.isConduitAvailable == false)
                    _buildYesNoQuestion(
                      question: 'Le client autorise-t-il une saignée ?',
                      value: entrance.canMakeTrench,
                      onChanged: (val) => setState(() => entrance.canMakeTrench = val),
                      mediaFile: entrance.trenchMedia,
                      onMediaChanged: (f) => setState(() => entrance.trenchMedia = f),
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
                    onChanged: (val) => setState(() => entrance.hasObstacles = val),
                    mediaFile: entrance.obstacleMedia,
                    onMediaChanged: (f) => setState(() => entrance.obstacleMedia = f),
                  ),
                  if (entrance.hasObstacles == true)
                    _buildConditionalTextField(
                      controller: entrance.obstacleNotesController,
                      labelText: 'Veuillez les décrire',
                    ),
                  const SizedBox(height: 16),

                  // Width field with specific photo button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: entrance.entranceWidthController,
                          decoration: const InputDecoration(labelText: 'Largeur de l\'entrée (m)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildMiniMediaButton(
                          file: entrance.widthMedia,
                          onChanged: (f) => setState(() => entrance.widthMedia = f)
                      ),
                    ],
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
                    onChanged: (val) => setState(() => entrance.hasMetalStructures = val),
                    mediaFile: entrance.metalMedia,
                    onMediaChanged: (f) => setState(() => entrance.metalMedia = f),
                  ),
                  _buildYesNoQuestion(
                    question: 'Autres systèmes électroniques présents ?',
                    value: entrance.hasOtherSystems,
                    onChanged: (val) => setState(() => entrance.hasOtherSystems = val),
                    mediaFile: entrance.otherSystemsMedia,
                    onMediaChanged: (f) => setState(() => entrance.otherSystemsMedia = f),
                  ),
                ],
              ),
            ),
            _buildExpansionSection(
              title: 'Photos Supplémentaires',
              icon: Icons.camera_alt_outlined,
              child: Column(
                children: [
                  // Legacy bulk upload for extra photos
                  if (entrance.mediaFiles.isNotEmpty)
                    Container(
                      height: 100,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: entrance.mediaFiles.length,
                        itemBuilder: (context, mediaIndex) {
                          return _buildMediaThumbnail(entrance.mediaFiles[mediaIndex]);
                        },
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickMedia(index), // Keeps bulk picker for generic files
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Ajouter d\'autres photos/vidéos'),
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

  // Legacy builder for list
  Widget _buildMediaThumbnail(File file) {
    String extension = path.extension(file.path).toLowerCase();
    Widget thumbnail;

    if (['.jpg', '.jpeg', '.png'].contains(extension)) {
      thumbnail = Image.file(file, width: 100, height: 100, fit: BoxFit.cover);
    } else {
      thumbnail = Container(
        width: 100, height: 100, color: Colors.grey.shade300,
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

  Widget _buildExpansionSection({required String title, required IconData icon, required Widget child}) {
    return ExpansionTile(
      leading: Icon(icon, color: primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [child],
    );
  }

  // ✅ UPDATED: Now supports a specific media file next to the buttons
  Widget _buildYesNoQuestion({
    required String question,
    required bool? value,
    required ValueChanged<bool> onChanged,
    File? mediaFile,
    ValueChanged<File?>? onMediaChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(question, style: const TextStyle(fontSize: 14))),
            if (onMediaChanged != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: _buildMiniMediaButton(file: mediaFile, onChanged: onMediaChanged),
              ),
          ],
        ),
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

  // ✅ New Widget: Small camera button that becomes a thumbnail
  Widget _buildMiniMediaButton({required File? file, required ValueChanged<File?> onChanged}) {
    if (file != null) {
      return GestureDetector(
        onTap: () => _openMediaPreview(context, file),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(file, width: 48, height: 48, fit: BoxFit.cover),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () => onChanged(null), // Remove photo
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return IconButton(
        onPressed: () => _pickSingleFile(onChanged),
        icon: const Icon(Icons.add_a_photo, color: Colors.grey),
        tooltip: "Ajouter une preuve photo",
      );
    }
  }

  Widget _buildConditionalTextField({required TextEditingController controller, required String labelText}) {
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
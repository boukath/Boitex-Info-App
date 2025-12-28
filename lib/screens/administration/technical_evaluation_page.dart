// lib/screens/administration/technical_evaluation_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart'; // ✅ REMOVED: No longer needed for files
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

// ✅ ADDED: Imports for Backblaze B2 upload
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class EntranceData {
  String? entranceType;
  String? doorType;
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

  // ✅ CHANGED: This function no longer uploads. It just prepares the data map.
  // The file URLs will be added later in _saveEvaluation.
  Map<String, dynamic> getDataMap() {
    return {
      'entranceType': entranceType,
      'doorType': doorType,
      // 'media' key will be added in _saveEvaluation after B2 upload
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

  // ✅ ADDED: B2 Cloud Function URL constant (cloned from add_sav_ticket_page.dart)
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

  // ✅ --- START: ADDED B2 HELPER FUNCTIONS (cloned from add_sav_ticket_page.dart) ---

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

  // ✅ MODIFIED: This version is cloned from add_sav_ticket_page.dart
  // but customized with the storage path from *this* file's original toMap logic.
  Future<String?> _uploadFileToB2(
      File file,
      Map<String, dynamic> b2Creds, {
        required String projectId,
        required int entranceIndex,
      }) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();

      // --- Start: Logic from original toMap ---
      final String originalFileName = path.basename(file.path);
      final String extension = path.extension(originalFileName).toLowerCase();
      String fileTypeFolder;
      if (['.jpg', '.jpeg', '.png'].contains(extension)) {
        fileTypeFolder = 'photos';
      } else if (['.mp4', '.mov', '.avi'].contains(extension)) {
        fileTypeFolder = 'videos';
      } else if (extension == '.pdf') {
        fileTypeFolder = 'pdfs';
      } else {
        fileTypeFolder = 'other_files';
      }

      // This is the B2-compatible file name (which is the full path)
      final String b2FileName =
          'technical_evaluations/$projectId/entrance_$entranceIndex/$fileTypeFolder/$originalFileName';
      // --- End: Logic from original toMap ---

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
          'X-Bz-File-Name': Uri.encodeComponent(b2FileName), // Use the full path
          'Content-Type': mimeType ?? 'b2/x-auto',
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

  Future<void> _pickMedia(int entranceIndex) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      // ✅ ADDED: File size check (cloned from add_sav_ticket_page.dart)
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
      // ✅ CHANGED: We build the list manually instead of using Future.wait
      final List<Map<String, dynamic>> evaluationData = [];

      for (final entry in _entrances.asMap().entries) {
        final int index = entry.key;
        final EntranceData entrance = entry.value;

        // 1. Get the non-file data from the model
        final Map<String, dynamic> entranceMap = entrance.getDataMap();

        // 2. Upload files for this entrance to B2
        final List<String> mediaUrls = [];
        for (final file in entrance.mediaFiles) {
          final String? downloadUrl = await _uploadFileToB2(
            file,
            b2Credentials,
            projectId: widget.projectId,
            entranceIndex: index,
          );
          if (downloadUrl != null) {
            mediaUrls.add(downloadUrl);
          } else {
            debugPrint('Failed to upload file: ${path.basename(file.path)}');
            // Optionally throw an error or show a snackbar for the failed file
          }
        }

        // 3. Add the uploaded URLs to the map
        entranceMap['media'] = mediaUrls;

        // 4. Add the completed map to the final list
        evaluationData.add(entranceMap);
      }

      // 5. Save the final list to Firestore
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
                  ),
                  if (entrance.isFloorFinalized == true)
                    _buildYesNoQuestion(
                      question: 'Un fourreau vide est-il disponible ?',
                      value: entrance.isConduitAvailable,
                      onChanged: (val) => setState(() => entrance.isConduitAvailable = val),
                    ),
                  if (entrance.isConduitAvailable == false)
                    _buildYesNoQuestion(
                      question: 'Le client autorise-t-il une saignée ?',
                      value: entrance.canMakeTrench,
                      onChanged: (val) => setState(() => entrance.canMakeTrench = val),
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
                  ),
                  if (entrance.hasObstacles == true)
                    _buildConditionalTextField(
                      controller: entrance.obstacleNotesController,
                      labelText: 'Veuillez les décrire',
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: entrance.entranceWidthController,
                    decoration: const InputDecoration(labelText: 'Mesure de la largeur de l\'entrée (m)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
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
                  ),
                  _buildYesNoQuestion(
                    question: 'Autres systèmes électroniques présents ?',
                    value: entrance.hasOtherSystems,
                    onChanged: (val) => setState(() => entrance.hasOtherSystems = val),
                  ),
                ],
              ),
            ),
            _buildExpansionSection(
              title: 'Fichiers et Photos',
              icon: Icons.camera_alt_outlined,
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
                          return _buildMediaThumbnail(entrance.mediaFiles[mediaIndex]);
                        },
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickMedia(index),
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Ajouter des Fichiers'),
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

  Widget _buildMediaThumbnail(File file) {
    String extension = path.extension(file.path).toLowerCase();
    Widget thumbnail;

    if (['.jpg', '.jpeg', '.png'].contains(extension)) {
      thumbnail = Image.file(file, width: 100, height: 100, fit: BoxFit.cover);
    } else if (['.mp4', '.mov', '.avi'].contains(extension)) {
      thumbnail = Container(
        width: 100,
        height: 100,
        color: Colors.grey.shade300,
        child: const Icon(Icons.video_library, size: 40, color: Colors.black54),
      );
    } else if (extension == '.pdf') {
      thumbnail = Container(
        width: 100,
        height: 100,
        color: Colors.grey.shade300,
        child: const Icon(Icons.picture_as_pdf, size: 40, color: Colors.red),
      );
    } else {
      thumbnail = Container(
        width: 100,
        height: 100,
        color: Colors.grey.shade300,
        child: const Icon(Icons.insert_drive_file, size: 40, color: Colors.black54),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: thumbnail,
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
          border: const OutlineInputBorder(),
        ),
        maxLines: 2,
      ),
    );
  }
}
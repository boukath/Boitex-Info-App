// lib/screens/administration/technical_evaluation_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

class EntranceData {
  String? entranceType;
  String? doorType;
  List<File> photos = [];

  bool? isPowerAvailable;
  final TextEditingController powerNotesController = TextEditingController();

  // ✅ ADDED: New boolean for the trench question
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

  Future<Map<String, dynamic>> toMap(String projectId, int entranceIndex) async {
    List<String> photoUrls = [];
    for (var file in photos) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('technical_evaluations/$projectId/entrance_$entranceIndex/$fileName');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      photoUrls.add(url);
    }

    return {
      'entranceType': entranceType,
      'doorType': doorType,
      'photos': photoUrls,
      'isPowerAvailable': isPowerAvailable,
      'powerNotes': powerNotesController.text,
      'isFloorFinalized': isFloorFinalized,
      'isConduitAvailable': isConduitAvailable,
      // ✅ ADDED: Save the new field
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

  Future<void> _pickPhotos(int entranceIndex) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _entrances[entranceIndex].photos.addAll(
          result.paths.map((path) => File(path!)).toList(),
        );
      });
    }
  }

  Future<void> _saveEvaluation() async {
    setState(() { _isLoading = true; });
    try {
      final List<Map<String, dynamic>> evaluationData = await Future.wait(
        _entrances.asMap().entries.map((entry) {
          int index = entry.key;
          EntranceData entrance = entry.value;
          return entrance.toMap(widget.projectId, index);
        }).toList(),
      );

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
            // ✅ UPDATED: The "Sol et Passage" section now has the new conditional questions
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
                  // Only show the next question if the floor is finalized
                  if (entrance.isFloorFinalized == true)
                    _buildYesNoQuestion(
                      question: 'Un fourreau vide est-il disponible ?',
                      value: entrance.isConduitAvailable,
                      onChanged: (val) => setState(() => entrance.isConduitAvailable = val),
                    ),
                  // Only show the final question if the conduit is NOT available
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
              title: 'Photos et Notes',
              icon: Icons.camera_alt_outlined,
              child: Column(
                children: [
                  if (entrance.photos.isNotEmpty)
                    Container(
                      height: 100,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: entrance.photos.length,
                        itemBuilder: (context, photoIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Image.file(entrance.photos[photoIndex], width: 100, height: 100, fit: BoxFit.cover),
                          );
                        },
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhotos(index),
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
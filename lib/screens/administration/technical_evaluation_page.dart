// lib/screens/administration/technical_evaluation_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// A data model to hold the information for a single entrance
class EntranceData {
  String? entranceType;
  String? doorType;
  final TextEditingController entranceLengthController = TextEditingController();
  final TextEditingController entranceWidthController = TextEditingController();
  final TextEditingController doorLengthController = TextEditingController();
  final TextEditingController doorWidthController = TextEditingController();
  bool hasPower = false;
  bool hasConduit = false;

  void dispose() {
    entranceLengthController.dispose();
    entranceWidthController.dispose();
    doorLengthController.dispose();
    doorWidthController.dispose();
  }

  Map<String, dynamic> toMap() {
    return {
      'entranceType': entranceType,
      'doorType': doorType,
      'entranceLength': entranceLengthController.text,
      'entranceWidth': entranceWidthController.text,
      'doorLength': doorType != 'sans porte' ? doorLengthController.text : null,
      'doorWidth': doorType != 'sans porte' ? doorWidthController.text : null,
      'hasPower': hasPower,
      'hasConduit': hasConduit,
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
  // NEW: Define theme color
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

  Future<void> _saveEvaluation() async {
    setState(() { _isLoading = true; });
    try {
      final List<Map<String, dynamic>> evaluationData =
      _entrances.map((entrance) => entrance.toMap()).toList();

      await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
        'technical_evaluation': evaluationData,
        'status': 'Évaluation Technique Terminé',
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("Erreur lors de l'enregistrement de l'évaluation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
      );
      setState(() { _isLoading = false; });
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
          // MODIFIED: Styled the bottom action area
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

  // MODIFIED: This entire card widget is redesigned for a better look
  Widget _buildEntranceCard(int index) {
    final entrance = _entrances[index];
    final OutlineInputBorder focusedBorder = OutlineInputBorder(borderSide: const BorderSide(color: primaryColor, width: 2.0), borderRadius: BorderRadius.circular(12.0));
    final OutlineInputBorder defaultBorder = OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12.0));

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              decoration: InputDecoration(border: defaultBorder, focusedBorder: focusedBorder, floatingLabelStyle: const TextStyle(color: primaryColor)),
              items: ['Porte battante', 'Porte Automatique', 'Entree Libre'].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (value) => setState(() => entrance.entranceType = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: entrance.doorType,
              hint: const Text('Type de porte'),
              decoration: InputDecoration(border: defaultBorder, focusedBorder: focusedBorder, floatingLabelStyle: const TextStyle(color: primaryColor)),
              items: ['porte vitrée', 'porte metalique', 'sans porte'].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (value) => setState(() => entrance.doorType = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextFormField(controller: entrance.entranceLengthController, decoration: InputDecoration(labelText: 'Longeur entrée (m)', border: defaultBorder, focusedBorder: focusedBorder, floatingLabelStyle: const TextStyle(color: primaryColor)), keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(controller: entrance.entranceWidthController, decoration: InputDecoration(labelText: 'Largeur entrée (m)', border: defaultBorder, focusedBorder: focusedBorder, floatingLabelStyle: const TextStyle(color: primaryColor)), keyboardType: TextInputType.number)),
              ],
            ),
            if (entrance.doorType != null && entrance.doorType != 'sans porte')
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    Expanded(child: TextFormField(controller: entrance.doorLengthController, decoration: InputDecoration(labelText: 'Longeur porte (m)', border: defaultBorder, focusedBorder: focusedBorder, floatingLabelStyle: const TextStyle(color: primaryColor)), keyboardType: TextInputType.number)),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(controller: entrance.doorWidthController, decoration: InputDecoration(labelText: 'Largeur porte (m)', border: defaultBorder, focusedBorder: focusedBorder, floatingLabelStyle: const TextStyle(color: primaryColor)), keyboardType: TextInputType.number)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Prise 220V disponible'),
              value: entrance.hasPower,
              onChanged: (value) => setState(() => entrance.hasPower = value),
              contentPadding: EdgeInsets.zero,
              activeColor: primaryColor,
            ),
            SwitchListTile(
              title: const Text('Tube/Gaine au sol disponible'),
              value: entrance.hasConduit,
              onChanged: (value) => setState(() => entrance.hasConduit = value),
              contentPadding: EdgeInsets.zero,
              activeColor: primaryColor,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () { /* Add image picking logic here later */ },
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Ajouter des Photos'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
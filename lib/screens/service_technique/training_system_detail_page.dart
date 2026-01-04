// lib/screens/service_technique/training_system_detail_page.dart

import 'dart:ui'; // Required for ImageFilter
import 'package:boitex_info_app/screens/service_technique/training_document_list_page.dart';

import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TrainingSystemDetailPage extends StatefulWidget {
  final String categoryId;
  final String systemId;
  final String systemName;

  const TrainingSystemDetailPage({
    super.key,
    required this.categoryId,
    required this.systemId,
    required this.systemName,
  });

  @override
  State<TrainingSystemDetailPage> createState() =>
      _TrainingSystemDetailPageState();
}

class _TrainingSystemDetailPageState extends State<TrainingSystemDetailPage> {
  bool _isManager = false;
  final TextEditingController _subSystemNameController = TextEditingController();
  late final CollectionReference _subSystemsCollection;

  @override
  void initState() {
    super.initState();
    _subSystemsCollection = FirebaseFirestore.instance
        .collection('training_categories')
        .doc(widget.categoryId)
        .collection('training_systems')
        .doc(widget.systemId)
        .collection('training_sub_systems');

    _fetchUserRole();
  }

  @override
  void dispose() {
    _subSystemNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserRole() async {
    final role = await UserRoles.getCurrentUserRole();
    if (mounted) {
      setState(() {
        _isManager = _checkIsManager(role);
      });
    }
  }

  bool _checkIsManager(String? role) {
    if (role == null) return false;
    final managerRoles = <String>{
      UserRoles.pdg,
      UserRoles.admin,
      UserRoles.responsableAdministratif,
      UserRoles.responsableCommercial,
      UserRoles.responsableTechnique,
      UserRoles.responsableIT,
      UserRoles.chefDeProjet,
    };
    return managerRoles.contains(role);
  }

  // ===========================================================================
  // 🎨 THEMED DIALOGS
  // ===========================================================================

  void _showAddSubSystemDialog() {
    _subSystemNameController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _buildModernDialog(
          title: 'Nouveau Sous-Système',
          content: TextField(
            controller: _subSystemNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nom (ex: Synergy, Advantage...)',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00F0FF)),
              ),
              prefixIcon: const Icon(Icons.layers, color: Colors.white54),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: Text('Annuler', style: TextStyle(color: Colors.white.withOpacity(0.6))),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ajouter'),
              onPressed: () {
                final name = _subSystemNameController.text.trim();
                if (name.isNotEmpty) {
                  _addSubSystem(name);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(String docId, String subSystemName) {
    showDialog(
      context: context,
      builder: (context) {
        return _buildModernDialog(
          title: 'Supprimer',
          content: Text(
              'Voulez-vous supprimer "$subSystemName" ?\nCette action est irréversible.',
              style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2E63),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
              onPressed: () {
                _deleteSubSystem(docId);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildModernDialog({required String title, required Widget content, required List<Widget> actions}) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C).withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        content: content,
        actions: actions,
        actionsPadding: const EdgeInsets.all(16),
      ),
    );
  }

  // ===========================================================================
  // 💾 FIRESTORE ACTIONS
  // ===========================================================================

  Future<void> _addSubSystem(String name) async {
    try {
      await _subSystemsCollection.add({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _deleteSubSystem(String docId) async {
    try {
      await _subSystemsCollection.doc(docId).delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // ===========================================================================
  // 💎 GLASSMORPHIC LIST ITEM
  // ===========================================================================

  Widget _buildSubSystemCard(String docId, String name, VoidCallback onTap, VoidCallback onDelete) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.02)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    // Icon Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F0FF).withOpacity(0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.2), blurRadius: 15),
                        ],
                        border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.category_rounded, color: Color(0xFF00F0FF), size: 24),
                    ),
                    const SizedBox(width: 20),

                    // Text
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    // Chevron or Delete
                    if (_isManager)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        tooltip: 'Supprimer',
                        onPressed: onDelete,
                      )
                    else
                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.3), size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.systemName.toUpperCase()),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: _isManager
          ? InkWell(
        onTap: _showAddSubSystemDialog,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00F0FF), Color(0xFF0077FF)]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.4), blurRadius: 20, spreadRadius: 2)
              ]
          ),
          child: const Icon(Icons.add_box_outlined, color: Colors.black),
        ),
      )
          : null,
      body: Stack(
        children: [
          // 🌌 Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF000000)],
              ),
            ),
          ),

          // 💡 Ambient Effects
          Positioned(
            top: 100, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00F0FF).withOpacity(0.05),
                boxShadow: [BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.1), blurRadius: 150)],
              ),
            ),
          ),

          // 📄 List
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: _subSystemsCollection.orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF)));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Erreur de chargement.', style: TextStyle(color: Colors.white54)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.layers_clear_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun sous-système.',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final subSystemName = data['name'] ?? 'Sans nom';

                    return _buildSubSystemCard(
                      doc.id,
                      subSystemName,
                          () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrainingDocumentListPage(
                              categoryId: widget.categoryId,
                              systemId: widget.systemId,
                              subSystemId: doc.id,
                              subSystemName: subSystemName,
                            ),
                          ),
                        );
                      },
                          () => _showDeleteConfirmDialog(doc.id, subSystemName),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
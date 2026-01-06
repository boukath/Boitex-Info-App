// lib/screens/service_technique/training_systems_list_page.dart

import 'dart:io';
import 'dart:ui'; // Required for ImageFilter
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart'; // For SHA1
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart'; // ✅ IMAGE PICKER

import 'package:boitex_info_app/screens/service_technique/training_system_detail_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TrainingSystemsListPage extends StatefulWidget {
  final String categoryName;
  final String categoryId;

  const TrainingSystemsListPage({
    super.key,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  State<TrainingSystemsListPage> createState() =>
      _TrainingSystemsListPageState();
}

class _TrainingSystemsListPageState extends State<TrainingSystemsListPage> {
  bool _isManager = false;
  final TextEditingController _systemNameController = TextEditingController();
  late final CollectionReference _systemsCollection;

  // ✅ Image Upload State
  bool _isUploading = false;
  String? _tempUploadedImageUrl;
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl';

  @override
  void initState() {
    super.initState();
    _systemsCollection = FirebaseFirestore.instance
        .collection('training_categories')
        .doc(widget.categoryId)
        .collection('training_systems');

    _fetchUserRole();
  }

  @override
  void dispose() {
    _systemNameController.dispose();
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
  // ☁️ B2 UPLOAD HELPERS
  // ===========================================================================

  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response = await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error calling Cloud Function: $e');
    }
    return null;
  }

  Future<String?> _uploadFileToB2(File file, Map<String, dynamic> b2Creds) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final fileName = 'training_systems/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';

      String? mimeType;
      if (fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (fileName.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      }

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
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
      }
    } catch (e) {
      debugPrint('Error uploading file to B2: $e');
    }
    return null;
  }

  // ===========================================================================
  // 📸 IMAGE PICKER LOGIC
  // ===========================================================================

  Future<void> _pickAndUploadImage(StateSetter setStateDialog) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image != null) {
      setStateDialog(() {
        _isUploading = true;
      });

      try {
        final File file = File(image.path);
        final b2Creds = await _getB2UploadCredentials();
        if (b2Creds == null) throw Exception("Impossible d'obtenir les clés B2");

        final String? downloadUrl = await _uploadFileToB2(file, b2Creds);
        if (downloadUrl == null) throw Exception("Échec de l'upload B2");

        setStateDialog(() {
          _tempUploadedImageUrl = downloadUrl;
          _isUploading = false;
        });
      } catch (e) {
        setStateDialog(() {
          _isUploading = false;
        });
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur upload: $e")));
        }
      }
    }
  }

  // ===========================================================================
  // ✏️ ADD / EDIT DIALOG
  // ===========================================================================

  void _showSystemDialog({DocumentSnapshot? existingDoc}) {
    // Reset or Pre-fill
    if (existingDoc != null) {
      final data = existingDoc.data() as Map<String, dynamic>;
      _systemNameController.text = data['name'] ?? '';
      _tempUploadedImageUrl = data['photoUrl'];
    } else {
      _systemNameController.clear();
      _tempUploadedImageUrl = null;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return _buildModernDialog(
              title: existingDoc == null ? 'Nouveau Système' : 'Modifier Système',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. IMAGE PICKER
                  GestureDetector(
                    onTap: () => _pickAndUploadImage(setStateDialog),
                    child: Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.3)),
                        image: _tempUploadedImageUrl != null
                            ? DecorationImage(
                          image: NetworkImage(_tempUploadedImageUrl!),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: _isUploading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF)))
                          : _tempUploadedImageUrl == null
                          ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_rounded, color: Colors.white70, size: 30),
                          const SizedBox(height: 8),
                          Text("Ajouter Logo", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                        ],
                      )
                          : null,
                    ),
                  ),

                  if (_tempUploadedImageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                        label: const Text("Retirer la photo", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        onPressed: () {
                          setStateDialog(() {
                            _tempUploadedImageUrl = null;
                          });
                        },
                      ),
                    ),

                  const SizedBox(height: 20),

                  // 2. NAME INPUT
                  TextField(
                    controller: _systemNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nom du système',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00F0FF)),
                      ),
                      prefixIcon: const Icon(Icons.grid_view_rounded, color: Colors.white54),
                    ),
                    autofocus: true,
                  ),
                ],
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
                  child: Text(existingDoc == null ? 'Ajouter' : 'Sauvegarder'),
                  onPressed: () {
                    final name = _systemNameController.text.trim();
                    if (name.isNotEmpty) {
                      if (existingDoc == null) {
                        _addSystem(name, _tempUploadedImageUrl);
                      } else {
                        _updateSystem(existingDoc.id, name, _tempUploadedImageUrl);
                      }
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(String docId, String systemName) {
    showDialog(
      context: context,
      builder: (context) {
        return _buildModernDialog(
          title: 'Supprimer',
          content: Text(
              'Voulez-vous vraiment supprimer le système "$systemName" ?\nCette action est irréversible.',
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
                _deleteSystem(docId);
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

  Future<void> _addSystem(String name, String? photoUrl) async {
    try {
      await _systemsCollection.add({
        'name': name,
        'photoUrl': photoUrl, // ✅ Save Photo URL
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _updateSystem(String docId, String name, String? photoUrl) async {
    try {
      await _systemsCollection.doc(docId).update({
        'name': name,
        'photoUrl': photoUrl, // ✅ Update Photo URL
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur maj: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _deleteSystem(String docId) async {
    try {
      await _systemsCollection.doc(docId).delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // ===========================================================================
  // 💎 GLASSMORPHIC LIST ITEM
  // ===========================================================================

  Widget _buildSystemCard(DocumentSnapshot doc, VoidCallback onTap) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Sans nom';
    final photoUrl = data['photoUrl']; // ✅ Retrieve Photo
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: hasPhoto ? const Color(0xFF00F0FF).withOpacity(0.3) : Colors.white.withOpacity(0.1),
            width: 1
        ),
        // ✅ Background Image if exists, else gradient
        image: hasPhoto ? DecorationImage(
          image: NetworkImage(photoUrl),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
        ) : null,
        gradient: hasPhoto ? null : LinearGradient(
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
                    // Icon Box (Only show if NO Photo)
                    if (!hasPhoto) ...[
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
                        child: const Icon(Icons.dns_rounded, color: Color(0xFF00F0FF), size: 24),
                      ),
                      const SizedBox(width: 20),
                    ],

                    // Text
                    Expanded(
                      child: Text(
                        name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.0,
                          // Add shadow if photo is present for better contrast
                          shadows: hasPhoto ? [const Shadow(color: Colors.black, blurRadius: 5)] : null,
                        ),
                      ),
                    ),

                    // ACTIONS
                    if (_isManager) ...[
                      // Edit Button
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Color(0xFF00F0FF)),
                        tooltip: 'Modifier',
                        onPressed: () => _showSystemDialog(existingDoc: doc), // ✅ CALL EDIT
                      ),
                      // Delete Button
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        tooltip: 'Supprimer',
                        onPressed: () => _showDeleteConfirmDialog(doc.id, name),
                      ),
                    ]
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
        title: Text(widget.categoryName.toUpperCase()),
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
        onTap: () => _showSystemDialog(), // ✅ Call Add Dialog
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
          child: const Icon(Icons.add, color: Colors.black),
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
            bottom: 100, right: -50,
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
              stream: _systemsCollection.orderBy('name').snapshots(),
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
                        Icon(Icons.grid_off_rounded, size: 64, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun système trouvé.',
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
                    final systemName = data['name'] ?? 'Sans nom';

                    return _buildSystemCard(
                      doc, // ✅ Pass full doc for editing
                          () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrainingSystemDetailPage(
                              categoryId: widget.categoryId,
                              systemId: doc.id,
                              systemName: systemName,
                            ),
                          ),
                        );
                      },
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
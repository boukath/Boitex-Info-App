import 'dart:io';
import 'dart:ui'; // Required for ImageFilter
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart'; // For SHA1
import 'package:path/path.dart' as path;

import 'package:boitex_info_app/screens/service_technique/training_systems_list_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class TrainingHubPage extends StatefulWidget {
  const TrainingHubPage({super.key});

  @override
  State<TrainingHubPage> createState() => _TrainingHubPageState();
}

class _TrainingHubPageState extends State<TrainingHubPage> {
  bool _isManager = false;

  // Controllers for Add/Edit
  final TextEditingController _categoryNameController = TextEditingController();

  // State for the Dialog (Image Uploading)
  bool _isUploading = false;
  String? _tempUploadedImageUrl;
  String _selectedIconName = 'default';

  // ✅ B2 Configuration (Cloud Function URL)
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl';

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
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
      } else {
        debugPrint('Failed to get B2 credentials: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error calling Cloud Function: $e');
      return null;
    }
  }

  Future<String?> _uploadFileToB2(File file, Map<String, dynamic> b2Creds) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final fileName = 'training_logos/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';

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
      } else {
        debugPrint('Failed to upload to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file to B2: $e');
      return null;
    }
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

        // 1. Get B2 Credentials
        final b2Creds = await _getB2UploadCredentials();
        if (b2Creds == null) throw Exception("Impossible d'obtenir les clés B2");

        // 2. Upload to B2
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

  void _showCategoryDialog({_TrainingCategory? existingCategory}) {
    // Reset or Pre-fill
    if (existingCategory != null) {
      _categoryNameController.text = existingCategory.name;
      _tempUploadedImageUrl = existingCategory.photoUrl;
      _selectedIconName = 'default';
    } else {
      _categoryNameController.clear();
      _tempUploadedImageUrl = null;
      _selectedIconName = 'default';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return _buildModernDialog(
              title: existingCategory == null ? 'Nouvelle Section' : 'Modifier Section',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. IMAGE PICKER AREA
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
                    controller: _categoryNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nom de la section (ex: Antivol)',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00F0FF)),
                      ),
                      prefixIcon: const Icon(Icons.layers_outlined, color: Colors.white54),
                    ),
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
                    elevation: 10,
                    shadowColor: const Color(0xFF00F0FF).withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(existingCategory == null ? 'Créer' : 'Sauvegarder'),
                  onPressed: () {
                    final name = _categoryNameController.text.trim();
                    if (name.isNotEmpty) {
                      if (existingCategory == null) {
                        _addCategory(name, _tempUploadedImageUrl);
                      } else {
                        _updateCategory(existingCategory.docId, name, _tempUploadedImageUrl);
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

  /// 💾 FIRESTORE ACTIONS

  Future<void> _addCategory(String name, String? photoUrl) async {
    try {
      await FirebaseFirestore.instance.collection('training_categories').add({
        'name': name,
        'iconName': 'default',
        'colorHex': '#808080',
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _updateCategory(String docId, String name, String? photoUrl) async {
    try {
      await FirebaseFirestore.instance.collection('training_categories').doc(docId).update({
        'name': name,
        'photoUrl': photoUrl,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur maj: $e')));
    }
  }

  Future<void> _deleteCategory(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('training_categories').doc(docId).delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  void _showDeleteConfirmDialog(String docId, String categoryName) {
    showDialog(
      context: context,
      builder: (context) {
        return _buildModernDialog(
          title: 'Supprimer ?',
          content: Text(
            'Voulez-vous supprimer "$categoryName" ?\nCette action est irréversible.',
            style: const TextStyle(color: Colors.white70),
          ),
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
                _deleteCategory(docId);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  // Helper UI pour les dialogs
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('TRAINING HUB'),
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
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          color: Colors.white,
        ),
        actions: [
          if (_isManager)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: InkWell(
                onTap: () => _showCategoryDialog(), // Call Add Dialog
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFF00F0FF).withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.3), blurRadius: 10)
                      ]
                  ),
                  child: const Icon(Icons.add, color: Color(0xFF00F0FF)),
                ),
              ),
            ),
        ],
      ),
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
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00F0FF).withOpacity(0.1),
                boxShadow: [BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.2), blurRadius: 150)],
              ),
            ),
          ),

          // 📄 List
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('training_categories').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('Aucune section.', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                  );
                }

                final docs = snapshot.data!.docs;

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20.0,
                    mainAxisSpacing: 20.0,
                    childAspectRatio: 0.85, // Taller for photo logic
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final category = _TrainingCategory(
                      docId: doc.id,
                      name: data['name'] ?? 'Sans nom',
                      icon: _getIconFromName(data['iconName'] ?? 'default'),
                      color: _getColorFromHex(data['colorHex'] ?? '#808080'),
                      photoUrl: data['photoUrl'],
                    );

                    return _CategoryCard(
                      category: category,
                      isManager: _isManager,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrainingSystemsListPage(
                              categoryName: category.name,
                              categoryId: category.docId,
                            ),
                          ),
                        );
                      },
                      onDelete: () => _showDeleteConfirmDialog(category.docId, category.name),
                      onEdit: () => _showCategoryDialog(existingCategory: category),
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

// 📦 DATA CLASS
class _TrainingCategory {
  final String docId;
  final String name;
  final IconData icon;
  final Color color;
  final String? photoUrl;

  const _TrainingCategory({
    required this.docId,
    required this.name,
    required this.icon,
    required this.color,
    this.photoUrl,
  });
}

// 💎 HIGH QUALITY CARD COMPONENT
class _CategoryCard extends StatefulWidget {
  final _TrainingCategory category;
  final bool isManager;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _CategoryCard({
    required this.category,
    required this.isManager,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 📸 Has Photo?
    final bool hasPhoto = widget.category.photoUrl != null && widget.category.photoUrl!.isNotEmpty;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Stack(
          children: [
            // Glass Container
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                // ✅ Dynamic Border color if photo is present
                border: Border.all(
                  color: hasPhoto ? const Color(0xFF00F0FF).withOpacity(0.3) : Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
                color: const Color(0xFF1E1E2C).withOpacity(0.6), // Fallback
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
                ],
                // ✅ Background Image if Photo Exists
                image: hasPhoto ? DecorationImage(
                  image: NetworkImage(widget.category.photoUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken), // Darken for readability
                ) : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: hasPhoto ? 0 : 10, sigmaY: hasPhoto ? 0 : 10),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: hasPhoto ? null : BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.02)],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ✨ Icon (Only show if NO Photo)
                        if (!hasPhoto) ...[
                          Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF00F0FF).withOpacity(0.1),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.3), blurRadius: 20),
                              ],
                              border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.3)),
                            ),
                            child: Icon(widget.category.icon, size: 28, color: const Color(0xFF00F0FF)),
                          ),
                          const Spacer(),
                        ] else ...[
                          // If photo, push text to bottom
                          const Spacer(),
                        ],

                        // Title
                        Text(
                          widget.category.name.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Colors.black.withOpacity(0.8), offset: const Offset(0, 2), blurRadius: 6),
                              if(hasPhoto) const Shadow(color: Color(0xFF00F0FF), blurRadius: 10), // Neon glow text on photo
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if(hasPhoto) const SizedBox(height: 10), // Padding bottom for photo cards
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 🛠 MANAGER CONTROLS (Edit & Delete)
            if (widget.isManager) ...[
              // Delete (Top Right)
              Positioned(
                top: 8, right: 8,
                child: _buildMiniButton(Icons.close, Colors.redAccent, widget.onDelete),
              ),
              // Edit (Top Left)
              Positioned(
                top: 8, left: 8,
                child: _buildMiniButton(Icons.edit_rounded, const Color(0xFF00F0FF), widget.onEdit),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMiniButton(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

// --- Utils ---

IconData _getIconFromName(String iconName) {
  return Icons.layers_outlined; // Default fallback
}

Color _getColorFromHex(String hexColor) {
  hexColor = hexColor.toUpperCase().replaceAll('#', '');
  if (hexColor.length == 6) hexColor = 'FF$hexColor';
  try {
    return Color(int.parse(hexColor, radix: 16));
  } catch (e) {
    return const Color(0xFF00F0FF);
  }
}
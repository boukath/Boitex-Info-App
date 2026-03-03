// lib/screens/service_technique/training_systems_list_page.dart

import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:boitex_info_app/screens/service_technique/training_system_detail_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// 🎨 --- 2026 PREMIUM APPLE CONSTANTS --- 🎨
const kTextDark = Color(0xFF1D1D1F);
const kTextSecondary = Color(0xFF86868B);
const kAppleBlue = Color(0xFF007AFF);
const double kRadius = 28.0;

class TrainingSystemsListPage extends StatefulWidget {
  final String categoryName;
  final String categoryId;

  const TrainingSystemsListPage({
    super.key,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  State<TrainingSystemsListPage> createState() => _TrainingSystemsListPageState();
}

class _TrainingSystemsListPageState extends State<TrainingSystemsListPage> {
  bool _isManager = false;
  final TextEditingController _systemNameController = TextEditingController();
  late final CollectionReference _systemsCollection;

  // ☁️ Image Upload State
  bool _isUploading = false;
  String? _tempUploadedImageUrl;
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

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
      setStateDialog(() => _isUploading = true);
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
        setStateDialog(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Erreur upload: $e", style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFFFF3B30),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  // ===========================================================================
  // ✏️ PREMIUM ADD / EDIT DIALOG
  // ===========================================================================

  void _showSystemDialog({DocumentSnapshot? existingDoc}) {
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
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Text(
                            existingDoc == null ? 'Nouveau Système' : 'Modifier Système',
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 24),

                          // Text Field
                          TextFormField(
                            controller: _systemNameController,
                            style: GoogleFonts.inter(fontSize: 16, color: kTextDark, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              labelText: 'Nom du système',
                              labelStyle: GoogleFonts.inter(color: kTextSecondary),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.04),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              prefixIcon: const Icon(Icons.grid_view_rounded, color: kTextSecondary),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Image Upload Area
                          GestureDetector(
                            onTap: _isUploading ? null : () => _pickAndUploadImage(setStateDialog),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 140,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _tempUploadedImageUrl != null ? kAppleBlue.withOpacity(0.5) : Colors.black.withOpacity(0.1),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: _isUploading
                                    ? const Center(child: CircularProgressIndicator.adaptive())
                                    : _tempUploadedImageUrl != null
                                    ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(_tempUploadedImageUrl!, fit: BoxFit.cover),
                                    Container(color: Colors.black.withOpacity(0.2)),
                                    const Center(child: Icon(Icons.edit_rounded, color: Colors.white, size: 32)),
                                  ],
                                )
                                    : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_rounded, size: 40, color: kTextSecondary.withOpacity(0.5)),
                                    const SizedBox(height: 8),
                                    Text("Ajouter une image", style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          if (_tempUploadedImageUrl != null && !_isUploading)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: TextButton.icon(
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFFF3B30), size: 16),
                                label: Text("Retirer la photo", style: GoogleFonts.inter(color: const Color(0xFFFF3B30), fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => setStateDialog(() => _tempUploadedImageUrl = null),
                              ),
                            ),

                          const SizedBox(height: 32),

                          // Actions
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Text("Annuler", style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kAppleBlue,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  onPressed: _isUploading
                                      ? null
                                      : () async {
                                    final name = _systemNameController.text.trim();
                                    if (name.isEmpty) return;

                                    if (existingDoc == null) {
                                      await _addSystem(name, _tempUploadedImageUrl);
                                    } else {
                                      await _updateSystem(existingDoc.id, name, _tempUploadedImageUrl);
                                    }
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  child: Text(existingDoc == null ? "Créer" : "Sauvegarder", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(String docId, String systemName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Supprimer ?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextDark)),
        content: Text('Voulez-vous vraiment supprimer "$systemName" ?', style: GoogleFonts.inter(color: kTextDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30), elevation: 0),
            onPressed: () {
              _deleteSystem(docId);
              Navigator.pop(context);
            },
            child: Text('Supprimer', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _updateSystem(String docId, String name, String? photoUrl) async {
    try {
      await _systemsCollection.doc(docId).update({
        'name': name,
        'photoUrl': photoUrl,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur maj: $e')));
    }
  }

  Future<void> _deleteSystem(String docId) async {
    try {
      await _systemsCollection.doc(docId).delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  // ===========================================================================
  // 🎨 MAIN UI (WEB & MOBILE OPTIMIZED)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      floatingActionButton: _isManager
          ? FloatingActionButton.extended(
        onPressed: () => _showSystemDialog(),
        backgroundColor: kTextDark,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text("Système", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 8,
      )
          : null,
      body: Stack(
        children: [
          // ✨ 1. VIBRANT MESH GLASS BACKGROUND
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.4, 0.8, 1.0],
                  colors: [
                    Color(0xFFE8F1F5), // White-ish Blue
                    Color(0xFFD4CCEC), // Soft Lilac
                    Color(0xFF4CA1AF), // Soft Teal
                    Color(0xFFC4E0E5), // Light Cyan
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.white.withOpacity(0.4)),
            ),
          ),

          // ✨ 2. ADAPTIVE SLIVER SCROLL VIEW
          CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildGlassSliverAppBar(),
              StreamBuilder<QuerySnapshot>(
                stream: _systemsCollection.orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator.adaptive()),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grid_off_rounded, size: 64, color: Colors.black.withOpacity(0.1)),
                            const SizedBox(height: 16),
                            Text("Aucun système trouvé.", style: GoogleFonts.inter(color: kTextSecondary, fontSize: 16)),
                          ],
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20).copyWith(bottom: 120),
                    sliver: SliverGrid(
                      // 🔥 ADAPTIVE WEB & MOBILE GRID
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final systemName = data['name'] ?? 'Sans nom';

                          return _GlassSystemCard(
                            doc: doc,
                            index: index,
                            isManager: _isManager,
                            onEdit: () => _showSystemDialog(existingDoc: doc),
                            onDelete: () => _showDeleteConfirmDialog(doc.id, systemName),
                            onTap: () {
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
                        childCount: docs.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                border: Border.all(color: Colors.white.withOpacity(0.6)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextDark, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SÉLECTION DU SYSTÈME",
                  style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 1.2),
                ),
                Text(
                  widget.categoryName,
                  style: GoogleFonts.inter(color: kTextDark, fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            background: Container(color: Colors.white.withOpacity(0.2)),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ✨ CUSTOM GLASSMORPHIC SYSTEM CARD (Hover & Mobile Optimized)
// -----------------------------------------------------------------------------
class _GlassSystemCard extends StatefulWidget {
  final DocumentSnapshot doc;
  final int index;
  final bool isManager;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GlassSystemCard({
    required this.doc,
    required this.index,
    required this.isManager,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_GlassSystemCard> createState() => _GlassSystemCardState();
}

class _GlassSystemCardState extends State<_GlassSystemCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final String name = data['name'] ?? 'Inconnu';
    final String? photoUrl = data['photoUrl'];

    final delay = widget.index * 40;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        if (value == 0 && delay > 0) Future.delayed(Duration(milliseconds: delay));
        return Transform.translate(
          offset: Offset(0, 40 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()..scale(_isPressed ? 0.95 : (_isHovered ? 1.02 : 1.0)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(_isHovered ? 0.9 : 0.6),
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isHovered ? 0.1 : 0.05),
                  blurRadius: _isHovered ? 30 : 20,
                  offset: Offset(0, _isHovered ? 12 : 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kRadius),
              child: Stack(
                children: [
                  // 📷 IMAGE LAYER
                  Positioned(
                    top: 0, left: 0, right: 0, height: 200,
                    child: photoUrl != null && photoUrl.isNotEmpty
                        ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(color: Colors.black.withOpacity(0.05), child: const Center(child: CircularProgressIndicator.adaptive()));
                      },
                      errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
                    )
                        : _buildFallbackIcon(),
                  ),

                  // 📝 TEXT LAYER (Frosted Bottom Panel)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.5))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -0.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), shape: BoxShape.circle),
                                child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kTextSecondary),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ⚙️ MANAGER CONTROLS
                  if (widget.isManager)
                    Positioned(
                      top: 12, right: 12,
                      child: Row(
                        children: [
                          _buildGlassMiniButton(Icons.edit_rounded, Colors.black87, widget.onEdit),
                          const SizedBox(width: 8),
                          _buildGlassMiniButton(Icons.delete_outline_rounded, const Color(0xFFFF3B30), widget.onDelete),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      color: Colors.teal.withOpacity(0.05),
      child: Center(
        child: Icon(Icons.dns_rounded, size: 48, color: Colors.teal.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildGlassMiniButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.8)),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}
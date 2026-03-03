// lib/screens/service_technique/training_hub_page.dart

import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart'; // For SHA1
import 'package:path/path.dart' as path;

import 'package:boitex_info_app/screens/service_technique/training_systems_list_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

// 🎨 --- 2026 PREMIUM APPLE CONSTANTS --- 🎨
const kTextDark = Color(0xFF1D1D1F);
const kTextSecondary = Color(0xFF86868B);
const kAppleBlue = Color(0xFF007AFF);
const double kRadius = 28.0;

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
  final String _selectedIconName = 'default';

  // ✅ B2 Configuration (Cloud Function URL)
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    String? role = await UserRoles.getCurrentUserRole();
    // Any role that can see the admin card is considered a manager/admin
    bool isMgr = role != null && RolePermissions.canSeeAdminCard(role);

    if (mounted) {
      setState(() => _isManager = isMgr);
    }
  }

  // ---------------------------------------------------------------------------
  // ⚙️ B2 IMAGE UPLOAD LOGIC
  // ---------------------------------------------------------------------------

  Future<void> _pickAndUploadImage(StateSetter setStateDialog) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 80,
    );

    if (image == null) return;

    setStateDialog(() => _isUploading = true);

    try {
      final bytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final downloadUrl = await uploadImageToB2(bytes, fileName);

      if (downloadUrl != null) {
        setStateDialog(() => _tempUploadedImageUrl = downloadUrl);
      } else {
        throw Exception("Failed to get download URL from B2");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de l\'upload : $e', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      setStateDialog(() => _isUploading = false);
    }
  }

  Future<String?> uploadImageToB2(List<int> fileBytes, String fileName) async {
    try {
      final response = await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      final uploadUrl = data['uploadUrl'];
      final authorizationToken = data['authorizationToken'];

      final String sha1Hash = sha1.convert(fileBytes).toString();
      String mimeType = 'image/jpeg';
      if (fileName.toLowerCase().endsWith('.png')) mimeType = 'image/png';

      final uploadResponse = await http.post(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': authorizationToken,
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': mimeType,
          'X-Bz-Content-Sha1': sha1Hash,
        },
        body: fileBytes,
      );

      if (uploadResponse.statusCode == 200) {
        return "https://f003.backblazeb2.com/file/boitex-info-files/$fileName";
      } else {
        debugPrint("B2 Upload Error: ${uploadResponse.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Exception during upload: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 💎 PREMIUM GLASS DIALOG (ADD / EDIT CATEGORY)
  // ---------------------------------------------------------------------------

  void _showAddOrEditCategoryDialog({DocumentSnapshot? doc}) {
    if (doc != null) {
      _categoryNameController.text = doc['name'] ?? '';
      _tempUploadedImageUrl = doc.data().toString().contains('imageUrl') ? doc['imageUrl'] : null;
    } else {
      _categoryNameController.clear();
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
                            doc == null ? 'Nouvelle Catégorie' : 'Modifier la Catégorie',
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 24),

                          // Text Field
                          TextFormField(
                            controller: _categoryNameController,
                            style: GoogleFonts.inter(fontSize: 16, color: kTextDark, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              labelText: 'Nom de la catégorie',
                              labelStyle: GoogleFonts.inter(color: kTextSecondary),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.04),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              prefixIcon: const Icon(Icons.folder_special_rounded, color: kTextSecondary),
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
                                    if (_categoryNameController.text.trim().isEmpty) return;

                                    final Map<String, dynamic> data = {
                                      'name': _categoryNameController.text.trim(),
                                      'iconName': _selectedIconName, // Kept for backward compatibility
                                      'colorHex': '0xFF3B82F6', // Default blue hex
                                    };
                                    if (_tempUploadedImageUrl != null) {
                                      data['imageUrl'] = _tempUploadedImageUrl;
                                    }

                                    if (doc == null) {
                                      await FirebaseFirestore.instance.collection('training_categories').add(data);
                                    } else {
                                      await FirebaseFirestore.instance.collection('training_categories').doc(doc.id).update(data);
                                    }
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  child: Text(doc == null ? "Créer" : "Sauvegarder", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  Future<void> _deleteCategory(DocumentSnapshot doc) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Supprimer ?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer cette catégorie ?', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler', style: GoogleFonts.inter(color: kTextSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30), elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Supprimer', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('training_categories').doc(doc.id).delete();
    }
  }

  // ---------------------------------------------------------------------------
  // 🎨 MAIN UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      floatingActionButton: _isManager
          ? FloatingActionButton.extended(
        onPressed: () => _showAddOrEditCategoryDialog(),
        backgroundColor: kTextDark,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text("Catégorie", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 8,
      )
          : null,
      body: Stack(
        children: [
          // ✨ 1. ANIMATED MESH GLASS BACKGROUND
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.4, 0.8, 1.0],
                  colors: [
                    Color(0xFFC4E0E5), // Light Cyan
                    Color(0xFF4CA1AF), // Soft Teal
                    Color(0xFFD4CCEC), // Soft Lilac
                    Color(0xFFE8F1F5), // White-ish Blue
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

          // ✨ 2. MAIN SLIVER CONTENT
          CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildGlassSliverAppBar(),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('training_categories').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator.adaptive()),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Text("Aucune catégorie disponible.", style: GoogleFonts.inter(color: kTextSecondary, fontSize: 16)),
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
                        childAspectRatio: 0.85, // Perfect ratio for large image cards
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final doc = docs[index];
                          return _GlassTrainingCategoryCard(
                            doc: doc,
                            index: index,
                            isManager: _isManager,
                            onEdit: () => _showAddOrEditCategoryDialog(doc: doc),
                            onDelete: () => _deleteCategory(doc),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TrainingSystemsListPage(
                                    categoryId: doc.id,
                                    categoryName: doc['name'] ?? 'Catégorie',
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
      expandedHeight: 120.0,
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
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.school_rounded, color: Colors.blueAccent, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  "Hub de Formation",
                  style: GoogleFonts.inter(color: kTextDark, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5),
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
// ✨ CUSTOM GLASSMORPHIC TRAINING CARD (Hover & Mobile Optimized)
// -----------------------------------------------------------------------------
class _GlassTrainingCategoryCard extends StatefulWidget {
  final DocumentSnapshot doc;
  final int index;
  final bool isManager;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GlassTrainingCategoryCard({
    required this.doc,
    required this.index,
    required this.isManager,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_GlassTrainingCategoryCard> createState() => _GlassTrainingCategoryCardState();
}

class _GlassTrainingCategoryCardState extends State<_GlassTrainingCategoryCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final String title = data['name'] ?? 'Inconnu';
    final String? imageUrl = data.containsKey('imageUrl') ? data['imageUrl'] : null;

    final delay = widget.index * 50;

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
            duration: const Duration(milliseconds: 250),
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
                  // 📷 IMAGE LAYER (Takes up top 65%)
                  Positioned(
                    top: 0, left: 0, right: 0, height: 200, // Adjust height based on aspect ratio
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(color: Colors.black.withOpacity(0.05), child: const Center(child: CircularProgressIndicator.adaptive()));
                      },
                      errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
                    )
                        : _buildFallbackIcon(),
                  ),

                  // 📝 TEXT LAYER (Frosted Glass at the bottom)
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
                                  title,
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
      color: Colors.blueAccent.withOpacity(0.05),
      child: Center(
        child: Icon(Icons.menu_book_rounded, size: 48, color: Colors.blueAccent.withOpacity(0.3)),
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
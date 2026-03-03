// lib/screens/service_technique/training_system_detail_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:boitex_info_app/screens/service_technique/training_document_list_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';

// 🎨 --- 2026 PREMIUM APPLE CONSTANTS --- 🎨
const kTextDark = Color(0xFF1D1D1F);
const kTextSecondary = Color(0xFF86868B);
const kAppleBlue = Color(0xFF007AFF);
const double kRadius = 24.0;

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
  State<TrainingSystemDetailPage> createState() => _TrainingSystemDetailPageState();
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
    // Using the same logic as the other hub pages
    bool isMgr = role != null && RolePermissions.canSeeAdminCard(role);
    if (mounted) setState(() => _isManager = isMgr);
  }

  // ===========================================================================
  // ✏️ PREMIUM ADD / EDIT DIALOG
  // ===========================================================================

  void _showSubSystemDialog({DocumentSnapshot? existingDoc}) {
    if (existingDoc != null) {
      _subSystemNameController.text = existingDoc['name'] ?? '';
    } else {
      _subSystemNameController.clear();
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: kAppleBlue.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.account_tree_rounded, color: kAppleBlue, size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        existingDoc == null ? 'Nouveau Sous-système' : 'Modifier',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 24),

                      // Text Field
                      TextFormField(
                        controller: _subSystemNameController,
                        autofocus: true,
                        style: GoogleFonts.inter(fontSize: 16, color: kTextDark, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'Nom du module',
                          labelStyle: GoogleFonts.inter(color: kTextSecondary),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.04),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.folder_special_rounded, color: kTextSecondary),
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
                              onPressed: () {
                                final name = _subSystemNameController.text.trim();
                                if (name.isNotEmpty) {
                                  if (existingDoc == null) {
                                    _subSystemsCollection.add({'name': name, 'createdAt': FieldValue.serverTimestamp()});
                                  } else {
                                    _subSystemsCollection.doc(existingDoc.id).update({'name': name});
                                  }
                                  Navigator.pop(context);
                                }
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
  }

  void _showDeleteConfirmDialog(String docId, String subSystemName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Supprimer ?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextDark)),
        content: Text('Voulez-vous vraiment supprimer "$subSystemName" ?', style: GoogleFonts.inter(color: kTextDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30), elevation: 0),
            onPressed: () {
              _subSystemsCollection.doc(docId).delete();
              Navigator.pop(context);
            },
            child: Text('Supprimer', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
        onPressed: () => _showSubSystemDialog(),
        backgroundColor: kTextDark,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text("Module", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  stops: [0.0, 0.5, 1.0],
                  colors: [
                    Color(0xFFE8F1F5), // White-ish Blue
                    Color(0xFFB4AEE8), // Soft Purple
                    Color(0xFF8EC5FC), // Light Cyan
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.white.withOpacity(0.35)),
            ),
          ),

          // ✨ 2. ADAPTIVE SLIVER SCROLL VIEW
          CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildGlassSliverAppBar(),
              StreamBuilder<QuerySnapshot>(
                stream: _subSystemsCollection.orderBy('name').snapshots(),
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
                            Icon(Icons.folder_off_rounded, size: 64, color: Colors.black.withOpacity(0.1)),
                            const SizedBox(height: 16),
                            Text("Aucun module trouvé.", style: GoogleFonts.inter(color: kTextSecondary, fontSize: 16)),
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
                        maxCrossAxisExtent: 250,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.1, // Folder proportion
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final subSystemName = data['name'] ?? 'Sans nom';

                          return _GlassSubSystemCard(
                            doc: doc,
                            name: subSystemName,
                            index: index,
                            isManager: _isManager,
                            onEdit: () => _showSubSystemDialog(existingDoc: doc),
                            onDelete: () => _showDeleteConfirmDialog(doc.id, subSystemName),
                            onTap: () {
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
                  "SOUS-SYSTÈMES",
                  style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 1.2),
                ),
                Text(
                  widget.systemName,
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
// ✨ CUSTOM GLASSMORPHIC SUB-SYSTEM FOLDER CARD
// -----------------------------------------------------------------------------
class _GlassSubSystemCard extends StatefulWidget {
  final DocumentSnapshot doc;
  final String name;
  final int index;
  final bool isManager;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GlassSubSystemCard({
    required this.doc,
    required this.name,
    required this.index,
    required this.isManager,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_GlassSubSystemCard> createState() => _GlassSubSystemCardState();
}

class _GlassSubSystemCardState extends State<_GlassSubSystemCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final delay = widget.index * 40;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        if (value == 0 && delay > 0) Future.delayed(Duration(milliseconds: delay));
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
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
            transform: Matrix4.identity()..scale(_isPressed ? 0.95 : (_isHovered ? 1.03 : 1.0)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(_isHovered ? 0.8 : 0.6),
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isHovered ? 0.08 : 0.04),
                  blurRadius: _isHovered ? 30 : 20,
                  offset: Offset(0, _isHovered ? 12 : 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Icon & Manager Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: kAppleBlue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.folder_shared_rounded, color: kAppleBlue, size: 24),
                          ),
                          if (widget.isManager)
                            Row(
                              children: [
                                _buildGlassMiniButton(Icons.edit_rounded, Colors.black87, widget.onEdit),
                                const SizedBox(width: 4),
                                _buildGlassMiniButton(Icons.delete_outline_rounded, const Color(0xFFFF3B30), widget.onDelete),
                              ],
                            ),
                        ],
                      ),
                      const Spacer(),

                      // Title
                      Text(
                        widget.name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: kTextDark,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text("Ouvrir", style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: kTextSecondary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassMiniButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.8)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
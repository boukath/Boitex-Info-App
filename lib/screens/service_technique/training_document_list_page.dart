// lib/screens/service_technique/training_document_list_page.dart

import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';

// THUMBNAILS & MEDIA IMPORTS
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:shimmer/shimmer.dart';

import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';

// 🎨 --- 2026 PREMIUM APPLE CONSTANTS --- 🎨
const kTextDark = Color(0xFF1D1D1F);
const kTextSecondary = Color(0xFF86868B);
const kAppleBlue = Color(0xFF007AFF);
const double kRadius = 24.0;

class TrainingDocumentListPage extends StatefulWidget {
  final String categoryId;
  final String systemId;
  final String subSystemId;
  final String subSystemName;

  const TrainingDocumentListPage({
    super.key,
    required this.categoryId,
    required this.systemId,
    required this.subSystemId,
    required this.subSystemName,
  });

  @override
  State<TrainingDocumentListPage> createState() => _TrainingDocumentListPageState();
}

class _TrainingDocumentListPageState extends State<TrainingDocumentListPage> {
  bool _isManager = false;
  late final CollectionReference _documentsCollection;

  // Upload State
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  final String _getB2UploadUrlCloudFunctionUrl = 'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  @override
  void initState() {
    super.initState();
    _documentsCollection = FirebaseFirestore.instance
        .collection('training_categories')
        .doc(widget.categoryId)
        .collection('training_systems')
        .doc(widget.systemId)
        .collection('training_sub_systems')
        .doc(widget.subSystemId)
        .collection('training_documents');

    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final role = await UserRoles.getCurrentUserRole();
    bool isMgr = role != null && RolePermissions.canSeeAdminCard(role);
    if (mounted) setState(() => _isManager = isMgr);
  }

  // ===========================================================================
  // ☁️ B2 UPLOAD LOGIC
  // ===========================================================================

  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response = await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting B2 credentials: $e');
    }
    return null;
  }

  Future<String?> _uploadFileToB2(File file, Map<String, dynamic> b2Creds, StateSetter setProgressState) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final fileName = 'training_documents/${const Uuid().v4()}_${path.basename(file.path)}';

      String mimeType = 'application/octet-stream';
      final ext = path.extension(fileName).toLowerCase();
      if (ext == '.jpg' || ext == '.jpeg') mimeType = 'image/jpeg';
      else if (ext == '.png') mimeType = 'image/png';
      else if (ext == '.pdf') mimeType = 'application/pdf';
      else if (ext == '.mp4') mimeType = 'video/mp4';
      else if (ext == '.mov') mimeType = 'video/quicktime';

      final request = http.MultipartRequest('POST', uploadUri);
      request.headers.addAll({
        'Authorization': b2Creds['authorizationToken'] as String,
        'X-Bz-File-Name': Uri.encodeComponent(fileName),
        'Content-Type': mimeType,
        'X-Bz-Content-Sha1': sha1Hash,
      });

      request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));

      final streamedResponse = await request.send();
      if (streamedResponse.statusCode == 200) {
        final respStr = await streamedResponse.stream.bytesToString();
        final body = json.decode(respStr) as Map<String, dynamic>;
        final encodedPath = (body['fileName'] as String).split('/').map(Uri.encodeComponent).join('/');
        return "${b2Creds['downloadUrlPrefix']}$encodedPath";
      }
    } catch (e) {
      debugPrint('Error uploading file to B2: $e');
    }
    return null;
  }

  // ===========================================================================
  // ➕ ADD DOCUMENT ACTIONS
  // ===========================================================================

  void _showAddDocumentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40)],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 24),
                      Text("Ajouter un document", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -0.5)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildGlassMenuOption(Icons.image_rounded, "Photo", Colors.pinkAccent, () { Navigator.pop(context); _pickFile(FileType.image); }),
                          _buildGlassMenuOption(Icons.videocam_rounded, "Vidéo", Colors.deepPurpleAccent, () { Navigator.pop(context); _pickFile(FileType.video); }),
                          _buildGlassMenuOption(Icons.description_rounded, "PDF/Doc", kAppleBlue, () { Navigator.pop(context); _pickFile(FileType.any); }),
                        ],
                      ),
                      const SizedBox(height: 16),
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

  Widget _buildGlassMenuOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextDark)),
        ],
      ),
    );
  }

  Future<void> _pickFile(FileType fileType) async {
    File? fileToUpload;
    String fileName = '';
    String title = '';
    String docType = 'document';

    if (fileType == FileType.image || fileType == FileType.video) {
      final picker = ImagePicker();
      final XFile? media = fileType == FileType.image
          ? await picker.pickImage(source: ImageSource.gallery, imageQuality: 80)
          : await picker.pickVideo(source: ImageSource.gallery);

      if (media != null) {
        fileToUpload = File(media.path);
        fileName = media.name;
        docType = fileType == FileType.image ? 'image' : 'video';
      }
    } else {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
      if (result != null && result.files.single.path != null) {
        fileToUpload = File(result.files.single.path!);
        fileName = result.files.single.name;
        docType = 'document';
      }
    }

    if (fileToUpload == null) return;

    final TextEditingController titleController = TextEditingController(text: path.basenameWithoutExtension(fileName));

    bool shouldUpload = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: Text('Détails du document', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextDark)),
        content: TextField(
          controller: titleController,
          style: GoogleFonts.inter(color: kTextDark, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: 'Titre',
            labelStyle: GoogleFonts.inter(color: kTextSecondary),
            filled: true,
            fillColor: Colors.black.withOpacity(0.04),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler', style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kAppleBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Uploader', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (!shouldUpload) return;
    title = titleController.text.trim();
    if (title.isEmpty) title = "Document sans titre";

    _performUpload(fileToUpload, title, docType);
  }

  Future<void> _performUpload(File file, String title, String docType) async {
    setState(() { _isUploading = true; _uploadProgress = 0.0; });

    try {
      final b2Creds = await _getB2UploadCredentials();
      if (b2Creds == null) throw Exception("B2 Auth Failed");

      final downloadUrl = await _uploadFileToB2(file, b2Creds, (setState) {});
      if (downloadUrl == null) throw Exception("Upload Failed");

      await _documentsCollection.add({
        'title': title,
        'type': docType,
        'url': downloadUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Ajouté avec succès !", style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF34C759),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur: $e", style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ===========================================================================
  // 🎨 MAIN UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      floatingActionButton: _isManager && !_isUploading
          ? FloatingActionButton.extended(
        onPressed: _showAddDocumentMenu,
        backgroundColor: kTextDark,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text("Document", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  stops: [0.0, 0.5, 1.0],
                  colors: [
                    Color(0xFFE8F1F5), // White-ish
                    Color(0xFFC3B4E3), // Deep Violet
                    Color(0xFF8EC5FC), // Light Cyan
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.white.withOpacity(0.3)),
            ),
          ),

          // ✨ 2. MAIN SLIVER CONTENT
          CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildGlassSliverAppBar(),

              if (_isUploading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator.adaptive()),
                          const SizedBox(width: 16),
                          Text("Upload en cours...", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextDark)),
                        ],
                      ),
                    ),
                  ),
                ),

              StreamBuilder<QuerySnapshot>(
                stream: _documentsCollection.orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(child: Center(child: CircularProgressIndicator.adaptive()));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 64, color: Colors.black.withOpacity(0.1)),
                            const SizedBox(height: 16),
                            Text("Aucun document.", style: GoogleFonts.inter(color: kTextSecondary, fontSize: 16)),
                          ],
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10).copyWith(bottom: 120),
                    sliver: SliverGrid(
                      // 🔥 ADAPTIVE WEB & MOBILE GRID
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.9,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          return _GlassDocumentCard(
                            doc: docs[index],
                            index: index,
                            isManager: _isManager,
                            onDelete: () async {
                              bool? confirm = await showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: Text("Supprimer ?", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextDark)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Annuler", style: GoogleFonts.inter(color: kTextSecondary))),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30), elevation: 0),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text("Supprimer", style: GoogleFonts.inter(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _documentsCollection.doc(docs[index].id).delete();
                              }
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
                  "DOCUMENTS & MEDIAS",
                  style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 1.2),
                ),
                Text(
                  widget.subSystemName,
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
// ✨ CUSTOM GLASSMORPHIC DOCUMENT CARD (Hover & Mobile Optimized)
// -----------------------------------------------------------------------------
class _GlassDocumentCard extends StatefulWidget {
  final DocumentSnapshot doc;
  final int index;
  final bool isManager;
  final VoidCallback onDelete;

  const _GlassDocumentCard({
    required this.doc,
    required this.index,
    required this.isManager,
    required this.onDelete,
  });

  @override
  State<_GlassDocumentCard> createState() => _GlassDocumentCardState();
}

class _GlassDocumentCardState extends State<_GlassDocumentCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  void _openDocument(BuildContext context, String type, String url, String title) {
    if (type == 'image') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ImageGalleryPage(imageUrls: [url], initialIndex: 0)));
    } else if (type == 'video') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerPage(videoUrl: url)));
    } else {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final String title = data['title'] ?? 'Document';
    final String type = data['type'] ?? 'document';
    final String url = data['url'] ?? '';

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
          onTap: () => _openDocument(context, type, url, title),
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
                  // 🖼️ MEDIA PREVIEW LAYER
                  Positioned(
                    top: 0, left: 0, right: 0, bottom: 60,
                    child: _buildMediaPreview(type, url),
                  ),

                  // 📝 TEXT LAYER (Frosted Bottom Panel)
                  Positioned(
                    bottom: 0, left: 0, right: 0, height: 60,
                    child: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.5))),
                          ),
                          child: Row(
                            children: [
                              _getMiniIcon(type),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  title,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -0.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ⚙️ MANAGER DELETE BUTTON
                  if (widget.isManager)
                    Positioned(
                      top: 8, right: 8,
                      child: GestureDetector(
                        onTap: widget.onDelete,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.8)),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFFF3B30)),
                            ),
                          ),
                        ),
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

  Widget _buildMediaPreview(String type, String url) {
    if (type == 'image') {
      return Image.network(
        url, fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) => progress == null ? child : Container(color: Colors.black.withOpacity(0.05), child: const Center(child: CircularProgressIndicator.adaptive())),
        errorBuilder: (ctx, err, stack) => _buildFallbackIcon(Icons.image_not_supported_rounded, Colors.pink),
      );
    } else if (type == 'video') {
      return VideoThumbnailWidget(videoUrl: url);
    } else {
      return _buildFallbackIcon(Icons.picture_as_pdf_rounded, kAppleBlue);
    }
  }

  Widget _buildFallbackIcon(IconData icon, Color color) {
    return Container(
      color: color.withOpacity(0.05),
      child: Center(child: Icon(icon, size: 48, color: color.withOpacity(0.4))),
    );
  }

  Widget _getMiniIcon(String type) {
    IconData icon;
    Color color;
    if (type == 'image') { icon = Icons.image_rounded; color = Colors.pinkAccent; }
    else if (type == 'video') { icon = Icons.play_circle_fill_rounded; color = Colors.deepPurpleAccent; }
    else { icon = Icons.insert_drive_file_rounded; color = kAppleBlue; }

    return Icon(icon, size: 16, color: color);
  }
}

// -----------------------------------------------------------------------------
// 🎬 PREMIUM VIDEO THUMBNAIL GENERATOR
// -----------------------------------------------------------------------------
class VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;
  const VideoThumbnailWidget({super.key, required this.videoUrl});

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  String? _thumbnailPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: widget.videoUrl,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.WEBP,
        quality: 50,
      );
      if (mounted) setState(() { _thumbnailPath = thumbnailPath; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.black.withOpacity(0.05),
        highlightColor: Colors.white.withOpacity(0.5),
        child: Container(color: Colors.white),
      );
    }
    if (_thumbnailPath == null) {
      return Container(
        color: Colors.deepPurpleAccent.withOpacity(0.05),
        child: Center(child: Icon(Icons.videocam_off_rounded, color: Colors.deepPurpleAccent.withOpacity(0.4), size: 40)),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(_thumbnailPath!), fit: BoxFit.cover),
        Container(color: Colors.black.withOpacity(0.2)), // Darken for contrast
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
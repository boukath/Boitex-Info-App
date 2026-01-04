import 'dart:io';
import 'dart:ui'; // Required for ImageFilter
import 'dart:convert';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

// ✅ IMPORTS FOR THUMBNAILS AND LOADING
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:shimmer/shimmer.dart';

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
  State<TrainingDocumentListPage> createState() =>
      _TrainingDocumentListPageState();
}

class _TrainingDocumentListPageState extends State<TrainingDocumentListPage> {
  bool _isManager = false;
  final TextEditingController _docNameController = TextEditingController();
  late final CollectionReference _documentsCollection;
  bool _isLoading = false;

  final String b2PublicUrl = 'https://f003.backblazeb2.com/file/BoitexInfo';

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

  @override
  void dispose() {
    _docNameController.dispose();
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

  void _showAddDocumentDialog() {
    _docNameController.clear();
    File? pickedFile;
    String pickedFileName = 'Aucun fichier sélectionné';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _buildModernDialog(
              title: 'Nouveau Document',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input Name
                  TextField(
                    controller: _docNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nom du document (ex: Manuel)',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00F0FF)),
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),

                  // File Picker Button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Sélectionner Fichier'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: const Color(0xFF00F0FF),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: [
                                'pdf', 'png', 'jpg', 'jpeg', 'mp4', 'mov', 'avi'
                              ],
                            );
                            if (result != null) {
                              pickedFile = File(result.files.single.path!);
                              setDialogState(() {
                                pickedFileName = result.files.single.name;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pickedFileName,
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Ajouter'),
                  onPressed: () {
                    final name = _docNameController.text.trim();
                    if (name.isNotEmpty && pickedFile != null) {
                      _addDocument(name, pickedFile!);
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nom et fichier requis.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
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

  void _showDeleteConfirmDialog(DocumentSnapshot doc) {
    final String docName = (doc.data() as Map<String, dynamic>)['name'] ?? '...';
    showDialog(
      context: context,
      builder: (context) {
        return _buildModernDialog(
          title: 'Supprimer',
          content: Text(
              'Voulez-vous vraiment supprimer "$docName" ?\nCette action est irréversible.',
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
                _deleteDocument(doc);
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
  // ☁️ B2 LOGIC
  // ===========================================================================

  Future<Map<String, String>?> _getB2UploadUrl() async {
    try {
      final functionUrl = Uri.parse(
          'https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl');
      final response = await http.get(functionUrl);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'uploadUrl': data['uploadUrl'] as String,
          'authorizationToken': data['authorizationToken'] as String,
        };
      } else {
        print('Error getting B2 URL - Status ${response.statusCode}');
      }
    } catch (e) {
      print('Error calling B2 upload function: $e');
    }
    return null;
  }

  Future<void> _addDocument(String name, File file) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final b2Data = await _getB2UploadUrl();
      if (b2Data == null) throw Exception('Impossible d\'obtenir l\'URL d\'upload B2.');

      final uploadUrl = b2Data['uploadUrl']!;
      final token = b2Data['authorizationToken']!;

      final fileBytes = await file.readAsBytes();
      final hash = sha1.convert(fileBytes).toString();
      final fileExtension = path.extension(file.path).replaceAll('.', '');
      final docType = _getFileType(fileExtension);
      final uniqueId = const Uuid().v4();
      final b2FileName = 'training_documents/$uniqueId.$fileExtension';

      final response = await http.post(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': token,
          'X-Bz-File-Name': b2FileName,
          'Content-Type': 'application/octet-stream',
          'Content-Length': fileBytes.length.toString(),
          'X-Bz-Content-Sha1': hash,
        },
        body: fileBytes,
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur d\'upload B2: ${response.body}');
      }
      final publicUrl = '$b2PublicUrl/$b2FileName';
      await _documentsCollection.add({
        'name': name,
        'type': docType,
        'url': publicUrl,
        'b2FileName': b2FileName,
        'fileExtension': fileExtension,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document téléversé.'), backgroundColor: Color(0xFF00F0FF)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDocument(DocumentSnapshot doc) async {
    setState(() => _isLoading = true);
    try {
      await _documentsCollection.doc(doc.id).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getFileType(String extension) {
    final ext = extension.toLowerCase();
    if (ext == 'pdf') return 'pdf';
    if (['png', 'jpg', 'jpeg'].contains(ext)) return 'image';
    if (['mp4', 'mov', 'avi', 'wmv'].contains(ext)) return 'video';
    return 'other';
  }

  Future<void> _openDocument(Map<String, dynamic> data) async {
    if (!data.containsKey('url') || data['url'] == null) return;

    final String url = data['url'];
    final String type = data['type'] ?? 'other';
    final uri = Uri.tryParse(url);

    if (uri == null) return;

    switch (type) {
      case 'pdf':
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        break;
      case 'image':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageGalleryPage(
              imageUrls: [url],
              initialIndex: 0,
            ),
          ),
        );
        break;
      case 'video':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerPage(videoUrl: url),
          ),
        );
        break;
      default:
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
    }
  }

  // ===========================================================================
  // 💎 GLASSMORPHIC CARD
  // ===========================================================================

  Widget _buildDocumentCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final docName = data['name'] ?? 'Sans nom';
    final docType = data['type'] ?? 'other';
    final docExtension = data['fileExtension'] ?? '...';
    final url = data['url'] ?? '';

    return Container(
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
          child: InkWell(
            onTap: () => _openDocument(data),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail section
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DocumentThumbnail(docType: docType, url: url),
                      // Gradient overlay for text readability
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      // Type Badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Text(
                            docExtension.toUpperCase(),
                            style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      // Delete button (Manager)
                      if (_isManager)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: () => _showDeleteConfirmDialog(doc),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                              ),
                              child: const Icon(Icons.close, color: Colors.redAccent, size: 14),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Text content section
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        docName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
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
        title: Text(widget.subSystemName.toUpperCase()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: _isManager
          ? InkWell(
        onTap: _showAddDocumentDialog,
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
          child: const Icon(Icons.note_add, color: Colors.black),
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
            bottom: -100, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00F0FF).withOpacity(0.05),
                boxShadow: [BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.1), blurRadius: 150)],
              ),
            ),
          ),

          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: _documentsCollection.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingGrid();
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Erreur de chargement.', style: TextStyle(color: Colors.white54)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_off_outlined, size: 60, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text('Aucun document.', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildDocumentCard(docs[index]);
                  },
                );
              },
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF00F0FF)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.1),
      highlightColor: Colors.white.withOpacity(0.05),
      child: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 0.8,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }
}

// ✅ THUMBNAIL HELPERS (Dark Mode optimized)
class DocumentThumbnail extends StatelessWidget {
  final String docType;
  final String url;

  const DocumentThumbnail({super.key, required this.docType, required this.url});

  Widget _buildLoadingPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.1),
      highlightColor: Colors.white.withOpacity(0.05),
      child: Container(color: Colors.black),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (docType) {
      case 'image':
        return Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingPlaceholder();
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(child: Icon(Icons.broken_image, color: Colors.white24));
          },
        );
      case 'video':
        return VideoThumbnailWidget(videoUrl: url);
      case 'pdf':
        return Container(
          color: const Color(0xFF1E1E2C),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 8),
              Text("PDF", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      default:
        return Container(
          color: const Color(0xFF1E1E2C),
          child: Center(
            child: Icon(Icons.insert_drive_file, color: Colors.white.withOpacity(0.2), size: 40),
          ),
        );
    }
  }
}

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
      if (mounted) {
        setState(() {
          _thumbnailPath = thumbnailPath;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.05),
        child: Container(color: Colors.black),
      );
    }

    if (_thumbnailPath == null) {
      return Container(
        color: const Color(0xFF1E1E2C),
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white24, size: 40),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(_thumbnailPath!), fit: BoxFit.cover),
        Container(
          color: Colors.black.withOpacity(0.3),
          child: const Center(
            child: Icon(Icons.play_circle_fill, color: Color(0xFF00F0FF), size: 40),
          ),
        ),
      ],
    );
  }
}
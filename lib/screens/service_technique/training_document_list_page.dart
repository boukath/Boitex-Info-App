// lib/screens/service_technique/training_document_list_page.dart
import 'dart:io';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

// ✅ 1. ADD NEW IMPORTS FOR THUMBNAILS AND LOADING
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

  // This is the correct, working URL
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

  // --- No changes to these functions ---
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
            return AlertDialog(
              title: const Text('Nouveau Document'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _docNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du document (ex: Manuel...)',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Sélectionner Fichier'),
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: [
                                'pdf',
                                'png',
                                'jpg',
                                'jpeg',
                                'mp4',
                                'mov',
                                'avi'
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pickedFileName,
                            style: const TextStyle(color: Colors.black54),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Annuler'),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: const Text('Ajouter'),
                  onPressed: () {
                    final name = _docNameController.text.trim();
                    if (name.isNotEmpty && pickedFile != null) {
                      _addDocument(name, pickedFile!);
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Veuillez entrer un nom ET sélectionner un fichier.'),
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
        print(
            'Error getting B2 URL - Status ${response.statusCode}: ${response.body}');
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
      if (b2Data == null) {
        throw Exception('Impossible d\'obtenir l\'URL d\'upload B2.');
      }

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
          const SnackBar(
            content: Text('Document téléversé avec succès.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDeleteConfirmDialog(DocumentSnapshot doc) {
    final String docName = (doc.data() as Map<String, dynamic>)['name'] ?? '...';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer le Document'),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer le document "$docName" ?'),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer'),
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

  Future<void> _deleteDocument(DocumentSnapshot doc) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _documentsCollection.doc(doc.id).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getFileType(String extension) {
    final ext = extension.toLowerCase();
    if (ext == 'pdf') {
      return 'pdf';
    }
    if (['png', 'jpg', 'jpeg'].contains(ext)) {
      return 'image';
    }
    if (['mp4', 'mov', 'avi', 'wmv'].contains(ext)) {
      return 'video';
    }
    return 'other';
  }

  Future<void> _openDocument(Map<String, dynamic> data) async {
    if (!data.containsKey('url') || data['url'] == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL du document non trouvée.')),
        );
      }
      return;
    }

    final String url = data['url'];
    final String type = data['type'] ?? 'other';
    final uri = Uri.tryParse(url);

    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('URL invalide: $url')),
        );
      }
      return;
    }

    switch (type) {
      case 'pdf':
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Impossible d\'ouvrir le PDF: $url')),
            );
          }
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
            builder: (context) => VideoPlayerPage(
              videoUrl: url,
            ),
          ),
        );
        break;
      default:
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                  Text('Impossible d\'ouvrir ce type de fichier: $type')),
            );
          }
        }
    }
  }
  // --- End of unchanged functions ---

  // ✅ 2. DELETED the old `_buildFileIcon` function. It's replaced by DocumentThumbnail.

  // ✅ 3. NEW: A dedicated widget to build the card for our GridView
  Widget _buildDocumentCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final docName = data['name'] ?? 'Sans nom';
    final docType = data['type'] ?? 'other';
    final docExtension = data['fileExtension'] ?? '...';
    final url = data['url'] ?? '';

    return Card(
      clipBehavior: Clip.antiAlias, // Ensures the thumbnail corners are rounded
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 3,
      child: InkWell(
        onTap: () {
          _openDocument(data);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail section
            AspectRatio(
              aspectRatio: 16 / 10,
              child: DocumentThumbnail(
                docType: docType,
                url: url,
              ),
            ),
            // Text content section
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    docName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '.$docExtension',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            // Delete button (if manager)
            if (_isManager) ...[
              const Spacer(), // Pushes the button to the bottom
              Align(
                alignment: Alignment.bottomRight,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent),
                  tooltip: 'Supprimer le document',
                  onPressed: () {
                    _showDeleteConfirmDialog(doc);
                  },
                ),
              ),
            ] else
              const Spacer(), // Use spacer to keep card heights consistent
          ],
        ),
      ),
    );
  }

  // ✅ 4. UPDATED: The main build method now uses GridView.builder
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subSystemName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      floatingActionButton: _isManager
          ? FloatingActionButton(
        onPressed: _showAddDocumentDialog,
        child: const Icon(Icons.note_add),
        tooltip: 'Ajouter un document',
      )
          : null,
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _documentsCollection
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // Show a loading grid
                return _buildLoadingGrid();
              }
              if (snapshot.hasError) {
                return const Center(
                    child: Text('Erreur de chargement des documents.'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                    child: Text(
                        'Aucun document trouvé pour ${widget.subSystemName}.'));
              }

              final docs = snapshot.data!.docs;

              // Use GridView.builder instead of ListView
              return GridView.builder(
                padding: const EdgeInsets.all(12.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 columns
                  crossAxisSpacing: 12.0, // Spacing between columns
                  mainAxisSpacing: 12.0, // Spacing between rows
                  childAspectRatio: 0.75, // Adjust height vs width
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  return _buildDocumentCard(docs[index]);
                },
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Téléchargement en cours...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ 5. NEW: A helper to show a loading state for the grid
  Widget _buildLoadingGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(12.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          childAspectRatio: 0.75,
        ),
        itemCount: 6, // Show 6 shimmer cards
        itemBuilder: (context, index) {
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ✅ 6. NEW: Helper widget to display the correct thumbnail
class DocumentThumbnail extends StatelessWidget {
  final String docType;
  final String url;

  const DocumentThumbnail({
    super.key,
    required this.docType,
    required this.url,
  });

  // Loading placeholder
  Widget _buildLoadingPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(color: Colors.white),
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
            return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
          },
        );
      case 'video':
        return VideoThumbnailWidget(videoUrl: url);
      case 'pdf':
        return Container(
          color: Colors.red[50],
          child: const Center(
            child: Icon(Icons.picture_as_pdf, color: Colors.red, size: 40),
          ),
        );
      default:
        return Container(
          color: Colors.grey[200],
          child: Center(
            child: Icon(Icons.insert_drive_file, color: Colors.grey[700], size: 40),
          ),
        );
    }
  }
}

// ✅ 7. NEW: Stateful widget to generate and display video thumbnails
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
      print('Error generating video thumbnail: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Loading placeholder
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(color: Colors.white),
      );
    }

    if (_thumbnailPath == null) {
      // Error placeholder
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Icon(Icons.movie_creation, color: Colors.grey[700], size: 40),
        ),
      );
    }

    // Display the thumbnail
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(_thumbnailPath!),
          fit: BoxFit.cover,
        ),
        // Play icon overlay
        Container(
          color: Colors.black.withOpacity(0.2),
          child: const Center(
            child: Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ],
    );
  }
}
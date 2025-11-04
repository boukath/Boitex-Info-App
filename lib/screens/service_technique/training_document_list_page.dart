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

// ✅ 1. CLONED IMPORTS (from intervention_details_page.dart)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

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

  // ✅ 2. CLONED B2 PUBLIC URL (from intervention_details_page.dart)
  final String b2PublicUrl = 'https://f005.backblazeb2.com/file/boitex-info-bucket';

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
                                'png', 'jpg', 'jpeg',
                                'mp4', 'mov', 'avi'
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

  // ✅ 3. CLONED FUNCTION (from intervention_details_page.dart)
  /// Calls the Firebase Function to get a B2 upload URL
  Future<Map<String, String>?> _getB2UploadUrl() async {
    try {
      // NOTE: This MUST match your Firebase Function name in `index.ts`
      final functionUrl =
      Uri.parse('https://europe-west1-boitex-info-app.cloudfunctions.net/getB2UploadUrl');
      final response = await http.get(functionUrl);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'uploadUrl': data['uploadUrl'] as String,
          'authorizationToken': data['authorizationToken'] as String,
        };
      }
    } catch (e) {
      print('Error getting B2 upload URL: $e');
    }
    return null;
  }

  // ✅ 4. UPGRADED: Function now uploads to B2, not Firebase Storage
  Future<void> _addDocument(String name, File file) async {
    setState(() { _isLoading = true; });

    try {
      // 1. Get B2 Upload URL from our cloud function
      final b2Data = await _getB2UploadUrl();
      if (b2Data == null) {
        throw Exception('Impossible d\'obtenir l\'URL d\'upload B2.');
      }

      final uploadUrl = b2Data['uploadUrl']!;
      final token = b2Data['authorizationToken']!;

      // 2. Get file info and calculate SHA1
      final fileBytes = await file.readAsBytes();
      final hash = sha1.convert(fileBytes).toString();
      final fileExtension = path.extension(file.path).substring(1);
      final docType = _getFileType(fileExtension);
      final uniqueId = const Uuid().v4();
      final b2FileName = 'training_documents/$uniqueId.$fileExtension';

      // 3. Upload file directly to B2 (cloned from intervention_details_page.dart)
      final response = await http.post(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': token,
          'X-Bz-File-Name': b2FileName,
          'Content-Type': 'application/octet-stream', // Use generic stream or mime type
          'Content-Length': fileBytes.length.toString(),
          'X-Bz-Content-Sha1': hash,
        },
        body: fileBytes,
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur d\'upload B2: ${response.body}');
      }

      // 4. Get the final public URL
      final publicUrl = '$b2PublicUrl/$b2FileName';

      // 5. Save document info to Firestore
      await _documentsCollection.add({
        'name': name,
        'type': docType,
        'url': publicUrl, // This is now the B2 URL
        'b2FileName': b2FileName, // Save B2 name for future (e.g., deletion)
        'fileExtension': fileExtension,
        'createdAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
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

  // ✅ 5. UPGRADED: Cloned deletion logic (only deletes from Firestore)
  Future<void> _deleteDocument(DocumentSnapshot doc) async {
    // Your app's pattern (from intervention_details_page.dart)
    // seems to only remove the Firestore reference, not the B2 file.
    // I am cloning that logic here.

    // If you DO have a cloud function for B2 deletion,
    // you would call it here before deleting the doc.
    // (e.g., await http.post(Uri.parse('.../deleteB2File'), body: {'b2FileName': ...}))

    setState(() { _isLoading = true; });
    try {
      // Delete document from Firestore
      await _documentsCollection.doc(doc.id).delete();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // Helper to get file type from extension
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

  // Helper to build colorful icons
  Widget _buildFileIcon(String type) {
    switch (type) {
      case 'pdf':
        return const Icon(Icons.picture_as_pdf, color: Colors.redAccent);
      case 'image':
        return const Icon(Icons.image, color: Colors.blueAccent);
      case 'video':
        return const Icon(Icons.video_library, color: Colors.green);
      default:
        return const Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }

  // Handles opening the correct viewer for each file type
  Future<void> _openDocument(Map<String, dynamic> data) async {
    if (!data.containsKey('url') || data['url'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL du document non trouvée.')),
      );
      return;
    }

    final String url = data['url'];
    final String type = data['type'] ?? 'other';

    switch (type) {
      case 'pdf':
        final uri = Uri.tryParse(url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Impossible d\'ouvrir le PDF: $url')),
          );
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
        final uri = Uri.tryParse(url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Impossible d\'ouvrir ce type de fichier: $type')),
          );
        }
    }
  }

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
                return const Center(child: CircularProgressIndicator());
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

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final docName = data['name'] ?? 'Sans nom';
                  final docType = data['type'] ?? 'other';
                  final docExtension = data['fileExtension'] ?? '...';

                  return ListTile(
                    leading: _buildFileIcon(docType),
                    title: Text(docName),
                    subtitle: Text(
                      'Type: ${docType.toUpperCase()} ($docExtension)',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    onTap: () {
                      _openDocument(data);
                    },
                    trailing: _isManager
                        ? IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.red),
                      tooltip: 'Supprimer le document',
                      onPressed: () {
                        _showDeleteConfirmDialog(doc);
                      },
                    )
                        : null,
                  );
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
}
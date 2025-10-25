// lib/screens/administration/project_details_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/technical_evaluation_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart'; // ✅ REMOVED: No longer needed
import 'package:url_launcher/url_launcher.dart';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/widgets/product_selector_dialog.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
// import 'package:boitex_info_app/screens/administration/system_proposals_page.dart'; // REMOVED
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boitex_info_app/screens/service_it/it_evaluation_page.dart';
import 'package:path/path.dart' as path;
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';

// Imports for Backblaze B2 upload & PDF download
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
// Import for the PDF Viewer Page
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';
// Import for path_provider
import 'package:path_provider/path_provider.dart';


class ProjectDetailsPage extends StatefulWidget {
  final String projectId;
  final String userRole;

  const ProjectDetailsPage(
      {super.key, required this.projectId, required this.userRole});

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  bool _isActionInProgress = false;
  static const Color primaryColor = Colors.deepPurple;

  // B2 Cloud Function URL constant
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';


  // ✅ --- START: B2 HELPER FUNCTIONS ---
  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response =
      await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
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

  // Generic B2 Upload Helper
  Future<String?> _uploadFileToB2({
    required File file,
    required Map<String, dynamic> b2Creds,
    required String b2FileName, // The full desired path in B2
  }) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final String originalFileName = path.basename(file.path);

      // Determine mime type
      String? mimeType;
      final String extension = path.extension(originalFileName).toLowerCase();
      if (extension == '.jpg' || extension == '.jpeg') mimeType = 'image/jpeg';
      else if (extension == '.png') mimeType = 'image/png';
      else if (extension == '.pdf') mimeType = 'application/pdf';
      // Add more mime types if needed

      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(b2FileName), // Use the full B2 path
          'Content-Type': mimeType ?? 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final encodedPath = (body['fileName'] as String).split('/').map(Uri.encodeComponent).join('/');
        return (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
      } else {
        // Provide filename in error log
        debugPrint('Failed to upload file ($originalFileName) to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      // Provide filename in error log
      debugPrint('Error uploading file (${path.basename(file.path)}) to B2: $e');
      return null;
    }
  }
  // ✅ --- END: B2 HELPER FUNCTIONS ---


  // ✅ CHANGED: Upload Devis using Backblaze B2
  Future<void> _uploadDevis() async {
    setState(() { _isActionInProgress = true; });

    final b2Credentials = await _getB2UploadCredentials();
    if (b2Credentials == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Impossible de contacter le service d\'upload.'), backgroundColor: Colors.red),
        );
        setState(() { _isActionInProgress = false; });
      }
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        setState(() { _isActionInProgress = false; });
        return;
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final String b2DevisPath = 'devis/${widget.projectId}/$fileName';

      final downloadUrl = await _uploadFileToB2(
        file: file,
        b2Creds: b2Credentials,
        b2FileName: b2DevisPath,
      );

      if (downloadUrl != null) {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .update({
          'devisUrl': downloadUrl, // Store B2 URL
          'devisFileName': fileName,
          'status': 'Devis Envoyé',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Devis ajouté avec succès.')),
          );
        }
      } else {
        throw Exception('Échec de l\'upload du devis vers B2.');
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() { _isActionInProgress = false; });
      }
    }
  }


  // --- Approval Dialogs ---
  void _showApprovalDialog() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Preuve d\'Approbation'),
          content:
          const Text('Comment le client a-t-il approuvé le devis ?'),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _confirmApprovalByPhone();
                },
                child: const Text('Par Téléphone')),
            ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _uploadBonDeCommande(); // This now uses B2
                },
                child: const Text('Bon de Commande')),
          ],
        ));
  }
  Future<void> _confirmApprovalByPhone() async {
    final noteController = TextEditingController();
    final note = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmation par Téléphone'),
          content: TextField(
              controller: noteController,
              autofocus: true,
              decoration:
              const InputDecoration(labelText: 'Confirmé par (nom)')),
          actions: [
            TextButton(
                child: const Text('Annuler'),
                onPressed: () => Navigator.of(ctx).pop()),
            ElevatedButton(
                child: const Text('Confirmer'),
                onPressed: () => Navigator.of(ctx).pop(noteController.text)),
          ],
        ));

    if (note != null && note.isNotEmpty) {
      setState(() { _isActionInProgress = true; });
      try {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .update({
          'status': 'Finalisation de la Commande',
          'approvalType': 'Téléphone',
          'approvalNotes': note,
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      } finally {
        if (mounted) {
          setState(() { _isActionInProgress = false; });
        }
      }
    }
  }

  // ✅ CHANGED: Upload Bon de Commande using Backblaze B2
  Future<void> _uploadBonDeCommande() async {
    setState(() { _isActionInProgress = true; });

    final b2Credentials = await _getB2UploadCredentials();
    if (b2Credentials == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Impossible de contacter le service d\'upload.'), backgroundColor: Colors.red),
        );
        setState(() { _isActionInProgress = false; });
      }
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) {
        setState(() { _isActionInProgress = false; });
        return;
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final String b2BonPath = 'bon_de_commande/${widget.projectId}/$fileName';

      final downloadUrl = await _uploadFileToB2(
        file: file,
        b2Creds: b2Credentials,
        b2FileName: b2BonPath,
      );

      if(downloadUrl != null) {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .update({
          'bonDeCommandeUrl': downloadUrl, // Store B2 URL
          'bonDeCommandeFileName': fileName,
          'status': 'Finalisation de la Commande',
          'approvalType': 'Fichier',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bon de commande ajouté.')),
          );
        }
      } else {
        throw Exception('Échec de l\'upload du bon de commande vers B2.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() { _isActionInProgress = false; });
      }
    }
  }


  // --- Other existing functions ---
  void _showProductFinalizationDialog(List<dynamic> existingItems) {
    showDialog(
      context: context,
      builder: (context) => _OrderFinalizationDialog(
        projectId: widget.projectId,
        existingItems: existingItems,
      ),
    );
  }

  // ✅ REPLACED: Updated _createInstallationTask function
  Future<void> _createInstallationTask(Map<String, dynamic> projectData) async {
    setState(() => _isActionInProgress = true);
    // Capture context objects before async gaps
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Define the document reference outside the transaction for later use
      final newInstallationRef = FirebaseFirestore.instance.collection('installations').doc();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final currentYear = DateTime.now().year;
        final counterRef = FirebaseFirestore.instance
            .collection('counters')
            .doc('installation_counter_$currentYear');

        final counterDoc = await transaction.get(counterRef);
        final newCount = (counterDoc.data()?['count'] as int? ?? 0) + 1;
        final installationCode = 'INST-$newCount/$currentYear';

        // Add Null checks (??) for potentially missing fields
        transaction.set(newInstallationRef, {
          'installationCode': installationCode,
          'projectId': widget.projectId,
          'clientId': projectData['clientId'] ?? 'ID Client Manquant', // Provide default
          'clientName': projectData['clientName'] ?? 'Nom Client Manquant', // Provide default
          'clientPhone': projectData['clientPhone'] ?? '', // Default to empty string
          'storeId': projectData['storeId'], // Keep as null if missing
          'storeName': projectData['storeName'], // Keep as null if missing
          'initialRequest': projectData['initialRequest'] ?? 'N/A', // Default
          'technicalEvaluation': projectData['technical_evaluation'] ?? [], // Default to empty list
          'orderedProducts': projectData['orderedProducts'] ?? [], // Default to empty list
          'serviceType': projectData['serviceType'] ?? 'Inconnu', // Default
          'status': 'À Planifier',
          'createdAt': Timestamp.now(),
          // Add createdBy info if available
          'createdByUid': FirebaseAuth.instance.currentUser?.uid,
          'createdByName': FirebaseAuth.instance.currentUser?.displayName ?? 'Inconnu',
        });

        transaction.set(
            counterRef, {'count': newCount}, SetOptions(merge: true));

        final projectRef =
        FirebaseFirestore.instance.collection('projects').doc(widget.projectId);
        transaction
            .update(projectRef, {'status': 'Transféré à l\'Installation'});

      }); // End of Transaction

      // Get the newly created document AFTER the transaction commits successfully
      final newInstallationDoc = await newInstallationRef.get();

      // Check if document exists before navigating (important safety check)
      if (!newInstallationDoc.exists) {
        throw Exception("Le document d'installation n'a pas été créé correctement.");
      }

      // Use the navigator captured before the async gap
      // Check if the widget is still mounted before navigating
      if (mounted) {
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => InstallationDetailsPage(
                installationDoc: newInstallationDoc, // Pass the DocumentSnapshot
                userRole: widget.userRole
            ),
          ),
        );
      }

    } catch (e) {
      // Log the error for debugging
      debugPrint("*******************************************");
      debugPrint("Error creating installation task: $e");
      debugPrint("Project Data at time of error: $projectData");
      debugPrint("*******************************************");
      // Use the scaffoldMessenger captured before the async gap
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text('Erreur création tâche: ${e.toString()}'), // Show error to user
            backgroundColor: Colors.red
        ));
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }


  // UPLOAD PROJECT FILES TO B2
  Future<void> _uploadProjectFiles() async {
    setState(() { _isActionInProgress = true; });

    final b2Credentials = await _getB2UploadCredentials();
    if (b2Credentials == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Impossible de contacter le service d\'upload.'), backgroundColor: Colors.red),
        );
        setState(() { _isActionInProgress = false; });
      }
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() { _isActionInProgress = false; });
        return;
      }

      List<Map<String, String>> uploadedFilesData = [];
      int successCount = 0;

      for (var fileData in result.files) {
        if (fileData.path != null) {
          final file = File(fileData.path!);
          final originalFileName = fileData.name;
          final String uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$originalFileName';
          final String b2ProjectFilePath = 'project_files/${widget.projectId}/$uniqueFileName';

          final downloadUrl = await _uploadFileToB2( // Use generic helper
            file: file,
            b2Creds: b2Credentials,
            b2FileName: b2ProjectFilePath,
          );

          if (downloadUrl != null) {
            uploadedFilesData.add({
              'fileName': originalFileName,
              'fileUrl': downloadUrl,
              'uploadedAt': Timestamp.now().toDate().toIso8601String(),
            });
            successCount++;
          } else {
            debugPrint('Failed to upload project file: $originalFileName');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Échec upload: $originalFileName'), backgroundColor: Colors.orange),
              );
            }
          }
        }
      }

      if (uploadedFilesData.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .update({
          'projectFiles': FieldValue.arrayUnion(uploadedFilesData),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$successCount / ${result.files.length} fichier(s) ajouté(s).')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun fichier n\'a pu être uploadé.'), backgroundColor: Colors.orange),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur lors de l\'upload: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() { _isActionInProgress = false; });
      }
    }
  }

  // --- FILE OPENING ---
  Future<void> _openUrl(String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print('Could not launch $url');
    }
  }
  Future<void> _openPdfViewer(String pdfUrl, String title) async {
    setState(() => _isActionInProgress = true);
    ScaffoldMessengerState? scaffoldMessenger;
    if (mounted) scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode == 200) {
        final pdfBytes = response.bodyBytes;
        if(mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfViewerPage(
                pdfBytes: pdfBytes,
                title: title,
              ),
            ),
          );
        }
      } else {
        throw Exception('Impossible de télécharger le PDF (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error opening PDF viewer: $e');
      scaffoldMessenger?.showSnackBar(
        SnackBar(content: Text('Erreur ouverture PDF: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  // --- FILE TYPE CHECKING ---
  bool _isImage(String url) {
    final uri = Uri.parse(url);
    final extension = path.extension(uri.path).toLowerCase();
    return extension == '.jpg' || extension == '.jpeg' || extension == '.png';
  }
  bool _isVideo(String url) {
    final uri = Uri.parse(url);
    final extension = path.extension(uri.path).toLowerCase();
    return extension == '.mp4' || extension == '.mov' || extension == '.avi';
  }
  bool _isPdf(String url) {
    final uri = Uri.parse(url);
    final extension = path.extension(uri.path).toLowerCase();
    return extension == '.pdf';
  }

  // --- WIDGET BUILDERS ---
  Widget _buildMediaThumbnail(BuildContext context, String mediaUrl, List<String> allMediaUrls, {String? fileName}) {
    Widget buildIconPlaceholder(IconData iconData, Color iconColor, String label) {
      return Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 8.0, top: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade100,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconData, color: iconColor, size: 36),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                label,
                style: TextStyle(color: iconColor, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    Widget content;
    String fileLabel = fileName ?? 'Fichier';

    if (_isImage(mediaUrl)) {
      content = Image.network(
        mediaUrl,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return buildIconPlaceholder(Icons.image_outlined, primaryColor, 'Image');
        },
        errorBuilder: (context, error, stackTrace) {
          return buildIconPlaceholder(Icons.broken_image_outlined, Colors.red, 'Erreur');
        },
      );
      fileLabel = 'Image';
    } else if (_isVideo(mediaUrl)) {
      content = FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(
          video: mediaUrl,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 80,
          quality: 25,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return buildIconPlaceholder(Icons.videocam_outlined, Colors.blue, 'Vidéo');
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Image.memory(snapshot.data!, width: 80, height: 80, fit: BoxFit.cover),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                ),
              ],
            );
          }
          return buildIconPlaceholder(Icons.videocam_off_outlined, Colors.red, 'Erreur Vidéo');
        },
      );
      fileLabel = 'Vidéo';
    } else if (_isPdf(mediaUrl)) {
      content = buildIconPlaceholder(Icons.picture_as_pdf_outlined, Colors.red, 'PDF');
      fileLabel = 'PDF';
    } else {
      content = buildIconPlaceholder(Icons.attach_file_outlined, Colors.grey, 'Fichier');
    }

    final String pdfTitle = fileName ?? path.basename(Uri.parse(mediaUrl).path);

    return GestureDetector(
        onTap: () {
          if (_isImage(mediaUrl)) {
            final imageURLs = allMediaUrls.where(_isImage).toList();
            final initialIndex = imageURLs.indexOf(mediaUrl);
            if (initialIndex != -1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageGalleryPage(
                    imageUrls: imageURLs,
                    initialIndex: initialIndex,
                  ),
                ),
              );
            }
          } else if (_isVideo(mediaUrl)) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerPage(videoUrl: mediaUrl),
              ),
            );
          } else if (_isPdf(mediaUrl)) {
            _openPdfViewer(mediaUrl, pdfTitle); // Use PDF viewer
          } else {
            _openUrl(mediaUrl); // Fallback
          }
        },
        child: Container(
          margin: const EdgeInsets.only(right: 8.0, top: 8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: content,
          ),
        )
    );
  }
  Widget _buildDetailItem(String label, dynamic value) {
    String displayValue;
    IconData? icon;
    Color? iconColor;

    if (value is bool) {
      displayValue = value ? 'Oui' : 'Non';
      icon = value ? Icons.check_circle_outline : Icons.highlight_off_outlined;
      iconColor = value ? Colors.green : Colors.red;
    } else if (value == null || (value is String && value.isEmpty)) {
      displayValue = 'N/A';
      icon = Icons.help_outline;
      iconColor = Colors.grey;
    } else {
      displayValue = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) Icon(icon, size: 18, color: iconColor ?? Theme.of(context).textTheme.bodySmall?.color),
          if (icon != null) const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(displayValue),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du Projet'),
        backgroundColor: primaryColor,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final projectData = snapshot.data!.data() as Map<String, dynamic>;
          final createdAt = (projectData['createdAt'] as Timestamp).toDate();
          final technicalEvaluation =
          projectData['technical_evaluation'] as List<dynamic>?;
          final status = projectData['status'] ?? 'Inconnu';
          final orderedProducts =
          projectData['orderedProducts'] as List<dynamic>?;
          final projectFiles = projectData['projectFiles'] as List<dynamic>? ?? [];


          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildStatusHeader(status),
              const SizedBox(height: 16),
              _buildInfoCard( /* ... Client Info ... */
                title: 'Informations Client',
                icon: Icons.person_outline,
                children: [
                  ListTile(
                      title: Text(projectData['clientName'] ?? 'N/A'),
                      subtitle: const Text('Nom du Client')),
                  ListTile(
                      title: Text(projectData['clientPhone'] ?? 'N/A'),
                      subtitle: const Text('Téléphone')),
                  ListTile(
                      title: Text(projectData['createdByName'] ?? 'N/A'),
                      subtitle: const Text('Créé par')),
                  ListTile(
                      title: Text(
                          DateFormat('dd MMMM yyyy', 'fr_FR').format(createdAt)),
                      subtitle: const Text('Date de création')),
                ],
              ),
              _buildInfoCard( /* ... Initial Request ... */
                title: 'Demande Initiale',
                icon: Icons.request_page_outlined,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(projectData['initialRequest'] ?? 'N/A'),
                  ),
                ],
              ),
              if (technicalEvaluation != null && technicalEvaluation.isNotEmpty)
                _buildInfoCard( /* ... Technical Evaluation with ExpansionTiles ... */
                  title: 'Évaluation Technique',
                  icon: Icons.square_foot_outlined,
                  children: [
                    for (int i = 0; i < technicalEvaluation.length; i++)
                      ExpansionTile(
                        title: Text(
                          'Entrée #${i + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: primaryColor,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(),
                                const SizedBox(height: 12),
                                _buildDetailItem('Type d\'entrée', technicalEvaluation[i]['entranceType']),
                                _buildDetailItem('Type de porte', technicalEvaluation[i]['doorType']),
                                _buildDetailItem('Largeur', '${technicalEvaluation[i]['entranceWidth'] ?? 'N/A'} m'),
                                const SizedBox(height: 12),
                                const Text("Alimentation Électrique", style: TextStyle(fontWeight: FontWeight.bold)),
                                _buildDetailItem('Prise 220V disponible (< 2m)', technicalEvaluation[i]['isPowerAvailable']),
                                if (technicalEvaluation[i]['powerNotes'] != null && technicalEvaluation[i]['powerNotes'].isNotEmpty)
                                  _buildDetailItem('Notes Alim.', technicalEvaluation[i]['powerNotes']),
                                const SizedBox(height: 12),
                                const Text("Sol et Passage Câbles", style: TextStyle(fontWeight: FontWeight.bold)),
                                _buildDetailItem('Sol finalisé', technicalEvaluation[i]['isFloorFinalized']),
                                _buildDetailItem('Fourreau dispo.', technicalEvaluation[i]['isConduitAvailable']),
                                _buildDetailItem('Saignée autorisée', technicalEvaluation[i]['canMakeTrench']),
                                const SizedBox(height: 12),
                                const Text("Zone d'Installation", style: TextStyle(fontWeight: FontWeight.bold)),
                                _buildDetailItem('Obstacles présents', technicalEvaluation[i]['hasObstacles']),
                                if (technicalEvaluation[i]['obstacleNotes'] != null && technicalEvaluation[i]['obstacleNotes'].isNotEmpty)
                                  _buildDetailItem('Notes Obstacles', technicalEvaluation[i]['obstacleNotes']),
                                const SizedBox(height: 12),
                                const Text("Environnement", style: TextStyle(fontWeight: FontWeight.bold)),
                                _buildDetailItem('Structures métalliques', technicalEvaluation[i]['hasMetalStructures']),
                                _buildDetailItem('Autres systèmes', technicalEvaluation[i]['hasOtherSystems']),
                                if (technicalEvaluation[i]['media'] != null &&
                                    (technicalEvaluation[i]['media'] as List).isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Fichiers d\'Évaluation:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(
                                    height: 100,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        for (var mediaUrl in (technicalEvaluation[i]['media'] as List<dynamic>))
                                          _buildMediaThumbnail(
                                            context,
                                            mediaUrl as String,
                                            (technicalEvaluation[i]['media'] as List<dynamic>).map((e) => e as String).toList(),
                                            // Pass filename if available
                                            // fileName: ...
                                          ),
                                      ],
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              if (orderedProducts != null && orderedProducts.isNotEmpty)
                _buildInfoCard( /* ... Ordered Products ... */
                  title: 'Produits Commandés',
                  icon: Icons.shopping_cart_checkout,
                  children: orderedProducts.map<Widget>((item) {
                    return ListTile(
                      title: Text(item['productName']),
                      trailing: Text('Qté: ${item['quantity']}'),
                    );
                  }).toList(),
                ),

              if (projectData['devisUrl'] != null ||
                  projectData['bonDeCommandeUrl'] != null ||
                  projectData['approvalNotes'] != null ||
                  projectFiles.isNotEmpty)
                _buildInfoCard( /* ... Documents and Files ... */
                  title: 'Documents et Fichiers',
                  icon: Icons.attach_file,
                  children: [
                    // Devis (Now uses B2 URL, PDF viewer)
                    if (projectData['devisUrl'] != null)
                      ListTile(
                        leading: const Icon(Icons.request_quote_outlined, color: Colors.red),
                        title: Text(projectData['devisFileName'] ?? 'Devis.pdf'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _isPdf(projectData['devisUrl'])
                            ? _openPdfViewer(projectData['devisUrl'], projectData['devisFileName'] ?? 'Devis')
                            : _openUrl(projectData['devisUrl']),
                      ),
                    // Bon de Commande (Now uses B2 URL, PDF viewer)
                    if (projectData['bonDeCommandeUrl'] != null)
                      ListTile(
                        leading: const Icon(Icons.fact_check_outlined, color: Colors.green),
                        title: Text(projectData['bonDeCommandeFileName'] ?? 'Bon de commande.pdf'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _isPdf(projectData['bonDeCommandeUrl'])
                            ? _openPdfViewer(projectData['bonDeCommandeUrl'], projectData['bonDeCommandeFileName'] ?? 'Bon de Commande')
                            : _openUrl(projectData['bonDeCommandeUrl']),
                      ),
                    // Approval Notes
                    if (projectData['approvalNotes'] != null)
                      ListTile(
                        leading: const Icon(Icons.phone_in_talk_outlined, color: Colors.green),
                        title: const Text('Approbation par Téléphone'),
                        subtitle: Text('Confirmé par: ${projectData['approvalNotes']}'),
                      ),
                    // Project Files (B2 URLs, correct viewers)
                    for (var fileInfo in projectFiles.map((e) => Map<String, dynamic>.from(e)))
                      ListTile(
                        leading: Icon(
                          _isPdf(fileInfo['fileUrl']) ? Icons.picture_as_pdf_outlined
                              : _isImage(fileInfo['fileUrl']) ? Icons.image_outlined
                              : Icons.attach_file,
                          color: _isPdf(fileInfo['fileUrl']) ? Colors.red
                              : _isImage(fileInfo['fileUrl']) ? primaryColor
                              : Colors.grey,
                        ),
                        title: Text(fileInfo['fileName'] ?? 'Fichier'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          final url = fileInfo['fileUrl'];
                          final name = fileInfo['fileName'] ?? 'Fichier';
                          if (_isPdf(url)) {
                            _openPdfViewer(url, name); // Use PDF viewer
                          } else if (_isImage(url)) {
                            Navigator.push(context, MaterialPageRoute(builder: (context)=> ImageGalleryPage(imageUrls: [url], initialIndex: 0)));
                          } else {
                            _openUrl(url); // Fallback
                          }
                        },
                      ),
                  ],
                ),

              _buildInfoCard( /* ... Actions ... */
                title: 'Actions',
                icon: Icons.task_alt,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildActionButtons(
                        status, widget.userRole, projectData),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader(String status) {
    // ... (keep existing _buildStatusHeader code) ...
    IconData icon;
    Color color;
    switch (status) {
      case 'Nouvelle Demande':
        icon = Icons.new_releases_outlined;
        color = Colors.blue;
        break;
      case 'Évaluation Technique Terminé':
        icon = Icons.rule_outlined;
        color = Colors.orange;
        break;
      case 'Devis Envoyé':
        icon = Icons.send_outlined;
        color = Colors.purple;
        break;
      case 'Finalisation de la Commande':
        icon = Icons.playlist_add_check_outlined;
        color = Colors.teal;
        break;
      case 'À Planifier':
        icon = Icons.event_available_outlined;
        color = Colors.blue;
        break;
      case 'Transféré à l\'Installation':
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Statut Actuel', style: TextStyle(fontSize: 12)),
                Text(status,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      {required String title,
        required IconData icon,
        required List<Widget> children}) {
    // ... (keep existing _buildInfoCard code) ...
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: primaryColor),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }


  Widget _buildActionButtons(
      String status, String userRole, Map<String, dynamic> projectData) {
    // ... (keep existing _buildActionButtons code) ...
    if (_isActionInProgress) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Widget> buttons = [];

    if (status == 'Nouvelle Demande' &&
        RolePermissions.canPerformTechnicalEvaluation(userRole)) {
      buttons.add(SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      TechnicalEvaluationPage(projectId: widget.projectId))),
              icon: const Icon(Icons.rule),
              label: const Text('Ajouter l\'Évaluation Technique'))));
    }
    if (status == 'Nouvelle Demande' &&
        RolePermissions.canPerformItEvaluation(userRole)) {
      buttons.add(SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ItEvaluationPage(
                    projectId: widget.projectId))),
            icon: const Icon(Icons.network_ping),
            label: const Text('Ajouter l\'Évaluation IT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          )));
      buttons.add(const SizedBox(height: 12));
    }

    if (status == 'Évaluation Technique Terminé' &&
        RolePermissions.canUploadDevis(userRole)) {
      buttons.add(SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _uploadProjectFiles, // Use B2 upload
            icon: const Icon(Icons.attach_file_outlined),
            label: const Text('Ajouter Fichiers Projet'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white),
          )));
      buttons.add(const SizedBox(height: 12));

      // ✅ Button now calls the B2 version of _uploadDevis
      buttons.add(SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
              onPressed: _uploadDevis, // Calls the modified B2 version
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Devis')
          )));
    }

    if (status == 'Devis Envoyé' && RolePermissions.canUploadDevis(userRole)) {
      buttons.add(SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
              onPressed: _showApprovalDialog, // _uploadBonDeCommande inside now uses B2
              icon: const Icon(Icons.check),
              label: const Text('Confirmer l\'Approbation Client'))));
    }
    if (status == 'Finalisation de la Commande' &&
        RolePermissions.canUploadDevis(userRole)) {
      buttons.add(SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
              onPressed: () => _showProductFinalizationDialog(
                  projectData['orderedProducts'] ?? []),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Définir les Produits Commandés'))));
    }
    if (status == 'À Planifier' &&
        RolePermissions.canScheduleInstallation(userRole)) {
      buttons.add(SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _createInstallationTask(projectData),
            icon: const Icon(Icons.send_to_mobile),
            label: const Text('Créer la Tâche d\'Installation'),
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor, foregroundColor: Colors.white),
          )));
    }

    if (buttons.isEmpty) {
      return const Center(
          child: Text('Aucune action disponible pour ce statut.'));
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: buttons);
  }
}

// --- Order Finalization Dialog (Unchanged) ---
class _OrderFinalizationDialog extends StatefulWidget {
  final String projectId;
  final List<dynamic> existingItems;
  const _OrderFinalizationDialog(
      {required this.projectId, required this.existingItems});
  @override
  State<_OrderFinalizationDialog> createState() =>
      _OrderFinalizationDialogState();
}

class _OrderFinalizationDialogState extends State<_OrderFinalizationDialog> {
  late List<ProductSelection> _selectedProducts;
  bool _isSaving = false;
  @override
  void initState() {
    super.initState();
    _selectedProducts = widget.existingItems.map((item) {
      final productData = item as Map<String, dynamic>;
      return ProductSelection(
        productId: productData['productId'],
        productName: productData['productName'],
        marque: productData['marque'] ?? '',
        partNumber: productData['partNumber'] ?? 'N/A',
        quantity: productData['quantity'],
      );
    }).toList();
  }

  Future<void> _finalizeOrder() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        Map<String, DocumentSnapshot> productSnaps = {};
        for (var product in _selectedProducts) {
          final productRef = FirebaseFirestore.instance
              .collection('produits')
              .doc(product.productId);
          productSnaps[product.productId] = await transaction.get(productRef);
        }
        for (var product in _selectedProducts) {
          final snap = productSnaps[product.productId]!;
          final currentStock =
              (snap.data() as Map<String, dynamic>?)?['quantiteEnStock'] ?? 0;
          if (currentStock < product.quantity) {
            throw Exception('Stock insuffisant pour ${product.productName}');
          }
          transaction.update(snap.reference,
              {'quantiteEnStock': currentStock - product.quantity});
        }
        final projectRef = FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId);
        transaction.update(projectRef, {
          'orderedProducts': _selectedProducts
              .map((p) => {
            'productId': p.productId,
            'productName': p.productName,
            'quantity': p.quantity
          })
              .toList(),
          'status': 'À Planifier',
        });
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showProductSelector() async {
    final result = await showDialog<List<ProductSelection>>(
      context: context,
      builder: (ctx) => ProductSelectorDialog(
        initialProducts: _selectedProducts,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedProducts = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Finaliser la Commande'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: _selectedProducts.isEmpty
                  ? const Center(child: Text('Aucun produit ajouté.'))
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: _selectedProducts.length,
                itemBuilder: (context, index) {
                  final product = _selectedProducts[index];
                  return ListTile(
                    title: Text(product.productName),
                    trailing: Text('Qté: ${product.quantity}'),
                    onLongPress: () =>
                        setState(() => _selectedProducts.removeAt(index)),
                  );
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: _showProductSelector,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter/Modifier Produits'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler')),
        ElevatedButton(
            onPressed: _isSaving ? null : _finalizeOrder,
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Enregistrer')),
      ],
    );
  }
}
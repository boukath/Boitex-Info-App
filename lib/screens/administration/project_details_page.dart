// lib/screens/administration/project_details_page.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ REQUIRED FOR WEB FIX
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/technical_evaluation_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
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
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';

// Import the Dispatcher Dialog
import 'package:boitex_info_app/screens/administration/widgets/installation_dispatcher_dialog.dart';

// ✅ NEW IMPORT: Your Fixed Service
import 'package:boitex_info_app/services/project_dossier_service.dart';

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
  static const Color itPrimaryColor = Colors.blue;
  static const Color countingColor = Colors.teal;

  // B2 Cloud Function URL constant
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

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

  Future<String?> _uploadFileToB2({
    required File file,
    required Map<String, dynamic> b2Creds,
    required String b2FileName,
  }) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final String originalFileName = path.basename(file.path);

      String? mimeType;
      final String extension = path.extension(originalFileName).toLowerCase();
      if (extension == '.jpg' || extension == '.jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == '.png') {
        mimeType = 'image/png';
      } else if (extension == '.pdf') {
        mimeType = 'application/pdf';
      }

      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(b2FileName),
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
        debugPrint(
            'Failed to upload file ($originalFileName) to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint(
          'Error uploading file (${path.basename(file.path)}) to B2: $e');
      return null;
    }
  }
  // ✅ --- END: B2 HELPER FUNCTIONS ---

  // ✅ AUTOMATIC STATUS UPDATE LOGIC
  Future<void> _checkAndUpdateGlobalStatus() async {
    setState(() => _isActionInProgress = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();

      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;

      final bool hasTechnique = data['hasTechniqueModule'] ??
          (data['serviceType'] == 'Service Technique');
      final bool hasIt =
          data['hasItModule'] ?? (data['serviceType'] == 'Service IT');

      final techList = data['technical_evaluation'] as List<dynamic>? ?? [];
      final bool isTechniqueDone = techList.isNotEmpty;

      final itMap = data['it_evaluation'] as Map<String, dynamic>? ?? {};
      final bool isItDone = itMap.isNotEmpty;

      bool allRequiredDone = true;
      bool anyDone = false;

      if (hasTechnique) {
        if (!isTechniqueDone) allRequiredDone = false;
        if (isTechniqueDone) anyDone = true;
      }
      if (hasIt) {
        if (!isItDone) allRequiredDone = false;
        if (isItDone) anyDone = true;
      }

      String currentStatus = data['status'] ?? 'Nouvelle Demande';
      String newStatus = currentStatus;

      if (['Nouvelle Demande', 'En Cours d\'Évaluation', 'Évaluation Terminée', 'Évaluation Technique Terminé', 'Évaluation IT Terminé']
          .contains(currentStatus)) {
        if (allRequiredDone) {
          newStatus = 'Évaluation Terminée';
        } else if (anyDone) {
          newStatus = 'En Cours d\'Évaluation';
        }
      }

      if (newStatus != currentStatus) {
        await doc.reference.update({'status': newStatus});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Statut mis à jour : $newStatus'),
            backgroundColor: Colors.green,
          ));
        }
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  // ✅ NEW: PREMIUM PDF GENERATION (WEB COMPATIBLE)
  // Replaces the old crashing _downloadProDossier
  Future<void> _generateAndOpenDossier(Map<String, dynamic> projectData) async {
    setState(() => _isActionInProgress = true);
    try {
      final String fileName = 'Dossier_Projet_${widget.projectId}.pdf';

      // 🚀 Calls your fixed service which handles Web/Mobile logic internally
      await ProjectDossierService.generateAndOpen(projectData, fileName);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

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
                  _uploadBonDeCommande();
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
                onPressed: () =>
                    Navigator.of(ctx).pop(noteController.text)),
          ],
        ));

    if (note != null && note.isNotEmpty) {
      setState(() {
        _isActionInProgress = true;
      });
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
          setState(() {
            _isActionInProgress = false;
          });
        }
      }
    }
  }

  Future<void> _uploadBonDeCommande() async {
    setState(() {
      _isActionInProgress = true;
    });

    final b2Credentials = await _getB2UploadCredentials();
    if (b2Credentials == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Erreur: Impossible de contacter le service d\'upload.'),
              backgroundColor: Colors.red),
        );
        setState(() {
          _isActionInProgress = false;
        });
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
        setState(() {
          _isActionInProgress = false;
        });
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

      if (downloadUrl != null) {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .update({
          'bonDeCommandeUrl': downloadUrl,
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
        setState(() {
          _isActionInProgress = false;
        });
      }
    }
  }

  void _showProductFinalizationDialog(List<dynamic> existingItems) {
    showDialog(
      context: context,
      builder: (context) => _OrderFinalizationDialog(
        projectId: widget.projectId,
        existingItems: existingItems,
      ),
    );
  }

  Future<void> _handleInstallationCreation(Map<String, dynamic> projectData) async {
    final bool hasTech = projectData['hasTechniqueModule'] ?? (projectData['serviceType'] == 'Service Technique');
    final bool hasIt = projectData['hasItModule'] ?? (projectData['serviceType'] == 'Service IT');

    if (!(hasTech && hasIt)) {
      await _createInstallationTask(projectData);
      return;
    }

    final orderedProducts = projectData['orderedProducts'] as List<dynamic>? ?? [];

    if (orderedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun produit à dispatcher.')),
      );
      return;
    }

    final result = await showDialog<Map<String, List<dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => InstallationDispatcherDialog(orderedProducts: orderedProducts),
    );

    if (result != null) {
      final techProducts = result['technique']!;
      final itProducts = result['it']!;

      await _createDualInstallationTasks(
        projectData: projectData,
        techProducts: techProducts,
        itProducts: itProducts,
      );
    }
  }

  Future<void> _createDualInstallationTasks({
    required Map<String, dynamic> projectData,
    required List<dynamic> techProducts,
    required List<dynamic> itProducts,
  }) async {
    setState(() => _isActionInProgress = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final techRef = FirebaseFirestore.instance.collection('installations').doc();
      final itRef = FirebaseFirestore.instance.collection('installations').doc();
      final projectRef = FirebaseFirestore.instance.collection('projects').doc(widget.projectId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final currentYear = DateTime.now().year;
        final counterRef = FirebaseFirestore.instance.collection('counters').doc('installation_counter_$currentYear');

        final counterDoc = await transaction.get(counterRef);
        final currentCount = (counterDoc.data()?['count'] as int? ?? 0);

        final techCode = 'INST-${currentCount + 1}/$currentYear (T)';
        final itCode = 'INST-${currentCount + 2}/$currentYear (IT)';

        if (techProducts.isNotEmpty) {
          transaction.set(techRef, {
            'installationCode': techCode,
            'projectId': widget.projectId,
            'clientId': projectData['clientId'],
            'clientName': projectData['clientName'],
            'clientPhone': projectData['clientPhone'] ?? '',
            'storeId': projectData['storeId'],
            'storeName': projectData['storeName'],
            'initialRequest': projectData['initialRequest'] ?? 'N/A',
            'technicalEvaluation': projectData['technical_evaluation'] ?? [],
            'itEvaluation': {},
            'orderedProducts': techProducts,
            'serviceType': 'Service Technique',
            'status': 'À Planifier',
            'createdAt': Timestamp.now(),
            'createdByUid': FirebaseAuth.instance.currentUser?.uid,
            'createdByName': FirebaseAuth.instance.currentUser?.displayName ?? 'Inconnu',
          });
        }

        if (itProducts.isNotEmpty) {
          transaction.set(itRef, {
            'installationCode': itCode,
            'projectId': widget.projectId,
            'clientId': projectData['clientId'],
            'clientName': projectData['clientName'],
            'clientPhone': projectData['clientPhone'] ?? '',
            'storeId': projectData['storeId'],
            'storeName': projectData['storeName'],
            'initialRequest': projectData['initialRequest'] ?? 'N/A',
            'technicalEvaluation': [],
            'itEvaluation': projectData['it_evaluation'] ?? {},
            'orderedProducts': itProducts,
            'serviceType': 'Service IT',
            'status': 'À Planifier',
            'createdAt': Timestamp.now(),
            'createdByUid': FirebaseAuth.instance.currentUser?.uid,
            'createdByName': FirebaseAuth.instance.currentUser?.displayName ?? 'Inconnu',
          });
        }

        transaction.set(counterRef, {'count': currentCount + 2}, SetOptions(merge: true));

        transaction.update(projectRef, {
          'status': 'Transféré à l\'Installation',
          'installations': {
            'techniqueId': techProducts.isNotEmpty ? techRef.id : null,
            'itId': itProducts.isNotEmpty ? itRef.id : null,
          }
        });
      });

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Deux tâches d\'installation créées avec succès !'), backgroundColor: Colors.green),
        );
        navigator.pop();
      }

    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erreur Dispatch: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _createInstallationTask(Map<String, dynamic> projectData) async {
    setState(() => _isActionInProgress = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final newInstallationRef =
      FirebaseFirestore.instance.collection('installations').doc();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final currentYear = DateTime.now().year;
        final counterRef = FirebaseFirestore.instance
            .collection('counters')
            .doc('installation_counter_$currentYear');

        final counterDoc = await transaction.get(counterRef);
        final newCount = (counterDoc.data()?['count'] as int? ?? 0) + 1;
        final installationCode = 'INST-$newCount/$currentYear';

        transaction.set(newInstallationRef, {
          'installationCode': installationCode,
          'projectId': widget.projectId,
          'clientId': projectData['clientId'] ?? 'ID Client Manquant',
          'clientName': projectData['clientName'] ?? 'Nom Client Manquant',
          'clientPhone': projectData['clientPhone'] ?? '',
          'storeId': projectData['storeId'],
          'storeName': projectData['storeName'],
          'initialRequest': projectData['initialRequest'] ?? 'N/A',
          'technicalEvaluation': projectData['technical_evaluation'] ?? [],
          'itEvaluation': projectData['it_evaluation'] ?? {},
          'orderedProducts': projectData['orderedProducts'] ?? [],
          'serviceType': projectData['serviceType'] ?? 'Inconnu',
          'status': 'À Planifier',
          'createdAt': Timestamp.now(),
          'createdByUid': FirebaseAuth.instance.currentUser?.uid,
          'createdByName':
          FirebaseAuth.instance.currentUser?.displayName ?? 'Inconnu',
        });

        transaction.set(
            counterRef, {'count': newCount}, SetOptions(merge: true));

        final projectRef = FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId);
        transaction
            .update(projectRef, {'status': 'Transféré à l\'Installation'});
      });

      final newInstallationDoc = await newInstallationRef.get();

      if (!newInstallationDoc.exists) {
        throw Exception(
            "Le document d'installation n'a pas été créé correctement.");
      }

      if (mounted) {
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => InstallationDetailsPage(
                installationDoc: newInstallationDoc,
                userRole: widget.userRole),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text('Erreur création tâche: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _uploadProjectFiles() async {
    setState(() {
      _isActionInProgress = true;
    });

    final b2Credentials = await _getB2UploadCredentials();
    if (b2Credentials == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Erreur: Impossible de contacter le service d\'upload.'),
              backgroundColor: Colors.red),
        );
        setState(() {
          _isActionInProgress = false;
        });
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
        setState(() {
          _isActionInProgress = false;
        });
        return;
      }

      List<Map<String, String>> uploadedFilesData = [];
      int successCount = 0;

      for (var fileData in result.files) {
        if (fileData.path != null) {
          final file = File(fileData.path!);
          final originalFileName = fileData.name;
          final String uniqueFileName =
              '${DateTime.now().millisecondsSinceEpoch}_$originalFileName';
          final String b2ProjectFilePath =
              'project_files/${widget.projectId}/$uniqueFileName';

          final downloadUrl = await _uploadFileToB2(
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
            SnackBar(
                content: Text(
                    '$successCount / ${result.files.length} fichier(s) ajouté(s).')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur lors de l\'upload: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
      }
    }
  }

  Future<void> _openUrl(String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print('Could not launch $url');
    }
  }

  Future<void> _openPdfViewer(String pdfUrl, String title) async {
    // ✅ WEB FIX: Detect Web platform and open in new tab instead of crashing
    if (kIsWeb) {
      await _openUrl(pdfUrl); // Uses your existing launchUrl logic
      return;
    }

    setState(() => _isActionInProgress = true);
    ScaffoldMessengerState? scaffoldMessenger;
    if (mounted) scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode == 200) {
        final pdfBytes = response.bodyBytes;
        if (mounted) {
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
        throw Exception(
            'Impossible de télécharger le PDF (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error opening PDF viewer: $e');
      scaffoldMessenger?.showSnackBar(
        SnackBar(
            content: Text('Erreur ouverture PDF: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

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

  Widget _buildMediaThumbnail(
      BuildContext context, String mediaUrl, List<String> allMediaUrls,
      {String? fileName}) {
    Widget buildIconPlaceholder(
        IconData iconData, Color iconColor, String label) {
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

    if (_isImage(mediaUrl)) {
      content = Image.network(
        mediaUrl,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => buildIconPlaceholder(
            Icons.broken_image_outlined, Colors.red, 'Erreur'),
      );
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
            return buildIconPlaceholder(
                Icons.videocam_outlined, Colors.blue, 'Vidéo');
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Image.memory(snapshot.data!,
                    width: 80, height: 80, fit: BoxFit.cover),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 20),
                ),
              ],
            );
          }
          return buildIconPlaceholder(
              Icons.videocam_off_outlined, Colors.red, 'Erreur');
        },
      );
    } else if (_isPdf(mediaUrl)) {
      content = buildIconPlaceholder(
          Icons.picture_as_pdf_outlined, Colors.red, 'PDF');
    } else {
      content = buildIconPlaceholder(
          Icons.attach_file_outlined, Colors.grey, 'Fichier');
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
            _openPdfViewer(mediaUrl, pdfTitle);
          } else {
            _openUrl(mediaUrl);
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
        ));
  }

  // ✅ MODIFIED: Now accepts an optional photoUrl to display next to the value
  Widget _buildDetailItem(String label, dynamic value, {String? photoUrl}) {
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
          if (icon != null)
            Icon(icon,
                size: 18,
                color:
                iconColor ?? Theme.of(context).textTheme.bodySmall?.color),
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

          // ✅ ADDED: Photo Thumbnail if URL exists
          if (photoUrl != null && photoUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageGalleryPage(
                        imageUrls: [photoUrl],
                        initialIndex: 0,
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      photoUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 20),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItPhotosSection({required Map<String, dynamic> itData}) {
    final List<dynamic> photos = itData['photos'] as List<dynamic>? ?? [];
    if (photos.isEmpty) return const SizedBox.shrink();

    final List<String> photoUrls = photos.map((e) => e as String).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Photos d\'Évaluation IT',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: itPrimaryColor),
        ),
        const Divider(),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: photoUrls.length,
            itemBuilder: (context, index) {
              return _buildMediaThumbnail(
                context,
                photoUrls[index],
                photoUrls,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClientHardwareSection({
    required String title,
    required IconData icon,
    required Map<String, dynamic> itData,
  }) {
    final List<dynamic> devices =
        itData['clientDeviceList'] as List<dynamic>? ?? [];
    if (devices.isEmpty) return const SizedBox.shrink();

    return ExpansionTile(
      leading: Icon(icon, color: itPrimaryColor),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: itPrimaryColor)),
      children: [
        for (var device in devices)
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    // ✅ UPDATED: Include photo URL
                    _buildDetailItem('Type', device['deviceType'],
                        photoUrl: device['photoUrl']),
                    _buildDetailItem('Marque', device['brand']),
                    _buildDetailItem('Modèle', 'model'),
                    _buildDetailItem('OS', device['osType']),
                    _buildDetailItem('Notes', device['notes']),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildItListSection({
    required String title,
    required IconData icon,
    required Map<String, dynamic> itData,
  }) {
    Widget buildSubList(String listKey, String listTitle) {
      final List<dynamic> items = itData[listKey] as List<dynamic>? ?? [];
      if (items.isEmpty) return const SizedBox.shrink();

      return ExpansionTile(
        title: Text(listTitle,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        children: [
          for (var item in items)
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'] ?? 'Item',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(),
                      // ✅ UPDATED: Include photo URL for the item (attached to first field)
                      _buildDetailItem(
                          'Prise Électrique', item['hasPriseElectrique'],
                          photoUrl: item['photoUrl']),
                      if (item['hasPriseElectrique'] == true)
                        _buildDetailItem(
                            'Qté Électrique', item['quantityPriseElectrique']),
                      _buildDetailItem('Prise RJ45', item['hasPriseRJ45']),
                      if (item['hasPriseRJ45'] == true)
                        _buildDetailItem('Qté RJ45', item['quantityPriseRJ45']),
                      _buildDetailItem('Notes', item['notes']),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return ExpansionTile(
      leading: Icon(icon, color: itPrimaryColor),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: itPrimaryColor)),
      children: [
        buildSubList('tpvList', 'TPV'),
        buildSubList('printerList', 'Imprimantes'),
        buildSubList('kioskList', 'Bornes'),
        buildSubList('screenList', 'Écrans Pub'),
      ],
    );
  }

  Widget _buildInfoCard(
      {required String title,
        required IconData icon,
        required List<Widget> children}) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du Projet'),
        backgroundColor: primaryColor,
        // ✅ NEW: ADDED BUTTON TO GENERATE PDF
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.print_outlined),
                tooltip: "Générer le Dossier PDF",
                onPressed: () => _generateAndOpenDossier(snapshot.data!.data() as Map<String, dynamic>),
              );
            },
          )
        ],
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

          final technicalEvaluation = projectData['technical_evaluation'] as List<dynamic>?;
          // Counting Global Data
          final countingGlobal = projectData['counting_evaluation_global'] as Map<String, dynamic>?;
          final bool hasCountingStudy = projectData['has_counting_study'] == true;
          final bool isMallMode = projectData['is_mall_mode'] == true;
          final bool hasAntivolEval = projectData['has_antivol_evaluation'] == true;

          final itEvaluation = projectData['it_evaluation'] as Map<String, dynamic>?;
          final status = projectData['status'] ?? 'Inconnu';
          final orderedProducts = projectData['orderedProducts'] as List<dynamic>?;
          final projectFiles = projectData['projectFiles'] as List<dynamic>? ?? [];

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildStatusHeader(status),
              const SizedBox(height: 16),
              _buildInfoCard(
                title: 'Informations Client',
                icon: Icons.person_outline,
                children: [
                  ListTile(
                      title: Text(projectData['clientName'] ?? 'N/A'),
                      subtitle: const Text('Nom du Client')),
                  ListTile(
                    title: Text(
                        '${projectData['storeName'] ?? 'N/A'} - ${projectData['storeLocation'] ?? 'N/A'}'),
                    subtitle: const Text('Magasin'),
                  ),
                  ListTile(
                      title: Text(projectData['clientPhone'] ?? 'N/A'),
                      subtitle: const Text('Téléphone')),
                  ListTile(
                      title: Text(projectData['createdByName'] ?? 'N/A'),
                      subtitle: const Text('Créé par')),
                  ListTile(
                      title: Text(DateFormat('dd MMMM yyyy', 'fr_FR')
                          .format(createdAt)),
                      subtitle: const Text('Date de création')),
                ],
              ),
              _buildInfoCard(
                title: 'Demande Initiale',
                icon: Icons.request_page_outlined,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(projectData['initialRequest'] ?? 'N/A'),
                  ),
                ],
              ),

              // ✅ NEW: COUNTING EVALUATION CARD
              if (hasCountingStudy && technicalEvaluation != null)
                _buildInfoCard(
                  title: 'Étude Comptage & Flux',
                  icon: Icons.people_outline,
                  children: [
                    // Global Infra Section
                    if (countingGlobal != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Infrastructure Globale", style: TextStyle(fontWeight: FontWeight.bold, color: countingColor)),
                            const Divider(),
                            _buildDetailItem('Serveur / Hôte', countingGlobal['hostingDevice'], photoUrl: countingGlobal['hostingUrl']),
                            _buildDetailItem('Switch PoE', countingGlobal['hasPoeSwitch'], photoUrl: countingGlobal['poe_switchUrl']),
                            _buildDetailItem('Espace Baie', countingGlobal['hasRackSpace'], photoUrl: countingGlobal['rack_spaceUrl']),
                          ],
                        ),
                      ),
                      const Divider(thickness: 4, color: Colors.grey),
                    ],

                    // Camera Points List
                    for (int i = 0; i < technicalEvaluation.length; i++)
                      if (technicalEvaluation[i]['needsCountCamera'] == true)
                        ExpansionTile(
                          leading: const Icon(Icons.camera_alt, color: countingColor),
                          title: Text(
                            isMallMode
                                ? '${technicalEvaluation[i]['locationName'] ?? 'Point Inconnu'} (${technicalEvaluation[i]['zoneName'] ?? 'Zone N/A'})'
                                : 'Caméra - Entrée #${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: isMallMode ? Text(technicalEvaluation[i]['flowType'] ?? 'Flux Standard') : null,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Column(
                                children: [
                                  _buildDetailItem('Hauteur (m)', technicalEvaluation[i]['cameraHeight'], photoUrl: technicalEvaluation[i]['cameraHeightPhotoUrl']),
                                  _buildDetailItem('Type Plafond', technicalEvaluation[i]['ceilingType'], photoUrl: technicalEvaluation[i]['ceilingTypePhotoUrl']),
                                  _buildDetailItem('Support Requis', technicalEvaluation[i]['needsPoleSupport'], photoUrl: technicalEvaluation[i]['polePhotoUrl']),
                                  _buildDetailItem('Câble Cat6 Dispo', technicalEvaluation[i]['hasCat6'], photoUrl: technicalEvaluation[i]['cat6PhotoUrl']),
                                  if (technicalEvaluation[i]['hasCat6'] == false)
                                    _buildDetailItem('Distance Tirage (m)', technicalEvaluation[i]['cableDistance'], photoUrl: technicalEvaluation[i]['cableDistancePhotoUrl']),
                                ],
                              ),
                            )
                          ],
                        ),
                  ],
                ),

              // ✅ CONDITIONAL: TECHNICAL EVALUATION (ANTIVOL)
              if (hasAntivolEval && technicalEvaluation != null && technicalEvaluation.isNotEmpty)
                _buildInfoCard(
                  title: 'Évaluation Technique (Antivol)',
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(),
                                const SizedBox(height: 12),
                                _buildDetailItem('Type d\'entrée',
                                    technicalEvaluation[i]['entranceType']),
                                _buildDetailItem('Type de porte',
                                    technicalEvaluation[i]['doorType']),
                                // ✅ Updated: Width now supports a photo
                                _buildDetailItem('Largeur',
                                    '${technicalEvaluation[i]['entranceWidth'] ?? 'N/A'} m',
                                    photoUrl: technicalEvaluation[i]
                                    ['widthPhotoUrl']),
                                const SizedBox(height: 12),
                                const Text("Alimentation Électrique",
                                    style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                                // ✅ Updated: Power now supports a photo
                                _buildDetailItem(
                                    'Prise 220V disponible (< 2m)',
                                    technicalEvaluation[i]['isPowerAvailable'],
                                    photoUrl: technicalEvaluation[i]
                                    ['powerPhotoUrl']),
                                if (technicalEvaluation[i]['powerNotes'] !=
                                    null &&
                                    technicalEvaluation[i]['powerNotes']
                                        .isNotEmpty)
                                  _buildDetailItem('Notes Alim.',
                                      technicalEvaluation[i]['powerNotes']),
                                const SizedBox(height: 12),
                                const Text("Sol et Passage Câbles",
                                    style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                                // ✅ Updated: Floor/Conduit/Trench photos
                                _buildDetailItem(
                                    'Sol finalisé',
                                    technicalEvaluation[i]['isFloorFinalized'],
                                    photoUrl: technicalEvaluation[i]
                                    ['floorPhotoUrl']),
                                _buildDetailItem(
                                    'Fourreau dispo.',
                                    technicalEvaluation[i]
                                    ['isConduitAvailable'],
                                    photoUrl: technicalEvaluation[i]
                                    ['conduitPhotoUrl']),
                                _buildDetailItem(
                                    'Saignée autorisée',
                                    technicalEvaluation[i]['canMakeTrench'],
                                    photoUrl: technicalEvaluation[i]
                                    ['trenchPhotoUrl']),
                                const SizedBox(height: 12),
                                const Text("Zone d'Installation",
                                    style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                                // ✅ Updated: Obstacles photos
                                _buildDetailItem(
                                    'Obstacles présents',
                                    technicalEvaluation[i]['hasObstacles'],
                                    photoUrl: technicalEvaluation[i]
                                    ['obstaclePhotoUrl']),
                                if (technicalEvaluation[i]['obstacleNotes'] !=
                                    null &&
                                    technicalEvaluation[i]['obstacleNotes']
                                        .isNotEmpty)
                                  _buildDetailItem(
                                      'Notes Obstacles',
                                      technicalEvaluation[i]['obstacleNotes']),
                                const SizedBox(height: 12),
                                const Text("Environnement",
                                    style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                                // ✅ Updated: Environmental photos
                                _buildDetailItem(
                                    'Structures métalliques',
                                    technicalEvaluation[i]
                                    ['hasMetalStructures'],
                                    photoUrl: technicalEvaluation[i]
                                    ['metalPhotoUrl']),
                                _buildDetailItem(
                                    'Autres systèmes',
                                    technicalEvaluation[i]['hasOtherSystems'],
                                    photoUrl: technicalEvaluation[i]
                                    ['otherSystemsPhotoUrl']),

                                // Legacy generic media display
                                if (technicalEvaluation[i]['media'] != null &&
                                    (technicalEvaluation[i]['media'] as List)
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Autres Fichiers (Galerie):',
                                    style:
                                    TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(
                                    height: 100,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        for (var mediaUrl
                                        in (technicalEvaluation[i]['media']
                                        as List<dynamic>))
                                          _buildMediaThumbnail(
                                            context,
                                            mediaUrl as String,
                                            (technicalEvaluation[i]['media']
                                            as List<dynamic>)
                                                .map((e) => e as String)
                                                .toList(),
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
              if (itEvaluation != null && itEvaluation.isNotEmpty)
                _buildInfoCard(
                  title: 'Évaluation IT',
                  icon: Icons.network_check_outlined,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Réseau Existant",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: itPrimaryColor)),
                          const Divider(),
                          // ✅ UPDATED: Added networkPhotoUrl
                          _buildDetailItem('Réseau déjà installé',
                              itEvaluation['networkExists'],
                              photoUrl: itEvaluation['networkPhotoUrl']),
                          _buildDetailItem(
                              'Multi-étages', itEvaluation['isMultiFloor']),
                          _buildDetailItem(
                              'Notes Réseau', itEvaluation['networkNotes']),
                          const SizedBox(height: 16),
                          const Text("Environnement",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: itPrimaryColor)),
                          const Divider(),
                          // ✅ UPDATED: Added highVoltagePhotoUrl
                          _buildDetailItem('Haute tension à proximité',
                              itEvaluation['hasHighVoltage'],
                              photoUrl: itEvaluation['highVoltagePhotoUrl']),
                          _buildDetailItem('Notes Haute Tension',
                              itEvaluation['highVoltageNotes']),
                          const SizedBox(height: 16),
                          const Text("Baie de Brassage",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: itPrimaryColor)),
                          const Divider(),
                          // ✅ UPDATED: Added rackPhotoUrl & upsPhotoUrl
                          _buildDetailItem(
                              'Baie présente', itEvaluation['hasNetworkRack'],
                              photoUrl: itEvaluation['rackPhotoUrl']),
                          _buildDetailItem(
                              'Emplacement Baie', itEvaluation['rackLocation']),
                          _buildDetailItem('Espace disponible',
                              itEvaluation['hasRackSpace']),
                          _buildDetailItem('Onduleur (UPS) présent',
                              itEvaluation['hasUPS'],
                              photoUrl: itEvaluation['upsPhotoUrl']),
                          const SizedBox(height: 16),
                          const Text("Accès Internet",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: itPrimaryColor)),
                          const Divider(),
                          _buildDetailItem('Type de Connexion',
                              itEvaluation['internetAccessType']),
                          _buildDetailItem('Fournisseur (FAI)',
                              itEvaluation['internetProvider']),
                          // ✅ UPDATED: Added modemPhotoUrl
                          _buildDetailItem('Emplacement Modem',
                              itEvaluation['modemLocation'],
                              photoUrl: itEvaluation['modemPhotoUrl']),
                          const SizedBox(height: 16),
                          const Text("Câblage",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: itPrimaryColor)),
                          const Divider(),
                          _buildDetailItem('Type de Blindage',
                              itEvaluation['cableShieldType']),
                          _buildDetailItem('Catégorie de Câble',
                              itEvaluation['cableCategoryType']),
                          // ✅ UPDATED: Added cablingPathPhotoUrl
                          _buildDetailItem('Chemins de câbles',
                              itEvaluation['hasCablePaths'],
                              photoUrl: itEvaluation['cablingPathPhotoUrl']),
                          _buildDetailItem(
                              'Distance max.', itEvaluation['cableDistance']),
                          const SizedBox(height: 16),
                          _buildItListSection(
                            title: "Points d'Accès (Planning)",
                            icon: Icons.power_outlined,
                            itData: itEvaluation,
                          ),
                          const SizedBox(height: 8),
                          _buildClientHardwareSection(
                            title: "Inventaire Matériel Client",
                            icon: Icons.devices_outlined,
                            itData: itEvaluation,
                          ),
                          _buildItPhotosSection(itData: itEvaluation),
                        ],
                      ),
                    ),
                  ],
                ),
              if (orderedProducts != null && orderedProducts.isNotEmpty)
                _buildInfoCard(
                  title: 'Produits Commandés',
                  icon: Icons.shopping_cart_checkout,
                  children: orderedProducts.map<Widget>((item) {
                    return ListTile(
                      title: Text(item['productName']),
                      trailing: Text('Qté: ${item['quantity']}'),
                    );
                  }).toList(),
                ),
              if (projectData['bonDeCommandeUrl'] != null ||
                  projectData['approvalNotes'] != null ||
                  projectFiles.isNotEmpty)
                _buildInfoCard(
                  title: 'Documents et Fichiers',
                  icon: Icons.attach_file,
                  children: [
                    if (projectData['bonDeCommandeUrl'] != null)
                      ListTile(
                        leading: const Icon(Icons.fact_check_outlined,
                            color: Colors.green),
                        title: Text(projectData['bonDeCommandeFileName'] ??
                            'Bon de commande.pdf'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _isPdf(projectData['bonDeCommandeUrl'])
                            ? _openPdfViewer(
                            projectData['bonDeCommandeUrl'],
                            projectData['bonDeCommandeFileName'] ??
                                'Bon de Commande')
                            : _openUrl(projectData['bonDeCommandeUrl']),
                      ),
                    if (projectData['approvalNotes'] != null)
                      ListTile(
                        leading: const Icon(Icons.phone_in_talk_outlined,
                            color: Colors.green),
                        title: const Text('Approbation par Téléphone'),
                        subtitle: Text(
                            'Confirmé par: ${projectData['approvalNotes']}'),
                      ),
                    for (var fileInfo
                    in projectFiles.map((e) => Map<String, dynamic>.from(e)))
                      ListTile(
                        leading: Icon(
                          _isPdf(fileInfo['fileUrl'])
                              ? Icons.picture_as_pdf_outlined
                              : _isImage(fileInfo['fileUrl'])
                              ? Icons.image_outlined
                              : Icons.attach_file,
                          color: _isPdf(fileInfo['fileUrl'])
                              ? Colors.red
                              : _isImage(fileInfo['fileUrl'])
                              ? primaryColor
                              : Colors.grey,
                        ),
                        title: Text(fileInfo['fileName'] ?? 'Fichier'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          final url = fileInfo['fileUrl'];
                          final name = fileInfo['fileName'] ?? 'Fichier';
                          if (_isPdf(url)) {
                            _openPdfViewer(url, name);
                          } else if (_isImage(url)) {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ImageGalleryPage(
                                        imageUrls: [url], initialIndex: 0)));
                          } else {
                            _openUrl(url);
                          }
                        },
                      ),
                  ],
                ),
              _buildInfoCard(
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
    IconData icon;
    Color color;
    switch (status) {
      case 'Nouvelle Demande':
        icon = Icons.new_releases_outlined;
        color = Colors.blue;
        break;
    // ✅ ADDED: New intermediate status
      case 'En Cours d\'Évaluation':
        icon = Icons.pending_actions_outlined;
        color = Colors.orangeAccent;
        break;
    // ✅ CHANGED: Unified completion status
      case 'Évaluation Terminée':
      case 'Évaluation Technique Terminé':
      case 'Évaluation IT Terminé':
        icon = Icons.check_circle_outline;
        color = Colors.green;
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

  Widget _buildActionButtons(
      String status, String userRole, Map<String, dynamic> projectData) {
    if (_isActionInProgress) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Widget> buttons = [];

    // ✅ UPDATED: Use boolean flags instead of single ServiceType
    final bool hasTechnique = projectData['hasTechniqueModule'] ??
        (projectData['serviceType'] == 'Service Technique');
    final bool hasIt = projectData['hasItModule'] ??
        (projectData['serviceType'] == 'Service IT');

    // ✅ ADDED: Premium 2026 PDF Export Button (Available once evaluation is done)
    if (status != 'Nouvelle Demande') {
      buttons.add(SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _generateAndOpenDossier(projectData),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Extraire Dossier PDF Pro (2026)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            elevation: 8,
          ),
        ),
      ));
      buttons.add(const SizedBox(height: 12));
    }

    // 1. Technical Evaluation Button
    if (hasTechnique &&
        RolePermissions.canPerformTechnicalEvaluation(userRole)) {
      final techList =
          projectData['technical_evaluation'] as List<dynamic>? ?? [];
      final bool isTechDone = techList.isNotEmpty;

      if (!isTechDone ||
          status == 'Nouvelle Demande' ||
          status == 'En Cours d\'Évaluation') {
        buttons.add(SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => TechnicalEvaluationPage(
                          projectId: widget.projectId)));
                  // ✅ AUTOMATIC CHECK ON RETURN
                  _checkAndUpdateGlobalStatus();
                },
                icon: const Icon(Icons.rule),
                label: Text(isTechDone
                    ? 'Modifier l\'Évaluation Technique'
                    : 'Ajouter l\'Évaluation Technique'))));
        buttons.add(const SizedBox(height: 12));
      }
    }

    // 2. IT Evaluation Button
    if (hasIt && RolePermissions.canPerformItEvaluation(userRole)) {
      final itMap = projectData['it_evaluation'] as Map<String, dynamic>? ?? {};
      final bool isItDone = itMap.isNotEmpty;

      if (!isItDone ||
          status == 'Nouvelle Demande' ||
          status == 'En Cours d\'Évaluation') {
        buttons.add(SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        ItEvaluationPage(projectId: widget.projectId)));
                // ✅ AUTOMATIC CHECK ON RETURN
                _checkAndUpdateGlobalStatus();
              },
              icon: const Icon(Icons.network_ping),
              label: Text(isItDone
                  ? 'Modifier l\'Évaluation IT'
                  : 'Ajouter l\'Évaluation IT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: itPrimaryColor,
                foregroundColor: Colors.white,
              ),
            )));
        buttons.add(const SizedBox(height: 12));
      }
    }

    // 3. Global Actions (Upload Quote / Finalize)
    if ((status == 'Évaluation Terminée' ||
        status == 'Évaluation Technique Terminé' ||
        status == 'Évaluation IT Terminé') &&
        RolePermissions.canUploadDevis(userRole)) {
      buttons.add(SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _uploadProjectFiles,
            icon: const Icon(Icons.attach_file_outlined),
            label: const Text('Ajouter Fichiers Projet'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
          )));
      buttons.add(const SizedBox(height: 12));

      buttons.add(SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
              onPressed: _showApprovalDialog,
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
            onPressed: () => _handleInstallationCreation(projectData),
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

  Future<void> _checkStockAndProceed() async {
    setState(() => _isSaving = true);
    List<String> warnings = [];

    try {
      for (var product in _selectedProducts) {
        final doc = await FirebaseFirestore.instance
            .collection('produits')
            .doc(product.productId)
            .get();

        if (doc.exists) {
          final currentStock =
              (doc.data()?['quantiteEnStock'] as num?)?.toInt() ?? 0;
          if (currentStock < product.quantity) {
            final deficit = currentStock - product.quantity;
            warnings.add(
                '- ${product.productName}: Stock actuel $currentStock ➔ Nouveau stock $deficit');
          }
        }
      }

      if (warnings.isNotEmpty) {
        if (mounted) {
          setState(() => _isSaving = false);
          _showStockWarningDialog(warnings);
        }
      } else {
        await _executeFinalizationTransaction();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Erreur de vérification: $e"),
            backgroundColor: Colors.red));
        setState(() => _isSaving = false);
      }
    }
  }

  void _showStockWarningDialog(List<String> warnings) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Stock Insuffisant',
            style: TextStyle(color: Colors.orange)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Certains produits n\'ont pas assez de stock. Si vous continuez, les stocks passeront en négatif :'),
              const SizedBox(height: 12),
              ...warnings.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(w,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              _executeFinalizationTransaction();
            },
            child: const Text('Forcer la Commande'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeFinalizationTransaction() async {
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
          if (!snap.exists) continue;

          final currentStock =
              (snap.data() as Map<String, dynamic>?)?['quantiteEnStock'] ?? 0;

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
        setState(() => _isSaving = false);
      }
    }
  }

  void _showProductSelector() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GlobalProductSearchPage(
          isSelectionMode: true,
          onProductSelected: (productMap) {
            final productId = productMap['productId'];

            if (productId == null) return;

            final exists =
            _selectedProducts.any((p) => p.productId == productId);

            if (exists) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '${productMap['productName'] ?? 'Ce produit'} est déjà dans la liste.')),
              );
              return;
            }

            final newProduct = ProductSelection(
              productId: productId,
              productName: productMap['productName'] ?? 'Produit Inconnu',
              marque: productMap['marque'] ?? 'N/A',
              partNumber: productMap['partNumber'] ?? 'N/A',
              quantity: productMap['quantity'] ?? 1,
            );

            setState(() {
              _selectedProducts.add(newProduct);
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${newProduct.productName} ajouté.')),
            );
          },
        ),
      ),
    );
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
            onPressed: _isSaving ? null : _checkStockAndProceed,
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Enregistrer')),
      ],
    );
  }
}
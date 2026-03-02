// lib/screens/administration/project_details_page.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ PREMIUM UI ADDITION
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

// Import the Fixed Service
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

  // ✅ PREMIUM COLOR PALETTE
  static const Color bgColor = Color(0xFFF5F7FA);
  static const Color surfaceColor = Colors.white;
  static const Color primaryColor = Color(0xFF4F46E5); // Modern Indigo
  static const Color itPrimaryColor = Color(0xFF0EA5E9); // Modern Sky Blue
  static const Color countingColor = Color(0xFF10B981); // Modern Emerald
  static const Color textDark = Color(0xFF1E293B);
  static const Color textLight = Color(0xFF64748B);

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
            content: Text('Statut mis à jour : $newStatus', style: GoogleFonts.inter()),
            backgroundColor: countingColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _generateAndOpenDossier(Map<String, dynamic> projectData) async {
    setState(() => _isActionInProgress = true);
    try {
      final String fileName = 'Dossier_Projet_${widget.projectId}.pdf';
      await ProjectDossierService.generateAndOpen(projectData, fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur PDF: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  // ✅ NEW: Open the Installation Linker Sheet
  void _showInstallationLinker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InstallationLinkerSheet(projectId: widget.projectId),
    );
  }

  void _showApprovalDialog() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Preuve d\'Approbation', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text('Comment le client a-t-il approuvé le devis ?', style: GoogleFonts.inter()),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _confirmApprovalByPhone();
                },
                child: Text('Par Téléphone', style: GoogleFonts.inter(color: primaryColor, fontWeight: FontWeight.w600))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _uploadBonDeCommande();
                },
                child: Text('Bon de Commande', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
          ],
        ));
  }

  Future<void> _confirmApprovalByPhone() async {
    final noteController = TextEditingController();
    final note = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Confirmation par Téléphone', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: TextField(
              controller: noteController,
              autofocus: true,
              style: GoogleFonts.inter(),
              decoration: InputDecoration(
                labelText: 'Confirmé par (nom)',
                labelStyle: GoogleFonts.inter(color: textLight),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2)),
              )),
          actions: [
            TextButton(
                child: Text('Annuler', style: GoogleFonts.inter(color: textLight)),
                onPressed: () => Navigator.of(ctx).pop()),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Confirmer', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onPressed: () => Navigator.of(ctx).pop(noteController.text)),
          ],
        ));

    if (note != null && note.isNotEmpty) {
      setState(() => _isActionInProgress = true);
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
              .showSnackBar(SnackBar(content: Text('Erreur: $e', style: GoogleFonts.inter())));
        }
      } finally {
        if (mounted) setState(() => _isActionInProgress = false);
      }
    }
  }

  Future<void> _uploadBonDeCommande() async {
    setState(() => _isActionInProgress = true);

    final b2Credentials = await _getB2UploadCredentials();
    if (b2Credentials == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: Impossible de contacter le service d\'upload.', style: GoogleFonts.inter()),
              backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
        setState(() => _isActionInProgress = false);
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
        setState(() => _isActionInProgress = false);
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
            SnackBar(content: Text('Bon de commande ajouté.', style: GoogleFonts.inter()), backgroundColor: countingColor, behavior: SnackBarBehavior.floating),
          );
        }
      } else {
        throw Exception('Échec de l\'upload du bon de commande vers B2.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur: ${e.toString()}', style: GoogleFonts.inter()),
            backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
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
        SnackBar(content: Text('Aucun produit à dispatcher.', style: GoogleFonts.inter()), behavior: SnackBarBehavior.floating),
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
          SnackBar(content: Text('Deux tâches d\'installation créées avec succès !', style: GoogleFonts.inter()), backgroundColor: countingColor, behavior: SnackBarBehavior.floating,),
        );
        navigator.pop();
      }

    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erreur Dispatch: $e', style: GoogleFonts.inter()), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating,));
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
          content: Text('Erreur création tâche: ${e.toString()}', style: GoogleFonts.inter()),
          backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating,));
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _uploadProjectFiles() async {
    setState(() => _isActionInProgress = true);

    final b2Credentials = await _getB2UploadCredentials();
    if (b2Credentials == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: Impossible de contacter le service d\'upload.', style: GoogleFonts.inter()),
              backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
        setState(() => _isActionInProgress = false);
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
        setState(() => _isActionInProgress = false);
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
              content: Text('$successCount / ${result.files.length} fichier(s) ajouté(s).', style: GoogleFonts.inter()), behavior: SnackBarBehavior.floating,),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de l\'upload: ${e.toString()}', style: GoogleFonts.inter()),
          backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating,));
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
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
    if (kIsWeb) {
      await _openUrl(pdfUrl);
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
        throw Exception('Impossible de télécharger le PDF (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error opening PDF viewer: $e');
      scaffoldMessenger?.showSnackBar(
        SnackBar(
            content: Text('Erreur ouverture PDF: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
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
        width: 86,
        height: 86,
        margin: const EdgeInsets.only(right: 12.0, top: 12.0),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            color: surfaceColor,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
            ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconData, color: iconColor, size: 32),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                label,
                style: GoogleFonts.inter(color: iconColor, fontSize: 11, fontWeight: FontWeight.w500),
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
        width: 86,
        height: 86,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => buildIconPlaceholder(
            Icons.broken_image_outlined, Colors.redAccent, 'Erreur'),
      );
    } else if (_isVideo(mediaUrl)) {
      content = FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(
          video: mediaUrl,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 150,
          quality: 50,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return buildIconPlaceholder(Icons.videocam_outlined, itPrimaryColor, 'Vidéo');
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Image.memory(snapshot.data!, width: 86, height: 86, fit: BoxFit.cover),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                ),
              ],
            );
          }
          return buildIconPlaceholder(Icons.videocam_off_outlined, Colors.redAccent, 'Erreur');
        },
      );
    } else if (_isPdf(mediaUrl)) {
      content = buildIconPlaceholder(Icons.picture_as_pdf_rounded, Colors.redAccent, 'PDF');
    } else {
      content = buildIconPlaceholder(Icons.insert_drive_file_rounded, textLight, 'Fichier');
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
          margin: const EdgeInsets.only(right: 12.0, top: 12.0),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
              ]
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: content,
          ),
        ));
  }

  Widget _buildDetailItem(String label, dynamic value, {String? photoUrl}) {
    String displayValue;
    IconData? icon;
    Color? iconColor;

    if (value is bool) {
      displayValue = value ? 'Oui' : 'Non';
      icon = value ? Icons.check_circle_rounded : Icons.cancel_rounded;
      iconColor = value ? countingColor : Colors.redAccent;
    } else if (value == null || (value is String && value.isEmpty)) {
      displayValue = 'N/A';
      icon = Icons.help_outline_rounded;
      iconColor = textLight.withOpacity(0.5);
    } else {
      displayValue = value.toString();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.03))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(color: textLight, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    displayValue,
                    style: GoogleFonts.inter(color: textDark, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (photoUrl != null && photoUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
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
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photoUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey)),
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
        const SizedBox(height: 24),
        Text(
          'Photos d\'Évaluation IT',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: textDark),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: photoUrls.length,
            itemBuilder: (context, index) {
              return _buildMediaThumbnail(context, photoUrls[index], photoUrls);
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

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: itPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: itPrimaryColor, size: 20),
        ),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: textDark)),
        children: [
          for (var device in devices)
            Container(
              margin: const EdgeInsets.only(bottom: 12.0, top: 4.0),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.04)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailItem('Type', device['deviceType'], photoUrl: device['photoUrl']),
                    _buildDetailItem('Marque', device['brand']),
                    _buildDetailItem('Modèle', 'model'), // Missing model key in original logic
                    _buildDetailItem('OS', device['osType']),
                    _buildDetailItem('Notes', device['notes']),
                  ],
                ),
              ),
            ),
        ],
      ),
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

      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(listTitle, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textDark, fontSize: 14)),
          children: [
            for (var item in items)
              Container(
                margin: const EdgeInsets.only(bottom: 12.0, left: 12, right: 12, top: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.04)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'] ?? 'Item', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textDark, fontSize: 15)),
                      const SizedBox(height: 8),
                      _buildDetailItem('Prise Électrique', item['hasPriseElectrique'], photoUrl: item['photoUrl']),
                      if (item['hasPriseElectrique'] == true)
                        _buildDetailItem('Qté Électrique', item['quantityPriseElectrique']),
                      _buildDetailItem('Prise RJ45', item['hasPriseRJ45']),
                      if (item['hasPriseRJ45'] == true)
                        _buildDetailItem('Qté RJ45', item['quantityPriseRJ45']),
                      _buildDetailItem('Notes', item['notes']),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: itPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: itPrimaryColor, size: 20),
        ),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: textDark)),
        children: [
          buildSubList('tpvList', 'TPV'),
          buildSubList('printerList', 'Imprimantes'),
          buildSubList('kioskList', 'Bornes'),
          buildSubList('screenList', 'Écrans Pub'),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      {required String title,
        required IconData icon,
        required List<Widget> children,
        Color headerIconColor = primaryColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.03))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: headerIconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: headerIconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Text(title, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: textDark)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Détails du Projet', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textDark, fontSize: 18)),
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: textDark.withOpacity(0.04),
                ),
                child: IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: textDark),
                  tooltip: "Générer le Dossier PDF",
                  onPressed: () => _generateAndOpenDossier(snapshot.data!.data() as Map<String, dynamic>),
                ),
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
            return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor));
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
            padding: const EdgeInsets.all(20.0),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildStatusHeader(status),
              const SizedBox(height: 24),
              _buildInfoCard(
                title: 'Informations Client',
                icon: Icons.business_center_rounded,
                children: [
                  _buildPremiumListTile('Nom du Client', projectData['clientName'] ?? 'N/A', Icons.person_outline_rounded),
                  _buildPremiumListTile('Magasin', '${projectData['storeName'] ?? 'N/A'} - ${projectData['storeLocation'] ?? 'N/A'}', Icons.storefront_outlined),
                  _buildPremiumListTile('Téléphone', projectData['clientPhone'] ?? 'N/A', Icons.phone_outlined),
                  _buildPremiumListTile('Créé par', projectData['createdByName'] ?? 'N/A', Icons.badge_outlined),
                  _buildPremiumListTile('Date de création', DateFormat('dd MMMM yyyy', 'fr_FR').format(createdAt), Icons.calendar_today_outlined),
                ],
              ),
              _buildInfoCard(
                title: 'Demande Initiale',
                icon: Icons.description_outlined,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withOpacity(0.04)),
                    ),
                    child: Text(projectData['initialRequest'] ?? 'N/A', style: GoogleFonts.inter(height: 1.6, color: textDark, fontSize: 14)),
                  ),
                ],
              ),

              if (hasCountingStudy && technicalEvaluation != null)
                _buildInfoCard(
                  title: 'Étude Comptage & Flux',
                  icon: Icons.people_alt_rounded,
                  headerIconColor: countingColor,
                  children: [
                    if (countingGlobal != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Infrastructure Globale", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: countingColor, fontSize: 15)),
                            const SizedBox(height: 12),
                            _buildDetailItem('Serveur / Hôte', countingGlobal['hostingDevice'], photoUrl: countingGlobal['hostingUrl']),
                            _buildDetailItem('Switch PoE', countingGlobal['hasPoeSwitch'], photoUrl: countingGlobal['poe_switchUrl']),
                            _buildDetailItem('Espace Baie', countingGlobal['hasRackSpace'], photoUrl: countingGlobal['rack_spaceUrl']),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Divider(color: Colors.black.withOpacity(0.05), thickness: 1),
                      ),
                    ],

                    for (int i = 0; i < technicalEvaluation.length; i++)
                      if (technicalEvaluation[i]['needsCountCamera'] == true)
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: countingColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.videocam_rounded, color: countingColor, size: 20)),
                            title: Text(
                              isMallMode
                                  ? '${technicalEvaluation[i]['locationName'] ?? 'Point Inconnu'} (${technicalEvaluation[i]['zoneName'] ?? 'Zone N/A'})'
                                  : 'Caméra - Entrée #${i + 1}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: textDark),
                            ),
                            subtitle: isMallMode ? Text(technicalEvaluation[i]['flowType'] ?? 'Flux Standard', style: GoogleFonts.inter(color: textLight, fontSize: 12)) : null,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12, top: 4),
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.black.withOpacity(0.04)),
                                ),
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
                        ),
                  ],
                ),

              if (hasAntivolEval && technicalEvaluation != null && technicalEvaluation.isNotEmpty)
                _buildInfoCard(
                  title: 'Évaluation Technique (Antivol)',
                  icon: Icons.design_services_rounded,
                  children: [
                    for (int i = 0; i < technicalEvaluation.length; i++)
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: Text(
                            'Entrée #${i + 1}',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: primaryColor),
                          ),
                          children: [
                            Container(
                              margin: const EdgeInsets.only(left: 12, right: 12, bottom: 16),
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.black.withOpacity(0.04)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailItem('Type d\'entrée', technicalEvaluation[i]['entranceType']),
                                  _buildDetailItem('Type de porte', technicalEvaluation[i]['doorType']),
                                  _buildDetailItem('Largeur', '${technicalEvaluation[i]['entranceWidth'] ?? 'N/A'} m', photoUrl: technicalEvaluation[i]['widthPhotoUrl']),

                                  const SizedBox(height: 20),
                                  Text("Alimentation Électrique", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textDark, fontSize: 14)),
                                  const SizedBox(height: 8),
                                  _buildDetailItem('Prise 220V disponible (< 2m)', technicalEvaluation[i]['isPowerAvailable'], photoUrl: technicalEvaluation[i]['powerPhotoUrl']),
                                  if (technicalEvaluation[i]['powerNotes'] != null && technicalEvaluation[i]['powerNotes'].isNotEmpty)
                                    _buildDetailItem('Notes Alim.', technicalEvaluation[i]['powerNotes']),

                                  const SizedBox(height: 20),
                                  Text("Sol et Passage Câbles", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textDark, fontSize: 14)),
                                  const SizedBox(height: 8),
                                  _buildDetailItem('Sol finalisé', technicalEvaluation[i]['isFloorFinalized'], photoUrl: technicalEvaluation[i]['floorPhotoUrl']),
                                  _buildDetailItem('Fourreau dispo.', technicalEvaluation[i]['isConduitAvailable'], photoUrl: technicalEvaluation[i]['conduitPhotoUrl']),
                                  _buildDetailItem('Saignée autorisée', technicalEvaluation[i]['canMakeTrench'], photoUrl: technicalEvaluation[i]['trenchPhotoUrl']),

                                  const SizedBox(height: 20),
                                  Text("Zone d'Installation", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textDark, fontSize: 14)),
                                  const SizedBox(height: 8),
                                  _buildDetailItem('Obstacles présents', technicalEvaluation[i]['hasObstacles'], photoUrl: technicalEvaluation[i]['obstaclePhotoUrl']),
                                  if (technicalEvaluation[i]['obstacleNotes'] != null && technicalEvaluation[i]['obstacleNotes'].isNotEmpty)
                                    _buildDetailItem('Notes Obstacles', technicalEvaluation[i]['obstacleNotes']),

                                  const SizedBox(height: 20),
                                  Text("Environnement", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textDark, fontSize: 14)),
                                  const SizedBox(height: 8),
                                  _buildDetailItem('Structures métalliques', technicalEvaluation[i]['hasMetalStructures'], photoUrl: technicalEvaluation[i]['metalPhotoUrl']),
                                  _buildDetailItem('Autres systèmes', technicalEvaluation[i]['hasOtherSystems'], photoUrl: technicalEvaluation[i]['otherSystemsPhotoUrl']),

                                  if (technicalEvaluation[i]['media'] != null && (technicalEvaluation[i]['media'] as List).isNotEmpty) ...[
                                    const SizedBox(height: 24),
                                    Text('Autres Fichiers (Galerie)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textDark)),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 110,
                                      child: ListView(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        children: [
                                          for (var mediaUrl in (technicalEvaluation[i]['media'] as List<dynamic>))
                                            _buildMediaThumbnail(
                                              context,
                                              mediaUrl as String,
                                              (technicalEvaluation[i]['media'] as List<dynamic>).map((e) => e as String).toList(),
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
                      ),
                  ],
                ),

              if (itEvaluation != null && itEvaluation.isNotEmpty)
                _buildInfoCard(
                  title: 'Évaluation IT',
                  icon: Icons.router_rounded,
                  headerIconColor: itPrimaryColor,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Réseau Existant", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: itPrimaryColor)),
                          const SizedBox(height: 8),
                          _buildDetailItem('Réseau déjà installé', itEvaluation['networkExists'], photoUrl: itEvaluation['networkPhotoUrl']),
                          _buildDetailItem('Multi-étages', itEvaluation['isMultiFloor']),
                          _buildDetailItem('Notes Réseau', itEvaluation['networkNotes']),

                          const SizedBox(height: 24),
                          Text("Environnement", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: itPrimaryColor)),
                          const SizedBox(height: 8),
                          _buildDetailItem('Haute tension à proximité', itEvaluation['hasHighVoltage'], photoUrl: itEvaluation['highVoltagePhotoUrl']),
                          _buildDetailItem('Notes Haute Tension', itEvaluation['highVoltageNotes']),

                          const SizedBox(height: 24),
                          Text("Baie de Brassage", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: itPrimaryColor)),
                          const SizedBox(height: 8),
                          _buildDetailItem('Baie présente', itEvaluation['hasNetworkRack'], photoUrl: itEvaluation['rackPhotoUrl']),
                          _buildDetailItem('Emplacement Baie', itEvaluation['rackLocation']),
                          _buildDetailItem('Espace disponible', itEvaluation['hasRackSpace']),
                          _buildDetailItem('Onduleur (UPS) présent', itEvaluation['hasUPS'], photoUrl: itEvaluation['upsPhotoUrl']),

                          const SizedBox(height: 24),
                          Text("Accès Internet", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: itPrimaryColor)),
                          const SizedBox(height: 8),
                          _buildDetailItem('Type de Connexion', itEvaluation['internetAccessType']),
                          _buildDetailItem('Fournisseur (FAI)', itEvaluation['internetProvider']),
                          _buildDetailItem('Emplacement Modem', itEvaluation['modemLocation'], photoUrl: itEvaluation['modemPhotoUrl']),

                          const SizedBox(height: 24),
                          Text("Câblage", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: itPrimaryColor)),
                          const SizedBox(height: 8),
                          _buildDetailItem('Type de Blindage', itEvaluation['cableShieldType']),
                          _buildDetailItem('Catégorie de Câble', itEvaluation['cableCategoryType']),
                          _buildDetailItem('Chemins de câbles', itEvaluation['hasCablePaths'], photoUrl: itEvaluation['cablingPathPhotoUrl']),
                          _buildDetailItem('Distance max.', itEvaluation['cableDistance']),

                          const SizedBox(height: 16),
                          _buildItListSection(title: "Points d'Accès (Planning)", icon: Icons.power_settings_new_rounded, itData: itEvaluation),
                          const SizedBox(height: 8),
                          _buildClientHardwareSection(title: "Inventaire Matériel Client", icon: Icons.devices_other_rounded, itData: itEvaluation),
                          _buildItPhotosSection(itData: itEvaluation),
                        ],
                      ),
                    ),
                  ],
                ),

              if (orderedProducts != null && orderedProducts.isNotEmpty)
                _buildInfoCard(
                  title: 'Produits Commandés',
                  icon: Icons.inventory_2_rounded,
                  children: orderedProducts.map<Widget>((item) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.qr_code_2_rounded, color: primaryColor, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(item['productName'], style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textDark, fontSize: 15)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                            child: Text('Qté: ${item['quantity']}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: primaryColor)),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ),

              if (projectData['bonDeCommandeUrl'] != null ||
                  projectData['approvalNotes'] != null ||
                  projectFiles.isNotEmpty)
                _buildInfoCard(
                  title: 'Documents et Fichiers',
                  icon: Icons.folder_copy_rounded,
                  children: [
                    if (projectData['bonDeCommandeUrl'] != null)
                      _buildDocumentTile(
                        title: projectData['bonDeCommandeFileName'] ?? 'Bon de commande.pdf',
                        icon: Icons.verified_rounded,
                        color: countingColor,
                        onTap: () => _isPdf(projectData['bonDeCommandeUrl'])
                            ? _openPdfViewer(projectData['bonDeCommandeUrl'], projectData['bonDeCommandeFileName'] ?? 'Bon de Commande')
                            : _openUrl(projectData['bonDeCommandeUrl']),
                      ),
                    if (projectData['approvalNotes'] != null)
                      _buildDocumentTile(
                        title: 'Approbation par Téléphone',
                        subtitle: 'Confirmé par: ${projectData['approvalNotes']}',
                        icon: Icons.phone_in_talk_rounded,
                        color: countingColor,
                        onTap: () {},
                      ),
                    for (var fileInfo in projectFiles.map((e) => Map<String, dynamic>.from(e)))
                      _buildDocumentTile(
                        title: fileInfo['fileName'] ?? 'Fichier',
                        icon: _isPdf(fileInfo['fileUrl']) ? Icons.picture_as_pdf_rounded : _isImage(fileInfo['fileUrl']) ? Icons.image_rounded : Icons.insert_drive_file_rounded,
                        color: _isPdf(fileInfo['fileUrl']) ? Colors.redAccent : _isImage(fileInfo['fileUrl']) ? primaryColor : textLight,
                        onTap: () {
                          final url = fileInfo['fileUrl'];
                          final name = fileInfo['fileName'] ?? 'Fichier';
                          if (_isPdf(url)) {
                            _openPdfViewer(url, name);
                          } else if (_isImage(url)) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => ImageGalleryPage(imageUrls: [url], initialIndex: 0)));
                          } else {
                            _openUrl(url);
                          }
                        },
                      ),
                  ],
                ),

              const SizedBox(height: 8),
              Text("ACTIONS DISPONIBLES", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: textLight, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              _buildActionButtons(status, widget.userRole, projectData),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPremiumListTile(String subtitle, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: textLight, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle, style: GoogleFonts.inter(color: textLight, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(title, style: GoogleFonts.inter(color: textDark, fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDocumentTile({required String title, String? subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.03)))),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: textDark)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: GoogleFonts.inter(color: textLight, fontSize: 13)),
                  ]
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(String status) {
    IconData icon;
    Color colorStart;
    Color colorEnd;

    switch (status) {
      case 'Nouvelle Demande':
        icon = Icons.new_releases_rounded;
        colorStart = const Color(0xFF3B82F6);
        colorEnd = const Color(0xFF2563EB);
        break;
      case 'En Cours d\'Évaluation':
        icon = Icons.pending_actions_rounded;
        colorStart = const Color(0xFFF59E0B);
        colorEnd = const Color(0xFFD97706);
        break;
      case 'Évaluation Terminée':
      case 'Évaluation Technique Terminé':
      case 'Évaluation IT Terminé':
        icon = Icons.check_circle_rounded;
        colorStart = const Color(0xFF10B981);
        colorEnd = const Color(0xFF059669);
        break;
      case 'Finalisation de la Commande':
        icon = Icons.playlist_add_check_rounded;
        colorStart = const Color(0xFF14B8A6);
        colorEnd = const Color(0xFF0D9488);
        break;
      case 'À Planifier':
        icon = Icons.event_available_rounded;
        colorStart = const Color(0xFF6366F1);
        colorEnd = const Color(0xFF4F46E5);
        break;
      case 'Transféré à l\'Installation':
        icon = Icons.rocket_launch_rounded;
        colorStart = const Color(0xFF8B5CF6);
        colorEnd = const Color(0xFF7C3AED);
        break;
      default:
        icon = Icons.help_outline_rounded;
        colorStart = const Color(0xFF94A3B8);
        colorEnd = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [colorStart, colorEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: [
            BoxShadow(color: colorEnd.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))
          ]
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STATUT DU PROJET', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(status, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
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
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor));
    }

    List<Widget> buttons = [];

    final bool hasTechnique = projectData['hasTechniqueModule'] ?? (projectData['serviceType'] == 'Service Technique');
    final bool hasIt = projectData['hasItModule'] ?? (projectData['serviceType'] == 'Service IT');

    Widget buildCTA({required String label, required IconData icon, required VoidCallback onPressed, Color color = primaryColor, bool isSecondary = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 22, color: isSecondary ? color : Colors.white),
            label: Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: isSecondary ? color : Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isSecondary ? color.withOpacity(0.1) : color,
              elevation: isSecondary ? 0 : 8,
              shadowColor: color.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isSecondary ? BorderSide(color: color.withOpacity(0.2)) : BorderSide.none,
              ),
            ),
          ),
        ),
      );
    }

    if (status != 'Nouvelle Demande') {
      buttons.add(buildCTA(
        label: 'Extraire Dossier PDF',
        icon: Icons.picture_as_pdf_rounded,
        onPressed: () => _generateAndOpenDossier(projectData),
        color: textDark,
      ));
    }

    if (hasTechnique && RolePermissions.canPerformTechnicalEvaluation(userRole)) {
      final techList = projectData['technical_evaluation'] as List<dynamic>? ?? [];
      final bool isTechDone = techList.isNotEmpty;

      if (!isTechDone || status == 'Nouvelle Demande' || status == 'En Cours d\'Évaluation') {
        buttons.add(buildCTA(
          label: isTechDone ? 'Modifier l\'Évaluation Technique' : 'Ajouter l\'Évaluation Technique',
          icon: Icons.architecture_rounded,
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (context) => TechnicalEvaluationPage(projectId: widget.projectId)));
            _checkAndUpdateGlobalStatus();
          },
          color: primaryColor,
        ));
      }
    }

    if (hasIt && RolePermissions.canPerformItEvaluation(userRole)) {
      final itMap = projectData['it_evaluation'] as Map<String, dynamic>? ?? {};
      final bool isItDone = itMap.isNotEmpty;

      if (!isItDone || status == 'Nouvelle Demande' || status == 'En Cours d\'Évaluation') {
        buttons.add(buildCTA(
          label: isItDone ? 'Modifier l\'Évaluation IT' : 'Ajouter l\'Évaluation IT',
          icon: Icons.router_rounded,
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (context) => ItEvaluationPage(projectId: widget.projectId)));
            _checkAndUpdateGlobalStatus();
          },
          color: itPrimaryColor,
        ));
      }
    }

    if ((status == 'Évaluation Terminée' || status == 'Évaluation Technique Terminé' || status == 'Évaluation IT Terminé') && RolePermissions.canUploadDevis(userRole)) {
      buttons.add(buildCTA(
        label: 'Ajouter Fichiers Projet',
        icon: Icons.cloud_upload_rounded,
        onPressed: _uploadProjectFiles,
        color: const Color(0xFFF59E0B),
      ));
      buttons.add(buildCTA(
        label: 'Confirmer l\'Approbation Client',
        icon: Icons.verified_rounded,
        onPressed: _showApprovalDialog,
        color: countingColor,
      ));
    }

    if (status == 'Finalisation de la Commande' && RolePermissions.canUploadDevis(userRole)) {
      buttons.add(buildCTA(
        label: 'Définir les Produits Commandés',
        icon: Icons.format_list_bulleted_add,
        onPressed: () => _showProductFinalizationDialog(projectData['orderedProducts'] ?? []),
        color: const Color(0xFF14B8A6),
      ));
    }

    // 🚀 THE NEW INSTALLATION LINKING SECTION
    if (status != 'Transféré à l\'Installation' && status != 'Refusé') {
      if (RolePermissions.canScheduleInstallation(userRole)) {
        if (status == 'À Planifier') {
          buttons.add(buildCTA(
            label: 'Créer la Tâche d\'Installation',
            icon: Icons.rocket_launch_rounded,
            onPressed: () => _handleInstallationCreation(projectData),
            color: const Color(0xFF8B5CF6), // Purple
          ));
        }

        // ✅ NEW: Link to existing Installation
        buttons.add(buildCTA(
          label: 'Lier à une installation existante',
          icon: Icons.link_rounded,
          onPressed: _showInstallationLinker,
          color: const Color(0xFF64748B), // Slate
          isSecondary: true,
        ));
      }
    }

    if (buttons.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
        child: Center(child: Text('Aucune action disponible pour ce statut.', style: GoogleFonts.inter(color: textLight, fontWeight: FontWeight.w500))),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: buttons);
  }
}

// ----------------------------------------------------------------------
// ✅ 1. NEW: INSTALLATION LINKER BOTTOM SHEET
// ----------------------------------------------------------------------
class _InstallationLinkerSheet extends StatefulWidget {
  final String projectId;
  const _InstallationLinkerSheet({required this.projectId});

  @override
  State<_InstallationLinkerSheet> createState() => _InstallationLinkerSheetState();
}

class _InstallationLinkerSheetState extends State<_InstallationLinkerSheet> {
  String _searchQuery = "";
  bool _isLinking = false;

  Future<void> _linkToInstallation(String installationId, String installationCode) async {
    setState(() => _isLinking = true);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final projectRef = FirebaseFirestore.instance.collection('projects').doc(widget.projectId);
        final instRef = FirebaseFirestore.instance.collection('installations').doc(installationId);

        // Close the project
        transaction.update(projectRef, {
          'status': 'Transféré à l\'Installation',
          'installations': {
            'installationId': installationId,
            'installationCode': installationCode,
          }
        });

        // Link the installation back to the project
        transaction.update(instRef, {
          'projectId': widget.projectId,
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Projet lié et clôturé avec succès !', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Text("Lier à une Installation", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Text("Sélectionnez l'installation existante pour clôturer ce projet.", textAlign: TextAlign.center, style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13)),
          const SizedBox(height: 24),

          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: GoogleFonts.inter(),
            decoration: InputDecoration(
              hintText: "Rechercher par Code ou Client...",
              hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),

          // List of Installations
          Expanded(
            child: _isLinking
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
              // Fetching all installations, ordered by latest
              stream: FirebaseFirestore.instance
                  .collection('installations')
                  .orderBy('createdAt', descending: true)
                  .limit(100) // Limit to prevent massive reads
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("Aucune installation trouvée.", style: GoogleFonts.inter(color: Colors.grey)));

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final searchString = '${data['installationCode']} ${data['clientName']} ${data['storeName']}'.toLowerCase();
                  return searchString.contains(_searchQuery.toLowerCase());
                }).toList();

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final instCode = data['installationCode'] ?? 'Inconnu';
                    final status = data['status'] ?? 'Inconnu';

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.handyman_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      title: Text('$instCode - ${data['clientName']}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                      subtitle: Text('Statut: $status | Magasin: ${data['storeName']}', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13)),
                      trailing: const Icon(Icons.link_rounded, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      onTap: () => _linkToInstallation(docs[index].id, instCode),
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

// ----------------------------------------------------------------------
// ✅ 2. ORIGINAL: ORDER FINALIZATION DIALOG
// ----------------------------------------------------------------------
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
            content: Text("Erreur de vérification: $e", style: GoogleFonts.inter()),
            backgroundColor: Colors.redAccent));
        setState(() => _isSaving = false);
      }
    }
  }

  void _showStockWarningDialog(List<String> warnings) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('⚠️ Stock Insuffisant', style: GoogleFonts.inter(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Certains produits n\'ont pas assez de stock. Si vous continuez, les stocks passeront en négatif :', style: GoogleFonts.inter()),
              const SizedBox(height: 12),
              ...warnings.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(w, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler', style: GoogleFonts.inter(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              Navigator.of(ctx).pop();
              _executeFinalizationTransaction();
            },
            child: Text('Forcer la Commande', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
            SnackBar(content: Text("Erreur: $e", style: GoogleFonts.inter()), backgroundColor: Colors.redAccent));
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
                    content: Text('${productMap['productName'] ?? 'Ce produit'} est déjà dans la liste.', style: GoogleFonts.inter())),
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
              SnackBar(content: Text('${newProduct.productName} ajouté.', style: GoogleFonts.inter())),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Finaliser la Commande', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: _selectedProducts.isEmpty
                  ? Center(child: Text('Aucun produit ajouté.', style: GoogleFonts.inter(color: Colors.grey.shade600)))
                  : ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _selectedProducts.length,
                itemBuilder: (context, index) {
                  final product = _selectedProducts[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: ListTile(
                      title: Text(product.productName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Text('Qté: ${product.quantity}', style: GoogleFonts.inter(color: const Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                      ),
                      onLongPress: () => setState(() => _selectedProducts.removeAt(index)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.5)),
                ),
                onPressed: _showProductSelector,
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF4F46E5)),
                label: Text('Ajouter/Modifier Produits', style: GoogleFonts.inter(color: const Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler', style: GoogleFonts.inter(color: Colors.grey.shade600))),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: _isSaving ? null : _checkStockAndProceed,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Enregistrer', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
      ],
    );
  }
}
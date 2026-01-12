// lib/screens/service_technique/installation_details_page.dart

import 'package:flutter/foundation.dart'; // ✅ For kIsWeb
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:boitex_info_app/screens/service_technique/installation_report_page.dart';
import 'package:boitex_info_app/services/installation_pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// ✅ Cloud PDF Generation Imports
import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart'; // ✅ For Web Download

// ✅ Viewers
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';

class AppUser {
  final String uid;
  final String displayName;
  AppUser({required this.uid, required this.displayName});

  @override
  bool operator ==(Object other) => other is AppUser && other.uid == uid;
  @override
  int get hashCode => uid.hashCode;
}

class InstallationDetailsPage extends StatefulWidget {
  final DocumentSnapshot installationDoc;
  final String userRole;

  const InstallationDetailsPage(
      {super.key, required this.installationDoc, required this.userRole});

  @override
  State<InstallationDetailsPage> createState() =>
      _InstallationDetailsPageState();
}

class _InstallationDetailsPageState extends State<InstallationDetailsPage> {
  DateTime? _scheduledDate;
  List<AppUser> _allTechnicians = [];
  List<AppUser> _assignedTechnicians = [];
  List<String> _effectiveTechniciansNames =
  []; // Technicians who actually did the job
  bool _isLoading = false;
  Map<String, dynamic>? _installationReport; // Holds the report data if 'Terminée'
  static const Color primaryColor = Colors.green;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final data = widget.installationDoc.data() as Map<String, dynamic>;

    // 1. Parse Date
    if (data['installationDate'] != null) {
      _scheduledDate = (data['installationDate'] as Timestamp).toDate();
    }

    // 2. ✅ FIXED: Parse Assigned Technicians (Handles BOTH Old List<String> and New List<Map>)
    if (data['assignedTechnicians'] != null) {
      final rawList = data['assignedTechnicians'] as List;
      _assignedTechnicians = rawList.map((item) {
        if (item is String) {
          // LEGACY DATA: It is just an ID string.
          // We set a placeholder name. _fetchTechnicians will "heal" this shortly.
          return AppUser(uid: item, displayName: 'Chargement...');
        } else if (item is Map) {
          // NEW DATA: It is a Map object.
          return AppUser(
              uid: item['uid'] ?? '',
              displayName: item['displayName'] ?? 'Inconnu');
        }
        return AppUser(uid: 'error', displayName: 'Format Inconnu');
      }).toList();
    }

    // 3. Fetch list of all techs (and resolve Legacy IDs)
    _fetchTechnicians();

    // 4. If status is completed, fetch the report safely
    if (data['status'] == 'Terminée') {
      _fetchReportDetails();
    }
  }

  /// ✅ FIXED: Safely fetches report details without hanging indefinitely
  Future<void> _fetchReportDetails() async {
    setState(() => _isLoading = true);
    try {
      // Attempt 1: Check Subcollection (Standard path)
      final reportSnapshot = await FirebaseFirestore.instance
          .collection('installations')
          .doc(widget.installationDoc.id)
          .collection('reports')
          .limit(1)
          .get();

      Map<String, dynamic>? reportData;

      if (reportSnapshot.docs.isNotEmpty) {
        reportData = reportSnapshot.docs.first.data();
      } else {
        // Attempt 2: Fallback to main document (in case data was saved flat)
        final mainDoc = await FirebaseFirestore.instance
            .collection('installations')
            .doc(widget.installationDoc.id)
            .get();
        final mainData = mainDoc.data();
        // Check if main doc has report-like fields
        if (mainData != null &&
            (mainData.containsKey('effectiveTechnicians') ||
                mainData.containsKey('signatureUrl') ||
                mainData.containsKey('assignedTechnicianNames'))) {
          reportData = mainData;
        }
      }

      if (reportData != null) {
        // ✅ FIXED: Check BOTH possible field names for technicians
        if (reportData.containsKey('effectiveTechnicians')) {
          final rawTechs = reportData['effectiveTechnicians'];
          if (rawTechs is List) {
            _effectiveTechniciansNames = List<String>.from(rawTechs);
          }
        } else if (reportData.containsKey('assignedTechnicianNames')) {
          // Fallback for data coming from the Report Page
          final rawTechs = reportData['assignedTechnicianNames'];
          if (rawTechs is List) {
            _effectiveTechniciansNames = List<String>.from(rawTechs);
          }
        }

        if (mounted) {
          setState(() {
            _installationReport = reportData;
          });
        }
      }
    } catch (e) {
      print("Error fetching report: $e");
    } finally {
      // ✅ VITAL: Ensure loading stops no matter what
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTechnicians() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: [
        UserRoles.admin,
        UserRoles.responsableAdministratif,
        UserRoles.responsableCommercial,
        UserRoles.responsableTechnique,
        UserRoles.responsableIT,
        UserRoles.chefDeProjet,
        UserRoles.technicienST,
        UserRoles.technicienIT
      ]).get();

      final allTechnicians = snapshot.docs
          .map((doc) => AppUser(
          uid: doc.id,
          displayName: doc.data()['displayName'] as String? ??
              'Utilisateur Inconnu'))
          .toList();

      // ✅ VISION FIX: "Self-Healing" Legacy Data
      // If we have "Chargement..." names (from Legacy IDs), we replace them with real names now.
      List<AppUser> healedAssignedList = [];
      for (var assigned in _assignedTechnicians) {
        try {
          // Try to find the user in the full directory
          final match =
          allTechnicians.firstWhere((tech) => tech.uid == assigned.uid);
          healedAssignedList.add(match);
        } catch (e) {
          // If user not found (deleted?), keep original
          if (assigned.displayName == 'Chargement...') {
            healedAssignedList.add(AppUser(
                uid: assigned.uid, displayName: 'Technicien (Ex-employé)'));
          } else {
            healedAssignedList.add(assigned);
          }
        }
      }

      if (mounted) {
        setState(() {
          _allTechnicians = allTechnicians;
          _assignedTechnicians = healedAssignedList; // Update UI with real names
        });
      }
    } catch (e) {
      print("Error fetching users: $e");
    }
  }

  Future<void> _saveSchedule() async {
    setState(() => _isLoading = true);
    try {
      // This will overwrite Old IDs with New Objects, effectively migrating the data
      final techniciansToSave = _assignedTechnicians
          .map((user) => {'uid': user.uid, 'displayName': user.displayName})
          .toList();

      final Map<String, dynamic> updateData = {
        'assignedTechnicians': techniciansToSave,
      };

      if (_scheduledDate != null) {
        updateData['installationDate'] = Timestamp.fromDate(_scheduledDate!);
        updateData['status'] = 'Planifiée';
      } else {
        updateData['installationDate'] = FieldValue.delete();
        updateData['status'] = 'À Planifier';
      }

      await FirebaseFirestore.instance
          .collection('installations')
          .doc(widget.installationDoc.id)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_scheduledDate != null
                ? 'Installation planifiée avec succès'
                : 'Installation reportée (Date retirée)'),
            backgroundColor:
            _scheduledDate != null ? Colors.green : Colors.orange));
      }
    } catch (e) {
      print("Error saving schedule: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSchedulingDialog() {
    DateTime? tempDate = _scheduledDate;
    List<AppUser> tempTechnicians = List.from(_assignedTechnicians);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Planifier l\'Installation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                      tempDate == null
                          ? 'Sélectionner une date'
                          : DateFormat('dd MMMM yyyy', 'fr_FR')
                          .format(tempDate!),
                      style: TextStyle(
                          color: tempDate == null ? Colors.red : Colors.black)),
                  trailing: tempDate != null
                      ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () =>
                        setDialogState(() => tempDate = null),
                    tooltip: "Retirer la date (Reporter)",
                  )
                      : const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: context,
                        initialDate: tempDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030));
                    if (picked != null) setDialogState(() => tempDate = picked);
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade400)),
                ),
                if (tempDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextButton.icon(
                        onPressed: () => setDialogState(() => tempDate = null),
                        icon:
                        const Icon(Icons.event_busy, color: Colors.orange),
                        label: const Text("Reporter / Date indéterminée",
                            style: TextStyle(color: Colors.orange))),
                  ),
                const SizedBox(height: 16),
                MultiSelectDialogField<AppUser>(
                  items: _allTechnicians
                      .map((user) =>
                      MultiSelectItem<AppUser>(user, user.displayName))
                      .toList(),
                  initialValue: tempTechnicians,
                  title: const Text("Sélectionner Techniciens"),
                  buttonText: const Text("Assigner à (Optionnel)"),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade600),
                      borderRadius: BorderRadius.circular(8)),
                  onConfirm: (results) =>
                  tempTechnicians = results.cast<AppUser>(),
                  chipDisplay: MultiSelectChipDisplay<AppUser>(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _scheduledDate = tempDate;
                  _assignedTechnicians = tempTechnicians;
                });
                Navigator.of(ctx).pop();
                _saveSchedule();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // ✅ CLOUD PDF LOGIC
  // ----------------------------------------------------------------

  Future<Map<String, dynamic>?> _fetchPdfBytes() async {
    setState(() => _isLoading = true);
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('getInstallationPdf')
          .call({'installationId': widget.installationDoc.id});

      final data = result.data as Map<dynamic, dynamic>;
      final String base64Pdf = data['pdfBase64'];
      final String filename = data['filename'];
      final bytes = base64Decode(base64Pdf);

      return {'bytes': bytes, 'filename': filename};
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur PDF Cloud: $e'),
              backgroundColor: Colors.red),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<File> _saveFileForMobile(Uint8List bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _generateAndDownloadPDF() async {
    final pdfData = await _fetchPdfBytes();
    if (pdfData == null) return;

    final bytes = pdfData['bytes'] as Uint8List;
    final filename = pdfData['filename'] as String;

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: filename.replaceAll('.pdf', ''),
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Téléchargement démarré...'),
              backgroundColor: Colors.green),
        );
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerPage(
            pdfBytes: bytes,
            title: filename,
          ),
        ),
      );
    }
  }

  Future<void> _shareViaWhatsApp() async {
    if (kIsWeb) return;
    final pdfData = await _fetchPdfBytes();
    if (pdfData == null) return;

    final bytes = pdfData['bytes'] as Uint8List;
    final filename = pdfData['filename'] as String;
    final file = await _saveFileForMobile(bytes, filename);
    final data = widget.installationDoc.data() as Map<String, dynamic>;
    final message =
        "Voici le rapport d'installation pour ${data['clientName'] ?? 'Client'}.";
    await Share.shareXFiles([XFile(file.path)], text: message);
  }

  Future<void> _shareViaEmail() async {
    if (kIsWeb) return;
    final pdfData = await _fetchPdfBytes();
    if (pdfData == null) return;

    final bytes = pdfData['bytes'] as Uint8List;
    final filename = pdfData['filename'] as String;
    final file = await _saveFileForMobile(bytes, filename);
    final data = widget.installationDoc.data() as Map<String, dynamic>;
    final subject =
        "Rapport Installation: ${data['installationCode'] ?? 'N/A'}";
    final body =
        "Bonjour,\n\nVeuillez trouver ci-joint le rapport d'installation.\n\nCordialement.";
    await Share.shareXFiles([XFile(file.path)], subject: subject, text: body);
  }

  // ----------------------------------------------------------------
  // UI BUILDERS
  // ----------------------------------------------------------------

  bool _isVideoUrl(String path) {
    final lowercasePath = path.toLowerCase();
    return lowercasePath.endsWith('.mp4') ||
        lowercasePath.endsWith('.mov') ||
        lowercasePath.endsWith('.avi') ||
        lowercasePath.endsWith('.mkv');
  }

  Widget _buildDetailRow(String label, dynamic value, [Color? color]) {
    final displayValue = value is bool
        ? (value ? 'Oui' : 'Non')
        : (value ?? 'N/A').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
          Expanded(
            flex: 6,
            child: Text(displayValue,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: color, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildBooleanRow(String label, dynamic value, [String? notes]) {
    if (value == null) return const SizedBox.shrink();
    final bool isYes = value == true;
    final String statusText = isYes ? 'Oui' : 'Non';
    final Color statusColor =
    isYes ? Colors.green.shade700 : Colors.red.shade700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(label, statusText, statusColor),
        if (notes != null && notes.isNotEmpty)
          Padding(
            padding:
            const EdgeInsets.only(left: 32.0, bottom: 8.0, right: 16.0),
            child: Text('Détails: $notes',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isYes ? Colors.grey.shade600 : Colors.red.shade400)),
          ),
      ],
    );
  }

  List<Widget> _buildTechnicalEvaluation(List<dynamic> evaluations) {
    if (evaluations.isEmpty) return [];

    return evaluations.asMap().entries.map((entry) {
      Map<String, dynamic> evalData = (entry.value is Map)
          ? Map<String, dynamic>.from(entry.value as Map)
          : {};
      if (evalData.isEmpty) return const SizedBox.shrink();

      List<Widget> details = [
        _buildDetailRow('Type d\'entrée', evalData['entranceType']),
        _buildDetailRow('Type de porte', evalData['doorType']),
        _buildDetailRow(
            'Largeur entrée', '${evalData['entranceWidth'] ?? 'N/A'} m'),
        _buildDetailRow(
            'Longeur entrée', '${evalData['entranceLength'] ?? 'N/A'} m'),
        const Divider(height: 1),
        _buildBooleanRow('Alimentation', evalData['isPowerAvailable'],
            evalData['powerNotes']),
        _buildBooleanRow('Sol Fini', evalData['isFloorFinalized']),
        _buildBooleanRow('Conduit', evalData['isConduitAvailable']),
        _buildBooleanRow('Tranchée', evalData['canMakeTrench']),
        _buildBooleanRow(
            'Obstacles', evalData['hasObstacles'], evalData['obstacleNotes']),
        if (evalData['generalNotes'] != null)
          _buildDetailRow('Notes', evalData['generalNotes']),
      ];

      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          leading: Icon(Icons.square_foot_outlined, color: primaryColor),
          title: Text('Évaluation Technique #${entry.key + 1}',
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          children: [
            const Divider(height: 1),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: details),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.installationDoc.data() as Map<String, dynamic>;

    dynamic rawTechnicalData = data['technicalEvaluation'];
    final List<dynamic> technicalEvaluation = (rawTechnicalData is List)
        ? rawTechnicalData
        : (rawTechnicalData is Map ? [rawTechnicalData] : []);

    final status = data['status'] ?? 'Inconnu';
    final orderedProducts = data['orderedProducts'] as List? ?? [];

    final List<String> allMediaUrls =
    List<String>.from(data['mediaUrls'] ?? []);

    final List<String> sortedPhotoUrls = [];
    final List<String> sortedVideoUrls = [];

    for (String url in allMediaUrls) {
      if (_isVideoUrl(url)) {
        sortedVideoUrls.add(url);
      } else {
        sortedPhotoUrls.add(url);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Installation: ${data['clientName'] ?? ''}'),
        backgroundColor: primaryColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildStatusHeader(status),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Détails du Projet',
            icon: Icons.business_center,
            children: [
              ListTile(
                  title: Text(data['clientName'] ?? 'N/A'),
                  subtitle: const Text('Client')),
              ListTile(
                  title: Text(data['clientPhone'] ?? 'N/A'),
                  subtitle: const Text('Téléphone')),
              ListTile(
                title: Text(data['initialRequest'] ?? 'N/A',
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: const Text('Demande initiale'),
                isThreeLine: true,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.calendar_today_outlined,
                    color: Colors.grey.shade600),
                title: Text(
                  _scheduledDate == null
                      ? 'Non planifiée'
                      : DateFormat('dd MMMM yyyy', 'fr_FR')
                      .format(_scheduledDate!),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _scheduledDate == null ? Colors.blue.shade700 : null,
                  ),
                ),
                subtitle: const Text('Date d\'installation'),
              ),
            ],
          ),

          _buildTechnicianCard(),

          if (orderedProducts.isNotEmpty)
            _buildInfoCard(
              title: 'Produits à Installer',
              icon: Icons.inventory_2_outlined,
              children: orderedProducts
                  .map((item) => ListTile(
                title: Text(item['productName'] ?? 'N/A'),
                trailing: Text('Qté: ${item['quantity'] ?? 0}'),
              ))
                  .toList(),
            ),

          ..._buildTechnicalEvaluation(technicalEvaluation),
          const SizedBox(height: 16),

          MediaGalleryWidget(
            photoUrls: sortedPhotoUrls,
            videoUrls: sortedVideoUrls,
            primaryColor: primaryColor,
          ),

          _buildActionCard(status, widget.userRole),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(String status) {
    IconData icon;
    Color color;
    switch (status) {
      case 'À Planifier':
        icon = Icons.edit_calendar_outlined;
        color = Colors.blue;
        break;
      case 'Planifiée':
        icon = Icons.task_alt_outlined;
        color = primaryColor;
        break;
      case 'En Cours':
        icon = Icons.construction_outlined;
        color = Colors.orange;
        break;
      case 'Terminée':
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
        border: Border.all(color: color.withOpacity(0.3)),
      ),
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
          if (children.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
        ],
      ),
    );
  }

  /// ✅ UPDATED: Displays Effective Techs if report is loaded, else Assigned Techs
  Widget _buildTechnicianCard() {
    List<Widget> content;

    // 1. If we have effective technicians from the report (Job DONE)
    if (_effectiveTechniciansNames.isNotEmpty) {
      content = [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text("Techniciens ayant effectué l'installation:",
              style:
              TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ),
        ..._effectiveTechniciansNames
            .map((name) => ListTile(
          leading:
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          title: Text(name),
          dense: true,
        ))
            .toList()
      ];
    }
    // 2. If no report yet, show Assigned Techs (Job PLANNED)
    else if (_assignedTechnicians.isNotEmpty) {
      content = [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text("Techniciens planifiés:",
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        ..._assignedTechnicians
            .map((user) => ListTile(
          leading: const Icon(Icons.person_outline, size: 20),
          title: Text(user.displayName),
          dense: true,
        ))
            .toList()
      ];
    }
    // 3. None assigned
    else {
      content = [
        const ListTile(
          title: Text('Aucun technicien assigné'),
          subtitle: Text('La planification est requise'),
        )
      ];
    }

    return _buildInfoCard(
      title: 'Techniciens',
      icon: Icons.engineering_outlined,
      children: content,
    );
  }

  Widget _buildActionCard(String status, String userRole) {
    return _buildInfoCard(
      title: 'Actions',
      icon: Icons.task_alt_outlined,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _buildActionButtons(status, userRole)),
        ),
      ],
    );
  }

  List<Widget> _buildActionButtons(String status, String userRole) {
    List<Widget> buttons = [];
    switch (status) {
      case 'À Planifier':
        if (RolePermissions.canScheduleInstallation(userRole)) {
          buttons.add(
            ElevatedButton.icon(
              onPressed: _showSchedulingDialog,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Planifier l\'Installation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          );
        } else {
          buttons.add(const Text(
              'En attente de planification par un manager.',
              textAlign: TextAlign.center));
        }
        break;
      case 'Planifiée':
        buttons.add(
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (context) => InstallationReportPage(
                      installationId: widget.installationDoc.id)),
            ),
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Rédiger le Rapport'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

        if (RolePermissions.canScheduleInstallation(userRole)) {
          buttons.add(const SizedBox(height: 12));
          buttons.add(
            ElevatedButton.icon(
              onPressed: _showSchedulingDialog,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Modifier la Planification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          );
        }
        break;
      case 'Terminée':
        buttons.addAll([
          const Text('Installation terminée avec succès!',
              style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Text('Partager le rapport:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _generateAndDownloadPDF,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Générer / Voir PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _shareViaWhatsApp,
            icon: const Icon(Icons.phone),
            label: const Text('Partager via WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _shareViaEmail,
            icon: const Icon(Icons.email_outlined),
            label: const Text('Envoyer par Email'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF424242),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]);
        break;
      default:
        buttons.add(const SizedBox.shrink());
    }
    return buttons;
  }
}

class MediaGalleryWidget extends StatelessWidget {
  final List<String> photoUrls;
  final List<String> videoUrls;
  final Color primaryColor;

  const MediaGalleryWidget({
    super.key,
    required this.photoUrls,
    required this.videoUrls,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrls.isEmpty && videoUrls.isEmpty) {
      return const SizedBox.shrink();
    }

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
                Icon(Icons.perm_media_outlined, color: primaryColor),
                const SizedBox(width: 8),
                const Text("Photos & Vidéos",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildPhotoSection(context),
          _buildVideoSection(context),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(BuildContext context) {
    if (photoUrls.isEmpty) {
      return const ListTile(
        dense: true,
        leading: Icon(Icons.photo_outlined, size: 20),
        title: Text("Aucune photo", style: TextStyle(fontSize: 14)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Photos",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: photoUrls.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ImageGalleryPage(
                          imageUrls: photoUrls,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        photoUrls[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                              child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.error_outline,
                                color: Colors.red),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection(BuildContext context) {
    if (videoUrls.isEmpty) {
      return const ListTile(
        dense: true,
        leading: Icon(Icons.videocam_outlined, size: 20),
        title: Text("Aucune vidéo", style: TextStyle(fontSize: 14)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12.0).copyWith(top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Vidéos",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Column(
            children: videoUrls.asMap().entries.map((entry) {
              int index = entry.key;
              String url = entry.value;
              return ListTile(
                leading: Icon(Icons.play_circle_outline, color: primaryColor),
                title: Text("Vidéo ${index + 1}"),
                subtitle: Text(
                  _getFileNameFromUrl(url),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerPage(videoUrl: url),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getFileNameFromUrl(String url) {
    try {
      return Uri.decodeFull(url.split('/').last.split('?').first);
    } catch (e) {
      return 'Lien vidéo';
    }
  }
}
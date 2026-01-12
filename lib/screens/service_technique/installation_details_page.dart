// lib/screens/service_technique/installation_details_page.dart

import 'package:flutter/foundation.dart'; // ✅ For kIsWeb
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Typography
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
  List<String> _effectiveTechniciansNames = [];
  bool _isLoading = false;
  Map<String, dynamic>? _installationReport;

  // 🎨 THEME COLORS
  final Color _primaryBlue = const Color(0xFF2962FF);
  final Color _bgLight = const Color(0xFFF4F6F9);
  final Color _cardWhite = Colors.white;
  final Color _textDark = const Color(0xFF2D3436);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    // ✅ FIX: Safely cast data
    final data = widget.installationDoc.data() as Map<String, dynamic>? ?? {};

    // ✅ FIX 1: Safe Date Parsing
    if (data['installationDate'] != null) {
      if (data['installationDate'] is Timestamp) {
        _scheduledDate = (data['installationDate'] as Timestamp).toDate();
      } else {
        _scheduledDate = null;
      }
    }

    // ✅ FIX 2: Safe Technician List Parsing
    if (data['assignedTechnicians'] != null && data['assignedTechnicians'] is List) {
      final rawList = data['assignedTechnicians'] as List;
      _assignedTechnicians = rawList.map((item) {
        if (item is String) {
          return AppUser(uid: item, displayName: 'Chargement...');
        } else if (item is Map) {
          return AppUser(
              uid: item['uid'] ?? '',
              displayName: item['displayName'] ?? 'Inconnu');
        }
        return AppUser(uid: 'error', displayName: 'Format Inconnu');
      }).toList();
    }

    _fetchTechnicians();

    // Check for status or signature (handle missing signatureUrl key gracefully)
    if (data['status'] == 'Terminée' || (data.containsKey('signatureUrl') && data['signatureUrl'] != null)) {
      _fetchReportDetails();
    }
  }

  Future<void> _fetchReportDetails() async {
    setState(() => _isLoading = true);
    try {
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
        final mainDoc = await FirebaseFirestore.instance
            .collection('installations')
            .doc(widget.installationDoc.id)
            .get();
        final mainData = mainDoc.data();
        if (mainData != null) {
          // Check keys safely
          if (mainData.containsKey('effectiveTechnicians') ||
              mainData.containsKey('signatureUrl') ||
              mainData.containsKey('assignedTechnicianNames')) {
            reportData = mainData;
          }
        }
      }

      if (reportData != null) {
        if (reportData.containsKey('effectiveTechnicians')) {
          final rawTechs = reportData['effectiveTechnicians'];
          if (rawTechs is List) {
            _effectiveTechniciansNames = List<String>.from(rawTechs);
          }
        } else if (reportData.containsKey('assignedTechnicianNames')) {
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
      debugPrint("Error fetching report: $e");
    } finally {
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

      List<AppUser> healedAssignedList = [];
      for (var assigned in _assignedTechnicians) {
        try {
          final match =
          allTechnicians.firstWhere((tech) => tech.uid == assigned.uid);
          healedAssignedList.add(match);
        } catch (e) {
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
          _assignedTechnicians = healedAssignedList;
        });
      }
    } catch (e) {
      debugPrint("Error fetching users: $e");
    }
  }

  Future<void> _saveSchedule() async {
    setState(() => _isLoading = true);
    try {
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
      debugPrint("Error saving schedule: $e");
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
          title: Text('Planification', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      style: GoogleFonts.poppins(
                          color: tempDate == null ? Colors.red : Colors.black)),
                  trailing: tempDate != null
                      ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () =>
                        setDialogState(() => tempDate = null),
                    tooltip: "Reporter",
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
                const SizedBox(height: 16),
                MultiSelectDialogField<AppUser>(
                  items: _allTechnicians
                      .map((user) =>
                      MultiSelectItem<AppUser>(user, user.displayName))
                      .toList(),
                  initialValue: tempTechnicians,
                  title: const Text("Techniciens"),
                  buttonText: const Text("Assigner l'équipe"),
                  buttonIcon: const Icon(Icons.person_add_alt),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
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
                child: Text('Annuler', style: GoogleFonts.poppins())),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _scheduledDate = tempDate;
                  _assignedTechnicians = tempTechnicians;
                });
                Navigator.of(ctx).pop();
                _saveSchedule();
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue),
              child: Text('Enregistrer', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ... (PDF / Share Functions) ...
  Future<Map<String, dynamic>?> _fetchPdfBytes() async {
    setState(() => _isLoading = true);
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('getInstallationPdf')
          .call({'installationId': widget.installationDoc.id});
      final data = result.data as Map<dynamic, dynamic>;
      return {'bytes': base64Decode(data['pdfBase64']), 'filename': data['filename']};
    } catch (e) { return null; } finally { if (mounted) setState(() => _isLoading = false); }
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
    if (kIsWeb) {
      await FileSaver.instance.saveFile(name: pdfData['filename'].replaceAll('.pdf', ''), bytes: pdfData['bytes'], ext: 'pdf', mimeType: MimeType.pdf);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerPage(pdfBytes: pdfData['bytes'], title: pdfData['filename'])));
    }
  }

  Future<void> _shareViaWhatsApp() async {
    if (kIsWeb) return;
    final pdfData = await _fetchPdfBytes();
    if (pdfData != null) {
      final file = await _saveFileForMobile(pdfData['bytes'], pdfData['filename']);
      await Share.shareXFiles([XFile(file.path)], text: "Rapport Installation");
    }
  }

  Future<void> _shareViaEmail() async {
    if (kIsWeb) return;
    final pdfData = await _fetchPdfBytes();
    if (pdfData != null) {
      final file = await _saveFileForMobile(pdfData['bytes'], pdfData['filename']);
      await Share.shareXFiles([XFile(file.path)], subject: "Rapport", text: "Ci-joint le rapport.");
    }
  }

  Future<void> _launchMaps(String? address) async {
    if (address == null || address.isEmpty) return;
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}");
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  bool _isVideoUrl(String path) {
    final l = path.toLowerCase();
    return l.endsWith('.mp4') || l.endsWith('.mov') || l.endsWith('.avi');
  }

  // ===============================================================
  // 🎨 NEW HIGH-QUALITY UI WIDGETS
  // ===============================================================

  Widget _buildTimeline(String status) {
    int step = 0;
    if (status == 'Planifiée') step = 1;
    if (status == 'En Cours') step = 2;
    if (status == 'Terminée') step = 3;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStep(0, "Attente", Icons.schedule, step >= 0),
          _buildLine(step >= 1),
          _buildStep(1, "Planifié", Icons.event_available, step >= 1),
          _buildLine(step >= 2),
          _buildStep(2, "En Cours", Icons.handyman, step >= 2),
          _buildLine(step >= 3),
          _buildStep(3, "Terminé", Icons.check_circle, step >= 3),
        ],
      ),
    );
  }

  Widget _buildStep(int idx, String label, IconData icon, bool active) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: active ? _primaryBlue : Colors.grey.shade300,
            shape: BoxShape.circle,
            boxShadow: active ? [BoxShadow(color: _primaryBlue.withOpacity(0.4), blurRadius: 8)] : [],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: active ? _primaryBlue : Colors.grey)),
      ],
    );
  }

  Widget _buildLine(bool active) {
    return Container(width: 20, height: 2, color: active ? _primaryBlue : Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 15));
  }

  Widget _buildJobTicket(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("CLIENT", style: GoogleFonts.poppins(fontSize: 10, letterSpacing: 1.5, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(data['clientName'] ?? 'Inconnu', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    // ✅ FIXED: Check nulls for old installations
                    icon: const Icon(Icons.map, color: Colors.blue),
                    onPressed: () => _launchMaps("${data['storeName'] ?? ''} ${data['storeLocation'] ?? ''}"),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(Icons.person, data['contactName'] ?? 'Contact non spécifié'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.phone, data['clientPhone'] ?? 'N/A', isLink: true),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.store, data['storeName'] ?? 'Magasin Inconnu'),
                const SizedBox(height: 8),
                // ✅ ADDED: Store Location Field (Safe)
                _buildInfoRow(Icons.location_on, data['storeLocation'] ?? 'Ville Inconnue'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.description, data['initialRequest'] ?? 'Pas de description'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {bool isLink = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: isLink ? () => launchUrl(Uri.parse("tel:$text")) : null,
            child: Text(text, style: GoogleFonts.poppins(fontSize: 14, color: isLink ? Colors.blue : _textDark, decoration: isLink ? TextDecoration.underline : null)),
          ),
        ),
      ],
    );
  }

  // ✅ NEW: Completion Report Card (Notes + Signature)
  Widget _buildCompletionReport() {
    // ✅ FIX: Use data map for safe access on old documents
    final data = widget.installationDoc.data() as Map<String, dynamic>? ?? {};

    final notes = _installationReport?['notes'] ?? data['notes'];
    final signName = _installationReport?['signatoryName'] ?? data['signatoryName'];
    final signUrl = _installationReport?['signatureUrl'] ?? data['signatureUrl'];

    if (notes == null && signUrl == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 20),
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.green.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.verified, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text("RAPPORT DE CLÔTURE", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade800, letterSpacing: 1)),
            ]),
            const Divider(color: Colors.green),
            if (notes != null) ...[
              const SizedBox(height: 8),
              Text("Description / Notes:", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.green.shade900)),
              Text(notes, style: GoogleFonts.poppins(fontSize: 14, color: _textDark)),
            ],
            if (signUrl != null) ...[
              const SizedBox(height: 16),
              Text("Signature:", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.green.shade900)),
              const SizedBox(height: 4),
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: Image.network(signUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text("Erreur image")),
              ),
              if (signName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text("Signé par: $signName", style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
                ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicianList() {
    bool hasReport = _effectiveTechniciansNames.isNotEmpty;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(Icons.engineering, color: _primaryBlue, size: 20), const SizedBox(width: 8), Text(hasReport ? "Techs Effectifs" : "Techs Planifiés", style: GoogleFonts.poppins(fontWeight: FontWeight.w600))]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: hasReport
                  ? _effectiveTechniciansNames.map((name) => Chip(label: Text(name), avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green), backgroundColor: Colors.green.shade50)).toList()
                  : _assignedTechnicians.isNotEmpty
                  ? _assignedTechnicians.map((u) => Chip(label: Text(u.displayName), avatar: const Icon(Icons.account_circle, size: 16), backgroundColor: Colors.blue.shade50)).toList()
                  : [Text("Non assigné", style: GoogleFonts.poppins(fontStyle: FontStyle.italic, color: Colors.grey))],
            )
          ],
        ),
      ),
    );
  }

  // ✅ FIX 3: Safe Product List Parsing
  Widget _buildProductsCard(dynamic products) {
    List safeProducts = [];
    if (products is List) {
      safeProducts = products;
    }

    if (safeProducts.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("MATÉRIEL À INSTALLER", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            ...safeProducts.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.inbox, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p['productName'] ?? 'N/A', style: GoogleFonts.poppins(fontSize: 14))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text("x${p['quantity'] ?? '0'}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                  )
                ],
              ),
            ))
          ],
        ),
      ),
    );
  }

  Widget _buildTechEvalList(List<dynamic> evals) {
    if (evals.isEmpty) return const SizedBox.shrink();
    return Column(
      children: evals.asMap().entries.map((entry) {
        final Map<String, dynamic> e = entry.value ?? {};
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
          child: ExpansionTile(
            title: Text("Évaluation Tech #${entry.key + 1}", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            leading: Icon(Icons.square_foot, color: _primaryBlue),
            backgroundColor: Colors.transparent,
            childrenPadding: const EdgeInsets.all(16),
            children: [
              _buildDetailRow('Entrée', e['entranceType']),
              _buildDetailRow('Porte', e['doorType']),
              _buildBooleanRow('Alim. Élec', e['isPowerAvailable']),
              _buildBooleanRow('Conduit', e['isConduitAvailable']),
              if (e['generalNotes'] != null) Text("Note: ${e['generalNotes']}", style: GoogleFonts.poppins(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey.shade700)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailRow(String label, dynamic val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [Text("$label: ", style: GoogleFonts.poppins(color: Colors.grey)), Expanded(child: Text(val?.toString() ?? 'N/A', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)))]),
    );
  }

  Widget _buildBooleanRow(String label, bool? val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text("$label: ", style: GoogleFonts.poppins(color: Colors.grey)),
        Icon(val == true ? Icons.check : Icons.close, size: 16, color: val == true ? Colors.green : Colors.red),
        const SizedBox(width: 4),
        Text(val == true ? "Oui" : "Non", style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: val == true ? Colors.green : Colors.red))
      ]),
    );
  }

  // ✅ FIX 4: Safe Media Gallery Parsing
  Widget _buildMediaGallery(Map<String, dynamic> data) {
    final rawMedia = data['mediaUrls'];
    final List<String> urls = (rawMedia is List)
        ? rawMedia.map((e) => e.toString()).toList()
        : [];

    if (urls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("GALERIE MÉDIA", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            itemBuilder: (ctx, i) {
              final url = urls[i];
              final isVideo = _isVideoUrl(url);
              return GestureDetector(
                onTap: () {
                  if (isVideo) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerPage(videoUrl: url)));
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ImageGalleryPage(imageUrls: urls.where((u) => !_isVideoUrl(u)).toList(), initialIndex: 0)));
                  }
                },
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: isVideo
                        ? Center(child: Icon(Icons.play_circle_fill, color: _primaryBlue, size: 32))
                        : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.installationDoc.data() as Map<String, dynamic>? ?? {};
    final status = data['status'] ?? 'Inconnu';
    final rawEvals = data['technicalEvaluation'];
    final evals = (rawEvals is List) ? rawEvals : (rawEvals is Map ? [rawEvals] : []);

    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          data['installationCode'] ?? 'Détails',
          style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      bottomNavigationBar: _buildStickyFooter(status),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16).copyWith(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeline(status),
            _buildJobTicket(data),
            _buildCompletionReport(), // ✅ ADDED: Completion Report Card (Notes + Signature)
            const SizedBox(height: 20),
            _buildTechnicianList(),
            const SizedBox(height: 20),
            // ✅ FIX 3 Applied Here
            _buildProductsCard(data['orderedProducts']),
            const SizedBox(height: 20),
            _buildTechEvalList(evals),
            const SizedBox(height: 20),
            // ✅ FIX 4 Applied Here
            _buildMediaGallery(data),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyFooter(String status) {
    List<Widget> buttons = [];

    // SCHEDULE BUTTON
    if (status == 'À Planifier' && RolePermissions.canScheduleInstallation(widget.userRole)) {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showSchedulingDialog,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: const Text("PLANIFIER"),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      );
    }

    // REPORT BUTTON
    if (status == 'Planifiée' || status == 'En Cours') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InstallationReportPage(installationId: widget.installationDoc.id))),
            icon: const Icon(Icons.edit_document, size: 18),
            label: const Text("RAPPORT"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      );
    }

    // COMPLETED ACTIONS
    if (status == 'Terminée') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _generateAndDownloadPDF,
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text("PDF"),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      );
      buttons.add(const SizedBox(width: 10));
      buttons.add(
        Container(
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
          child: IconButton(icon: const Icon(Icons.share, color: Colors.green), onPressed: _shareViaWhatsApp),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewPadding.bottom + 20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))]),
      child: Row(children: buttons),
    );
  }
}
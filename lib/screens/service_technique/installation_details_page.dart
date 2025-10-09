// lib/screens/service_technique/installation_details_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:boitex_info_app/screens/service_technique/installation_report_page.dart';
import 'package:boitex_info_app/services/installation_pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  const InstallationDetailsPage({super.key, required this.installationDoc, required this.userRole});
  @override
  State<InstallationDetailsPage> createState() => _InstallationDetailsPageState();
}

class _InstallationDetailsPageState extends State<InstallationDetailsPage> {
  DateTime? _scheduledDate;
  List<AppUser> _allTechnicians = [];
  List<AppUser> _selectedTechnicians = [];
  bool _isLoading = false;
  static const Color primaryColor = Colors.green;

  @override
  void initState() {
    super.initState();
    final data = widget.installationDoc.data() as Map<String, dynamic>;
    if (data['installationDate'] != null) {
      _scheduledDate = (data['installationDate'] as Timestamp).toDate();
    }
    if (data['assignedTechnicians'] != null) {
      _selectedTechnicians = (data['assignedTechnicians'] as List)
          .map((tech) => AppUser(uid: tech['uid'], displayName: tech['displayName']))
          .toList();
    }
    _fetchTechnicians();
  }

  Future<void> _fetchTechnicians() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users')
          .where('role', whereIn: ['Responsable Technique', 'Responsable IT', 'Chef de Projet', UserRoles.technicienST, UserRoles.technicienIT])
          .get();
      final allTechnicians = snapshot.docs.map((doc) => AppUser(uid: doc.id, displayName: doc.data()['displayName'])).toList();
      if (mounted) setState(() => _allTechnicians = allTechnicians);
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _saveSchedule() async {
    if (_scheduledDate == null || _selectedTechnicians.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner une date et au moins un technicien.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final techniciansToSave = _selectedTechnicians.map((user) => {'uid': user.uid, 'displayName': user.displayName}).toList();
      await FirebaseFirestore.instance.collection('installations').doc(widget.installationDoc.id).update({
        'installationDate': Timestamp.fromDate(_scheduledDate!),
        'assignedTechnicians': techniciansToSave,
        'status': 'Planifiée',
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Installation planifiée avec succès'), backgroundColor: Colors.green));
    } catch (e) {
      print("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSchedulingDialog() {
    DateTime? tempDate = _scheduledDate;
    List<AppUser> tempTechnicians = List.from(_selectedTechnicians);
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
                  title: Text(tempDate == null ? 'Sélectionner une date' : DateFormat('dd MMMM yyyy', 'fr_FR').format(tempDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: tempDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                    if (picked != null) setDialogState(() => tempDate = picked);
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade400)),
                ),
                const SizedBox(height: 16),
                MultiSelectDialogField<AppUser>(
                  items: _allTechnicians.map((user) => MultiSelectItem<AppUser>(user, user.displayName)).toList(),
                  initialValue: tempTechnicians,
                  title: const Text("Sélectionner Techniciens"),
                  buttonText: const Text("Assigner à"),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade600), borderRadius: BorderRadius.circular(8)),
                  onConfirm: (results) => tempTechnicians = results.cast<AppUser>(),
                  chipDisplay: MultiSelectChipDisplay<AppUser>(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _scheduledDate = tempDate;
                  _selectedTechnicians = tempTechnicians;
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

  // PDF GENERATION METHODS
  Future<void> _generateAndDownloadPDF() async {
    setState(() => _isLoading = true);
    try {
      final data = widget.installationDoc.data() as Map<String, dynamic>;
      final pdfFile = await InstallationPdfService.generateInstallationReport(installationData: data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF généré!\n${pdfFile.path}'), backgroundColor: Colors.green, duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareViaWhatsApp() async {
    setState(() => _isLoading = true);
    try {
      final data = widget.installationDoc.data() as Map<String, dynamic>;
      final pdfFile = await InstallationPdfService.generateInstallationReport(installationData: data);
      final message = InstallationPdfService.generateWhatsAppMessage(data);
      await Share.shareXFiles([XFile(pdfFile.path)], text: message);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareViaEmail() async {
    setState(() => _isLoading = true);
    try {
      final data = widget.installationDoc.data() as Map<String, dynamic>;
      final pdfFile = await InstallationPdfService.generateInstallationReport(installationData: data);
      final emailContent = InstallationPdfService.generateEmailContent(data);
      await Share.shareXFiles([XFile(pdfFile.path)], subject: emailContent['subject'], text: emailContent['body']);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.installationDoc.data() as Map<String, dynamic>;
    final technicalEvaluation = data['technicalEvaluation'] as List? ?? [];
    final status = data['status'] ?? 'Inconnu';
    final orderedProducts = data['orderedProducts'] as List? ?? [];

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
              ListTile(title: Text(data['clientName'] ?? 'N/A'), subtitle: const Text('Client')),
              ListTile(title: Text(data['clientPhone'] ?? 'N/A'), subtitle: const Text('Téléphone')),
              ListTile(
                title: Text(data['initialRequest'] ?? 'N/A', maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: const Text('Demande initiale'),
                isThreeLine: true,
              ),
            ],
          ),
          if (orderedProducts.isNotEmpty)
            _buildInfoCard(
              title: 'Produits à Installer',
              icon: Icons.inventory_2_outlined,
              children: orderedProducts.map((item) => ListTile(
                title: Text(item['productName'] ?? 'N/A'),
                trailing: Text('Qté: ${item['quantity'] ?? 0}'),
              )).toList(),
            ),
          ...technicalEvaluation.asMap().entries.map((entry) {
            int idx = entry.key;
            Map<String, dynamic> evalData = Map<String, dynamic>.from(entry.value);
            return _buildInfoCard(
              title: 'Évaluation - Entrée #${idx + 1}',
              icon: Icons.square_foot_outlined,
              children: [
                ListTile(title: Text(evalData['entranceType'] ?? 'N/A'), subtitle: const Text('Type d\'entrée')),
                ListTile(title: Text(evalData['doorType'] ?? 'N/A'), subtitle: const Text('Type de porte')),
                ListTile(title: Text('${evalData['entranceLength'] ?? 'N/A'} m'), subtitle: const Text('Longeur entrée')),
              ],
            );
          }).toList(),
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
                Text(status, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> children}) {
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
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
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
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _buildActionButtons(status, userRole)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          );
        } else {
          buttons.add(const Text('En attente de planification par un manager.', textAlign: TextAlign.center));
        }
        break;
      case 'Planifiée':
        buttons.add(
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => InstallationReportPage(installationId: widget.installationDoc.id)),
            ),
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Rédiger le Rapport'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
        break;
      case 'Terminée':
        buttons.addAll([
          const Text('Installation terminée avec succès!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Text('Partager le rapport:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _generateAndDownloadPDF,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Générer PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

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

// Imports for the image and video viewer pages
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';

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
          .map((tech) =>
          AppUser(uid: tech['uid'], displayName: tech['displayName']))
          .toList();
    }
    _fetchTechnicians();
  }

  Future<void> _fetchTechnicians() async {
    try {
      // ✅ MODIFIED: List includes ALL managerial roles and technicians EXCEPT PDG
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: [
        UserRoles.admin, // Admin
        UserRoles.responsableAdministratif, // Responsable Administratif
        UserRoles.responsableCommercial, // Responsable Commercial
        UserRoles.responsableTechnique, // Responsable Technique
        UserRoles.responsableIT, // Responsable IT
        UserRoles.chefDeProjet, // Chef de Projet
        UserRoles.technicienST, // Technicien ST
        UserRoles.technicienIT // Technicien IT
      ]).get();

      final allTechnicians = snapshot.docs
          .map((doc) => AppUser(
          uid: doc.id,
          displayName:
          doc.data()['displayName'] as String? ?? 'Utilisateur Inconnu'))
          .toList();
      if (mounted) setState(() => _allTechnicians = allTechnicians);
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _saveSchedule() async {
    // This function is from our previous change (technician is optional)
    if (_scheduledDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Veuillez sélectionner une date.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final techniciansToSave = _selectedTechnicians
          .map((user) => {'uid': user.uid, 'displayName': user.displayName})
          .toList();
      await FirebaseFirestore.instance
          .collection('installations')
          .doc(widget.installationDoc.id)
          .update({
        'installationDate': Timestamp.fromDate(_scheduledDate!),
        'assignedTechnicians':
        techniciansToSave, // This will save an empty list if none are selected
        'status': 'Planifiée',
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Installation planifiée avec succès'),
            backgroundColor: Colors.green));
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
              mainAxisSize:
              MainAxisSize.min, // ✅ FIXED: Removed redundant 'MainAxisSize.'
              children: [
                ListTile(
                  title: Text(tempDate == null
                      ? 'Sélectionner une date'
                      : DateFormat('dd MMMM yyyy', 'fr_FR').format(tempDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: context,
                        initialDate: tempDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030));
                    if (picked != null)
                      setDialogState(() => tempDate = picked);
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
                  title: const Text("Sélectionner Techniciens"),
                  buttonText: const Text("Assigner à (Optionnel)"), // Text updated
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
      final pdfFile = await InstallationPdfService.generateInstallationReport(
          installationData: data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('PDF généré!\n${pdfFile.path}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareViaWhatsApp() async {
    setState(() => _isLoading = true);
    try {
      final data = widget.installationDoc.data() as Map<String, dynamic>;
      final pdfFile = await InstallationPdfService.generateInstallationReport(
          installationData: data);
      final message = InstallationPdfService.generateWhatsAppMessage(data);
      await Share.shareXFiles([XFile(pdfFile.path)], text: message);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareViaEmail() async {
    setState(() => _isLoading = true);
    try {
      final data = widget.installationDoc.data() as Map<String, dynamic>;
      final pdfFile = await InstallationPdfService.generateInstallationReport(
          installationData: data);
      final emailContent = InstallationPdfService.generateEmailContent(data);
      await Share.shareXFiles([XFile(pdfFile.path)],
          subject: emailContent['subject'], text: emailContent['body']);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ --- START: HELPER FUNCTION TO SORT MEDIA ---
  // This helper checks if a URL is a video
  bool _isVideoUrl(String path) {
    final lowercasePath = path.toLowerCase();
    // You can add more video extensions here if needed
    return lowercasePath.endsWith('.mp4') ||
        lowercasePath.endsWith('.mov') ||
        lowercasePath.endsWith('.avi') ||
        lowercasePath.endsWith('.mkv');
  }
  // ✅ --- END: HELPER FUNCTION TO SORT MEDIA ---

  // ✅ NOUVEAU: Helper pour afficher une ligne simple
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
                style:
                TextStyle(color: Colors.grey.shade600, fontSize: 14)),
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

  // ✅ NOUVEAU: Helper pour afficher les questions Oui/Non avec notes
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
        // Display notes regardless of Oui/Non, but styled differently
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

  // ✅ MODIFIÉ: Fonction pour afficher les détails de l'évaluation technique (expansible avec tous les détails)
  List<Widget> _buildTechnicalEvaluation(List<dynamic> evaluations) {
    if (evaluations.isEmpty) return [];

    return evaluations.asMap().entries.map((entry) {
      // ✅ FIX ANTI-CRASH: Cast entry.value safely to Map<String, dynamic>
      Map<String, dynamic> evalData = (entry.value is Map)
          ? Map<String, dynamic>.from(entry.value as Map)
          : {};

      if (evalData.isEmpty)
        return const SizedBox.shrink(); // Skip invalid entries

      List<Widget> details = [
        _buildDetailRow('Type d\'entrée', evalData['entranceType']),
        _buildDetailRow('Type de porte', evalData['doorType']),
        _buildDetailRow(
            'Largeur entrée', '${evalData['entranceWidth'] ?? 'N/A'} m'),
        _buildDetailRow('Longeur entrée',
            '${evalData['entranceLength'] ?? 'N/A'} m'), // ✅ CORRECTED: Used evalData here
        const Divider(height: 1),

        // 1. Alimentation
        _buildBooleanRow(
            'Alimentation disponible', evalData['isPowerAvailable'],
            evalData['powerNotes']),

        // 2. Sol Fini (Simple Boolean)
        _buildBooleanRow('Sol Fini', evalData['isFloorFinalized']),

        // 3. Conduit
        _buildBooleanRow('Conduit disponible', evalData['isConduitAvailable']),

        // 4. Tranchée
        _buildBooleanRow('Autorisé à trancher', evalData['canMakeTrench']),

        // 5. Obstacles
        _buildBooleanRow(
            'Obstacles', evalData['hasObstacles'], evalData['obstacleNotes']),

        // 6. Structures Métalliques
        _buildBooleanRow(
            'Structures métalliques', evalData['hasMetalStructures']),

        // 7. Autres Systèmes
        _buildBooleanRow('Autres systèmes', evalData['hasOtherSystems']),

        // Overall notes
        if (evalData['generalNotes'] != null &&
            (evalData['generalNotes'] as String).isNotEmpty) ...[
          const Divider(height: 1),
          _buildDetailRow('Notes générales', evalData['generalNotes']),
        ],
      ];

      // ✅ MODIFIÉ: Retourne un Card avec ExpansionTile (pour l'expandabilité)
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
            // The list of details forms the content of the expanded area
            Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: details),
          ],
        ),
      );
    }).toList();
  }

  // ✅ MODIFIÉ: Fonction pour afficher les détails de l'évaluation IT (maintenant expansible)
  List<Widget> _buildItEvaluation(List<dynamic> itItems) {
    if (itItems.isEmpty) return [];

    List<Widget> children = [];

    itItems.asMap().entries.forEach((entry) {
      // ✅ FIX ANTI-CRASH: Cast entry.value safely to Map<String, dynamic>
      Map<String, dynamic> itemData = (entry.value is Map)
          ? Map<String, dynamic>.from(entry.value as Map)
          : {};

      if (itemData.isEmpty) return; // Skip invalid entries

      children.add(
        ListTile(
          dense: true,
          leading: Icon(Icons.computer, color: Colors.blue.shade800),
          title: Text(itemData['itemType'] ?? 'Équipement Inconnu',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Marque', itemData['brand']),
              _buildDetailRow('Modèle', itemData['model']),
              if (itemData['osType'] != null)
                _buildDetailRow('OS', itemData['osType']),
              if (itemData['notes'] != null &&
                  (itemData['notes'] as String).isNotEmpty)
                _buildDetailRow('Notes', itemData['notes']),
            ],
          ),
        ),
      );
    });

    // ✅ MODIFIÉ: Retourne un Card avec ExpansionTile (pour l'expandabilité)
    return [
      Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          leading: Icon(Icons.computer_outlined, color: Colors.blue.shade800),
          title: const Text('Évaluation IT',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          children: [
            const Divider(height: 1),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ],
        ),
      )
    ];
  }

  // -----------------------------------------------------------------
  // VVV THIS FUNCTION IS MODIFIED VVV
  // -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final data = widget.installationDoc.data() as Map<String, dynamic>;

    // ✅ CRITICAL FIX (CRASH PREVENTION): Safely convert the evaluation data from Map or null to List.
    // This handles the type mismatch error: Map is not List.
    dynamic rawTechnicalData = data['technicalEvaluation'];
    final List<dynamic> technicalEvaluation = (rawTechnicalData is List)
        ? rawTechnicalData
        : (rawTechnicalData is Map ? [rawTechnicalData] : []);

    dynamic rawItData = data['itEvaluation'];
    final List<dynamic> itEvaluation = (rawItData is List)
        ? rawItData
        : (rawItData is Map ? [rawItData] : []);

    final status = data['status'] ?? 'Inconnu';
    final orderedProducts = data['orderedProducts'] as List? ?? [];

    // --- Media Sorting Logic (Remains unchanged but uses safe list) ---
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
    // --- End Media Sorting Logic ---

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
              // --- MODIFICATION START ---
              // ✅ ADDED: Display the installation date
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
                visualDensity: VisualDensity.compact,
              ),
              // --- MODIFICATION END ---
            ],
          ),

          // This is from our previous change
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

          // ✅ Remplacement de l'ancien affichage simple par les nouvelles fonctions
          ..._buildTechnicalEvaluation(technicalEvaluation),
          const SizedBox(height: 16),

          // ✅ FIX VISIBILITY: Only show IT Evaluation if the service type is NOT Service Technique (or if it's dual service/IT service)
          if (data['serviceType'] != 'Service Technique') ...[
            ..._buildItEvaluation(itEvaluation),
            const SizedBox(height: 16),
          ],

          // ✅ MODIFIED: Pass the new sorted lists to the widget
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
  // -----------------------------------------------------------------
  // ^^^ THIS FUNCTION IS MODIFIED ^^^
  // -----------------------------------------------------------------

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
          // Only wrap content in a Column if there are items, otherwise it can cause issues.
          ...children.isNotEmpty
              ? [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            )
          ]
              : [],
        ],
      ),
    );
  }

  /// Builds a card to display the list of assigned technicians
  Widget _buildTechnicianCard() {
    return _buildInfoCard(
      title: 'Techniciens Assignés',
      icon: Icons.engineering_outlined,
      children: _selectedTechnicians.isEmpty
      // Show this if no technicians are assigned
          ? [
        const ListTile(
          title: Text('Aucun technicien assigné'),
          subtitle: Text('La planification est requise'),
        )
      ]
      // Show the list of technicians
          : _selectedTechnicians
          .map(
            (user) => ListTile(
          title: Text(user.displayName),
        ),
      )
          .toList(),
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
    // This function is from our previous change (Edit button for "Planifiée")
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
      // Button 1: Rédiger le Rapport (for Technicians)
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

        // Button 2: Modifier la Planification (for Managers)
        if (RolePermissions.canScheduleInstallation(userRole)) {
          buttons.add(const SizedBox(height: 12)); // Add space
          buttons.add(
            ElevatedButton.icon(
              onPressed:
              _showSchedulingDialog, // Re-uses the same dialog function
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Modifier la Planification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700, // Different color
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
            label: const Text('Générer PDF'),
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

// ===================================================================
// This is the Media Gallery widget we built before.
// It is UNCHANGED, as it's already built to accept separate lists.
// ===================================================================

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
    // If there are no photos or videos, don't show anything
    if (photoUrls.isEmpty && videoUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    // Reuse the style of _buildInfoCard
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
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

          // Photo Section
          _buildPhotoSection(context),

          // Video Section
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
            height: 100, // Fixed height for the horizontal list
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: photoUrls.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    // Navigate to your existing ImageGalleryPage
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
                        // Show a loading indicator
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                              child: CircularProgressIndicator());
                        },
                        // Show an error icon if loading fails
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
          // Build a vertical list of video links
          Column(
            children: videoUrls.asMap().entries.map((entry) {
              int index = entry.key;
              String url = entry.value;
              return ListTile(
                leading: Icon(Icons.play_circle_outline, color: primaryColor),
                title: Text("Vidéo ${index + 1}"),
                subtitle: Text(
                  _getFileNameFromUrl(url), // Helper to show a clean name
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                onTap: () {
                  // Navigate to your existing VideoPlayerPage
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

  // Helper function to try and get a readable name from the URL
  String _getFileNameFromUrl(String url) {
    try {
      return Uri.decodeFull(url.split('/').last.split('?').first);
    } catch (e) {
      return 'Lien vidéo';
    }
  }
}
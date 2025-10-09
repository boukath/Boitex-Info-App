// lib/screens/administration/project_details_page.dart
// UPDATED: Year-based installation numbering (INST-1/2025, INST-2/2025, etc.)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/technical_evaluation_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/widgets/product_selector_dialog.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';

class ProjectDetailsPage extends StatefulWidget {
  final String projectId;
  final String userRole;

  const ProjectDetailsPage({super.key, required this.projectId, required this.userRole});

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  bool _isActionInProgress = false;
  static const Color primaryColor = Colors.deepPurple;

  Future<void> _uploadDevis() async {
    setState(() { _isActionInProgress = true; });
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);
      if (result == null || result.files.single.path == null) {
        setState(() { _isActionInProgress = false; });
        return;
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final storageRef = FirebaseStorage.instance.ref().child('devis/${widget.projectId}/$fileName');
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
        'devisUrl': downloadUrl,
        'devisFileName': fileName,
        'status': 'Devis Envoyé',
      });
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() { _isActionInProgress = false; });
    }
  }

  void _showApprovalDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Preuve d\'Approbation'),
      content: const Text('Comment le client a-t-il approuvé le devis ?'),
      actions: [
        TextButton(onPressed: () { Navigator.of(ctx).pop(); _confirmApprovalByPhone(); }, child: const Text('Par Téléphone')),
        ElevatedButton(onPressed: () { Navigator.of(ctx).pop(); _uploadBonDeCommande(); }, child: const Text('Bon de Commande')),
      ],
    ));
  }

  Future<void> _confirmApprovalByPhone() async {
    final noteController = TextEditingController();
    final note = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Confirmation par Téléphone'),
      content: TextField(controller: noteController, autofocus: true, decoration: const InputDecoration(labelText: 'Confirmé par (nom)')),
      actions: [
        TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(ctx).pop()),
        ElevatedButton(child: const Text('Confirmer'), onPressed: () => Navigator.of(ctx).pop(noteController.text)),
      ],
    ));

    if (note != null && note.isNotEmpty) {
      setState(() { _isActionInProgress = true; });
      try {
        await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
          'status': 'Finalisation de la Commande',
          'approvalType': 'Téléphone',
          'approvalNotes': note,
        });
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      } finally {
        if(mounted) setState(() { _isActionInProgress = false; });
      }
    }
  }

  Future<void> _uploadBonDeCommande() async {
    setState(() { _isActionInProgress = true; });
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);
      if (result == null || result.files.single.path == null) {
        setState(() { _isActionInProgress = false; });
        return;
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final storageRef = FirebaseStorage.instance.ref().child('bon_de_commande/${widget.projectId}/$fileName');
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({
        'bonDeCommandeUrl': downloadUrl,
        'bonDeCommandeFileName': fileName,
        'status': 'Finalisation de la Commande',
        'approvalType': 'Fichier',
      });
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() { _isActionInProgress = false; });
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

  // ═══════════════════════════════════════════════════════════════
  // ✅ UPDATED: Year-based installation code generation
  // ═══════════════════════════════════════════════════════════════
  Future<void> _createInstallationTask(Map<String, dynamic> projectData) async {
    setState(() => _isActionInProgress = true);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Get current year
        final currentYear = DateTime.now().year;

        // Use year-specific counter: installation_counter_2025
        final counterRef = FirebaseFirestore.instance
            .collection('counters')
            .doc('installation_counter_$currentYear');

        final counterDoc = await transaction.get(counterRef);

        // Get count for this year (starts at 0 if doesn't exist)
        final newCount = (counterDoc.data()?['count'] as int? ?? 0) + 1;

        // Generate code with year: INST-1/2025
        final installationCode = 'INST-$newCount/$currentYear';

        final newInstallationRef = FirebaseFirestore.instance.collection('installations').doc();

        transaction.set(newInstallationRef, {
          'installationCode': installationCode, // NEW: Installation code with year
          'projectId': widget.projectId,
          'clientId': projectData['clientId'],
          'clientName': projectData['clientName'],
          'clientPhone': projectData['clientPhone'],
          'storeId': projectData['storeId'],
          'storeName': projectData['storeName'],
          'initialRequest': projectData['initialRequest'],
          'technicalEvaluation': projectData['technical_evaluation'],
          'orderedProducts': projectData['orderedProducts'],
          'serviceType': projectData['serviceType'], // Include service type
          'status': 'À Planifier',
          'createdAt': Timestamp.now(),
        });

        // Update year-specific counter
        transaction.set(
            counterRef,
            {'count': newCount},
            SetOptions(merge: true)
        );

        // Update project status
        final projectRef = FirebaseFirestore.instance.collection('projects').doc(widget.projectId);
        transaction.update(projectRef, {'status': 'Transféré à l\'Installation'});

        // Navigate after transaction completes
        if (mounted) {
          final newInstallationDoc = await newInstallationRef.get();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => InstallationDetailsPage(
                  installationDoc: newInstallationDoc,
                  userRole: widget.userRole
              ),
            ),
          );
        }
      });
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if(mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _openUrl(String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du Projet'),
        backgroundColor: primaryColor,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final projectData = snapshot.data!.data() as Map<String, dynamic>;
          final createdAt = (projectData['createdAt'] as Timestamp).toDate();
          final technicalEvaluation = projectData['technical_evaluation'] as List<dynamic>?;
          final status = projectData['status'] ?? 'Inconnu';
          final orderedProducts = projectData['orderedProducts'] as List<dynamic>?;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildStatusHeader(status),
              const SizedBox(height: 16),
              _buildInfoCard(
                title: 'Informations Client',
                icon: Icons.person_outline,
                children: [
                  ListTile(title: Text(projectData['clientName'] ?? 'N/A'), subtitle: const Text('Nom du Client')),
                  ListTile(title: Text(projectData['clientPhone'] ?? 'N/A'), subtitle: const Text('Téléphone')),
                  ListTile(title: Text(projectData['createdByName'] ?? 'N/A'), subtitle: const Text('Créé par')),
                  ListTile(title: Text(DateFormat('dd MMMM yyyy', 'fr_FR').format(createdAt)), subtitle: const Text('Date de création')),
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
              if (technicalEvaluation != null && technicalEvaluation.isNotEmpty)
                ...technicalEvaluation.asMap().entries.map((entry) {
                  int idx = entry.key;
                  Map<String, dynamic> evalData = Map<String, dynamic>.from(entry.value);
                  return _buildInfoCard(
                    title: 'Évaluation Technique - Entrée #${idx + 1}',
                    icon: Icons.square_foot_outlined,
                    children: [
                      ListTile(title: Text(evalData['entranceType'] ?? 'N/A'), subtitle: const Text('Type d\'entrée')),
                      ListTile(title: Text(evalData['doorType'] ?? 'N/A'), subtitle: const Text('Type de porte')),
                      ListTile(title: Text('${evalData['entranceLength'] ?? 'N/A'} m'), subtitle: const Text('Longeur entrée')),
                      ListTile(title: Text('${evalData['entranceWidth'] ?? 'N/A'} m'), subtitle: const Text('Largeur entrée')),
                      if(evalData['doorLength'] != null) ListTile(title: Text('${evalData['doorLength']} m'), subtitle: const Text('Longeur porte')),
                      if(evalData['doorWidth'] != null) ListTile(title: Text('${evalData['doorWidth']} m'), subtitle: const Text('Largeur porte')),
                      ListTile(title: Text((evalData['hasPower'] ?? false) ? 'Oui' : 'Non'), subtitle: const Text('Prise 220V')),
                      ListTile(title: Text((evalData['hasConduit'] ?? false) ? 'Oui' : 'Non'), subtitle: const Text('Gaine au sol')),
                    ],
                  );
                }),
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
              if (projectData['devisUrl'] != null || projectData['bonDeCommandeUrl'] != null || projectData['approvalNotes'] != null)
                _buildInfoCard(
                  title: 'Documents et Approbations',
                  icon: Icons.attach_file,
                  children: [
                    if (projectData['devisUrl'] != null)
                      ListTile(
                        leading: const Icon(Icons.request_quote_outlined, color: Colors.red),
                        title: Text(projectData['devisFileName'] ?? 'Devis.pdf'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openUrl(projectData['devisUrl']),
                      ),
                    if (projectData['bonDeCommandeUrl'] != null)
                      ListTile(
                        leading: const Icon(Icons.fact_check_outlined, color: Colors.green),
                        title: Text(projectData['bonDeCommandeFileName'] ?? 'Bon de commande.pdf'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openUrl(projectData['bonDeCommandeUrl']),
                      ),
                    if (projectData['approvalNotes'] != null)
                      ListTile(
                        leading: const Icon(Icons.phone_in_talk_outlined, color: Colors.green),
                        title: const Text('Approbation par Téléphone'),
                        subtitle: Text('Confirmé par: ${projectData['approvalNotes']}'),
                      ),
                  ],
                ),
              _buildInfoCard(
                title: 'Actions',
                icon: Icons.task_alt,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildActionButtons(status, widget.userRole, projectData),
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
      case 'Nouvelle Demande': icon = Icons.new_releases_outlined; color = Colors.blue; break;
      case 'Évaluation Technique Terminé': icon = Icons.rule_outlined; color = Colors.orange; break;
      case 'Devis Envoyé': icon = Icons.send_outlined; color = Colors.purple; break;
      case 'Finalisation de la Commande': icon = Icons.playlist_add_check_outlined; color = Colors.teal; break;
      case 'À Planifier': icon = Icons.event_available_outlined; color = Colors.blue; break;
      case 'Transféré à l\'Installation': icon = Icons.check_circle_outline; color = Colors.green; break;
      default: icon = Icons.help_outline; color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: color.withOpacity(0.3))
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

  Widget _buildActionButtons(String status, String userRole, Map<String, dynamic> projectData) {
    if (_isActionInProgress) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Widget> buttons = [];

    if (status == 'Nouvelle Demande' && RolePermissions.canPerformTechnicalEvaluation(userRole)) {
      buttons.add(SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => TechnicalEvaluationPage(projectId: widget.projectId))), icon: const Icon(Icons.rule), label: const Text('Ajouter l\'Évaluation Technique'))));
    }

    if (status == 'Évaluation Technique Terminé' && RolePermissions.canUploadDevis(userRole)) {
      buttons.add(SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _uploadDevis, icon: const Icon(Icons.upload_file_outlined), label: const Text('Devis'))));
    }

    if (status == 'Devis Envoyé' && RolePermissions.canUploadDevis(userRole)) {
      buttons.add(SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _showApprovalDialog, icon: const Icon(Icons.check), label: const Text('Confirmer l\'Approbation Client'))));
    }

    if (status == 'Finalisation de la Commande' && RolePermissions.canUploadDevis(userRole)) {
      buttons.add(SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () => _showProductFinalizationDialog(projectData['orderedProducts'] ?? []),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Définir les Produits Commandés')
      )));
    }

    if (status == 'À Planifier' && RolePermissions.canScheduleInstallation(userRole)) {
      buttons.add(SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: () => _createInstallationTask(projectData),
        icon: const Icon(Icons.send_to_mobile),
        label: const Text('Créer la Tâche d\'Installation'),
        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
      )));
    }

    if(buttons.isEmpty) {
      return const Center(child: Text('Aucune action disponible pour ce statut.'));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: buttons);
  }
}

// OrderFinalizationDialog remains the same...
class _OrderFinalizationDialog extends StatefulWidget {
  final String projectId;
  final List<dynamic> existingItems;

  const _OrderFinalizationDialog({required this.projectId, required this.existingItems});

  @override
  State<_OrderFinalizationDialog> createState() => _OrderFinalizationDialogState();
}

class _OrderFinalizationDialogState extends State<_OrderFinalizationDialog> {
  late List<ProductSelection> _selectedProducts;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedProducts = widget.existingItems.map((item) => ProductSelection(
      productId: item['productId'],
      productName: item['productName'],
      quantity: item['quantity'],
    )).toList();
  }

  Future<void> _finalizeOrder() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        Map<String, DocumentSnapshot> productSnaps = {};
        for (var product in _selectedProducts) {
          final productRef = FirebaseFirestore.instance.collection('produits').doc(product.productId);
          productSnaps[product.productId] = await transaction.get(productRef);
        }

        for (var product in _selectedProducts) {
          final snap = productSnaps[product.productId]!;
          final currentStock = (snap.data() as Map<String, dynamic>?)?['quantiteEnStock'] ?? 0;
          if (currentStock < product.quantity) {
            throw Exception('Stock insuffisant pour ${product.productName}');
          }
          transaction.update(snap.reference, {'quantiteEnStock': currentStock - product.quantity});
        }

        final projectRef = FirebaseFirestore.instance.collection('projects').doc(widget.projectId);
        transaction.update(projectRef, {
          'orderedProducts': _selectedProducts.map((p) => {'productId': p.productId, 'productName': p.productName, 'quantity': p.quantity}).toList(),
          'status': 'À Planifier',
        });
      });

      if(mounted) Navigator.of(context).pop();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isSaving = false);
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
                    onLongPress: () => setState(() => _selectedProducts.removeAt(index)),
                  );
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                showDialog(context: context, builder: (ctx) => ProductSelectorDialog(
                  onProductSelected: (product) => setState(() {
                    if (!_selectedProducts.any((p) => p.productId == product.productId)) {
                      _selectedProducts.add(product);
                    }
                  }),
                ));
              },
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un Produit'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
            onPressed: _isSaving ? null : _finalizeOrder,
            child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Enregistrer')
        ),
      ],
    );
  }
}

// lib/screens/administration/replacement_request_details_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:boitex_info_app/screens/service_technique/confirm_replacement_page.dart';

class ReplacementRequestDetailsPage extends StatefulWidget {
  final String requestId;
  const ReplacementRequestDetailsPage({super.key, required this.requestId});

  @override
  State<ReplacementRequestDetailsPage> createState() => _ReplacementRequestDetailsPageState();
}

class _ReplacementRequestDetailsPageState extends State<ReplacementRequestDetailsPage> {
  Map<String, dynamic>? _requestData;
  bool _isLoading = true;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _fetchRequestDetails();
  }

  Future<void> _fetchRequestDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('replacementRequests')
          .doc(widget.requestId)
          .get();
      if (mounted) {
        setState(() {
          _requestData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ CORRECTED: Add stock check logic AFTER approval
  Future<void> _handleApproval({required String method, File? poFile, String? note}) async {
    setState(() => _isActionInProgress = true);

    try {
      final productName = _requestData!['productName'];
      if (productName == null) throw Exception("Nom du produit manquant.");

      // ✅ Step 1: Check stock and determine next status
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Get product reference
        final productQuery = await FirebaseFirestore.instance
            .collection('produits')
            .where('nom', isEqualTo: productName)
            .limit(1)
            .get();

        if (productQuery.docs.isEmpty) {
          throw Exception("Produit introuvable dans le catalogue.");
        }

        final productRef = productQuery.docs.first.reference;
        final productSnap = await transaction.get(productRef);
        final currentStock = (productSnap.data() as Map<String, dynamic>?)?['quantiteEnStock'] ?? 0;

        String newStatus;
        String logMessage;
        Map<String, dynamic> updates = {'approvalMethod': method};

        // Handle approval proof
        if (method == 'Bon de commande' && poFile != null) {
          final ref = FirebaseStorage.instance.ref().child(
              'replacement_pos/${widget.requestId}/po_${DateTime.now().millisecondsSinceEpoch}');
          await ref.putFile(poFile);
          final proofUrl = await ref.getDownloadURL();
          updates['approvalProofUrl'] = proofUrl;
        } else if (note != null && note.isNotEmpty) {
          updates['approvalNotes'] = note;
        }

        // ✅ Step 2: Check stock and set appropriate status
        if (currentStock > 0) {
          // Stock available: Decrement and mark as ready
          newStatus = 'Approuvé - Produit en stock';
          logMessage = "Demande de remplacement ${_requestData!['replacementRequestCode']} approuvée. "
              "Stock disponible ($currentStock unités). Stock décrémenté à ${currentStock - 1}.";

          // Decrement stock
          transaction.update(productRef, {'quantiteEnStock': currentStock - 1});
        } else {
          // Stock unavailable: Create backorder (negative stock)
          newStatus = 'Approuvé - En attente de commande';
          logMessage = "Demande de remplacement ${_requestData!['replacementRequestCode']} approuvée. "
              "Stock indisponible. Backorder créé (stock: ${currentStock - 1}).";

          // Create backorder by going negative
          transaction.update(productRef, {'quantiteEnStock': currentStock - 1});
        }

        updates['requestStatus'] = newStatus;
        updates['approvedAt'] = FieldValue.serverTimestamp();
        updates['updatedAt'] = FieldValue.serverTimestamp();

        final requestRef = FirebaseFirestore.instance
            .collection('replacementRequests')
            .doc(widget.requestId);
        transaction.update(requestRef, updates);
      });

      // ✅ FIXED: Correct parameters
      await ActivityLogger.logActivity(
        message: "Demande de remplacement ${_requestData!['replacementRequestCode']} approuvée.",
        category: 'Remplacements',
        replacementRequestId: widget.requestId,
        clientName: _requestData!['clientName'],
      );

      await _fetchRequestDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de remplacement approuvée avec succès!'),
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
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _showApprovalMethodDialog() async {
    final method = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Méthode d\'approbation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Bon de commande'),
              leading: const Icon(Icons.description),
              onTap: () => Navigator.of(ctx).pop('Bon de commande'),
            ),
            ListTile(
              title: const Text('Appel téléphonique'),
              leading: const Icon(Icons.phone),
              onTap: () => Navigator.of(ctx).pop('Appel téléphonique'),
            ),
            ListTile(
              title: const Text('Email'),
              leading: const Icon(Icons.email),
              onTap: () => Navigator.of(ctx).pop('Email'),
            ),
            ListTile(
              title: const Text('Visite en personne'),
              leading: const Icon(Icons.person),
              onTap: () => Navigator.of(ctx).pop('Visite en personne'),
            ),
          ],
        ),
      ),
    );

    if (method == null) return;

    if (method == 'Bon de commande') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null) {
        final file = File(result.files.single.path!);
        await _handleApproval(method: method, poFile: file);
      }
    } else {
      final noteController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Notes - $method'),
          content: TextField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'Détails de l\'approbation',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _handleApproval(method: method, note: noteController.text);
      }
    }
  }

  Future<void> _releaseToTechnician() async {
    setState(() => _isActionInProgress = true);
    try {
      await FirebaseFirestore.instance
          .collection('replacementRequests')
          .doc(widget.requestId)
          .update({
        'requestStatus': 'Prêt pour Technicien',
        'releasedToTechnicianAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ FIXED: Correct parameters
      await ActivityLogger.logActivity(
        message: "Produit de remplacement ${_requestData!['replacementRequestCode']} libéré au technicien.",
        category: 'Remplacements',
        replacementRequestId: widget.requestId,
        clientName: _requestData!['clientName'],
      );

      await _fetchRequestDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produit libéré au technicien!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _confirmReplacement() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmReplacementPage(requestId: widget.requestId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Détails de la Demande'),
          backgroundColor: Colors.orange,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_requestData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Détails de la Demande'),
          backgroundColor: Colors.orange,
        ),
        body: const Center(child: Text('Demande introuvable')),
      );
    }

    final status = _requestData!['requestStatus'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_requestData!['replacementRequestCode'] ?? 'Demande'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusBadge(status),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'Informations du Ticket SAV',
              icon: Icons.build_circle_outlined,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Code SAV'),
                    subtitle: Text(_requestData!['savCode'] ?? 'N/A'),
                  ),
                  ListTile(
                    title: const Text('Diagnostic Technicien'),
                    subtitle: Text(_requestData!['technicianDiagnosis'] ?? 'N/A'),
                  ),
                ],
              ),
            ),
            _buildInfoCard(
              title: 'Informations Client',
              icon: Icons.person_outline,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Client'),
                    subtitle: Text(_requestData!['clientName'] ?? 'N/A'),
                  ),
                  ListTile(
                    title: const Text('Magasin'),
                    subtitle: Text(_requestData!['storeName'] ?? 'N/A'),
                  ),
                ],
              ),
            ),
            _buildInfoCard(
              title: 'Produit à Remplacer',
              icon: Icons.inventory_outlined,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Produit'),
                    subtitle: Text(_requestData!['productName'] ?? 'N/A'),
                  ),
                  ListTile(
                    title: const Text('Numéro de Série'),
                    subtitle: Text(_requestData!['serialNumber'] ?? 'N/A'),
                  ),
                ],
              ),
            ),
            if (_requestData!['approvalMethod'] != null)
              _buildInfoCard(
                title: 'Détails d\'Approbation',
                icon: Icons.check_circle_outline,
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Méthode'),
                      subtitle: Text(_requestData!['approvalMethod']),
                    ),
                    if (_requestData!['approvalNotes'] != null)
                      ListTile(
                        title: const Text('Notes'),
                        subtitle: Text(_requestData!['approvalNotes']),
                      ),
                    if (_requestData!['approvalProofUrl'] != null)
                      ListTile(
                        title: const Text('Preuve'),
                        subtitle: InkWell(
                          onTap: () => launchUrl(Uri.parse(_requestData!['approvalProofUrl'])),
                          child: const Text(
                            'Voir le document',
                            style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (_isActionInProgress)
              const Center(child: CircularProgressIndicator())
            else
              _buildActionButtons(status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    IconData icon;

    switch (status) {
      case "En attente d'action":
        bgColor = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
      case 'Approuvé - Produit en stock':
        bgColor = Colors.blue;
        icon = Icons.check_circle;
        break;
      case 'Approuvé - En attente de commande':
        bgColor = Colors.purple;
        icon = Icons.shopping_cart;
        break;
      case 'Prêt pour Technicien':
        bgColor = Colors.green;
        icon = Icons.build;
        break;
      case 'Remplacement Effectué':
        bgColor = Colors.grey;
        icon = Icons.done_all;
        break;
      default:
        bgColor = Colors.grey;
        icon = Icons.info;
    }

    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                status,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(icon, color: Colors.orange),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  Widget _buildActionButtons(String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status == "En attente d'action")
          ElevatedButton.icon(
            onPressed: _showApprovalMethodDialog,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Approuver le Remplacement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
          ),
        if (status == 'Approuvé - Produit en stock')
          ElevatedButton.icon(
            onPressed: _releaseToTechnician,
            icon: const Icon(Icons.send),
            label: const Text('Libérer au Technicien'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
          ),
        if (status == 'Prêt pour Technicien')
          ElevatedButton.icon(
            onPressed: _confirmReplacement,
            icon: const Icon(Icons.done_all),
            label: const Text('Confirmer le Remplacement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
          ),
        if (status == 'Approuvé - En attente de commande')
          const Card(
            color: Colors.purple,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.shopping_cart, color: Colors.white, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'En attente de réapprovisionnement',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Le produit sera automatiquement disponible une fois le stock reçu.',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        if (status == 'Remplacement Effectué')
          const Card(
            color: Colors.grey,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.done_all, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Remplacement terminé',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

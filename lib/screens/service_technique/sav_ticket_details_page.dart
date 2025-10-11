// lib/screens/service_technique/sav_ticket_details_page.dart
// ✅ UPDATED: DR codes now use format DR-{COUNTER}/{YEAR} (e.g., DR-1/2025)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class SavTicketDetailsPage extends StatefulWidget {
  final SavTicket ticket;
  const SavTicketDetailsPage({super.key, required this.ticket});

  @override
  State<SavTicketDetailsPage> createState() => _SavTicketDetailsPageState();
}

class _SavTicketDetailsPageState extends State<SavTicketDetailsPage> {
  late SavTicket _currentTicket;
  late final TextEditingController _reportController;
  bool _isUpdating = false;
  Map<String, int> _stockStatus = {};

  @override
  void initState() {
    super.initState();
    _currentTicket = widget.ticket;
    _reportController = TextEditingController(text: _currentTicket.technicianReport);
    if (_currentTicket.brokenParts.isNotEmpty) {
      _checkStockForParts(_currentTicket.brokenParts);
    }
  }

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _updateTicketStatus(String newStatus, {String? newReport}) async {
    setState(() { _isUpdating = true; });
    try {
      if (newStatus == 'Terminé') {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final counterRef = FirebaseFirestore.instance.collection('counters').doc('reparation_counter');
          final counterSnap = await transaction.get(counterRef);
          final currentCount = (counterSnap.data()?['count'] as int?) ?? 0;
          final nextCount = currentCount + 1;
          final newReparationCode = 'RP-$nextCount';
          final ticketRef = FirebaseFirestore.instance.collection('sav_tickets').doc(_currentTicket.id);
          transaction.update(ticketRef, {
            'status': newStatus,
            'technicianReport': newReport ?? _reportController.text,
            'reparationCode': newReparationCode,
            'repairedAt': FieldValue.serverTimestamp(),
          });
          transaction.set(counterRef, {'count': nextCount}, SetOptions(merge: true));
        });
      } else {
        final docRef = FirebaseFirestore.instance.collection('sav_tickets').doc(_currentTicket.id);
        await docRef.update({
          'status': newStatus,
          'technicianReport': newReport ?? _reportController.text,
        });
      }
      await _refreshTicketData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() { _isUpdating = false; });
    }
  }

  Future<void> _showPartSelectorDialog() async {
    final List<DocumentSnapshot>? results = await showDialog(
      context: context,
      builder: (ctx) => _PartSelectorDialog(
        initialSelectedParts: _currentTicket.brokenParts,
      ),
    );
    if (results != null) {
      final List<BrokenPart> previouslyRequestedParts = _currentTicket.brokenParts
          .where((p) => p.status == 'Requested' && !results.any((res) => res.id == p.productId))
          .toList();
      final newBrokenParts = results.map((doc) {
        return BrokenPart(productId: doc.id, productName: doc['nom'], status: 'Identified');
      }).toList();
      final finalPartsList = [...newBrokenParts, ...previouslyRequestedParts];
      await FirebaseFirestore.instance.collection('sav_tickets').doc(_currentTicket.id).update({
        'brokenParts': finalPartsList.map((p) => p.toJson()).toList(),
      });
      await _refreshTicketData();
      _checkStockForParts(finalPartsList);
    }
  }

  Future<void> _checkStockForParts(List<BrokenPart> parts) async {
    for (final part in parts) {
      if (_stockStatus[part.productId] == null) {
        final doc = await FirebaseFirestore.instance.collection('produits').doc(part.productId).get();
        final stock = doc.data()?['quantiteEnStock'] as int? ?? 0;
        if (mounted) {
          setState(() {
            _stockStatus[part.productId] = stock;
          });
        }
      }
    }
  }

  Future<void> _requestPart(BrokenPart partToRequest) async {
    final updatedParts = _currentTicket.brokenParts.map((p) {
      if (p.productId == partToRequest.productId) {
        return BrokenPart(productId: p.productId, productName: p.productName, status: 'Requested');
      }
      return p;
    }).toList();
    await FirebaseFirestore.instance.collection('sav_tickets').doc(_currentTicket.id).update({
      'brokenParts': updatedParts.map((p) => p.toJson()).toList(),
    });
    await _refreshTicketData();
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ UPDATED: Year-based DR code generation (DR-1/2025)
  // ═══════════════════════════════════════════════════════════════
  // Replace the entire _declareUnrepairable function with this
  Future<void> _declareUnrepairable() async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déclarer Irréparable'),
        content: const Text(
          'Déclarer cet article comme irréparable?\n\n'
              'Une demande de remplacement sera créée et envoyée à l\'équipe commerciale pour approbation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final currentYear = DateTime.now().year;
        final counterRef = FirebaseFirestore.instance
            .collection('counters')
            .doc('replacementRequests_$currentYear');

        final counterSnap = await transaction.get(counterRef);
        final currentCount = (counterSnap.data()?['count'] as int?) ?? 0;
        final nextCount = currentCount + 1;
        final newRequestCode = 'DR-$nextCount/$currentYear';

        final newRequestRef = FirebaseFirestore.instance.collection('replacementRequests').doc();
        transaction.set(newRequestRef, {
          'replacementRequestCode': newRequestCode,
          // ✅ ADDED: This line copies the serviceType from the SAV ticket
          'serviceType': _currentTicket.serviceType,
          'savTicketId': _currentTicket.id,
          'savCode': _currentTicket.savCode,
          'clientId': _currentTicket.clientId,
          'clientName': _currentTicket.clientName,
          'storeId': _currentTicket.storeId,
          'storeName': _currentTicket.storeName,
          'productName': _currentTicket.productName,
          'serialNumber': _currentTicket.serialNumber,
          'technicianDiagnosis': _reportController.text.isEmpty
              ? "Article déclaré irréparable. Remplacement demandé."
              : _reportController.text,
          'requestStatus': "En attente d'action",
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdBy': 'Service Technique',
        });
        transaction.set(counterRef, {'count': nextCount}, SetOptions(merge: true));
        final ticketRef = FirebaseFirestore.instance.collection('sav_tickets').doc(_currentTicket.id);
        transaction.update(ticketRef, {
          'status': 'Irréparable - Remplacement Demandé',
          'replacementRequestId': newRequestRef.id,
          'replacementRequestCode': newRequestCode,
          'technicianReport': _reportController.text.isEmpty
              ? "Article déclaré irréparable. Remplacement demandé."
              : _reportController.text,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      await ActivityLogger.logActivity(
        message: 'Ticket SAV ${_currentTicket.savCode}: Déclaré irréparable. '
            'Demande de remplacement créée et en attente d\'approbation commerciale.',
        category: 'SAV',
        clientName: _currentTicket.clientName,
      );
      await _refreshTicketData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demande de remplacement créée avec succès!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _refreshTicketData() async {
    final updatedDoc = await FirebaseFirestore.instance.collection('sav_tickets').doc(_currentTicket.id).get();
    if(mounted) {
      setState(() {
        _currentTicket = SavTicket.fromFirestore(updatedDoc as DocumentSnapshot<Map<String, dynamic>>);
        _reportController.text = _currentTicket.technicianReport ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTicket.savCode),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStatusTracker(_currentTicket.status),
            const SizedBox(height: 24),
            _buildInfoCard(
              title: 'Détails du Ticket',
              icon: Icons.article_outlined,
              child: _buildTicketDetailsContent(),
            ),
            _buildInfoCard(
              title: 'Atelier du Technicien',
              icon: Icons.construction_outlined,
              child: _buildTechnicianWorkbench(),
            ),
            _buildInfoCard(
              title: 'Problème Signalé',
              icon: Icons.report_problem_outlined,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_currentTicket.problemDescription),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicianWorkbench() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _reportController,
            decoration: const InputDecoration(
              labelText: 'Diagnostic et notes de réparation',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          const Text('Pièces Défectueuses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (_currentTicket.brokenParts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Aucune pièce identifiée.', style: TextStyle(color: Colors.grey)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentTicket.brokenParts.length,
              itemBuilder: (context, index) {
                final part = _currentTicket.brokenParts[index];
                final stockCount = _stockStatus[part.productId];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(part.productName),
                  trailing: _buildStockStatusBadge(stockCount, part),
                );
              },
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showPartSelectorDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Identifier les Pièces'),
            ),
          ),
          const Divider(height: 32),
          if (_isUpdating)
            const Center(child: CircularProgressIndicator())
          else
            _buildActionButtonsForStatus(_currentTicket.status),
        ],
      ),
    );
  }

  Widget _buildStockStatusBadge(int? stockCount, BrokenPart part) {
    if (stockCount == null) return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    if (part.status == 'Requested') {
      return const Chip(label: Text('Demandé'), backgroundColor: Colors.blue, labelStyle: TextStyle(color: Colors.white));
    }
    if (stockCount > 0) {
      return Chip(label: Text('En Stock ($stockCount)'), backgroundColor: Colors.green, labelStyle: const TextStyle(color: Colors.white));
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Chip(label: Text('Hors Stock'), backgroundColor: Colors.red, labelStyle: TextStyle(color: Colors.white)),
          const SizedBox(width: 8),
          ElevatedButton(child: const Text('Demander'), onPressed: () => _requestPart(part)),
        ],
      );
    }
  }

  Widget _buildActionButtonsForStatus(String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status == 'Nouveau')
          ElevatedButton.icon(onPressed: () => _updateTicketStatus('En Diagnostic'), icon: const Icon(Icons.science_outlined), label: const Text('Commencer le Diagnostic')),
        if (status == 'En Diagnostic' || status == 'En Réparation')
          ElevatedButton.icon(onPressed: () => _updateTicketStatus('Terminé'), icon: const Icon(Icons.check_circle_outline), label: const Text('Marquer comme Réparé'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)),
        if (status == 'Terminé')
          ElevatedButton.icon(onPressed: () => _updateTicketStatus('Retourné'), icon: const Icon(Icons.storefront_outlined), label: const Text('Retourner au Client'), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white)),
        if (status.startsWith('Irréparable'))
          Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(status, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))),
        if (status == 'Retourné')
          const Center(child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Ce ticket est clôturé.', style: TextStyle(color: Colors.grey)),
          )),
        const SizedBox(height: 10),
        if (status != 'Terminé' && status != 'Retourné' && !status.startsWith('Irréparable'))
          OutlinedButton.icon(
            onPressed: _declareUnrepairable,
            icon: const Icon(Icons.do_not_disturb_on_outlined),
            label: const Text('Déclarer Irréparable'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
          ),
      ],
    );
  }

  Widget _buildStatusTracker(String currentStatus) {
    final statuses = ['Nouveau', 'En Diagnostic', 'En Réparation', 'Terminé', 'Retourné'];
    int currentIndex = statuses.indexOf(currentStatus);
    if(currentStatus.startsWith('Irréparable')) {
      currentIndex = 2;
    }
    if (currentIndex == -1) currentIndex = 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(statuses.length, (index) {
            final bool isActive = index <= currentIndex;
            return _buildStatusStep(
              title: statuses[index],
              icon: _getStatusIcon(statuses[index]),
              isActive: isActive,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStatusStep({required String title, required IconData icon, required bool isActive}) {
    final color = isActive ? Colors.orange : Colors.grey;
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(color: color, fontSize: 10)),
      ],
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
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  Widget _buildTicketDetailsContent() {
    return Column(
      children: [
        ListTile(title: const Text('Client'), subtitle: Text(_currentTicket.clientName)),
        ListTile(title: const Text('Magasin'), subtitle: Text(_currentTicket.storeName ?? 'N/A')),
        ListTile(title: const Text('Produit'), subtitle: Text(_currentTicket.productName)),
        ListTile(title: const Text('Numéro de Série'), subtitle: Text(_currentTicket.serialNumber)),
        ListTile(
          title: const Text('Date de Récupération'),
          subtitle: Text(DateFormat('dd MMMM yyyy', 'fr_FR').format(_currentTicket.pickupDate)),
        ),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Nouveau': return Icons.inventory_outlined;
      case 'En Diagnostic': return Icons.science_outlined;
      case 'En Réparation': return Icons.build_circle_outlined;
      case 'Terminé': return Icons.check_circle_outline;
      case 'Retourné': return Icons.storefront_outlined;
      default: return Icons.help_outline;
    }
  }
}

class _PartSelectorDialog extends StatefulWidget {
  final List<BrokenPart> initialSelectedParts;
  const _PartSelectorDialog({required this.initialSelectedParts});

  @override
  State<_PartSelectorDialog> createState() => _PartSelectorDialogState();
}

class _PartSelectorDialogState extends State<_PartSelectorDialog> {
  List<String> _categories = [];
  List<DocumentSnapshot> _productsForCategory = [];
  bool _isLoadingCategories = true;
  bool _isLoadingProducts = false;
  String? _selectedCategory;
  List<DocumentSnapshot> _selectedParts = [];

  @override
  void initState() {
    super.initState();
    _fetchProductCategories();
  }

  Future<void> _fetchProductCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('produits').get();
      final categories = snapshot.docs.map((doc) => doc.data()['categorie'] as String?).where((c) => c != null && c.isNotEmpty).toSet().toList();
      categories.sort();
      if (mounted) setState(() { _categories = categories.cast<String>(); _isLoadingCategories = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingCategories = false; });
    }
  }

  Future<void> _fetchProductsForCategory(String category) async {
    setState(() { _isLoadingProducts = true; _productsForCategory = []; });
    try {
      final snapshot = await FirebaseFirestore.instance.collection('produits').where('categorie', isEqualTo: category).orderBy('nom').get();
      if (mounted) setState(() { _productsForCategory = snapshot.docs; _isLoadingProducts = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingProducts = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sélectionner les pièces'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                  _fetchProductsForCategory(value);
                }
              },
              decoration: InputDecoration(
                labelText: 'Catégorie',
                border: const OutlineInputBorder(),
                prefixIcon: _isLoadingCategories ? const CircularProgressIndicator() : null,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator())
                  : _productsForCategory.isEmpty
                  ? const Center(child: Text('Sélectionnez une catégorie.'))
                  : ListView.builder(
                itemCount: _productsForCategory.length,
                itemBuilder: (context, index) {
                  final product = _productsForCategory[index];
                  final isSelected = _selectedParts.any((p) => p.id == product.id);
                  return CheckboxListTile(
                    title: Text(product['nom']),
                    value: isSelected,
                    onChanged: (bool? selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedParts.add(product);
                        } else {
                          _selectedParts.removeWhere((p) => p.id == product.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(child: const Text('ANNULER'), onPressed: () => Navigator.of(context).pop()),
        ElevatedButton(child: const Text('CONFIRMER'), onPressed: () => Navigator.of(context).pop(_selectedParts)),
      ],
    );
  }
}

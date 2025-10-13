// lib/screens/service_technique/sav_ticket_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:boitex_info_app/screens/service_technique/finalize_sav_return_page.dart';

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

  final List<String> _statusOptions = [
    'Nouveau',
    'En Diagnostic',
    'En Réparation',
    'Terminé',
    'Irréparable - Remplacement Demandé',
  ];

  @override
  void initState() {
    super.initState();
    _currentTicket = widget.ticket;
    _reportController =
        TextEditingController(text: _currentTicket.technicianReport ?? '');

    FirebaseFirestore.instance
        .collection('sav_tickets')
        .doc(widget.ticket.id)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          _currentTicket = SavTicket.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>);
          if (_reportController.text != (_currentTicket.technicianReport ?? '')) {
            _reportController.text = _currentTicket.technicianReport ?? '';
          }
        });
      }
    });

    if (_currentTicket.brokenParts.isNotEmpty) {
      _checkStockForParts(_currentTicket.brokenParts);
    }
  }

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _checkStockForParts(List<BrokenPart> parts) async {
    final tempStatus = <String, int>{};
    for (var part in parts) {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(part.productId)
          .get();
      if (productDoc.exists) {
        tempStatus[part.productId] =
            (productDoc.data()?['stock'] as int?) ?? 0;
      }
    }
    if (mounted) {
      setState(() {
        _stockStatus = tempStatus;
      });
    }
  }

  Future<void> _updateTicket(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance
          .collection('sav_tickets')
          .doc(_currentTicket.id)
          .update({
        'status': newStatus,
        'technicianReport': _reportController.text,
        'brokenParts':
        _currentTicket.brokenParts.map((p) => p.toJson()).toList(),
      });

      // ✅ FIXED: Corrected the parameters for ActivityLogger
      await ActivityLogger.logActivity(
        message:
        "Le statut du ticket SAV ${_currentTicket.savCode} a été mis à jour à '$newStatus'.",
        interventionId: _currentTicket.id,
        category: 'SAV',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ticket mis à jour avec succès.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _showAddPartsDialog() async {
    final selectedProducts = await showDialog<List<DocumentSnapshot>>(
      context: context,
      builder: (context) => _AddPartsDialog(
          initialSelected:
          _currentTicket.brokenParts.map((p) => p.productId).toList()),
    );

    if (selectedProducts != null) {
      final newParts = selectedProducts.map((doc) {
        return BrokenPart(
          productId: doc.id,
          productName: doc['nom'] as String,
          status: 'À Remplacer',
        );
      }).toList();

      setState(() {
        _currentTicket = SavTicket(
          id: _currentTicket.id,
          serviceType: _currentTicket.serviceType,
          savCode: _currentTicket.savCode,
          clientId: _currentTicket.clientId,
          clientName: _currentTicket.clientName,
          pickupDate: _currentTicket.pickupDate,
          pickupTechnicianIds: _currentTicket.pickupTechnicianIds,
          pickupTechnicianNames: _currentTicket.pickupTechnicianNames,
          productName: _currentTicket.productName,
          serialNumber: _currentTicket.serialNumber,
          problemDescription: _currentTicket.problemDescription,
          itemPhotoUrls: _currentTicket.itemPhotoUrls,
          storeManagerName: _currentTicket.storeManagerName,
          storeManagerSignatureUrl: _currentTicket.storeManagerSignatureUrl,
          status: _currentTicket.status,
          technicianReport: _reportController.text,
          createdBy: _currentTicket.createdBy,
          createdAt: _currentTicket.createdAt,
          brokenParts: newParts,
        );
      });
      _checkStockForParts(newParts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTicket.savCode),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildTechnicianSection(),
            const SizedBox(height: 24),
            if (_currentTicket.status == 'Approuvé - Prêt pour retour')
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.inventory_outlined),
                    label: const Text('Finaliser le Retour'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              FinalizeSavReturnPage(ticket: _currentTicket),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations sur le Ticket',
                style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            _buildInfoRow('Client:', _currentTicket.clientName),
            _buildInfoRow('Magasin:', _currentTicket.storeName ?? 'N/A'),
            _buildInfoRow('Produit:', _currentTicket.productName),
            _buildInfoRow('N° de Série:', _currentTicket.serialNumber),
            const SizedBox(height: 8),
            const Text('Description du Problème:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_currentTicket.problemDescription,
                style: const TextStyle(height: 1.4)),
            const Divider(height: 20),
            _buildInfoRow('Statut Actuel:', _currentTicket.status,
                isStatus: true),
            if (_currentTicket.billingStatus != null)
              _buildInfoRow('Facturation:', _currentTicket.billingStatus!),
            _buildInfoRow(
                'Date de création:',
                DateFormat('dd MMM yyyy, HH:mm', 'fr_FR')
                    .format(_currentTicket.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicianSection() {
    bool isReadOnly = _currentTicket.status == 'Terminé' ||
        _currentTicket.status == 'Approuvé - Prêt pour retour' ||
        _currentTicket.status == 'Retourné';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Section Technicien',
                style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            DropdownButtonFormField<String>(
              value: _currentTicket.status,
              items: _statusOptions
                  .map((status) =>
                  DropdownMenuItem(value: status, child: Text(status)))
                  .toList(),
              onChanged: isReadOnly
                  ? null
                  : (value) {
                if (value != null) _updateTicket(value);
              },
              decoration: const InputDecoration(labelText: 'Changer le statut'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reportController,
              readOnly: isReadOnly,
              decoration: const InputDecoration(
                labelText: 'Rapport du technicien',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            if (!isReadOnly)
              OutlinedButton.icon(
                onPressed: _showAddPartsDialog,
                icon: const Icon(Icons.add),
                label: const Text('Pièces défectueuses'),
              ),
            const SizedBox(height: 16),
            if (_currentTicket.brokenParts.isNotEmpty) ...[
              const Text('Pièces Défectueuses:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._currentTicket.brokenParts.map((part) => ListTile(
                title: Text(part.productName),
                trailing: Text(
                    'Stock: ${_stockStatus[part.productId]?.toString() ?? '...'}'),
              )),
            ],
            const SizedBox(height: 24),
            if (!isReadOnly)
              ElevatedButton(
                onPressed: _isUpdating
                    ? null
                    : () => _updateTicket(_currentTicket.status),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isUpdating
                    ? const CircularProgressIndicator()
                    : const Text('Enregistrer les Modifications'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
              child: Text(value,
                  style: isStatus
                      ? TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold)
                      : null)),
        ],
      ),
    );
  }
}

class _AddPartsDialog extends StatefulWidget {
  final List<String> initialSelected;
  const _AddPartsDialog({required this.initialSelected});

  @override
  _AddPartsDialogState createState() => _AddPartsDialogState();
}

class _AddPartsDialogState extends State<_AddPartsDialog> {
  List<DocumentSnapshot> _allProducts = [];
  List<DocumentSnapshot> _productsForCategory = [];
  String? _selectedCategory;
  bool _isLoadingProducts = false;
  late List<DocumentSnapshot> _selectedParts;

  @override
  void initState() {
    super.initState();
    _selectedParts = [];
    _fetchAllProducts();
  }

  Future<void> _fetchAllProducts() async {
    final snapshot =
    await FirebaseFirestore.instance.collection('products').get();
    setState(() {
      _allProducts = snapshot.docs;
    });
    _selectedParts
        .addAll(_allProducts.where((p) => widget.initialSelected.contains(p.id)));
  }

  void _filterProductsByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _productsForCategory =
          _allProducts.where((doc) => doc['categorie'] == category).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories =
    _allProducts.map((doc) => doc['categorie'] as String).toSet().toList();

    return AlertDialog(
      title: const Text('Ajouter des pièces défectueuses'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text('Sélectionner une catégorie'),
              onChanged: (value) {
                if (value != null) _filterProductsByCategory(value);
              },
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
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
                  final isSelected =
                  _selectedParts.any((p) => p.id == product.id);
                  return CheckboxListTile(
                    title: Text(product['nom']),
                    value: isSelected,
                    onChanged: (bool? selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedParts.add(product);
                        } else {
                          _selectedParts.removeWhere(
                                  (p) => p.id == product.id);
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
        TextButton(
            child: const Text('ANNULER'),
            onPressed: () => Navigator.of(context).pop()),
        ElevatedButton(
            child: const Text('CONFIRMER'),
            onPressed: () => Navigator.of(context).pop(_selectedParts)),
      ],
    );
  }
}
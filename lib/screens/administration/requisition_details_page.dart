// lib/screens/administration/requisition_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boitex_info_app/screens/administration/add_requisition_page.dart';
import 'package:boitex_info_app/screens/administration/confirm_receipt_page.dart';

class RequisitionDetailsPage extends StatefulWidget {
  final String requisitionId;
  final String userRole;

  const RequisitionDetailsPage({
    super.key,
    required this.requisitionId,
    required this.userRole,
  });

  @override
  State<RequisitionDetailsPage> createState() => _RequisitionDetailsPageState();
}

class _RequisitionDetailsPageState extends State<RequisitionDetailsPage> {
  Map<String, dynamic>? _requisitionData;
  bool _isLoading = true;
  bool _isActionInProgress = false;

  bool _isEditMode = false;
  List<Map<String, dynamic>> _editableItems = [];
  late List<TextEditingController> _quantityControllers;

  @override
  void initState() {
    super.initState();
    _fetchRequisitionDetails();
  }

  @override
  void dispose() {
    if (_isEditMode) {
      _disposeControllers();
    }
    super.dispose();
  }

  void _initializeControllers() {
    _quantityControllers = _editableItems.map((item) {
      return TextEditingController(text: item['quantity'].toString());
    }).toList();
  }

  void _disposeControllers() {
    for (var controller in _quantityControllers) {
      controller.dispose();
    }
  }

  Future<void> _fetchRequisitionDetails() async {
    if(!mounted) return;
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('requisitions').doc(widget.requisitionId).get();
      if (mounted) {
        setState(() {
          _requisitionData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleEditMode({bool cancel = false}) {
    setState(() {
      _isEditMode = !_isEditMode;
      if (_isEditMode) {
        _editableItems = List<Map<String, dynamic>>.from(
            (_requisitionData!['items'] as List).map((item) => Map<String, dynamic>.from(item))
        );
        _initializeControllers();
      } else {
        _disposeControllers();
      }
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _isActionInProgress = true);
    try {
      final List<Map<String, dynamic>> updatedItems = [];
      for (int i = 0; i < _editableItems.length; i++) {
        updatedItems.add({
          'productName': _editableItems[i]['productName'],
          'productId': _editableItems[i]['productId'],
          'quantity': int.tryParse(_quantityControllers[i].text) ?? 0,
        });
      }
      await FirebaseFirestore.instance.collection('requisitions').doc(widget.requisitionId).update({
        'items': updatedItems,
      });
      _toggleEditMode();
      await _fetchRequisitionDetails();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if(mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _showAddItemDialog() async {
    final result = await showDialog<RequisitionItem>(
      context: context,
      builder: (ctx) => const _AddItemDialog(),
    );

    if (result != null) {
      setState(() {
        if (!_editableItems.any((item) => item['productId'] == result.id)) {
          _editableItems.add(result.toJson());
          _quantityControllers.add(TextEditingController(text: result.quantity.toString()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce produit est déjà dans la liste.')));
        }
      });
    }
  }

  void _deleteItem(int index) {
    setState(() {
      _editableItems.removeAt(index);
      _quantityControllers.removeAt(index).dispose();
    });
  }

  Future<void> _updateRequisitionStatus(String newStatus) async {
    setState(() => _isActionInProgress = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['displayName'] ?? 'Utilisateur inconnu';

      final logEntry = {
        'action': newStatus,
        'user': userName,
        'timestamp': Timestamp.now(),
      };
      await FirebaseFirestore.instance.collection('requisitions').doc(widget.requisitionId).update({
        'status': newStatus,
        'activityLog': FieldValue.arrayUnion([logEntry]),
      });
      await _fetchRequisitionDetails();
      if (newStatus == 'Approuvée' || newStatus == 'Refusée') {
        if(mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if(mounted) setState(() => _isActionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(title: const Text('Chargement...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_requisitionData == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(title: const Text('Erreur')),
        body: const Center(child: Text('Demande introuvable.')),
      );
    }

    final data = _requisitionData!;
    final activityLog = (data['activityLog'] as List<dynamic>? ?? [])
        .map((log) => log as Map<String, dynamic>)
        .toList()
      ..sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp']));

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(data['requisitionCode'] ?? 'Détail de la Demande'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          if (widget.userRole == 'PDG' && !_isEditMode && data['status'] == "En attente d'approbation")
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _toggleEditMode, tooltip: 'Modifier')
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(data),
            const SizedBox(height: 24),
            _buildStatusBadge(data['status']),
            const SizedBox(height: 24),
            if (_isActionInProgress)
              const Center(child: CircularProgressIndicator())
            else
              _buildActionButtons(data['status']),
            const SizedBox(height: 24),
            _buildItemsList(data),
            const SizedBox(height: 24),
            const Text(
              "Journal d'Activité",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            _ActivityTimeline(activityLog: activityLog),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> data) {
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade400, Colors.indigo.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['requisitionCode'] ?? 'Demande d\'Achat',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Demandé par: ${data['requestedBy'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Date: ${DateFormat('dd MMMM yyyy', 'fr_FR').format(createdAt)}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final style = _TimelineStyle.fromAction(status);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: style.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: style.color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, color: style.color, size: 20),
            const SizedBox(width: 8),
            Text(
              status,
              style: TextStyle(color: style.color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(Map<String, dynamic> data) {
    final items = _isEditMode
        ? _editableItems
        : (data['items'] as List<dynamic>).map((item) => item as Map<String, dynamic>).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Articles Demandés',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.withOpacity(0.1),
                  child: const Icon(Icons.inventory_2_outlined, color: Colors.indigo),
                ),
                title: Text(item['productName']),
                trailing: _isEditMode
                    ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 60,
                      child: TextFormField(
                        controller: _quantityControllers[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(labelText: 'Qté'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteItem(index),
                    ),
                  ],
                )
                    : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Qté: ${item['quantity']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isEditMode)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un Produit'),
                onPressed: _showAddItemDialog,
              ),
            ),
          ),
      ],
    );
  }

  // ✅ ADDED BACK: The missing implementation for the action buttons
  Widget _buildActionButtons(String status) {
    final isPdg = widget.userRole == 'PDG';
    final isManager = ['Admin', 'Responsable Administratif', 'Responsable Commercial', 'Chef de Projet'].contains(widget.userRole);

    if (_isEditMode) {
      return Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: _toggleEditMode, child: const Text('Annuler'))),
          const SizedBox(width: 16),
          Expanded(child: ElevatedButton(onPressed: _saveChanges, child: const Text('Enregistrer'))),
        ],
      );
    }

    switch (status) {
      case "En attente d'approbation":
        if (isPdg) {
          return Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateRequisitionStatus('Refusée'),
                  icon: const Icon(Icons.close),
                  label: const Text('Refuser'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateRequisitionStatus('Approuvée'),
                  icon: const Icon(Icons.check),
                  label: const Text('Approuver'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ),
            ],
          );
        }
        return const Center(child: Text("En attente de l'approbation du PDG."));

      case 'Approuvée':
        if (isManager || isPdg) {
          return ElevatedButton.icon(
            onPressed: () => _updateRequisitionStatus('Commandée'),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Marquer comme Commandée'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          );
        }
        return const Center(child: Text("Approuvé. En attente de commande."));

      case 'Commandée':
        if (isManager || isPdg) {
          return ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ConfirmReceiptPage(requisitionId: widget.requisitionId),
                ),
              );
            },
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Confirmer la Réception'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          );
        }
        return const Center(child: Text("En attente de réception."));

      default:
        return Center(child: Chip(label: Text('Statut: $status')));
    }
  }
}

// ✅ ADDED BACK: The missing implementation for the timeline widget
class _ActivityTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> activityLog;

  const _ActivityTimeline({required this.activityLog});

  @override
  Widget build(BuildContext context) {
    if (activityLog.isEmpty) {
      return const Card(child: ListTile(title: Text('Aucune activité enregistrée.')));
    }
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: activityLog.length,
      itemBuilder: (context, index) {
        final log = activityLog[index];
        return _TimelineTile(
          log: log,
          isFirst: index == 0,
          isLast: index == activityLog.length - 1,
        );
      },
    );
  }
}

// ✅ ADDED BACK: The missing implementation for the timeline tile widget
class _TimelineTile extends StatelessWidget {
  final Map<String, dynamic> log;
  final bool isFirst;
  final bool isLast;

  const _TimelineTile({required this.log, required this.isFirst, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final style = _TimelineStyle.fromAction(log['action']);
    final logTime = (log['timestamp'] as Timestamp).toDate();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : Colors.grey.shade300,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst ? style.color : Colors.grey.shade300,
                  ),
                  child: Icon(style.icon, color: Colors.white, size: isFirst ? 20 : 12),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        log['action'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isFirst ? style.color : Colors.black87,
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yy HH:mm').format(logTime),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Par: ${log['user'] ?? 'Utilisateur inconnu'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStyle {
  final IconData icon;
  final Color color;
  _TimelineStyle({required this.icon, required this.color});

  factory _TimelineStyle.fromAction(String action) {
    switch (action) {
      case 'Approuvée': return _TimelineStyle(icon: Icons.check_circle_outline, color: Colors.green);
      case 'Commandée': return _TimelineStyle(icon: Icons.local_shipping_outlined, color: Colors.blue);
      case 'Reçue': return _TimelineStyle(icon: Icons.inventory_2_outlined, color: Colors.teal);
      case 'Reçue avec Écarts': return _TimelineStyle(icon: Icons.warning_amber_rounded, color: Colors.orange);
      case 'Refusée': return _TimelineStyle(icon: Icons.cancel_outlined, color: Colors.red);
      default: return _TimelineStyle(icon: Icons.history, color: Colors.grey);
    }
  }
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog();
  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final List<String> _mainCategories = ['Antivol', 'TPV', 'Compteur Client'];
  String? _selectedMainCategory;
  List<String> _subCategories = [];
  bool _isLoadingSubCategories = false;
  String? _selectedSubCategory;
  List<DocumentSnapshot> _products = [];
  bool _isLoadingProducts = false;
  DocumentSnapshot? _selectedProduct;
  final _quantityController = TextEditingController(text: "1");
  final _dialogFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategoriesForMainSection(String mainCategory) async {
    setState(() {
      _isLoadingSubCategories = true; _subCategories = []; _selectedSubCategory = null;
      _products = []; _selectedProduct = null;
    });
    final snapshot = await FirebaseFirestore.instance.collection('produits').where('mainCategory', isEqualTo: mainCategory).get();
    final categoriesSet = <String>{};
    for (var doc in snapshot.docs) {
      categoriesSet.add(doc.data()['categorie'] as String);
    }
    final sortedList = categoriesSet.toList();
    sortedList.sort();
    if (mounted) {
      setState(() { _subCategories = sortedList; _isLoadingSubCategories = false; });
    }
  }

  Future<void> _fetchProductsForSubCategory(String category) async {
    setState(() { _isLoadingProducts = true; _products = []; _selectedProduct = null; });
    try {
      final snapshot = await FirebaseFirestore.instance.collection('produits').where('categorie', isEqualTo: category).orderBy('nom').get();
      if (mounted) setState(() { _products = snapshot.docs; _isLoadingProducts = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingProducts = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un Produit'),
      content: Form(
        key: _dialogFormKey,
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedMainCategory,
                items: _mainCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if(val != null) {
                    setState(() => _selectedMainCategory = val);
                    _fetchCategoriesForMainSection(val);
                  }
                },
                decoration: const InputDecoration(labelText: 'Section Principale', border: OutlineInputBorder()),
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSubCategory,
                items: _subCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: _selectedMainCategory == null || _isLoadingSubCategories ? null : (val) {
                  if (val != null) {
                    setState(() => _selectedSubCategory = val);
                    _fetchProductsForSubCategory(val);
                  }
                },
                decoration: const InputDecoration(labelText: 'Catégorie', border: const OutlineInputBorder()),
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DocumentSnapshot>(
                value: _selectedProduct,
                items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p['nom']))).toList(),
                onChanged: _selectedSubCategory == null || _isLoadingProducts ? null : (val) => setState(() => _selectedProduct = val),
                decoration: const InputDecoration(labelText: 'Produit', border: const OutlineInputBorder()),
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Quantité', border: const OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Quantité requise' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () {
            if (_dialogFormKey.currentState!.validate()) {
              final quantity = int.tryParse(_quantityController.text) ?? 0;
              Navigator.of(context).pop(RequisitionItem(productDoc: _selectedProduct!, quantity: quantity));
            }
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
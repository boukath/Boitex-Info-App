// lib/screens/administration/requisition_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boitex_info_app/screens/administration/add_requisition_page.dart';
import 'package:boitex_info_app/screens/administration/confirm_receipt_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
// ✅ IMPORT PRODUCT DETAILS PAGE
import 'package:boitex_info_app/screens/administration/product_details_page.dart';

class RequisitionDetailsPage extends StatefulWidget {
  final String requisitionId;
  final String userRole;
  // ✅ NEW PARAMETER
  final bool startInEditMode;

  const RequisitionDetailsPage({
    super.key,
    required this.requisitionId,
    required this.userRole,
    // ✅ NEW: Default to false
    this.startInEditMode = false,
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

  bool _canAccessPOReference() {
    return widget.userRole == 'PDG' ||
        widget.userRole == 'Admin' ||
        widget.userRole == 'Responsable Administratif';
  }

  Future<String?> _showPOReferenceDialog({String? currentPOReference}) async {
    final controller = TextEditingController(text: currentPOReference ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(currentPOReference == null
            ? 'Référence Bon de Commande'
            : 'Modifier Référence BC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'N° Bon de Commande (Optionnel)',
                hintText: 'Ex: PO-2025-0432, BC-789...',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 8),
            Text(
              'Ce numéro vous permet de retrouver facilement la commande.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<void> _editPOReference() async {
    final currentPORef = _requisitionData?['purchaseOrderReference'] as String?;
    final newPOReference =
    await _showPOReferenceDialog(currentPOReference: currentPORef);

    if (newPOReference == null) return;

    setState(() => _isActionInProgress = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté.');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName = userDoc.data()?['displayName'] ?? 'Utilisateur inconnu';

      final updateData = <String, dynamic>{
        'poReferenceAddedBy': user.email ?? user.uid,
        'poReferenceAddedAt': Timestamp.now(),
        'activityLog': FieldValue.arrayUnion([
          {
            'action': newPOReference.isEmpty
                ? 'Référence BC supprimée'
                : 'Référence BC modifiée',
            'user': userName,
            'timestamp': Timestamp.now(),
            if (newPOReference.isNotEmpty) 'purchaseOrderRef': newPOReference,
          }
        ]),
      };

      if (newPOReference.isEmpty) {
        updateData['purchaseOrderReference'] = FieldValue.delete();
      } else {
        updateData['purchaseOrderReference'] = newPOReference;
      }

      await FirebaseFirestore.instance
          .collection('requisitions')
          .doc(widget.requisitionId)
          .update(updateData);
      await _fetchRequisitionDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newPOReference.isEmpty
                ? 'Référence BC supprimée'
                : 'Référence BC mise à jour: $newPOReference'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  void _initializeControllers() {
    _quantityControllers = _editableItems.map((item) {
      final int qty = item['orderedQuantity'] ?? item['quantity'] ?? 0;
      return TextEditingController(text: qty.toString());
    }).toList();
  }

  void _disposeControllers() {
    for (var controller in _quantityControllers) {
      controller.dispose();
    }
  }

  // ✅ UPDATED FUNCTION
  Future<void> _fetchRequisitionDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('requisitions')
          .doc(widget.requisitionId)
          .get();
      if (mounted) {
        setState(() {
          _requisitionData = doc.data();
          _isLoading = false;
        });

        // ✅ NEW LOGIC: Check if we should auto-enter edit mode
        if (widget.startInEditMode && _requisitionData != null) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            bool canModify =
                _requisitionData!['requestedById'] == currentUser.uid &&
                    _requisitionData!['status'] == "En attente d'approbation";

            // Only toggle edit mode if all conditions are met
            if (canModify && !_isEditMode) {
              _toggleEditMode();
            }
          }
        }
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
            (_requisitionData!['items'] as List)
                .map((item) => Map<String, dynamic>.from(item)));
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
        final int newQty = int.tryParse(_quantityControllers[i].text) ?? 0;
        updatedItems.add({
          'productName': _editableItems[i]['productName'],
          'productId': _editableItems[i]['productId'],
          'orderedQuantity': newQty,
          'receivedQuantity': _editableItems[i]['receivedQuantity'] ?? 0,
        });
      }

      await FirebaseFirestore.instance
          .collection('requisitions')
          .doc(widget.requisitionId)
          .update({'items': updatedItems});
      _toggleEditMode();
      await _fetchRequisitionDetails();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
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
          final newItem = result.toJson();
          newItem['orderedQuantity'] = newItem['quantity'];
          newItem['receivedQuantity'] = 0;
          newItem.remove('quantity');
          _editableItems.add(newItem);
          _quantityControllers
              .add(TextEditingController(text: result.quantity.toString()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Ce produit est déjà dans la liste.')));
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
    String? poReference;

    if (newStatus == 'Commandée') {
      poReference = await _showPOReferenceDialog();
      if (poReference == null) return;
    }

    // ✅ FIX: Add a small delay to ensure dialog is fully closed
    await Future.delayed(const Duration(milliseconds: 100));

    // ✅ FIX: Check if widget is still mounted before calling setState
    if (!mounted) return;

    setState(() => _isActionInProgress = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName = userDoc.data()?['displayName'] ?? 'Utilisateur inconnu';

      final logEntry = {
        'action': newStatus,
        'user': userName,
        'timestamp': Timestamp.now(),
        if (poReference != null && poReference.isNotEmpty)
          'purchaseOrderRef': poReference,
      };

      final updateData = {
        'status': newStatus,
        'activityLog': FieldValue.arrayUnion([logEntry]),
      };

      if (poReference != null && poReference.isNotEmpty) {
        updateData['purchaseOrderReference'] = poReference;
        updateData['poReferenceAddedBy'] = user.email ?? user.uid;
        updateData['poReferenceAddedAt'] = Timestamp.now();
      }

      await FirebaseFirestore.instance
          .collection('requisitions')
          .doc(widget.requisitionId)
          .update(updateData);
      await _fetchRequisitionDetails();

      if (newStatus == 'Approuvée' || newStatus == 'Refusée') {
        if (mounted) Navigator.of(context).pop();
      }

      if (mounted && newStatus == 'Commandée') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(poReference != null && poReference.isNotEmpty
                ? 'Commande enregistrée avec le N° BC: $poReference'
                : 'Commande enregistrée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  // ✅ NEW FUNCTION: To delete the requisition
  Future<void> _deleteRequisition() async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text(
              'Voulez-vous vraiment supprimer cette demande ? Cette action est irréversible.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child:
              const Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        setState(() => _isActionInProgress = true);
        await FirebaseFirestore.instance
            .collection('requisitions')
            .doc(widget.requisitionId)
            .delete();

        // You could add an ActivityLogger call here if needed

        Navigator.of(context).pop(); // Go back to the previous page
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande supprimée avec succès.')),
        );
      } catch (e) {
        setState(() => _isActionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
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
    final activityLog = (data['activityLog'] as List? ?? [])
        .map((log) => log as Map<String, dynamic>)
        .toList()
      ..sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp']));

    // ✅ NEW LOGIC: Check if the current user can modify (edit/delete)
    final currentUser = FirebaseAuth.instance.currentUser;
    bool canModify = false;
    if (_requisitionData != null && currentUser != null) {
      canModify = _requisitionData!['requestedById'] == currentUser.uid &&
          _requisitionData!['status'] == "En attente d'approbation";
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      // ✅ UPDATED AppBar with new actions
      appBar: AppBar(
        title: Text(data['requisitionCode'] ?? 'Détail de la Demande'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          if (_isLoading) Container(), // Show nothing while loading

          // Show Edit/Delete only if the user is the requester AND status is pending
          if (canModify && !_isEditMode) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _toggleEditMode, // This function already exists!
              tooltip: 'Modifier',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteRequisition, // The new function we added
              tooltip: 'Supprimer',
            ),
          ],

          // Show a "Cancel" button when in edit mode
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _toggleEditMode,
              tooltip: 'Annuler',
            ),
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
            _buildReceptionHistory(),
            const SizedBox(height: 24),
            const Text("Journal d'Activité",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 16),
            _ActivityTimeline(
                activityLog: activityLog,
                canAccessPORef: _canAccessPOReference()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> data) {
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    final poReference = data['purchaseOrderReference'] as String?;
    final status = data['status'] as String;

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
            Text(data['requisitionCode'] ?? 'Demande d\'Achat',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.person_outline, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text('Demandé par: ${data['requestedBy'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                  'Date: ${DateFormat('dd MMMM yyyy', 'fr_FR').format(createdAt)}',
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ]),
            if (_canAccessPOReference() &&
                (status == 'Commandée' ||
                    status == 'Partiellement Reçue' ||
                    status == 'Reçue')) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.receipt_long, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poReference != null && poReference.isNotEmpty
                        ? 'N° BC: $poReference'
                        : 'N° BC: Non renseigné',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: poReference != null && poReference.isNotEmpty
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (status != 'Reçue')
                  InkWell(
                    onTap: _isActionInProgress ? null : _editPOReference,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4)),
                      child:
                      const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
              ]),
            ],
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(style.icon, color: style.color, size: 20),
          const SizedBox(width: 8),
          Text(status,
              style: TextStyle(
                  color: style.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ]),
      ),
    );
  }

  Widget _buildItemsList(Map<String, dynamic> data) {
    List<Map<String, dynamic>> items = [];
    if (_isEditMode) {
      items = _editableItems;
    } else {
      final dynamic itemsData = data['items'];
      if (itemsData is List) {
        items = List<Map<String, dynamic>>.from(
            itemsData.map((item) => Map<String, dynamic>.from(item as Map)));
      } else if (itemsData is Map) {
        items = itemsData.values
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Articles Demandés',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final int orderedQty =
                  item['orderedQuantity'] ?? item['quantity'] ?? 0;
              final int receivedQty = item['receivedQuantity'] ?? 0;
              final bool isComplete = receivedQty >= orderedQty;

              // ✅ MODIFICATION: Fetch product to show image and enable navigation
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('produits')
                    .doc(item['productId'])
                    .get(),
                builder: (context, snapshot) {
                  // 1. Determine Leading Widget (Image or Icon)
                  Widget leadingWidget;
                  DocumentSnapshot? productDoc = snapshot.data;

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    if (data.containsKey('imageUrls') &&
                        (data['imageUrls'] as List).isNotEmpty) {
                      leadingWidget = CircleAvatar(
                        backgroundImage:
                        NetworkImage((data['imageUrls'] as List).first),
                        backgroundColor: Colors.transparent,
                      );
                    } else {
                      // Fallback icon if no image
                      leadingWidget = CircleAvatar(
                        backgroundColor: isComplete
                            ? Colors.teal.withOpacity(0.1)
                            : Colors.indigo.withOpacity(0.1),
                        child: Icon(
                            isComplete
                                ? Icons.check_circle_outline
                                : Icons.inventory_2_outlined,
                            color: isComplete ? Colors.teal : Colors.indigo),
                      );
                    }
                  } else {
                    // Loading or Error or Not Found state
                    leadingWidget = CircleAvatar(
                      backgroundColor: isComplete
                          ? Colors.teal.withOpacity(0.1)
                          : Colors.indigo.withOpacity(0.1),
                      child: Icon(
                          isComplete
                              ? Icons.check_circle_outline
                              : Icons.inventory_2_outlined,
                          color: isComplete ? Colors.teal : Colors.indigo),
                    );
                  }

                  // 2. Build Tile
                  return ListTile(
                    leading: leadingWidget,
                    title: Text(item['productName']),
                    subtitle: _isEditMode
                        ? null
                        : Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: (orderedQty == 0)
                                  ? 0
                                  : (receivedQty / orderedQty),
                              backgroundColor: Colors.grey.shade300,
                              color:
                              isComplete ? Colors.teal : Colors.blue,
                            ),
                            const SizedBox(height: 4),
                            Text('Reçu: $receivedQty / $orderedQty',
                                style: TextStyle(
                                    color: isComplete
                                        ? Colors.teal
                                        : Colors.black87,
                                    fontWeight: isComplete
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                          ]),
                    ),
                    // ✅ 3. Navigation to ProductDetailsPage
                    onTap: () {
                      if (productDoc != null && productDoc.exists) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailsPage(productDoc: productDoc),
                          ),
                        );
                      } else {
                        // Optional: Show feedback if still loading or not found
                      }
                    },
                    trailing: _isEditMode
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          controller: _quantityControllers[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration:
                          const InputDecoration(labelText: 'Qté'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        onPressed: () => _deleteItem(index),
                      ),
                    ])
                    // Show chevron to indicate it is clickable when not in edit mode
                        : const Icon(Icons.arrow_forward_ios,
                        size: 14, color: Colors.grey),
                  );
                },
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

  Widget _buildActionButtons(String status) {
    final isPdg = widget.userRole == 'PDG';
    final isManager = [
      'Admin',
      'Responsable Administratif',
      'Responsable Commercial',
      'Chef de Projet'
    ].contains(widget.userRole);

    if (_isEditMode) {
      return Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed: _toggleEditMode, child: const Text('Annuler'))),
        const SizedBox(width: 16),
        Expanded(
            child: ElevatedButton(
                onPressed: _saveChanges, child: const Text('Enregistrer'))),
      ]);
    }

    switch (status) {
      case "En attente d'approbation":
        if (isPdg) {
          return Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _updateRequisitionStatus('Refusée'),
                icon: const Icon(Icons.close),
                label: const Text('Refuser'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _updateRequisitionStatus('Approuvée'),
                icon: const Icon(Icons.check),
                label: const Text('Approuver'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
              ),
            ),
          ]);
        }
        return const Center(child: Text("En attente de l'approbation du PDG."));

      case 'Approuvée':
        if (isManager || isPdg) {
          return ElevatedButton.icon(
            onPressed: () => _updateRequisitionStatus('Commandée'),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Marquer comme Commandée'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, foregroundColor: Colors.white),
          );
        }
        return const Center(child: Text("Approuvé. En attente de commande."));

      case 'Commandée':
      case 'Partiellement Reçue':
      // ✅ Corrected permission check using the userRole passed to the page
        if (RolePermissions.canManageRequisitions(widget.userRole)) {
          return ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => ConfirmReceiptPage(
                        requisitionId: widget.requisitionId)),
              ); // Removed .then() call as StreamBuilder handles updates
            },
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Enregistrer une Réception'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white),
          );
        }
        // Show nothing if the user doesn't have permission
        return const SizedBox
            .shrink(); // Or return null if appropriate for the layout

      default:
        return Center(child: Chip(label: Text('Statut: $status')));
    }
  }

  Widget _buildReceptionHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Historique des Réceptions",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('requisitions')
              .doc(widget.requisitionId)
              .collection('receptions')
              .orderBy('receptionDate', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Center(child: Text('Erreur de chargement.'));
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());

            final receptionDocs = snapshot.data?.docs ?? [];
            if (receptionDocs.isEmpty) {
              return const Card(
                  child: ListTile(
                      title: Text(
                          'Aucune réception enregistrée pour le moment.')));
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: receptionDocs.length,
              itemBuilder: (context, index) {
                final doc = receptionDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                final receptionDate =
                (data['receptionDate'] as Timestamp).toDate();
                final items = (data['itemsInThisShipment'] as List)
                    .map((item) => item as Map<String, dynamic>)
                    .toList();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                        backgroundColor: Colors.teal.withOpacity(0.1),
                        child: const Icon(Icons.check, color: Colors.teal)),
                    title: Text(
                        'Réception du ${DateFormat('dd/MM/yyyy HH:mm').format(receptionDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Par: ${data['receivedBy'] ?? 'N/A'}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (data['notes'] != null &&
                                  data['notes'].isNotEmpty)
                                Text('Notes: ${data['notes']}',
                                    style: const TextStyle(
                                        fontStyle: FontStyle.italic)),
                              if (data['notes'] != null &&
                                  data['notes'].isNotEmpty)
                                const Divider(height: 16),
                              ...items.map((item) {
                                return ListTile(
                                  dense: true,
                                  title: Text(item['productName']),
                                  trailing: Text('Qté: ${item['quantity']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                );
                              }).toList(),
                            ]),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _ActivityTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> activityLog;
  final bool canAccessPORef;

  const _ActivityTimeline(
      {required this.activityLog, required this.canAccessPORef});

  @override
  Widget build(BuildContext context) {
    if (activityLog.isEmpty)
      return const Card(
          child: ListTile(title: Text('Aucune activité enregistrée.')));

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
            canAccessPORef: canAccessPORef);
      },
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final Map<String, dynamic> log;
  final bool isFirst;
  final bool isLast;
  final bool canAccessPORef;

  const _TimelineTile(
      {required this.log,
        required this.isFirst,
        required this.isLast,
        required this.canAccessPORef});

  @override
  Widget build(BuildContext context) {
    final style = _TimelineStyle.fromAction(log['action']);
    final logTime = (log['timestamp'] as Timestamp).toDate();
    final poRef = log['purchaseOrderRef'] as String?;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 50,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Expanded(
                child: Container(
                    width: 2,
                    color:
                    isFirst ? Colors.transparent : Colors.grey.shade300)),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFirst ? style.color : Colors.grey.shade300),
              child: Icon(style.icon,
                  color: Colors.white, size: isFirst ? 20 : 12),
            ),
            Expanded(
                child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.grey.shade300)),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(log['action'],
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isFirst ? style.color : Colors.black87)),
                Text(DateFormat('dd/MM/yy HH:mm').format(logTime),
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
              const SizedBox(height: 4),
              Text('Par: ${log['user'] ?? 'Utilisateur inconnu'}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              if (poRef != null && poRef.isNotEmpty && canAccessPORef)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.receipt_long,
                          size: 14, color: Colors.blue.shade900),
                      const SizedBox(width: 4),
                      Text('Réf BC: $poRef',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _TimelineStyle {
  final IconData icon;
  final Color color;

  _TimelineStyle({required this.icon, required this.color});

  factory _TimelineStyle.fromAction(String action) {
    switch (action) {
      case 'Approuvée':
        return _TimelineStyle(
            icon: Icons.check_circle_outline, color: Colors.green);
      case 'Commandée':
        return _TimelineStyle(
            icon: Icons.local_shipping_outlined, color: Colors.blue);
      case 'Partiellement Reçue':
        return _TimelineStyle(
            icon: Icons.inventory_2_outlined, color: Colors.orange);
      case 'Réception partielle':
        return _TimelineStyle(
            icon: Icons.inventory_2_outlined, color: Colors.orange.shade300);
      case 'Reçue':
        return _TimelineStyle(
            icon: Icons.inventory_2_outlined, color: Colors.teal);
      case 'Reçue avec Écarts':
        return _TimelineStyle(
            icon: Icons.warning_amber_rounded, color: Colors.orange);
      case 'Refusée':
        return _TimelineStyle(icon: Icons.cancel_outlined, color: Colors.red);
      case 'Référence BC modifiée':
      case 'Référence BC supprimée':
        return _TimelineStyle(icon: Icons.edit_note, color: Colors.indigo);
      default:
        return _TimelineStyle(icon: Icons.history, color: Colors.grey);
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
      _isLoadingSubCategories = true;
      _subCategories = [];
      _selectedSubCategory = null;
      _products = [];
      _selectedProduct = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('mainCategory', isEqualTo: mainCategory)
          .get();
      final categoriesSet = <String>{};
      for (var doc in snapshot.docs) {
        final categoryValue = doc.data()['categorie'];
        if (categoryValue != null && categoryValue is String) {
          categoriesSet.add(categoryValue);
        }
      }

      final sortedList = categoriesSet.toList();
      sortedList.sort();

      if (mounted) {
        setState(() {
          _subCategories = sortedList;
          _isLoadingSubCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSubCategories = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _fetchProductsForSubCategory(String category) async {
    setState(() {
      _isLoadingProducts = true;
      _products = [];
      _selectedProduct = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('categorie', isEqualTo: category)
          .orderBy('nom')
          .get();
      if (mounted)
        setState(() {
          _products = snapshot.docs;
          _isLoadingProducts = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: _selectedMainCategory,
              items: _mainCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedMainCategory = val);
                  _fetchCategoriesForMainSection(val);
                }
              },
              decoration: const InputDecoration(
                  labelText: 'Section Principale',
                  border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSubCategory,
              items: _subCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged:
              _selectedMainCategory == null || _isLoadingSubCategories
                  ? null
                  : (val) {
                if (val != null) {
                  setState(() => _selectedSubCategory = val);
                  _fetchProductsForSubCategory(val);
                }
              },
              decoration: const InputDecoration(
                  labelText: 'Catégorie', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DocumentSnapshot>(
              value: _selectedProduct,
              items: _products
                  .map((p) => DropdownMenuItem(value: p, child: Text(p['nom'])))
                  .toList(),
              onChanged: _selectedSubCategory == null || _isLoadingProducts
                  ? null
                  : (val) => setState(() => _selectedProduct = val),
              decoration: const InputDecoration(
                  labelText: 'Produit', border: OutlineInputBorder()),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                  labelText: 'Quantité', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (v) =>
              (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Quantité requise' : null,
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () {
            if (_dialogFormKey.currentState!.validate()) {
              final quantity = int.tryParse(_quantityController.text) ?? 0;
              Navigator.of(context).pop(RequisitionItem(
                  productDoc: _selectedProduct!, quantity: quantity));
            }
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
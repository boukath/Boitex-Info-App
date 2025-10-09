// lib/screens/administration/requisition_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  late List<TextEditingController> _quantityControllers;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _fetchRequisitionDetails();
  }

  @override
  void dispose() {
    if (_isEditMode) {
      for (var controller in _quantityControllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _fetchRequisitionDetails() async {
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

  void _initializeControllers() {
    // ... same as before
    if (_requisitionData == null) return;
    final items = List<Map<String, dynamic>>.from(_requisitionData!['items']);
    _quantityControllers = items.map((item) {
      return TextEditingController(text: item['quantity'].toString());
    }).toList();
  }

  void _toggleEditMode() {
    // ... same as before
    setState(() {
      _isEditMode = !_isEditMode;
      if (_isEditMode) {
        _initializeControllers();
      } else {
        for (var controller in _quantityControllers) {
          controller.dispose();
        }
      }
    });
  }

  Future<void> _saveChanges() async {
    // ... same as before
    setState(() => _isActionInProgress = true);
    try {
      final items = List<Map<String, dynamic>>.from(_requisitionData!['items']);
      final List<Map<String, dynamic>> updatedItems = [];
      for (int i = 0; i < items.length; i++) {
        updatedItems.add({
          'productName': items[i]['productName'],
          'productId': items[i]['productId'],
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

  Future<void> _updateRequisitionStatus(String newStatus) async {
    // ... same as before
    setState(() => _isActionInProgress = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final logEntry = {
        'action': newStatus,
        'user': user?.displayName ?? 'Utilisateur inconnu',
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

  // MODIFIED: This function now contains the full backorder notification logic.
  Future<void> _confirmReceiptAndUpdateStock() async {
    setState(() => _isActionInProgress = true);
    try {
      final items = List<Map<String, dynamic>>.from(_requisitionData!['items']);
      final user = FirebaseAuth.instance.currentUser;
      List<String> backorderedProducts = [];

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // --- READ PHASE ---
        final List<DocumentReference> productRefs = items.map((item) {
          return FirebaseFirestore.instance.collection('produits').doc(item['productId']);
        }).toList();
        final List<DocumentSnapshot> productSnaps = await Future.wait(productRefs.map((ref) => transaction.get(ref)));

        // --- WRITE PHASE ---
        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          final productRef = productRefs[i];
          final productSnap = productSnaps[i];
          final productData = productSnap.data() as Map<String, dynamic>?;

          final currentStock = productData?['quantiteEnStock'] ?? 0;

          // Check for backorder BEFORE updating stock
          if (currentStock < 0) {
            backorderedProducts.add(productData?['nom'] ?? 'Produit inconnu');
            // Find and update the associated replacement request
            final replacementReqQuery = await FirebaseFirestore.instance
                .collection('replacementRequests')
                .where('productName', isEqualTo: productData?['nom'])
                .where('requestStatus', whereIn: ['Approuvé - Bon de commande reçu', 'Approuvé - Confirmation téléphonique'])
                .limit(1)
                .get();

            if (replacementReqQuery.docs.isNotEmpty) {
              transaction.update(replacementReqQuery.docs.first.reference, {
                'requestStatus': 'Approuvé - Produit en stock'
              });
            }
          }

          final newStock = currentStock + item['quantity'];
          transaction.update(productRef, {'quantiteEnStock': newStock});

          final historyRef = productRef.collection('stock_history').doc();
          transaction.set(historyRef, {
            'change': item['quantity'],
            'newQuantity': newStock,
            'notes': 'Réception de la commande (Demande ID: ${widget.requisitionId})',
            'timestamp': FieldValue.serverTimestamp(),
            'updatedByUid': user?.uid,
          });
        }

        final requisitionRef = FirebaseFirestore.instance.collection('requisitions').doc(widget.requisitionId);
        final logEntry = {'action': 'Reçue', 'user': user?.displayName ?? 'Utilisateur inconnu', 'timestamp': Timestamp.now()};
        transaction.update(requisitionRef, {
          'status': 'Reçue',
          'activityLog': FieldValue.arrayUnion([logEntry]),
        });
      });

      // After transaction is successful, show alert if needed
      if (mounted && backorderedProducts.isNotEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Articles Réservés'),
            content: Text('Attention: Le stock a été mis à jour, mais les articles suivants sont réservés pour des remplacements approuvés:\n\n- ${backorderedProducts.join("\n- ")}'),
            actions: [ TextButton(child: const Text('OK'), onPressed: () => Navigator.of(ctx).pop()) ],
          ),
        );
      }

      await _fetchRequisitionDetails();

    } catch(e) {
      print(e);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if(mounted) setState(() => _isActionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... build method is unchanged
    if (_isLoading) return Scaffold(appBar: AppBar(title: const Text('Détail de la Demande')), body: const Center(child: CircularProgressIndicator()));
    if (_requisitionData == null) return Scaffold(appBar: AppBar(title: const Text('Détail de la Demande')), body: const Center(child: Text('Demande introuvable.')));

    final data = _requisitionData!;
    final items = (data['items'] as List<dynamic>).map((item) => item as Map<String, dynamic>).toList();
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    final activityLog = (data['activityLog'] as List<dynamic>? ?? []).map((log) => log as Map<String, dynamic>).toList()..sort((a,b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp']));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de la Demande'),
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
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Demandé par'),
              subtitle: Text(data['requestedBy'] ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Date'),
              subtitle: Text(DateFormat('dd MMMM yyyy', 'fr_FR').format(createdAt)),
            ),
            const Divider(height: 32),
            Text('Articles Demandés', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(item['productName']),
                    trailing: _isEditMode
                        ? SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: _quantityControllers[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(labelText: 'Qté'),
                      ),
                    )
                        : Text('Qté: ${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            if (_isActionInProgress) const Center(child: CircularProgressIndicator()) else _buildActionButtons(data['status']),
            const Divider(height: 32),
            Text("Journal d'Activité", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: activityLog.isEmpty
                  ? const ListTile(title: Text('Aucune activité enregistrée.'))
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activityLog.length,
                itemBuilder: (context, index) {
                  final log = activityLog[index];
                  final logTime = (log['timestamp'] as Timestamp).toDate();
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(log['action']),
                    subtitle: Text('Par ${log['user']}'),
                    trailing: Text(DateFormat('dd/MM/yy HH:mm').format(logTime)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(String status) {
    final isPdg = widget.userRole == 'PDG';
    final isManager = ['Admin', 'Responsable Administratif', 'Responsable Commercial', 'Chef de Projet'].contains(widget.userRole);

    if (_isEditMode && isPdg) {
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
            onPressed: _confirmReceiptAndUpdateStock,
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
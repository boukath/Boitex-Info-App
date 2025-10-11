// lib/screens/administration/confirm_receipt_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Helper class to manage the form state for each item
class ReceivedItemController {
  final String productName;
  final int orderedQuantity;
  final TextEditingController receivedQuantityController;

  ReceivedItemController({
    required this.productName,
    required this.orderedQuantity,
  }) : receivedQuantityController = TextEditingController(
    text: orderedQuantity.toString(),
  );

  void dispose() {
    receivedQuantityController.dispose();
  }
}

class ConfirmReceiptPage extends StatefulWidget {
  final String requisitionId;

  const ConfirmReceiptPage({super.key, required this.requisitionId});

  @override
  _ConfirmReceiptPageState createState() => _ConfirmReceiptPageState();
}

class _ConfirmReceiptPageState extends State<ConfirmReceiptPage> {
  Map<String, dynamic>? _requisitionData;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<ReceivedItemController> _itemControllers = [];
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRequisitionDetails();
  }

  @override
  void dispose() {
    for (var controller in _itemControllers) {
      controller.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequisitionDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('requisitions')
          .doc(widget.requisitionId)
          .get();
      final data = doc.data();
      if (data != null && mounted) {
        final items = List<Map<String, dynamic>>.from(
          (data['items'] as List<dynamic>),
        );
        setState(() {
          _requisitionData = data;
          for (var item in items) {
            _itemControllers.add(
              ReceivedItemController(
                productName: item['productName'] as String,
                orderedQuantity: item['quantity'] as int,
              ),
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Replace the entire _confirmAndSave function with this

  // Replace this function in confirm_receipt_page.dart

  Future<void> _confirmAndSave() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return; // Exit if no user is logged in

      // ✅ ADDED: Fetch user details from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['displayName'] ?? 'Utilisateur inconnu';

      final originalItems = List<Map<String, dynamic>>.from(_requisitionData!['items']);
      bool hasDiscrepancy = false;
      final List<Map<String, dynamic>> receivedItemsData = [];

      for (int i = 0; i < originalItems.length; i++) {
        final receivedQty = int.tryParse(_itemControllers[i].receivedQuantityController.text) ?? 0;
        if (receivedQty != originalItems[i]['quantity']) {
          hasDiscrepancy = true;
        }
        receivedItemsData.add({
          'productId': originalItems[i]['productId'],
          'productName': originalItems[i]['productName'],
          'orderedQuantity': originalItems[i]['quantity'],
          'receivedQuantity': receivedQty,
        });
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // ... (The inner part of the transaction remains the same)
        final List<DocumentSnapshot> productSnaps = [];
        final List<DocumentReference> productRefs = [];
        for (var receivedItem in receivedItemsData) {
          final productRef = FirebaseFirestore.instance.collection('produits').doc(receivedItem['productId']);
          productRefs.add(productRef);
          final productSnap = await transaction.get(productRef);
          productSnaps.add(productSnap);
        }
        for (int i = 0; i < receivedItemsData.length; i++) {
          final receivedItem = receivedItemsData[i];
          final productRef = productRefs[i];
          final productSnap = productSnaps[i];
          final currentStock = (productSnap.data() as Map<String, dynamic>?)?['quantiteEnStock'] ?? 0;
          final newStock = currentStock + receivedItem['receivedQuantity'];
          transaction.update(productRef, {'quantiteEnStock': newStock});
          final historyRef = productRef.collection('stock_history').doc();
          transaction.set(historyRef, {
            'change': receivedItem['receivedQuantity'],
            'newQuantity': newStock,
            'notes': 'Réception de la commande (Demande ID: ${widget.requisitionId})',
            'timestamp': FieldValue.serverTimestamp(),
            'updatedByUid': user.uid,
          });
        }

        final requisitionRef = FirebaseFirestore.instance.collection('requisitions').doc(widget.requisitionId);
        // ✅ CHANGED: Use the name from Firestore
        final logEntry = {'action': hasDiscrepancy ? 'Reçue avec Écarts' : 'Reçue', 'user': userName, 'timestamp': Timestamp.now()};

        transaction.update(requisitionRef, {
          'status': hasDiscrepancy ? 'Reçue avec Écarts' : 'Reçue',
          'receivedItems': receivedItemsData,
          'discrepancyNotes': _notesController.text,
          'activityLog': FieldValue.arrayUnion([logEntry]),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réception confirmée et stock mis à jour!'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmer la Réception'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Articles Commandés',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _itemControllers.length,
              itemBuilder: (context, index) {
                final item = _itemControllers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Commandé: ${item.orderedQuantity}',
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: TextField(
                                controller: item
                                    .receivedQuantityController,
                                keyboardType:
                                TextInputType.number,
                                decoration:
                                const InputDecoration(
                                  labelText: 'Qté Reçue',
                                  border:
                                  OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText:
                'Notes sur les écarts (Optionnel)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving
                    ? null
                    : _confirmAndSave,
                icon: const Icon(
                  Icons.inventory_2_outlined,
                ),
                label: const Text(
                  'Confirmer et Mettre à Jour le Stock',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                  ),
                ),
              ),
            ),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child:
                Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

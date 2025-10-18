// lib/screens/administration/confirm_receipt_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ✅ CHANGED: This helper class is now much more powerful.
// It stores the product ID and tracks ordered vs. already received quantities.
class ReceivedItemController {
  final String productId;
  final String productName;
  final int orderedQuantity;
  final int alreadyReceivedQuantity;
  final TextEditingController receivedQuantityController;

  ReceivedItemController({
    required this.productId,
    required this.productName,
    required this.orderedQuantity,
    required this.alreadyReceivedQuantity,
  }) : receivedQuantityController = TextEditingController(
    // 🆕 ADDED: Default to 0 for a new shipment.
    text: '0',
  );

  void dispose() {
    receivedQuantityController.dispose();
  }

  // 🆕 ADDED: Helper to calculate remaining quantity.
  int get remainingQuantity => orderedQuantity - alreadyReceivedQuantity;
}

class ConfirmReceiptPage extends StatefulWidget {
  final String requisitionId;
  const ConfirmReceiptPage({super.key, required this.requisitionId});

  @override
  _ConfirmReceiptPageState createState() => _ConfirmReceiptPageState();
}

class _ConfirmReceiptPageState extends State<ConfirmReceiptPage> {
  // 🆕 ADDED: We no longer need _requisitionData, we just need the list of items.
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

  // ✅ CHANGED: This function now populates our new controller list.
  Future<void> _fetchRequisitionDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('requisitions')
          .doc(widget.requisitionId)
          .get();

      final data = doc.data();
      if (data != null && mounted) {
        // ✅ NEW ROBUST LOGIC TO HANDLE MAP OR LIST
        List<Map<String, dynamic>> itemsList = [];
        final dynamic itemsData = data['items'];

        if (itemsData is List) {
          // This is the correct, expected format (Array)
          itemsList = List<Map<String, dynamic>>.from(
              itemsData.map((item) => Map<String, dynamic>.from(item as Map)));
        } else if (itemsData is Map) {
          // This is the error format (Map), let's convert it
          itemsList = itemsData.values.map((item) {
            return Map<String, dynamic>.from(item as Map);
          }).toList();
        }

        // If itemsData is null or some other type, 'itemsList' will just be an empty list.
        setState(() {
          for (var item in itemsList) {
            final int orderedQty = item['orderedQuantity'] ?? item['quantity'] ?? 0;
            final int receivedQty = item['receivedQuantity'] ?? 0;
            if (receivedQty < orderedQty) {
              _itemControllers.add(
                ReceivedItemController(
                  productId: item['productId'] as String,
                  productName: item['productName'] as String,
                  orderedQuantity: orderedQty,
                  alreadyReceivedQuantity: receivedQty,
                ),
              );
            }
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

  // ✅ FIXED: Transaction now performs ALL READS BEFORE ALL WRITES
  Future<void> _confirmAndSave() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté.");

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['displayName'] ?? 'Utilisateur inconnu';

      final List<Map<String, dynamic>> itemsForThisShipment = [];
      final Map<String, int> stockUpdates = {};
      final Map<String, int> newTotalReceivedQuantities = {};
      bool hasItemsInThisShipment = false;
      final String notes = _notesController.text.trim();

      for (final itemController in _itemControllers) {
        final int newReceivedQty = int.tryParse(itemController.receivedQuantityController.text) ?? 0;
        if (newReceivedQty > 0) {
          hasItemsInThisShipment = true;
          itemsForThisShipment.add({
            'productId': itemController.productId,
            'productName': itemController.productName,
            'quantity': newReceivedQty,
          });
          stockUpdates[itemController.productId] = newReceivedQty;
        }
        newTotalReceivedQuantities[itemController.productId] =
            itemController.alreadyReceivedQuantity + newReceivedQty;
      }

      // ✅ --- NEW VALIDATION LOGIC --- ✅
      if (!hasItemsInThisShipment && notes.isEmpty) {
        throw Exception(
            "Vous devez saisir une quantité (> 0) OU ajouter une note explicative.");
      }

      // ✅ --- CRITICAL FIX: ALL READS BEFORE ALL WRITES --- ✅
      await FirebaseFirestore.instance.runTransaction((transaction) async {

        // ==================== PHASE 1: ALL READS ====================

        // Read 1: Get the requisition document
        final requisitionRef = FirebaseFirestore.instance
            .collection('requisitions')
            .doc(widget.requisitionId);
        final requisitionSnap = await transaction.get(requisitionRef);

        if (!requisitionSnap.exists) throw Exception("Demande introuvable.");

        final requisitionData = requisitionSnap.data()!;
        final List<Map<String, dynamic>> currentItems =
        List<Map<String, dynamic>>.from(requisitionData['items']);

        // Read 2: Get ALL product documents BEFORE any writes
        final Map<String, DocumentSnapshot> productSnapshots = {};
        if (hasItemsInThisShipment) {
          for (var entry in stockUpdates.entries) {
            final productId = entry.key;
            final productRef = FirebaseFirestore.instance
                .collection('produits')
                .doc(productId);
            final productSnap = await transaction.get(productRef);

            if (!productSnap.exists) {
              throw Exception("Produit $productId introuvable.");
            }

            productSnapshots[productId] = productSnap;
          }
        }

        // ==================== PHASE 2: PROCESS DATA ====================

        final List<Map<String, dynamic>> newItemsList = [];
        bool isFullyReceived = true;

        for (var item in currentItems) {
          final productId = item['productId'];
          final int orderedQty = item['orderedQuantity'] ?? item['quantity'] ?? 0;

          if (newTotalReceivedQuantities.containsKey(productId)) {
            final int newTotalReceived = newTotalReceivedQuantities[productId]!;
            newItemsList.add({
              ...item,
              'orderedQuantity': orderedQty,
              'receivedQuantity': newTotalReceived,
            });
            if (newTotalReceived < orderedQty) isFullyReceived = false;
          } else {
            newItemsList.add(item);
            final int receivedQty = item['receivedQuantity'] ?? 0;
            if (receivedQty < orderedQty) isFullyReceived = false;
          }
        }

        final String newStatus = isFullyReceived ? 'Reçue' : 'Partiellement Reçue';
        final String logAction = hasItemsInThisShipment
            ? 'Réception partielle'
            : 'Note de réception ajoutée';

        // ==================== PHASE 3: ALL WRITES ====================

        // Write 1: Create the new reception document
        final receptionRef = requisitionRef.collection('receptions').doc();
        transaction.set(receptionRef, {
          'receptionDate': Timestamp.now(),
          'receivedBy': userName,
          'notes': notes,
          'itemsInThisShipment': itemsForThisShipment,
        });

        // Write 2: Update product stocks (only if items were received)
        if (hasItemsInThisShipment) {
          for (var entry in stockUpdates.entries) {
            final productId = entry.key;
            final int receivedQty = entry.value;

            // Use the snapshot we already read in Phase 1
            final productSnap = productSnapshots[productId]!;
            final currentStock =
                (productSnap.data() as Map<String, dynamic>?)?['quantiteEnStock'] ?? 0;
            final newStock = currentStock + receivedQty;

            final productRef = FirebaseFirestore.instance
                .collection('produits')
                .doc(productId);

            transaction.update(productRef, {'quantiteEnStock': newStock});

            // Create stock history entry
            final historyRef = productRef.collection('stock_history').doc();
            transaction.set(historyRef, {
              'change': receivedQty,
              'newQuantity': newStock,
              'notes': 'Réception partielle (Demande ID: ${widget.requisitionId})',
              'timestamp': FieldValue.serverTimestamp(),
              'updatedByUid': user.uid,
            });
          }
        }

        // Write 3: Update the main requisition document
        final logEntry = {
          'action': logAction,
          'user': userName,
          'timestamp': Timestamp.now(),
        };

        final finalLogEntry = {
          'action': newStatus,
          'user': userName,
          'timestamp': Timestamp.now(),
        };

        transaction.update(requisitionRef, {
          'status': newStatus,
          'items': newItemsList,
          'activityLog': FieldValue.arrayUnion(
              isFullyReceived ? [logEntry, finalLogEntry] : [logEntry]),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réception enregistrée!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ✅ CHANGED: The UI is updated to be clearer.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enregistrer une Réception'),
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
              'Articles en attente',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_itemControllers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Tous les articles ont été reçus."),
                ),
              ),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'En attente: ${item.remainingQuantity} (Reçu: ${item.alreadyReceivedQuantity} / ${item.orderedQuantity})',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: item.receivedQuantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Qté Reçue (cette livraison)',
                            border: OutlineInputBorder(),
                          ),
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
                labelText: 'Notes de livraison (Optionnel)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving || _itemControllers.isEmpty
                    ? null
                    : _confirmAndSave,
                icon: const Icon(Icons.check),
                label: const Text('Enregistrer la Réception'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
              ),
            ),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

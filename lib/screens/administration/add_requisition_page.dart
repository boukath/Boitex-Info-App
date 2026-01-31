// lib/screens/administration/add_requisition_page.dart

import 'dart:ui'; // For Glassmorphism
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // For Haptics

// ✅ IMPORT GLOBAL SEARCH
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';

// Helper class to manage items in the requisition list
class RequisitionItem {
  final DocumentSnapshot productDoc;
  final int quantity;

  RequisitionItem({required this.productDoc, required this.quantity});

  String get name => productDoc['nom'];
  String get id => productDoc.id;

  // Helper to safely get image
  String? get imageUrl {
    final data = productDoc.data() as Map<String, dynamic>?;
    if (data != null &&
        data.containsKey('imageUrls') &&
        (data['imageUrls'] is List) &&
        (data['imageUrls'] as List).isNotEmpty) {
      return (data['imageUrls'] as List).first;
    }
    return null;
  }

  // Helper to get brand
  String get brand {
    final data = productDoc.data() as Map<String, dynamic>?;
    return data?['marque'] ?? 'Marque inconnue';
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': id,
      'productName': name,
      if (imageUrl != null) 'productImage': imageUrl,
      'orderedQuantity': quantity,
      'receivedQuantity': 0, // Assume 0 when creating/updating
    };
  }
}

class AddRequisitionPage extends StatefulWidget {
  // Optional parameter to accept an existing requisition ID for editing
  final String? requisitionId;

  const AddRequisitionPage({super.key, this.requisitionId});

  @override
  State<AddRequisitionPage> createState() => _AddRequisitionPageState();
}

class _AddRequisitionPageState extends State<AddRequisitionPage> {
  final _formKey = GlobalKey<FormState>();

  // ✅ NEW: Controllers for Title and Supplier
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();

  // ✅ NEW: List to store unique brands/suppliers fetched from products
  List<String> _knownSuppliers = [];

  final List<RequisitionItem> _items = [];
  bool _isLoading = false;
  late bool _isEditMode;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.requisitionId != null;

    // ✅ NEW: Fetch known suppliers (marques) for autocomplete
    _fetchKnownSuppliers();

    if (_isEditMode) {
      _loadExistingRequisition();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  // ✅ NEW: Logic to get unique "marque" values from "produits" collection
  Future<void> _fetchKnownSuppliers() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('produits')
          .limit(500)
          .get();

      final Set<String> brands = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('marque') && data['marque'] != null) {
          final String brand = data['marque'].toString().trim();
          if (brand.isNotEmpty) {
            brands.add(brand);
          }
        }
      }

      if (mounted) {
        setState(() {
          _knownSuppliers = brands.toList()..sort();
        });
      }
    } catch (e) {
      debugPrint("Erreur lors du chargement des fournisseurs: $e");
    }
  }

  Future<void> _loadExistingRequisition() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('requisitions')
          .doc(widget.requisitionId!)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Demande non trouvée.')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      // ✅ NEW: Populate controllers from existing data
      _titleController.text = data['title'] ?? '';
      _supplierController.text = data['supplierName'] ?? '';

      final itemsFromDb = List<Map<String, dynamic>>.from(data['items'] ?? []);

      for (var itemMap in itemsFromDb) {
        final productDoc = await FirebaseFirestore.instance
            .collection('produits')
            .doc(itemMap['productId'])
            .get();

        if (productDoc.exists) {
          _items.add(RequisitionItem(
            productDoc: productDoc,
            quantity: itemMap['orderedQuantity'],
          ));
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  void _openProductSearch() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GlobalProductSearchPage(
          isSelectionMode: true,
          onProductSelected: (productMap) async {
            final String productId = productMap['productId'];
            final int quantity = productMap['quantity'] ?? 1;

            if (_items.any((item) => item.id == productId)) {
              return;
            }

            try {
              final doc = await FirebaseFirestore.instance
                  .collection('produits')
                  .doc(productId)
                  .get();

              if (doc.exists && mounted) {
                setState(() {
                  _items.add(RequisitionItem(
                    productDoc: doc,
                    quantity: quantity,
                  ));
                });
                HapticFeedback.mediumImpact();
              }
            } catch (e) {
              debugPrint("Error fetching product details: $e");
            }
          },
        ),
      ),
    );
  }

  Future<void> _showEditItemQuantityDialog(int index) async {
    final item = _items[index];
    final quantityController =
    TextEditingController(text: item.quantity.toString());

    final newQuantity = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Modifier Quantité'),
          content: TextFormField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantité',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            autofocus: true,
            validator: (v) {
              return (int.tryParse(v ?? '') ?? 0) <= 0
                  ? 'Quantité requise'
                  : null;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final int? qty = int.tryParse(quantityController.text);
                if (qty != null && qty > 0) {
                  Navigator.of(context).pop(qty);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Veuillez entrer une quantité valide.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    if (newQuantity != null && newQuantity > 0) {
      final updatedItem = RequisitionItem(
        productDoc: item.productDoc,
        quantity: newQuantity,
      );
      setState(() {
        _items.removeAt(index);
        _items.insert(index, updatedItem);
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _submitRequisition() async {
    // ✅ NEW: Validate that title is entered
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un objet pour la demande.')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins un produit.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();

    if (_isEditMode) {
      await _updateRequisition();
    } else {
      await _createNewRequisition();
    }
  }

  Future<void> _updateRequisition() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName = userDoc.data()?['displayName'] ?? 'Utilisateur Inconnu';

      final itemsJson = _items.map((item) => item.toJson()).toList();

      final logEntry = {
        'action': 'Modification',
        'user': userName,
        'timestamp': Timestamp.now(),
        'details': 'La liste des articles a été modifiée.'
      };

      await FirebaseFirestore.instance
          .collection('requisitions')
          .doc(widget.requisitionId)
          .update({
        // ✅ NEW: Save new fields
        'title': _titleController.text.trim(),
        'supplierName': _supplierController.text.trim(),
        'items': itemsJson,
        'activityLog': FieldValue.arrayUnion([logEntry]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande modifiée avec succès.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewRequisition() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté.');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName = userDoc.data()?['displayName'] ?? 'Utilisateur Inconnu';
      final userRole = userDoc.data()?['role'] ?? 'Inconnu';

      // Use a Transaction to safely increment ID (Best Practice)
      final String requisitionCode = await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterDocRef = FirebaseFirestore.instance
            .collection('counters')
            .doc('requisition_counter');

        final counterSnapshot = await transaction.get(counterDocRef);
        int nextId = 1;
        if (counterSnapshot.exists) {
          nextId = (counterSnapshot.data()?['currentId'] ?? 0) + 1;
        }
        transaction.set(counterDocRef, {'currentId': nextId}, SetOptions(merge: true));
        return 'CM-${DateTime.now().year}-${nextId.toString().padLeft(4, '0')}';
      });

      final itemsJson = _items.map((item) => item.toJson()).toList();

      final newRequisition = {
        'requisitionCode': requisitionCode,
        // ✅ NEW: Save new fields
        'title': _titleController.text.trim(),
        'supplierName': _supplierController.text.trim(),
        'requestedBy': userName,
        'requestedById': user.uid,
        'requestedByRole': userRole,
        'status': "En attente d'approbation",
        'createdAt': Timestamp.now(),
        'items': itemsJson,
        'activityLog': [
          {
            'action': 'Création',
            'user': userName,
            'timestamp': Timestamp.now(),
          }
        ],
      };

      await FirebaseFirestore.instance
          .collection('requisitions')
          .add(newRequisition);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande soumise avec succès.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  // ===========================================================================
  // ✨ PREMIUM UI IMPLEMENTATION START
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Key for premium glass feel
      body: Stack(
        children: [
          // 1. Animated Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFAFAFA), // Pure White
                  Color(0xFFF5F7FA), // Soft Blue-Grey
                  Color(0xFFE8EAF6), // Very light Indigo
                ],
              ),
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPremiumAppBar(),

                // --- Title Input (Headline Style) ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                  child: TextFormField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A237E),
                      letterSpacing: -0.5,
                    ),
                    decoration: InputDecoration(
                      hintText: "Objet de la demande...",
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),

                // --- Supplier Input (Autocomplete) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text == '') return const Iterable<String>.empty();
                            return _knownSuppliers.where((String option) {
                              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                            });
                          },
                          onSelected: (String selection) {
                            _supplierController.text = selection;
                          },
                          fieldViewBuilder: (context, fieldTextEditingController, fieldFocusNode, onFieldSubmitted) {
                            if (_supplierController.text.isNotEmpty && fieldTextEditingController.text.isEmpty) {
                              fieldTextEditingController.text = _supplierController.text;
                            }
                            return TextField(
                              controller: fieldTextEditingController,
                              focusNode: fieldFocusNode,
                              style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                hintText: "Fournisseur / Marque (Optionnel)",
                                hintStyle: TextStyle(color: Colors.grey.shade500),
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.store_mall_directory_rounded, color: Colors.blue.shade300, size: 20),
                                contentPadding: const EdgeInsets.only(top: 14), // Align text with icon
                              ),
                              onChanged: (val) => _supplierController.text = val,
                            );
                          },
                        );
                      }
                  ),
                ),

                const Divider(height: 1, indent: 24, endIndent: 24),
                const SizedBox(height: 10),

                // --- The List ---
                Expanded(
                  child: _items.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), // Bottom padding for dock
                    itemCount: _items.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _buildPremiumCard(index);
                    },
                  ),
                ),
              ],
            ),
          ),

          // 3. Floating Glass Dock
          Positioned(
            left: 20, right: 20, bottom: 30,
            child: _buildFloatingDock(),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            _isEditMode ? 'Modifier' : 'Nouveau',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_shopping_cart_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Votre panier est vide",
            style: TextStyle(fontSize: 18, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            "Ajoutez des produits pour commencer",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(int index) {
    final item = _items[index];
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeItem(index),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 30),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 30),
      ),
      child: GestureDetector(
        onTap: () => _showEditItemQuantityDialog(index),
        child: Container(
          height: 110, // Tall Card
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left: Image
              Container(
                width: 90,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                  color: Colors.grey.shade50,
                  image: item.imageUrl != null
                      ? DecorationImage(image: NetworkImage(item.imageUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: item.imageUrl == null
                    ? Icon(Icons.image_not_supported_rounded, color: Colors.grey.shade300, size: 30)
                    : null,
              ),

              // Middle: Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D3436),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.brand,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),

              // Right: Quantity Pill
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8EAF6), // Soft Indigo
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        "${item.quantity}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Discrete Remove Button
              IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade400),
                onPressed: () => _removeItem(index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingDock() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              // Search Button
              InkWell(
                onTap: _openProductSearch,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  height: 56, width: 56,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                    ],
                  ),
                  child: const Icon(Icons.search_rounded, color: Colors.black87, size: 28),
                ),
              ),
              const SizedBox(width: 12),

              // Submit Button
              Expanded(
                child: InkWell(
                  onTap: _isLoading ? null : _submitRequisition,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)]),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A237E).withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                      _isEditMode ? "SAUVEGARDER" : "SOUMETTRE LA DEMANDE",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// lib/screens/administration/direct_import_page.dart

import 'dart:io';
import 'dart:async';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:intl/intl.dart';

// ✅ IMPORTS
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';
import 'package:boitex_info_app/screens/administration/add_product_page.dart';
import 'package:boitex_info_app/services/zebra_service.dart';

// ==========================================
// DATA MODEL
// ==========================================
class ImportItem {
  final String id;
  final String existingProductId;
  final String name;
  final int quantity;
  final String? brand;
  final String? imageUrl;
  final bool isJustCreated;

  ImportItem({
    required this.id,
    required this.existingProductId,
    required this.name,
    required this.quantity,
    this.brand,
    this.imageUrl,
    this.isJustCreated = false,
  });
}

class DirectImportPage extends StatefulWidget {
  const DirectImportPage({super.key});

  @override
  State<DirectImportPage> createState() => _DirectImportPageState();
}

class _DirectImportPageState extends State<DirectImportPage> with TickerProviderStateMixin {
  final TextEditingController _sourceController = TextEditingController();
  final List<ImportItem> _items = [];
  bool _isLoading = false;
  bool _isProcessingScan = false;

  StreamSubscription? _scanSubscription;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _setupScanListener();

    // Radar Pulse Animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _sourceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ==========================================
  // LOGIC METHODS
  // ==========================================

  void _setupScanListener() {
    try {
      _scanSubscription = ZebraService().onScan.listen((barcode) {
        if (!_isProcessingScan && mounted) {
          _handleScannedBarcode(barcode);
        }
      });
    } catch (e) {
      debugPrint("PDA Scanner not available: $e");
    }
  }

  Future<void> _handleScannedBarcode(String barcode) async {
    setState(() => _isProcessingScan = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('produits')
          .where('code_barre', isEqualTo: barcode)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        HapticFeedback.mediumImpact();
        final doc = query.docs.first;
        final data = doc.data();
        final existingIndex = _items.indexWhere((item) => item.existingProductId == doc.id);

        if (existingIndex != -1) {
          _showScanActionDialog(
              title: "Produit déjà listé",
              content: "Ajouter combien ?",
              onConfirm: (qty) {
                final currentItem = _items[existingIndex];
                setState(() {
                  _items[existingIndex] = ImportItem(
                    id: currentItem.id,
                    existingProductId: currentItem.existingProductId,
                    name: currentItem.name,
                    quantity: currentItem.quantity + qty,
                    brand: currentItem.brand,
                    imageUrl: currentItem.imageUrl,
                    isJustCreated: currentItem.isJustCreated,
                  );
                });
              }
          );
        } else {
          String? imgUrl;
          if (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty) {
            imgUrl = (data['imageUrls'] as List).first;
          }
          _showScanActionDialog(
              title: "Produit Trouvé",
              content: "Ajouter '${data['nom']}' ? Quantité ?",
              onConfirm: (qty) {
                setState(() {
                  _items.add(ImportItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    existingProductId: doc.id,
                    name: data['nom'] ?? 'Inconnu',
                    quantity: qty,
                    imageUrl: imgUrl,
                    brand: data['marque'],
                  ));
                });
              }
          );
        }
      } else {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Code $barcode inconnu. Création..."), backgroundColor: Colors.orange)
        );
        await Future.delayed(const Duration(milliseconds: 500));
        if(mounted) _launchAddProductPage(scannedCode: barcode);
      }
    } catch (e) { debugPrint("Error: $e"); }
    finally { if (mounted) setState(() => _isProcessingScan = false); }
  }

  void _showScanActionDialog({required String title, required String content, required Function(int) onConfirm}) {
    final qtyController = TextEditingController(text: "1");
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(content),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "Quantité",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(qtyController.text) ?? 0;
                if (qty > 0) { onConfirm(qty); Navigator.pop(ctx); }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Ajouter"),
            ),
          ],
        )
    );
  }

  void _addExistingProduct() {
    Navigator.pop(context); // close sheet
    Navigator.push(context, MaterialPageRoute(builder: (_) => GlobalProductSearchPage(
      isSelectionMode: true,
      onProductSelected: (productMap) async {
        final pid = productMap['productId'];
        final qty = productMap['quantity'] ?? 1;
        final doc = await FirebaseFirestore.instance.collection('produits').doc(pid).get();
        if (doc.exists) {
          final d = doc.data()!;
          String? img;
          if (d['imageUrls'] != null && (d['imageUrls'] as List).isNotEmpty) {
            img = (d['imageUrls'] as List).first;
          }

          setState(() {
            _items.add(ImportItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              existingProductId: pid,
              name: d['nom'] ?? 'Inconnu',
              quantity: qty,
              imageUrl: img,
              brand: d['marque'],
            ));
          });
        }
      },
    )));
  }

  void _launchAddProductPage({String? scannedCode}) async {
    // Basic check to close sheet if open manually
    if (scannedCode == null && Navigator.canPop(context)) {
      // Navigator.pop(context); // Optional depending on flow
    }

    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddProductPage(scannedCode: scannedCode),
    ));

    if (result != null && result is Map<String, dynamic>) {
      if (mounted) {
        setState(() {
          _items.add(ImportItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            existingProductId: result['productId'],
            name: result['name'] ?? 'Nouveau',
            quantity: 1,
            imageUrl: result['imageUrl'],
            brand: result['brand'],
            isJustCreated: true,
          ));
        });
      }
    }
  }

  void _editQuantity(int index) async {
    final item = _items[index];
    final controller = TextEditingController(text: item.quantity.toString());
    final newQty = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Modifier Quantité"),
          content: TextField(
            controller: controller, keyboardType: TextInputType.number, autofocus: true,
            decoration: InputDecoration(suffixText: "unités", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
            ElevatedButton(
                onPressed: () {
                  final val = int.tryParse(controller.text);
                  if(val != null && val > 0) Navigator.pop(ctx, val);
                },
                child: const Text("Valider")
            ),
          ],
        )
    );
    if (newQty != null) {
      setState(() {
        _items[index] = ImportItem(
            id: item.id, existingProductId: item.existingProductId, name: item.name,
            quantity: newQty, brand: item.brand, imageUrl: item.imageUrl, isJustCreated: item.isJustCreated
        );
      });
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _submitImport() async {
    if (_items.isEmpty || _sourceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liste vide ou Contexte manquant'), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.runTransaction((transaction) async {

        // 1. Generate ID (Safe Syntax Fix)
        final counterRef = FirebaseFirestore.instance.collection('counters').doc('direct_import_counter');
        final counterDoc = await transaction.get(counterRef);

        int nextId = 1;
        if (counterDoc.exists) {
          final data = counterDoc.data();
          if (data is Map<String, dynamic>) {
            nextId = (data['currentId'] ?? 0) + 1;
          }
        }

        transaction.set(counterRef, {'currentId': nextId}, SetOptions(merge: true));

        final code = 'AD-${DateTime.now().year}-${nextId.toString().padLeft(4, '0')}';

        // 2. Prepare Items
        final itemsList = _items.map((i) => {
          'productId': i.existingProductId, 'productName': i.name,
          'orderedQuantity': i.quantity, 'receivedQuantity': i.quantity,
          'productImage': i.imageUrl, 'brand': i.brand
        }).toList();

        // 3. Create Requisition
        final reqRef = FirebaseFirestore.instance.collection('requisitions').doc();
        transaction.set(reqRef, {
          'requisitionCode': code,
          'title': _sourceController.text.trim(),
          'source': _sourceController.text.trim(),
          'supplierName': 'Import Direct',
          'requestedBy': user?.displayName ?? 'Admin',
          'requestedById': user?.uid,
          'status': 'Reçue',
          'createdAt': FieldValue.serverTimestamp(),
          'receivedAt': FieldValue.serverTimestamp(),
          'items': itemsList,
          'isDirectImport': true,
          'activityLog': [{'action': 'Import Direct', 'user': user?.displayName, 'timestamp': Timestamp.now()}]
        });

        // 4. Update Stock
        for (var i in _items) {
          transaction.update(FirebaseFirestore.instance.collection('produits').doc(i.existingProductId), {
            'stock': FieldValue.increment(i.quantity)
          });
        }
      });

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
      }
    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
      }
    }
  }

  // --- UI START ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFAFAFA),
                  Color(0xFFF5F7FA),
                  Color(0xFFE8EAF6),
                ],
              ),
            ),
          ),

          // 2. Content
          SafeArea(
            child: Column(
              children: [
                _buildPremiumAppBar(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: TextField(
                    controller: _sourceController,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A237E),
                      letterSpacing: -0.5,
                    ),
                    decoration: InputDecoration(
                      hintText: "Nom de l'import...",
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),

                const Divider(height: 1, indent: 24, endIndent: 24),

                Expanded(
                  child: _items.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    itemCount: _items.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildPremiumCard(item, index);
                    },
                  ),
                ),
              ],
            ),
          ),

          // 3. Dock
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                FadeTransition(
                  opacity: _pulseController,
                  child: const Icon(Icons.sensors, color: Colors.green, size: 16),
                ),
                const SizedBox(width: 6),
                const Text(
                  "SCAN READY",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.green,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
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
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Prêt à scanner",
            style: TextStyle(fontSize: 18, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            "Utilisez le PDA ou le bouton +",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(ImportItem item, int index) {
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
        onTap: () => _editQuantity(index),
        child: Container(
          height: 120, // Tall Card
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
                width: 100,
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
                      if (item.isJustCreated)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.purple, Colors.deepPurple]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "NOUVEAU",
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
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
                        item.brand ?? "Marque inconnue",
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
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EAF6), // Soft Indigo
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
                    const SizedBox(height: 4),
                    const Text("unités", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),

              // Delete Button
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
              InkWell(
                onTap: _showAddOptionsSheet,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  height: 56, width: 56,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0,4))
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.black87, size: 28),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: InkWell(
                  onTap: _items.isEmpty || _isLoading ? null : _submitImport,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: _items.isEmpty
                          ? LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400])
                          : const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)]),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        if (!_items.isEmpty)
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
                      "VALIDER (${_items.length})",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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

  void _showAddOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOptionTile(
              icon: Icons.search_rounded, color: Colors.blue,
              title: "Produit Existant", subtitle: "Rechercher dans la base",
              onTap: _addExistingProduct,
            ),
            const SizedBox(height: 16),
            _buildOptionTile(
              icon: Icons.add_circle_outline_rounded, color: Colors.purple,
              title: "Nouveau Produit", subtitle: "Créer et ajouter",
              onTap: () { Navigator.pop(context); _launchAddProductPage(); },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ])),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
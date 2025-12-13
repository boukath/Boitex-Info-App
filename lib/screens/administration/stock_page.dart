// lib/screens/administration/stock_page.dart

import 'dart:async'; // ✅ ADDED for Timer
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:boitex_info_app/screens/administration/stock_category_list_page.dart';
import 'package:boitex_info_app/screens/administration/add_requisition_page.dart';
import 'package:boitex_info_app/screens/administration/product_scanner_page.dart';
import 'package:boitex_info_app/screens/administration/antivol_config/antivol_main_page.dart';
import 'package:boitex_info_app/screens/administration/inventory_report_page.dart';
import 'package:boitex_info_app/screens/administration/stock_audit_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';

class MainCategory {
  final String name;
  final IconData icon;
  final Color color;

  MainCategory({required this.name, required this.icon, required this.color});
}

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // 🔥 1. ZEBRA/YOKOSCAN VARIABLES
  final StringBuffer _keyBuffer = StringBuffer();
  Timer? _bufferTimer;

  final List<MainCategory> _mainCategories = [
    MainCategory(
        name: 'Antivol',
        icon: Icons.shield_rounded,
        color: const Color(0xFF667EEA)),
    MainCategory(
        name: 'TPV',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFFEC4899)),
    MainCategory(
        name: 'Compteur Client',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF10B981)),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    // 🔥 Clean up timer
    _bufferTimer?.cancel();
    super.dispose();
  }

  // 🔥 2. HARDWARE KEY LISTENER (Engine B)
  void _onKeyEvent(KeyEvent event) {
    // Only handle Key Down events
    if (event is! KeyDownEvent) return;

    final String? character = event.character;

    // Detect "Enter" key (Scan complete)
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_keyBuffer.isNotEmpty) {
        String scanData = _keyBuffer.toString().trim();
        _keyBuffer.clear();
        print("ZEBRA SCAN DETECTED: $scanData");
        // Instantly trigger the exact same logic as the camera scanner
        _handleScannedBarcode(scanData);
      }
      return;
    }

    // Accumulate characters
    if (character != null && character.isNotEmpty) {
      _keyBuffer.write(character);
      // Reset timer: if no key for 200ms, clear buffer (prevents random typing interference)
      _bufferTimer?.cancel();
      _bufferTimer = Timer(const Duration(milliseconds: 200), () {
        _keyBuffer.clear();
      });
    }
  }

  // ✅ 3. BUILD METHOD (Wrapped in Focus for Listener)
  @override
  Widget build(BuildContext context) {
    // 🛡️ WRAP SCAFFOLD IN FOCUS TO CATCH HARDWARE SCANNER INPUT
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _onKeyEvent(event);
        return KeyEventResult.handled; // Prevent keys from typing in search bar
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.purple.shade50,
                Colors.pink.shade50,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildSearchBar(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _searchQuery.isNotEmpty
                        ? _buildSearchResults()
                        : _buildMainCategories(),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const AddRequisitionPage()),
              );
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            label: const Text('Demande d\'Achat',
                style: TextStyle(fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.add_shopping_cart_rounded),
          ),
        ),
      ),
    );
  }

  // --- 4. SEARCH FUNCTION ---
  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final queryLower = query.toLowerCase();
      final snapshot =
      await FirebaseFirestore.instance.collection('produits').get();

      final results = snapshot.docs.where((doc) {
        final data = doc.data();
        final productName = (data['nom'] ?? '').toString().toLowerCase();
        final reference = (data['reference'] ?? '').toString().toLowerCase();
        final category = (data['categorie'] ?? '').toString().toLowerCase();
        return productName.contains(queryLower) ||
            reference.contains(queryLower) ||
            category.contains(queryLower);
      }).toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de recherche: $e')),
        );
      }
    }
  }

  // ✅ 5. SECURE RESET FUNCTION (ADMIN ONLY)
  Future<void> _resetAllStock() async {
    final String? role = await UserRoles.getCurrentUserRole();
    print("🚨 DEBUG ROLE: Actuel='$role' vs Attendu='${UserRoles.admin}'");

    if (role != UserRoles.admin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⛔ Accès Refusé : Seul l\'Administrateur peut réinitialiser le stock.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    const String signatureName = UserRoles.admin;

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ DANGER: RESET TOTAL'),
        content: const Text(
            'Voulez-vous vraiment mettre TOUT le stock à 0 ?\n\nCette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OUI, TOUT EFFACER'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final db = FirebaseFirestore.instance;
      final snapshot = await db.collection('produits').get();

      int batchCount = 0;
      WriteBatch batch = db.batch();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'quantiteEnStock': 0,
          'lastModifiedBy': signatureName,
          'lastModifiedAt': FieldValue.serverTimestamp(),
        });

        final historyRef = db.collection('stock_movements').doc();
        batch.set(historyRef, {
          'productId': doc.id,
          'productName': doc.data()['nom'] ?? 'Produit',
          'quantityChange': -(doc.data()['quantiteEnStock'] ?? 0),
          'oldQuantity': doc.data()['quantiteEnStock'] ?? 0,
          'newQuantity': 0,
          'type': 'RESET',
          'user': signatureName,
          'notes': 'Reset Total',
          'timestamp': FieldValue.serverTimestamp(),
        });

        batchCount++;

        if (batchCount >= 200) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      if (mounted) {
        Navigator.pop(context);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('✅ Stock réinitialisé à 0 avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        String errorMsg = e.toString();
        if (errorMsg.contains("PERMISSION_DENIED")) {
          errorMsg = "Erreur de Permission: Vos règles de base de données exigent peut-être votre vrai nom.";
        }
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // 🔥 6. SHARED LOGIC: HANDLE BARCODE (FROM CAMERA OR LASER)
  Future<void> _handleScannedBarcode(String scannedCode) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Show loading only if triggered by laser (Camera already has its UI)
      if (mounted) {
        // HapticFeedback.mediumImpact(); // Optional feedback
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('reference', isEqualTo: scannedCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final productDoc = querySnapshot.docs.first;
        final productData = productDoc.data();
        final productName = productData['nom'] ?? 'Nom inconnu';
        final int currentStock = productData['quantiteEnStock'] ?? 0;

        final quantityController = TextEditingController(text: currentStock.toString());
        final notesController = TextEditingController();

        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_scanner, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    productName,
                    style: const TextStyle(fontSize: 18),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Stock actuel: $currentStock',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Nouvelle Quantité',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Valider'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final int newQty = int.tryParse(quantityController.text) ?? currentStock;
                  final String notes = notesController.text.trim();

                  if (newQty == currentStock) {
                    Navigator.of(ctx).pop();
                    return;
                  }

                  final authUser = FirebaseAuth.instance.currentUser;
                  final userId = authUser?.uid ?? 'unknown';
                  String userName = 'Utilisateur';

                  if (authUser != null) {
                    try {
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .get();

                      if (userDoc.exists) {
                        final data = userDoc.data();
                        if (data != null) {
                          userName = data['displayName'] ??
                              data['fullName'] ??
                              'Utilisateur';
                        }
                      } else {
                        userName = authUser.displayName ?? 'Utilisateur';
                      }
                    } catch (e) {
                      print("Error fetching user name: $e");
                    }
                  }

                  final db = FirebaseFirestore.instance;
                  final ledgerRef = db.collection('stock_movements').doc();

                  try {
                    await db.runTransaction((transaction) async {
                      transaction.set(ledgerRef, {
                        'productId': productDoc.id,
                        'productRef': productData['reference'] ?? 'N/A',
                        'productName': productName,
                        'quantityChange': newQty - currentStock,
                        'oldQuantity': currentStock,
                        'newQuantity': newQty,
                        'type': 'SCAN_ADJUST',
                        'notes': notes.isEmpty ? 'Scan rapide' : notes,
                        'userId': userId,
                        'user': userName,
                        'userDisplayName': userName,
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      transaction.update(productDoc.reference, {
                        'quantiteEnStock': newQty,
                        'lastModifiedBy': userName,
                        'lastModifiedAt': FieldValue.serverTimestamp(),
                      });
                    });

                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Stock mis à jour par $userName!'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text('Produit non trouvé pour: $scannedCode'),
              backgroundColor: Colors.orange
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  // --- 7. CAMERA SCANNER TRIGGER ---
  Future<void> _scanProduct(BuildContext context) async {
    final String? scannedCode = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProductScannerPage()),
    );

    if (scannedCode == null || scannedCode.isEmpty) return;

    // Reuse the shared logic!
    _handleScannedBarcode(scannedCode);
  }

  // --- 8. HELPER WIDGETS ---

  PopupMenuItem<dynamic> _buildMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color color = const Color(0xFF1F2937),
    Color iconColor = const Color(0xFF667EEA),
  }) {
    return PopupMenuItem(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Stock',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Scanner Button (Camera)
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
              tooltip: 'Scanner un produit (Caméra)',
              onPressed: () => _scanProduct(context),
            ),
          ),
          const SizedBox(width: 8),

          // Menu Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: PopupMenuButton<dynamic>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              offset: const Offset(0, 50),
              tooltip: 'Options',
              itemBuilder: (context) => <PopupMenuEntry<dynamic>>[
                _buildMenuItem(
                  icon: Icons.assessment_outlined,
                  text: 'Rapport d\'Inventaire',
                  onTap: () {
                    Future.delayed(Duration.zero, () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const InventoryReportPage(),
                        ),
                      );
                    });
                  },
                ),
                _buildMenuItem(
                  icon: Icons.history_outlined,
                  text: 'Audit des Mouvements',
                  onTap: () {
                    Future.delayed(Duration.zero, () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const StockAuditPage(),
                        ),
                      );
                    });
                  },
                ),
                _buildMenuItem(
                  icon: Icons.tune_rounded,
                  text: 'Configuration Antivol',
                  onTap: () {
                    Future.delayed(Duration.zero, () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const AntivolMainPage()),
                      );
                    });
                  },
                ),
                const PopupMenuDivider(),
                _buildMenuItem(
                  icon: Icons.delete_forever_rounded,
                  text: 'RESET TOUT LE STOCK',
                  color: Colors.red,
                  iconColor: Colors.red,
                  onTap: _resetAllStock,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.9),
              Colors.white.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() => _searchQuery = value);
            _searchProducts(value);
          },
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
          decoration: InputDecoration(
            hintText: 'Rechercher un produit, référence ou catégorie...',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.search_rounded,
                  color: Colors.white, size: 20),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 18, color: Color(0xFF1F2937)),
              ),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _searchResults = [];
                });
              },
            )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.7),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Recherche en cours...',
              style: TextStyle(
                color: Color(0xFF667EEA),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.shade100.withOpacity(0.5),
                    Colors.orange.shade50.withOpacity(0.3),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 80,
                color: Colors.orange.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun résultat',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Aucun produit trouvé pour "$_searchQuery"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final doc = _searchResults[index];
        final data = doc.data() as Map<String, dynamic>;
        final productName = data['nom'] ?? 'Sans nom';
        final reference = data['reference'] ?? 'N/A';
        final stock = data['quantiteEnStock'] ?? 0;
        final mainCategory = data['mainCategory'] ?? 'N/A';
        final category = data['categorie'] ?? 'N/A';

        Color categoryColor = const Color(0xFF667EEA);
        IconData categoryIcon = Icons.inventory_2_rounded;

        if (mainCategory == 'Antivol') {
          categoryColor = const Color(0xFF667EEA);
          categoryIcon = Icons.shield_rounded;
        } else if (mainCategory == 'TPV') {
          categoryColor = const Color(0xFFEC4899);
          categoryIcon = Icons.point_of_sale_rounded;
        } else if (mainCategory == 'Compteur Client') {
          categoryColor = const Color(0xFF10B981);
          categoryIcon = Icons.people_rounded;
        }

        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: categoryColor.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [categoryColor, categoryColor.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: categoryColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(categoryIcon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.qr_code_rounded,
                                size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              reference,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$mainCategory > $category',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: categoryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: stock > 0
                            ? [
                          const Color(0xFF10B981),
                          const Color(0xFF059669)
                        ]
                            : [
                          const Color(0xFFEF4444),
                          const Color(0xFFDC2626)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (stock > 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444))
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '$stock',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainCategories() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _mainCategories.length,
      itemBuilder: (context, index) {
        final mainCategory = _mainCategories[index];
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 100)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: mainCategory.color.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => StockCategoryListPage(
                        mainCategory: mainCategory.name,
                        mainCategoryColor: mainCategory.color,
                        mainCategoryIcon: mainCategory.icon,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              mainCategory.color,
                              mainCategory.color.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: mainCategory.color.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          mainCategory.icon,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mainCategory.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Voir le stock',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: mainCategory.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 18,
                          color: mainCategory.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
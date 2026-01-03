// lib/screens/administration/stock_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

// ✅ SERVICES & MODELS
import 'package:boitex_info_app/services/inventory_service.dart';
import 'package:boitex_info_app/services/stock_service.dart';
import 'package:boitex_info_app/models/inventory_session.dart';

// ✅ SCREENS
import 'package:boitex_info_app/screens/administration/stock_category_list_page.dart';
import 'package:boitex_info_app/screens/administration/add_requisition_page.dart';
import 'package:boitex_info_app/screens/administration/product_scanner_page.dart';
import 'package:boitex_info_app/screens/administration/antivol_config/antivol_main_page.dart';
import 'package:boitex_info_app/screens/administration/inventory_report_page.dart';
import 'package:boitex_info_app/screens/administration/stock_audit_page.dart';
import 'package:boitex_info_app/screens/administration/inventory_session_page.dart';
import 'package:boitex_info_app/screens/administration/inventory_approval_list_page.dart';
import 'package:boitex_info_app/screens/service_technique/add_sav_ticket_page.dart';
import 'package:boitex_info_app/screens/administration/add_product_page.dart';

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
  // --- UI STATE ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // --- HARDWARE SCANNER STATE ---
  final StringBuffer _keyBuffer = StringBuffer();
  Timer? _bufferTimer;

  // --- 📦 MODES STATE ---
  bool _isInventoryMode = false;
  bool _isReturnMode = false;

  String? _currentSessionId;
  String? _currentScope;

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

    _checkActiveSession();
  }

  void _checkActiveSession() {
    InventoryService().getActiveSession().listen((session) {
      if (mounted) {
        setState(() {
          if (session != null) {
            _isInventoryMode = true;
            _isReturnMode = false;
            _currentSessionId = session.id;
            _currentScope = session.scope;
          } else {
            _isInventoryMode = false;
            _currentSessionId = null;
            _currentScope = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _bufferTimer?.cancel();
    super.dispose();
  }

  // 🔥 HARDWARE KEY LISTENER
  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final String? character = event.character;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_keyBuffer.isNotEmpty) {
        String scanData = _keyBuffer.toString().trim();
        _keyBuffer.clear();
        print("ZEBRA SCAN DETECTED: $scanData");

        if (_isInventoryMode) {
          _handleInventoryScan(scanData);
        } else if (_isReturnMode) {
          _handleReturnScan(scanData);
        } else {
          _handleLiveStockUpdate(scanData);
        }
      }
      return;
    }

    if (character != null && character.isNotEmpty) {
      _keyBuffer.write(character);
      _bufferTimer?.cancel();
      _bufferTimer = Timer(const Duration(milliseconds: 200), () {
        _keyBuffer.clear();
      });
    }
  }

  // ✅ 3. BUILD METHOD (This was likely missing or malformed)
  @override
  Widget build(BuildContext context) {
    // 🎨 Dynamic Colors based on Mode
    Color primaryColor = const Color(0xFF667EEA);
    Color secondaryColor = const Color(0xFF764BA2);

    if (_isInventoryMode) {
      primaryColor = Colors.amber.shade800;
      secondaryColor = Colors.deepOrange.shade600;
    } else if (_isReturnMode) {
      primaryColor = Colors.deepPurple.shade600;
      secondaryColor = Colors.purple.shade800;
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _onKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isInventoryMode
                  ? [Colors.amber.shade50, Colors.orange.shade50, Colors.deepOrange.shade50]
                  : (_isReturnMode
                  ? [Colors.purple.shade50, Colors.deepPurple.shade50, Colors.indigo.shade50]
                  : [Colors.blue.shade50, Colors.purple.shade50, Colors.pink.shade50]),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(primaryColor, secondaryColor),

                // ⚠️ Mode Banners
                if (_isInventoryMode)
                  _buildModeBanner("MODE INVENTAIRE ACTIF (${_currentScope ?? 'Global'})", Icons.warning_amber_rounded, Colors.deepOrange, Colors.amber.shade100),

                if (_isReturnMode)
                  _buildModeBanner("MODE RETOUR CLIENT ACTIF", Icons.assignment_return, Colors.deepPurple, Colors.purple.shade100),

                _buildSearchBar(primaryColor),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _searchQuery.isNotEmpty
                        ? _buildSearchResults(primaryColor)
                        : _buildMainCategories(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 🏗️ Floating Action Button (Dynamic)
        floatingActionButton: _isInventoryMode
            ? FloatingActionButton.extended(
          onPressed: _finishInventorySession,
          backgroundColor: Colors.red.shade600,
          icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
          label: const Text("FINIR INVENTAIRE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )
            : (_isReturnMode
            ? FloatingActionButton.extended(
          onPressed: () => setState(() => _isReturnMode = false),
          backgroundColor: Colors.red,
          icon: const Icon(Icons.close, color: Colors.white),
          label: const Text("Quitter Mode Retour", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )
            : Container(
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
        )),
      ),
    );
  }

  Widget _buildModeBanner(String text, IconData icon, Color color, Color bg) {
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.5
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 HELPER: Ask to Create Product (Option B)
  Future<void> _promptToCreateProduct(String scannedCode) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Produit Inconnu'),
        content: Text('La référence "$scannedCode" n\'existe pas dans la base.\n\nVoulez-vous créer ce produit maintenant ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Oui, Créer'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddProductPage(scannedCode: scannedCode),
        ),
      );
    }
  }

  // ===========================================================================
  // ↩️ LOGIC: CLIENT RETURN
  // ===========================================================================

  Future<void> _handleReturnScan(String scannedCode) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('produits')
          .where('reference', isEqualTo: scannedCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // ✅ Trigger Creation Flow
        _promptToCreateProduct(scannedCode);
        return;
      }

      final productDoc = querySnapshot.docs.first;
      final productData = productDoc.data();

      if (mounted) {
        _showReturnTriageDialog(productDoc.id, productData);
      }

    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _showReturnTriageDialog(String productId, Map<String, dynamic> data) {
    final qtyController = TextEditingController(text: '1');
    final clientNameController = TextEditingController();
    String reason = 'Rétractation';
    bool isResellable = true;
    final String productCategory = data['mainCategory'] ?? 'Antivol';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.deepPurple.shade100, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.assignment_return, color: Colors.deepPurple),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text("Retour: ${data['nom']}", style: const TextStyle(fontSize: 16))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: "Quantité retournée", border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: clientNameController,
                    decoration: const InputDecoration(labelText: "Nom Client (Optionnel)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: reason,
                    decoration: const InputDecoration(labelText: "Motif du retour", border: OutlineInputBorder(), prefixIcon: Icon(Icons.help_outline)),
                    items: const [
                      DropdownMenuItem(value: 'Rétractation', child: Text('Rétractation / Avis')),
                      DropdownMenuItem(value: 'Erreur Achat', child: Text('Erreur d\'achat')),
                      DropdownMenuItem(value: 'Défectueux', child: Text('Défectueux / Panne')),
                      DropdownMenuItem(value: 'Autre', child: Text('Autre')),
                    ],
                    onChanged: (v) => setState(() => reason = v!),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isResellable ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isResellable ? Colors.green.shade300 : Colors.red.shade300),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isResellable ? "✅ ETAT VENDABLE (Remise en Stock)" : "⚠️ DÉFECTUEUX / SAV (Quarantaine)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isResellable ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SwitchListTile(
                          title: const Text("Le produit est-il neuf & scellé ?", style: TextStyle(fontSize: 14)),
                          value: isResellable,
                          activeColor: Colors.green,
                          inactiveTrackColor: Colors.red.shade200,
                          inactiveThumbColor: Colors.red,
                          onChanged: (v) => setState(() => isResellable = v),
                        ),
                        if (!isResellable)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.red.shade800),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "Stock inchangé. Un ticket SAV sera proposé.",
                                    style: TextStyle(fontSize: 12, color: Colors.red.shade800, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text("Valider"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: isResellable ? Colors.green : Colors.deepPurple,
                    foregroundColor: Colors.white
                ),
                onPressed: () async {
                  final int qty = int.tryParse(qtyController.text) ?? 0;
                  if (qty <= 0) return;

                  try {
                    await StockService().processClientReturn(
                      productId: productId,
                      productName: data['nom'] ?? 'Inconnu',
                      productReference: data['reference'] ?? 'N/A',
                      quantityReturned: qty,
                      isResellable: isResellable,
                      reason: reason,
                      clientName: clientNameController.text.trim().isEmpty ? null : clientNameController.text.trim(),
                    );

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Retour enregistré avec succès !"), backgroundColor: Colors.green),
                      );

                      if (!isResellable) {
                        _askToCreateSavTicket(productCategory);
                      }
                    }
                  } catch(e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _askToCreateSavTicket(String serviceType) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Créer un Ticket SAV ?"),
        content: const Text("Cet article est marqué comme défectueux. Voulez-vous ouvrir un dossier SAV immédiatement ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Plus tard")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text("Oui, ouvrir SAV"),
          )
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddSavTicketPage(serviceType: serviceType),
        ),
      );
    }
  }

  // ===========================================================================
  // 🚀 LOGIC 1: INVENTORY SESSION MANAGEMENT
  // ===========================================================================

  Future<void> _startInventorySession() async {
    final String? scope = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choisir la portée de l\'inventaire'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'Global'),
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('🌍 Global (Tout le magasin)'),
            ),
          ),
          ..._mainCategories.map((cat) => SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, cat.name),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(cat.icon, size: 18, color: cat.color),
                  const SizedBox(width: 8),
                  Text(cat.name),
                ],
              ),
            ),
          )),
        ],
      ),
    );

    if (scope == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      // ✅ UPDATED: Robust Name Capture
      // 1. Try to get name from Auth
      String userName = user?.displayName ?? "";

      // 2. If Auth name is empty, try to fetch from 'users' collection
      if (userName.isEmpty && user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            final data = userDoc.data();
            userName = data?['fullName'] ?? data?['name'] ?? "Technicien";
          }
        } catch (e) {
          // Ignore error, fallback to default
          print("Error fetching user name: $e");
        }
      }

      // 3. Final Fallback
      if (userName.isEmpty) userName = "Technicien";

      final sessionId = await InventoryService().startSession(
          scope: scope,
          userName: userName
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Inventaire '$scope' démarré ! Scannez les produits."), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _finishInventorySession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Terminer l'inventaire ?"),
        content: const Text("Les données seront envoyées pour validation par un Responsable.\n\nVoulez-vous continuer ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirmer & Envoyer"),
          )
        ],
      ),
    );

    if (confirm != true || _currentSessionId == null) return;

    await InventoryService().finishSession(_currentSessionId!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Inventaire envoyé pour validation !"), backgroundColor: Colors.green),
      );
    }
  }

  // ===========================================================================
  // 🚀 LOGIC 2: INVENTORY SCANNING (BLIND COUNT)
  // ===========================================================================

  Future<void> _handleInventoryScan(String scannedCode) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('produits')
        .where('reference', isEqualTo: scannedCode)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      // ✅ Trigger Creation Flow
      _promptToCreateProduct(scannedCode);
      return;
    }

    final productDoc = querySnapshot.docs.first;
    final data = productDoc.data();
    final String name = data['nom'] ?? 'Inconnu';
    final int systemQty = data['quantiteEnStock'] ?? 0;

    final countController = TextEditingController();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.amber.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.playlist_add_check, color: Colors.deepOrange),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Combien de pièces comptez-vous physiquement ?",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: countController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Quantité réelle",
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.numbers),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
            onPressed: () async {
              final int counted = int.tryParse(countController.text) ?? 0;
              final user = FirebaseAuth.instance.currentUser;

              final item = InventoryItem(
                productId: productDoc.id,
                productName: name,
                productReference: scannedCode,
                category: data['categorie'] ?? 'Divers',
                systemQuantity: systemQty,
                countedQuantity: counted,
                scannedByUid: user?.uid ?? 'unknown',
                scannedAt: DateTime.now(),
              );

              await InventoryService().addItemToSession(
                  sessionId: _currentSessionId!,
                  item: item
              );

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("✅ Ajouté: $name (Qté: $counted)"), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text("Valider"),
          )
        ],
      ),
    );
  }

  // ===========================================================================
  // 🚀 LOGIC 3: LIVE STOCK UPDATE (LEGACY MODE)
  // ===========================================================================

  Future<void> _handleLiveStockUpdate(String scannedCode) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
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
                  child: const Icon(Icons.edit, color: Colors.white),
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
                  'Stock actuel (LIVE): $currentStock',
                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
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
                    labelText: 'Motif / Notes',
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
                label: const Text('Mettre à jour'),
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
                  String userName = authUser?.displayName ?? 'Utilisateur';

                  final db = FirebaseFirestore.instance;
                  final ledgerRef = db.collection('stock_movements').doc();

                  await db.runTransaction((transaction) async {
                    transaction.set(ledgerRef, {
                      'productId': productDoc.id,
                      'productRef': productData['reference'] ?? 'N/A',
                      'productName': productName,
                      'quantityChange': newQty - currentStock,
                      'oldQuantity': currentStock,
                      'newQuantity': newQty,
                      'type': 'SCAN_ADJUST',
                      'notes': notes.isEmpty ? 'Mise à jour directe' : notes,
                      'userId': userId,
                      'user': userName,
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
                },
              ),
            ],
          ),
        );
      } else {
        // ✅ Trigger Creation Flow
        _promptToCreateProduct(scannedCode);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // --- 7. COMMON SCANNER TRIGGER ---
  Future<void> _scanProduct(BuildContext context) async {
    final String? scannedCode = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProductScannerPage()),
    );

    if (scannedCode == null || scannedCode.isEmpty) return;

    if (_isInventoryMode) {
      _handleInventoryScan(scannedCode);
    } else if (_isReturnMode) {
      _handleReturnScan(scannedCode);
    } else {
      _handleLiveStockUpdate(scannedCode);
    }
  }

  // --- 8. SEARCH FUNCTION ---
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
    }
  }

  // --- 9. RESET FUNCTION (ADMIN) ---
  Future<void> _resetAllStock() async {
    final String? role = await UserRoles.getCurrentUserRole();
    if (role != UserRoles.admin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⛔ Accès Refusé'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ DANGER: RESET TOTAL'),
        content: const Text('Voulez-vous vraiment mettre TOUT le stock à 0 ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OUI, EFFACER'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final db = FirebaseFirestore.instance;
    final snapshot = await db.collection('produits').get();
    WriteBatch batch = db.batch();
    int batchCount = 0;

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'quantiteEnStock': 0});
      batchCount++;
      if (batchCount >= 200) { await batch.commit(); batch = db.batch(); batchCount = 0; }
    }
    if (batchCount > 0) await batch.commit();

    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stock Reset Complete")));
  }

  // --- UI BUILDERS ---

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
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAppBar(Color primary, Color secondary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, secondary]),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _isInventoryMode ? 'Inventaire' : (_isReturnMode ? 'Retours' : 'Stock'),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
            ),
          ),

          if (!_isInventoryMode && !_isReturnMode) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: IconButton(
                icon: const Icon(Icons.assignment_return_rounded, color: Colors.white, size: 26),
                tooltip: "Mode Retour Client",
                onPressed: () => setState(() => _isReturnMode = true),
              ),
            ),

            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: IconButton(
                icon: const Icon(Icons.inventory_rounded, color: Colors.amberAccent, size: 26),
                tooltip: "Démarrer Inventaire",
                onPressed: _startInventorySession,
              ),
            ),
          ]
          else if (_isInventoryMode)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: IconButton(
                icon: const Icon(Icons.list_alt_rounded, color: Colors.white, size: 26),
                tooltip: "Voir la liste scannée",
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => InventorySessionPage(
                        sessionId: _currentSessionId!,
                        scope: _currentScope ?? 'Global',
                      ),
                    ),
                  );
                },
              ),
            )
          else if (_isReturnMode)
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), borderRadius: BorderRadius.circular(12)),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 26),
                  tooltip: "Quitter Mode Retour",
                  onPressed: () => setState(() => _isReturnMode = false),
                ),
              ),

          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
              onPressed: () => _scanProduct(context),
            ),
          ),
          const SizedBox(width: 8),

          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: PopupMenuButton<dynamic>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              itemBuilder: (context) => <PopupMenuEntry<dynamic>>[
                _buildMenuItem(
                  icon: Icons.assignment_turned_in_rounded,
                  text: 'Validations en Attente',
                  iconColor: Colors.indigo,
                  onTap: () {
                    Future.delayed(Duration.zero, () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const InventoryApprovalListPage(),
                        ),
                      );
                    });
                  },
                ),
                const PopupMenuDivider(),

                _buildMenuItem(
                  icon: Icons.assessment_outlined,
                  text: 'Rapport d\'Inventaire',
                  onTap: () {
                    Future.delayed(Duration.zero, () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventoryReportPage()));
                    });
                  },
                ),
                _buildMenuItem(
                  icon: Icons.history_outlined,
                  text: 'Audit des Mouvements',
                  onTap: () {
                    Future.delayed(Duration.zero, () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StockAuditPage()));
                    });
                  },
                ),
                _buildMenuItem(
                  icon: Icons.tune_rounded,
                  text: 'Configuration Antivol',
                  onTap: () {
                    Future.delayed(Duration.zero, () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AntivolMainPage()));
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

  Widget _buildSearchBar(Color primary) {
    String hintText = 'Rechercher un produit...';
    if (_isInventoryMode) hintText = 'Rechercher pour compter...';
    if (_isReturnMode) hintText = 'Rechercher un retour...';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() => _searchQuery = value);
            _searchProducts(value);
          },
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(Icons.search_rounded, color: primary),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; _searchResults = []; }))
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(Color primary) {
    if (_searchResults.isEmpty && _isSearching) return const Center(child: CircularProgressIndicator());
    if (_searchResults.isEmpty) return const Center(child: Text("Aucun produit trouvé"));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final data = _searchResults[index].data() as Map<String, dynamic>;
        final stock = data['quantiteEnStock'] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: primary.withOpacity(0.1),
              child: Icon(Icons.inventory_2, color: primary),
            ),
            title: Text(data['nom'] ?? 'Nom inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Ref: ${data['reference']}"),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: stock > 0 ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$stock', style: TextStyle(fontWeight: FontWeight.bold, color: stock > 0 ? Colors.green : Colors.red)),
            ),
            onTap: () {
              // 🚀 Smart Tap: Decides logic based on mode
              if (_isInventoryMode) {
                _handleInventoryScan(data['reference']);
              } else if (_isReturnMode) {
                _handleReturnScan(data['reference']);
              } else {
                _handleLiveStockUpdate(data['reference']);
              }
            },
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
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
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
                        color: mainCategory.color,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(mainCategory.icon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mainCategory.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Voir le stock', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 18, color: mainCategory.color),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
// lib/screens/administration/product_stock_list_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// 🎨 --- 2026 PREMIUM APPLE CONSTANTS --- 🎨
const kTextDark = Color(0xFF1D1D1F);
const kTextSecondary = Color(0xFF86868B);
const double kRadius = 24.0;

class ProductStockListPage extends StatefulWidget {
  final String category;
  final Color categoryColor;

  const ProductStockListPage({
    super.key,
    required this.category,
    required this.categoryColor,
  });

  @override
  State<ProductStockListPage> createState() => _ProductStockListPageState();
}

class _ProductStockListPageState extends State<ProductStockListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    // Generate harmonious colors for the animated mesh background
    final HSLColor hsl = HSLColor.fromColor(widget.categoryColor);
    final Color color2 = hsl.withHue((hsl.hue + 35) % 360).withLightness(0.85).toColor();
    final Color color3 = hsl.withHue((hsl.hue - 35) % 360).withLightness(0.90).toColor();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ✨ 1. ANIMATED MESH GLASS BACKGROUND
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.5, 1.0],
                  colors: [
                    widget.categoryColor.withOpacity(0.15),
                    color2.withOpacity(0.3),
                    color3.withOpacity(0.4),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.white.withOpacity(0.4)),
            ),
          ),

          // ✨ 2. MAIN SLIVER CONTENT
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('produits')
                .where('categorie', isEqualTo: widget.category)
                .snapshots(),
            builder: (context, snapshot) {
              Widget content;

              if (snapshot.connectionState == ConnectionState.waiting) {
                content = SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: widget.categoryColor)),
                );
              } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                content = SliverFillRemaining(
                  child: _buildEmptyState("Aucun produit dans ce stock."),
                );
              } else {
                // ⚡ LOCAL SEARCH FILTER
                List<QueryDocumentSnapshot> docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['nom'] ?? '').toString().toLowerCase();
                  final ref = (data['reference'] ?? '').toString().toLowerCase();
                  final search = _searchQuery.toLowerCase();
                  return name.contains(search) || ref.contains(search);
                }).toList();

                if (docs.isEmpty) {
                  content = SliverFillRemaining(
                    child: _buildEmptyState("Aucun résultat pour cette recherche."),
                  );
                } else {
                  content = SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10).copyWith(bottom: 100),
                    sliver: SliverGrid(
                      // 🔥 ADAPTIVE WEB & MOBILE GRID
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75, // Perfect ratio for stock cards
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          return _GlassStockProductCard(
                            productDoc: docs[index],
                            categoryColor: widget.categoryColor,
                            index: index,
                            onTap: () => _showAdjustStockDialog(context, docs[index]),
                          );
                        },
                        childCount: docs.length,
                      ),
                    ),
                  );
                }
              }

              return CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  _buildGlassSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      child: _buildGlassSearchBar(),
                    ),
                  ),
                  content,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 💎 HEADER & SEARCH COMPONENTS
  // ---------------------------------------------------------------------------

  Widget _buildGlassSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                border: Border.all(color: Colors.white.withOpacity(0.6)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextDark, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "INVENTAIRE EN DIRECT",
                      style: GoogleFonts.inter(
                        color: kTextSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.category,
                  style: GoogleFonts.inter(
                    color: kTextDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            background: Container(color: Colors.white.withOpacity(0.2)),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: GoogleFonts.inter(color: kTextDark, fontWeight: FontWeight.w500, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Rechercher (Nom, Réf)...',
              hintStyle: GoogleFonts.inter(color: kTextSecondary),
              prefixIcon: const Icon(Icons.search_rounded, color: kTextSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.cancel_rounded, color: kTextSecondary, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = "");
                  FocusScope.of(context).unfocus();
                },
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30)],
            ),
            child: Icon(Icons.inventory_2_rounded, size: 64, color: widget.categoryColor.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text(message, style: GoogleFonts.inter(color: kTextSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 💎 PREMIUM GLASS DIALOG (Update Stock)
  // ---------------------------------------------------------------------------
  void _showAdjustStockDialog(BuildContext context, DocumentSnapshot productDoc) {
    final formKey = GlobalKey<FormState>();
    final productData = productDoc.data() as Map<String, dynamic>;
    final authUser = FirebaseAuth.instance.currentUser;
    final String initialUid = authUser?.uid ?? 'unknown_uid';
    final int oldQuantity = productData['quantiteEnStock'] ?? 0;

    final newQuantityController = TextEditingController(text: oldQuantity.toString());
    final notesController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> _onSave() async {
              if (formKey.currentState!.validate()) {
                setStateDialog(() => isLoading = true);
                try {
                  int newQty = int.parse(newQuantityController.text);
                  if (newQty != oldQuantity) {
                    await FirebaseFirestore.instance.collection('produits').doc(productDoc.id).update({
                      'quantiteEnStock': newQty,
                    });
                    await FirebaseFirestore.instance.collection('produits').doc(productDoc.id).collection('logs').add({
                      'date': Timestamp.now(),
                      'userUid': initialUid,
                      'oldQuantity': oldQuantity,
                      'newQuantity': newQty,
                      'difference': newQty - oldQuantity,
                      'notes': notesController.text.isEmpty ? 'Mise à jour manuelle' : notesController.text,
                    });
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Stock mis à jour avec succès', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      backgroundColor: const Color(0xFF34C759),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Erreur: $e', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      backgroundColor: const Color(0xFFFF3B30),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } finally {
                  if (mounted) setStateDialog(() => isLoading = false);
                }
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Product Image / Icon
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: widget.categoryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.inventory_rounded, color: widget.categoryColor, size: 32),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              productData['nom'] ?? 'Produit Inconnu',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Ref: ${productData['reference'] ?? 'N/A'}",
                              style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 24),

                            // Quantity Input
                            TextFormField(
                              controller: newQuantityController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: widget.categoryColor),
                              decoration: InputDecoration(
                                labelText: 'Nouvelle Quantité',
                                labelStyle: GoogleFonts.inter(fontSize: 14, color: kTextSecondary, fontWeight: FontWeight.w500),
                                floatingLabelAlignment: FloatingLabelAlignment.center,
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.03),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                              ),
                              validator: (value) => (value == null || value.isEmpty) ? 'Requis' : null,
                            ),
                            const SizedBox(height: 16),

                            // Notes Input
                            TextFormField(
                              controller: notesController,
                              style: GoogleFonts.inter(fontSize: 14, color: kTextDark, fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                hintText: 'Note (Optionnel)',
                                hintStyle: GoogleFonts.inter(color: kTextSecondary),
                                prefixIcon: const Icon(Icons.edit_note_rounded, color: kTextSecondary),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.03),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Actions
                            isLoading
                                ? const Center(child: CircularProgressIndicator.adaptive())
                                : Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: Text("Annuler", style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.categoryColor,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 0,
                                    ),
                                    onPressed: _onSave,
                                    child: Text("Enregistrer", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// ✨ CUSTOM GLASSMORPHIC PRODUCT CARD (Hover & Mobile Optimized)
// -----------------------------------------------------------------------------
class _GlassStockProductCard extends StatefulWidget {
  final DocumentSnapshot productDoc;
  final Color categoryColor;
  final int index;
  final VoidCallback onTap;

  const _GlassStockProductCard({
    required this.productDoc,
    required this.categoryColor,
    required this.index,
    required this.onTap,
  });

  @override
  State<_GlassStockProductCard> createState() => _GlassStockProductCardState();
}

class _GlassStockProductCardState extends State<_GlassStockProductCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.productDoc.data() as Map<String, dynamic>;
    final int stock = data['quantiteEnStock'] ?? 0;
    final List<dynamic>? images = data['imageUrls'];
    final String? firstImageUrl = (images != null && images.isNotEmpty) ? images.first.toString() : null;

    final delay = widget.index * 40;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        if (value == 0 && delay > 0) Future.delayed(Duration(milliseconds: delay));
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()..scale(_isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(_isHovered ? 0.8 : 0.6),
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: widget.categoryColor.withOpacity(_isHovered ? 0.15 : 0.05),
                  blurRadius: _isHovered ? 30 : 20,
                  offset: Offset(0, _isHovered ? 12 : 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 📷 PRODUCT IMAGE
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.03))),
                        ),
                        child: firstImageUrl != null
                            ? Image.network(
                          firstImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => _buildFallbackIcon(),
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator.adaptive(
                                valueColor: AlwaysStoppedAnimation(widget.categoryColor.withOpacity(0.5)),
                              ),
                            );
                          },
                        )
                            : _buildFallbackIcon(),
                      ),
                    ),

                    // 📝 PRODUCT DETAILS
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['nom'] ?? 'Nom inconnu',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: kTextDark,
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Réf: ${data['reference'] ?? 'N/A'}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: kTextSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            const Spacer(),

                            // 📦 LARGE STOCK INDICATOR
                            _buildStockIndicator(stock),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.categoryColor.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.inventory_2_rounded, size: 32, color: widget.categoryColor.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildStockIndicator(int stock) {
    Color color;
    IconData icon;
    String label;

    if (stock > 5) {
      color = const Color(0xFF34C759); // Green
      icon = Icons.check_circle_rounded;
      label = "En stock";
    } else if (stock > 0) {
      color = const Color(0xFFFF9500); // Orange
      icon = Icons.warning_rounded;
      label = "Faible";
    } else {
      color = const Color(0xFFFF3B30); // Red
      icon = Icons.cancel_rounded;
      label = "Rupture";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Text(
            stock.toString(),
            style: GoogleFonts.inter(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
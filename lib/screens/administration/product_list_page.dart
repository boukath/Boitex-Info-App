// lib/screens/administration/product_list_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boitex_info_app/screens/administration/product_details_page.dart';

// 🎨 --- 2026 PREMIUM APPLE CONSTANTS --- 🎨
const kTextDark = Color(0xFF1D1D1F);
const kTextSecondary = Color(0xFF86868B);
const double kRadius = 24.0;

class ProductListPage extends StatefulWidget {
  final String category;
  final Color categoryColor;

  const ProductListPage({
    super.key,
    required this.category,
    required this.categoryColor,
  });

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  // ⚙️ FILTER STATE VARIABLES
  String _sortOption = 'az'; // Options: az, za, stock_asc, stock_desc, newest
  bool _hideOutOfStock = false;
  String? _selectedBrand;
  String? _selectedOrigin;

  @override
  Widget build(BuildContext context) {
    // Generate harmonious colors for the mesh background
    final HSLColor hsl = HSLColor.fromColor(widget.categoryColor);
    final Color color2 = hsl.withHue((hsl.hue + 30) % 360).withLightness(0.85).toColor();
    final Color color3 = hsl.withHue((hsl.hue - 30) % 360).withLightness(0.90).toColor();

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
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
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
                  child: _buildEmptyState("Aucun produit trouvé dans cette catégorie."),
                );
              } else {
                // ⚡ CORE LOGIC: PROCESS DATA CLIENT-SIDE
                List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

                // Apply Filters
                List<QueryDocumentSnapshot> filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final stock = data['quantiteEnStock'] is int ? data['quantiteEnStock'] as int : 0;
                  final brand = data['marque'] as String?;
                  final origin = data['origine'] as String?;

                  if (_hideOutOfStock && stock <= 0) return false;
                  if (_selectedBrand != null && brand != _selectedBrand) return false;
                  if (_selectedOrigin != null && origin != _selectedOrigin) return false;
                  return true;
                }).toList();

                // Apply Sorting
                filteredDocs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  switch (_sortOption) {
                    case 'za': return (dataB['nom'] ?? '').toString().compareTo((dataA['nom'] ?? '').toString());
                    case 'stock_asc': return (dataA['quantiteEnStock'] ?? 0).compareTo((dataB['quantiteEnStock'] ?? 0));
                    case 'stock_desc': return (dataB['quantiteEnStock'] ?? 0).compareTo((dataA['quantiteEnStock'] ?? 0));
                    case 'newest':
                      final dateA = (dataA['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                      final dateB = (dataB['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                      return dateB.compareTo(dateA);
                    case 'az':
                    default: return (dataA['nom'] ?? '').toString().compareTo((dataB['nom'] ?? '').toString());
                  }
                });

                if (filteredDocs.isEmpty) {
                  content = SliverFillRemaining(
                    child: _buildEmptyState("Aucun résultat avec ces filtres.", showReset: true),
                  );
                } else {
                  content = SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10).copyWith(bottom: 100),
                    sliver: SliverGrid(
                      // 🔥 ADAPTIVE WEB & MOBILE GRID
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260, // Adapts seamlessly to all screen sizes
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.72, // Perfect ratio for product cards
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _GlassProductCard(
                            productDoc: doc,
                            data: data,
                            categoryColor: widget.categoryColor,
                            index: index,
                          );
                        },
                        childCount: filteredDocs.length,
                      ),
                    ),
                  );
                }
              }

              return CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  _buildGlassSliverAppBar(),
                  if (_hasActiveFilters())
                    SliverToBoxAdapter(child: _buildActiveFiltersBar()),
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
  // 💎 SLIVER APP BAR & HEADER COMPONENTS
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
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: widget.categoryColor.withOpacity(0.15),
                  border: Border.all(color: Colors.white.withOpacity(0.6)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  icon: Icon(Icons.tune_rounded, color: widget.categoryColor, size: 22),
                  onPressed: () => _showFilterModal(context),
                ),
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Produits",
                  style: GoogleFonts.inter(
                    color: kTextSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
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

  bool _hasActiveFilters() {
    return _selectedBrand != null || _selectedOrigin != null || _hideOutOfStock;
  }

  Widget _buildActiveFiltersBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_hideOutOfStock) _buildGlassFilterChip('En Stock', () => setState(() => _hideOutOfStock = false)),
          if (_selectedBrand != null) _buildGlassFilterChip('Marque: $_selectedBrand', () => setState(() => _selectedBrand = null)),
          if (_selectedOrigin != null) _buildGlassFilterChip('Origine: $_selectedOrigin', () => setState(() => _selectedOrigin = null)),
        ],
      ),
    );
  }

  Widget _buildGlassFilterChip(String label, VoidCallback onDeleted) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: kTextDark)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onDeleted,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 14, color: kTextSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, {bool showReset = false}) {
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
          if (showReset) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: Text("Réinitialiser les filtres", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(foregroundColor: widget.categoryColor),
              onPressed: _resetFilters,
            ),
          ]
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 💎 FILTER BOTTOM SHEET (Apple Vision Style)
  // ---------------------------------------------------------------------------
  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, spreadRadius: 0)],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40, height: 5,
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Filtres & Tri', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -0.5)),
                            TextButton(
                              onPressed: () {
                                _resetFilters();
                                Navigator.pop(context);
                              },
                              child: Text('Réinitialiser', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextSecondary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            children: [
                              Text('TRIER PAR', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10, runSpacing: 10,
                                children: [
                                  _buildPremiumSortChip(setModalState, 'A - Z', 'az'),
                                  _buildPremiumSortChip(setModalState, 'Z - A', 'za'),
                                  _buildPremiumSortChip(setModalState, 'Stock Croissant', 'stock_asc'),
                                  _buildPremiumSortChip(setModalState, 'Stock Décroissant', 'stock_desc'),
                                  _buildPremiumSortChip(setModalState, 'Plus Récent', 'newest'),
                                ],
                              ),
                              const SizedBox(height: 32),

                              Text('OPTIONS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                                ),
                                child: SwitchListTile.adaptive(
                                  activeColor: widget.categoryColor,
                                  title: Text('Masquer rupture de stock', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextDark)),
                                  value: _hideOutOfStock,
                                  onChanged: (val) {
                                    setModalState(() => _hideOutOfStock = val);
                                    setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(height: 32),

                              Text('RECHERCHE PRÉCISE', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                              const SizedBox(height: 12),
                              _buildGlassTextField('Marque Exacte', 'Ex: Hikvision', Icons.business_rounded, _selectedBrand, (val) {
                                setState(() => _selectedBrand = val.isEmpty ? null : val);
                              }),
                              const SizedBox(height: 16),
                              _buildGlassTextField('Origine / Fournisseur', 'Ex: France', Icons.public_rounded, _selectedOrigin, (val) {
                                setState(() => _selectedOrigin = val.isEmpty ? null : val);
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kTextDark,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text('Appliquer les filtres', style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
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

  Widget _buildPremiumSortChip(StateSetter setModalState, String label, String value) {
    final isSelected = _sortOption == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: widget.categoryColor,
      labelStyle: GoogleFonts.inter(
        color: isSelected ? Colors.white : kTextDark,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? Colors.transparent : Colors.black.withOpacity(0.05)),
      ),
      onSelected: (selected) {
        if (selected) {
          setModalState(() => _sortOption = value);
          setState(() {});
        }
      },
    );
  }

  Widget _buildGlassTextField(String label, String hint, IconData icon, String? initialValue, Function(String) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: TextField(
        controller: TextEditingController(text: initialValue),
        onChanged: onChanged,
        style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: kTextDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: kTextSecondary, fontSize: 14),
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: widget.categoryColor.withOpacity(0.6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _sortOption = 'az';
      _hideOutOfStock = false;
      _selectedBrand = null;
      _selectedOrigin = null;
    });
  }
}

// -----------------------------------------------------------------------------
// ✨ CUSTOM GLASSMORPHIC PRODUCT CARD (Web Hover & Mobile Optimized)
// -----------------------------------------------------------------------------
class _GlassProductCard extends StatefulWidget {
  final DocumentSnapshot productDoc;
  final Map<String, dynamic> data;
  final Color categoryColor;
  final int index;

  const _GlassProductCard({
    required this.productDoc,
    required this.data,
    required this.categoryColor,
    required this.index,
  });

  @override
  State<_GlassProductCard> createState() => _GlassProductCardState();
}

class _GlassProductCardState extends State<_GlassProductCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final int stock = widget.data['quantiteEnStock'] ?? 0;
    final List<dynamic>? images = widget.data['imageUrls'];
    final String? firstImageUrl = (images != null && images.isNotEmpty) ? images.first.toString() : null;

    final delay = widget.index * 50;

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
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => ProductDetailsPage(productDoc: widget.productDoc)),
            );
          },
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
                  color: Colors.black.withOpacity(_isHovered ? 0.08 : 0.04),
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
                    // 📷 PRODUCT IMAGE PORTION
                    Expanded(
                      flex: 5,
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

                    // 📝 PRODUCT DETAILS PORTION
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Title & Ref
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.data['nom'] ?? 'Nom inconnu',
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
                                  'Réf: ${widget.data['reference'] ?? 'N/A'}',
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

                            // Stock Indicator Pill
                            _buildStockPill(stock),
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
        child: Icon(Icons.inventory_2_rounded, size: 40, color: widget.categoryColor.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildStockPill(int stock) {
    Color pillColor;
    String pillText;
    IconData pillIcon;

    if (stock > 5) {
      pillColor = const Color(0xFF34C759); // Apple Green
      pillText = '$stock en stock';
      pillIcon = Icons.check_circle_rounded;
    } else if (stock > 0) {
      pillColor = const Color(0xFFFF9500); // Apple Orange
      pillText = 'Stock faible ($stock)';
      pillIcon = Icons.warning_rounded;
    } else {
      pillColor = const Color(0xFFFF3B30); // Apple Red
      pillText = 'Rupture';
      pillIcon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pillColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pillColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pillIcon, size: 12, color: pillColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              pillText,
              style: GoogleFonts.inter(
                color: pillColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
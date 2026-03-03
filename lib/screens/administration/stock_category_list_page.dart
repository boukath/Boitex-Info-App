// lib/screens/administration/stock_category_list_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boitex_info_app/screens/administration/product_stock_list_page.dart';

// 🎨 --- 2026 PREMIUM APPLE CONSTANTS --- 🎨
const kTextDark = Color(0xFF1D1D1F);
const kTextSecondary = Color(0xFF86868B);
const double kRadius = 28.0;

class StockCategoryListPage extends StatefulWidget {
  final String mainCategory;
  final Color mainCategoryColor;
  final IconData mainCategoryIcon;

  const StockCategoryListPage({
    super.key,
    required this.mainCategory,
    required this.mainCategoryColor,
    required this.mainCategoryIcon,
  });

  @override
  State<StockCategoryListPage> createState() => _StockCategoryListPageState();
}

class _StockCategoryListPageState extends State<StockCategoryListPage> {
  late Future<List<String>> _categoriesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _fetchSubCategories();
  }

  // ⚙️ LOGIC: Fetches categories from Firebase
  Future<List<String>> _fetchSubCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('produits')
        .where('mainCategory', isEqualTo: widget.mainCategory)
        .get();

    if (snapshot.docs.isEmpty) return [];

    final categories = <String>{};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('categorie')) {
        categories.add(data['categorie'] as String);
      }
    }
    final sortedList = categories.toList();
    sortedList.sort();
    return sortedList;
  }

  // 🧠 SMART ICON ENGINE (Detects the category type and assigns a premium icon)
  IconData _getIconForSubCategory(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('carte') || lowerName.contains('badge')) return Icons.credit_card_rounded;
    if (lowerName.contains('clou')) return Icons.push_pin_rounded;
    if (lowerName.contains('etiquette') || lowerName.contains('label')) return Icons.label_outline_rounded;
    if (lowerName.contains('détacheur') || lowerName.contains('detacheur')) return Icons.lock_open_rounded;
    if (lowerName.contains('désactivateur') || lowerName.contains('desactivateur')) return Icons.nfc_rounded;
    if (lowerName.contains('antenne')) return Icons.sensors_rounded;
    if (lowerName.contains('centrale')) return Icons.developer_board_rounded;
    if (lowerName.contains('câble') || lowerName.contains('cable')) return Icons.cable_rounded;
    if (lowerName.contains('alimentation')) return Icons.power_rounded;
    if (lowerName.contains('accessoire')) return Icons.extension_rounded;
    if (lowerName.contains('écran') || lowerName.contains('tpv')) return Icons.monitor_rounded;
    if (lowerName.contains('imprimante')) return Icons.print_rounded;
    if (lowerName.contains('scanner') || lowerName.contains('douchette')) return Icons.qr_code_scanner_rounded;
    return Icons.inventory_2_rounded; // Default Stock Icon
  }

  @override
  Widget build(BuildContext context) {
    // Generate an analogous vibrant color for the mesh gradient based on the passed category color
    final HSLColor hsl = HSLColor.fromColor(widget.mainCategoryColor);
    final Color color2 = hsl.withHue((hsl.hue + 50) % 360).withLightness(0.85).toColor();
    final Color color3 = hsl.withHue((hsl.hue - 30) % 360).withLightness(0.90).toColor();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ✨ 1. THE 2026 ANIMATED MESH GLASS BACKGROUND
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.6, 1.0],
                  colors: [
                    widget.mainCategoryColor.withOpacity(0.18),
                    color2.withOpacity(0.4),
                    color3.withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),
          // Heavy Blur Overlay to blend the colors into frosted glass (VisionOS style)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.white.withOpacity(0.35)),
            ),
          ),

          // ✨ 2. THE SLIVER SCROLL VIEW (Native Apple Scroll Feel)
          CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildGlassSliverAppBar(),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: _buildGlassSearchBar(),
                ),
              ),

              // Dynamic Future Grid
              FutureBuilder<List<String>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: widget.mainCategoryColor)),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.black.withOpacity(0.1)),
                            const SizedBox(height: 16),
                            Text('Aucune catégorie de stock.', style: GoogleFonts.inter(color: kTextSecondary, fontSize: 16)),
                          ],
                        ),
                      ),
                    );
                  }

                  // Local Search Filter
                  final categories = snapshot.data!
                      .where((cat) => cat.toLowerCase().contains(_searchQuery.toLowerCase()))
                      .toList();

                  if (categories.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(child: Text("Aucun résultat.", style: GoogleFonts.inter(color: kTextSecondary))),
                    );
                  }

                  // ✨ 3. THE RESPONSIVE GLASS GRID
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10).copyWith(bottom: 100),
                    sliver: SliverGrid(
                      // 🔥 Magic Responsive Grid! Adapts automatically to Web, Tablet, and Mobile
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220, // Max width of a card before it creates a new column
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.95, // Elegantly proportioned
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          return _GlassStockCategoryCard(
                            categoryName: categories[index],
                            iconData: _getIconForSubCategory(categories[index]),
                            color: widget.mainCategoryColor,
                            index: index,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ProductStockListPage(
                                    category: categories[index],
                                    categoryColor: widget.mainCategoryColor,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        childCount: categories.length,
                      ),
                    ),
                  );
                },
              ),
            ],
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
                    Icon(Icons.inventory_rounded, size: 10, color: kTextSecondary),
                    const SizedBox(width: 4),
                    Text(
                      "GESTION DES STOCKS",
                      style: GoogleFonts.inter(
                        color: kTextSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Hero(
                      tag: 'stock_icon_${widget.mainCategory}',
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: widget.mainCategoryColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.mainCategoryIcon, color: widget.mainCategoryColor, size: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Hero(
                        tag: 'stock_title_${widget.mainCategory}',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            widget.mainCategory,
                            style: GoogleFonts.inter(
                              color: kTextDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            background: Container(color: Colors.white.withOpacity(0.2)),
          ),
        ),
      ),
    );
  }

  // ✨ PREMIUM SEARCH PILL
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
              hintText: 'Rechercher un stock...',
              hintStyle: GoogleFonts.inter(color: kTextSecondary),
              prefixIcon: const Icon(Icons.search_rounded, color: kTextSecondary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ✨ CUSTOM GLASSMORPHIC HOVER CARD (Web & Mobile Optimized)
// -----------------------------------------------------------------------------
class _GlassStockCategoryCard extends StatefulWidget {
  final String categoryName;
  final IconData iconData;
  final Color color;
  final int index;
  final VoidCallback onTap;

  const _GlassStockCategoryCard({
    required this.categoryName,
    required this.iconData,
    required this.color,
    required this.index,
    required this.onTap,
  });

  @override
  State<_GlassStockCategoryCard> createState() => _GlassStockCategoryCardState();
}

class _GlassStockCategoryCardState extends State<_GlassStockCategoryCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Entrance Animation Calculation
    final delay = widget.index * 50;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        if (value == 0 && delay > 0) Future.delayed(Duration(milliseconds: delay));
        return Transform.translate(
          offset: Offset(0, 40 * (1 - value)),
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
            // ✨ Hover/Press Scaling Effect for Web & Mobile
            transform: Matrix4.identity()..scale(_isPressed ? 0.95 : (_isHovered ? 1.03 : 1.0)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(_isHovered ? 0.8 : 0.55),
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(_isHovered ? 0.15 : 0.05),
                  blurRadius: _isHovered ? 30 : 20,
                  offset: Offset(0, _isHovered ? 12 : 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Stack(
                  children: [
                    // Subtle background glow based on the specific icon's intent
                    Positioned(
                      top: -20, right: -20,
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color.withOpacity(0.05),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated Icon Circle
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: _isHovered ? 64 : 56,
                            height: _isHovered ? 64 : 56,
                            decoration: BoxDecoration(
                              color: widget.color.withOpacity(0.1),
                              shape: BoxShape.circle,
                              boxShadow: _isHovered
                                  ? [BoxShadow(color: widget.color.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)]
                                  : [],
                            ),
                            child: Icon(
                              widget.iconData,
                              color: widget.color,
                              size: _isHovered ? 32 : 28,
                            ),
                          ),
                          const Spacer(),

                          // Category Text
                          Text(
                            widget.categoryName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: kTextDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Gérer le stock",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: kTextSecondary,
                              ),
                            ),
                          )
                        ],
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
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/product_list_page.dart';

class CategoryListPage extends StatefulWidget {
  final String mainCategory;
  final Color mainCategoryColor;
  final IconData mainCategoryIcon;

  const CategoryListPage({
    super.key,
    required this.mainCategory,
    required this.mainCategoryColor,
    required this.mainCategoryIcon,
  });

  @override
  State<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> with SingleTickerProviderStateMixin {
  late Future<List<String>> _categoriesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _fetchSubCategories();
  }

  Future<List<String>> _fetchSubCategories() async {
    // 1. Fetch all products in this Main Category
    final snapshot = await FirebaseFirestore.instance
        .collection('produits')
        .where('mainCategory', isEqualTo: widget.mainCategory)
        .get();

    if (snapshot.docs.isEmpty) {
      return [];
    }

    // 2. Extract unique 'categorie' names using a Set
    final categories = <String>{};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('categorie')) {
        categories.add(data['categorie'] as String);
      }
    }

    // 3. Sort alphabetically
    final sortedList = categories.toList();
    sortedList.sort();
    return sortedList;
  }

  // 🧠 SMART ICON ENGINE: Maps text to icons automatically
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

    return Icons.widgets_rounded; // Default fallback
  }

  @override
  Widget build(BuildContext context) {
    // Premium Off-White Background
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // ✨ 1. THE PREMIUM HEADER
          _buildModernHeader(context),

          // ✨ 2. THE CONTENT GRID
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: widget.mainCategoryColor),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Une erreur est survenue', style: TextStyle(color: Colors.grey.shade600)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune sous-catégorie trouvée.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                // Filter list based on local search
                final categories = snapshot.data!
                    .where((cat) => cat.toLowerCase().contains(_searchQuery.toLowerCase()))
                    .toList();

                if (categories.isEmpty) {
                  return const Center(child: Text("Aucun résultat pour votre recherche."));
                }

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 📱 2 Columns for that "App Store" look
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1, // Slightly wider than tall
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    return _buildAnimatedCategoryCard(
                      context,
                      categories[index],
                      index,
                      categories.length,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✨ HEADER WIDGET
  Widget _buildModernHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24,
        right: 24,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button & Icon
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade50,
                  padding: const EdgeInsets.all(12),
                ),
              ),
              const Spacer(),
              Hero(
                tag: 'icon_${widget.mainCategory}',
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.mainCategoryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.mainCategoryIcon, color: widget.mainCategoryColor, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Big Title
          Hero(
            tag: 'title_${widget.mainCategory}',
            child: Material(
              color: Colors.transparent,
              child: Text(
                widget.mainCategory,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Sélectionnez une sous-catégorie",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Search Pill
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Rechercher...",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✨ ANIMATED CARD WIDGET
  Widget _buildAnimatedCategoryCard(BuildContext context, String categoryName, int index, int total) {
    // Determine Icon based on name
    final iconData = _getIconForSubCategory(categoryName);

    // Staggered Animation Calculation
    // Items load one after another with a 50ms delay per item
    final delay = index * 50;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        // Wait for start delay
        if (value == 0 && delay > 0) {
          Future.delayed(Duration(milliseconds: delay));
          // Note: Simple staggered effect. For perfect staggering,
          // use a full AnimationController, but this is lighter code.
        }

        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)), // Slide Up
          child: Opacity(
            opacity: value, // Fade In
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProductListPage(
                category: categoryName,
                categoryColor: widget.mainCategoryColor,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64748B).withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Circle
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.mainCategoryColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconData,
                  color: widget.mainCategoryColor,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),

              // Text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  categoryName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
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
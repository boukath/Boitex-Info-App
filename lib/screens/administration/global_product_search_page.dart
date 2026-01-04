// lib/screens/administration/global_product_search_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/product_details_page.dart';

class GlobalProductSearchPage extends StatefulWidget {
  // ✅ NEW: Flag to control selection mode
  final bool isSelectionMode;

  // ✅ NEW: Callback function for rapid addition (keeps page open)
  final Function(Map<String, dynamic>)? onProductSelected;

  const GlobalProductSearchPage({
    super.key,
    // ✅ NEW: Default to false so it works as a normal search page unless specified
    this.isSelectionMode = false,
    this.onProductSelected,
  });

  @override
  State<GlobalProductSearchPage> createState() => _GlobalProductSearchPageState();
}

class _GlobalProductSearchPageState extends State<GlobalProductSearchPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  List<DocumentSnapshot> _searchResults = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
    super.dispose();
  }

  // ✅ NEW: Logic to handle "Stay Open" vs "Close"
  void _confirmSelection(BuildContext dialogContext, TextEditingController qtyCtrl, Map<String, dynamic> data, String productId) {
    final int qty = int.tryParse(qtyCtrl.text) ?? 1;

    final selectedProduct = {
      'productId': productId,
      'productName': data['nom'],
      'quantity': qty,
      'partNumber': data['reference'] ?? '',
      'marque': data['marque'] ?? 'N/A',
    };

    // 1. Close the small quantity dialog first
    Navigator.pop(dialogContext);

    // 2. Check if we have a callback (Rapid Mode)
    if (widget.onProductSelected != null) {
      // ✅ Execute the callback to update the previous screen instantly
      widget.onProductSelected!(selectedProduct);

      // ✅ Show success feedback without closing the main search page
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${data['nom']} ajouté ($qty)"),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 800), // Short duration so it doesn't block view
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // 3. Legacy Mode: Close the page and return data
      Navigator.pop(context, selectedProduct);
    }
  }

  // ✅ NEW: Dialog to ask for quantity before selecting
  void _showQuantityDialog(BuildContext context, Map<String, dynamic> data, String productId) {
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Quantité pour ${data['nom']}"),
        content: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Quantité",
            border: OutlineInputBorder(),
          ),
          // Allow pressing "Enter" on keyboard to submit
          onSubmitted: (_) => _confirmSelection(ctx, quantityController, data, productId),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => _confirmSelection(ctx, quantityController, data, productId),
            child: const Text("Ajouter"),
          )
        ],
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final queryLower = query.toLowerCase();

      // Fetch all products
      // Note: For production with many items, consider Algolia or a specific Firestore search index
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .get();

      // Filter products locally for comprehensive search
      final results = snapshot.docs.where((doc) {
        final data = doc.data();

        // Search in all text fields
        final nom = (data['nom'] ?? '').toString().toLowerCase();
        final marque = (data['marque'] ?? '').toString().toLowerCase();
        final reference = (data['reference'] ?? '').toString().toLowerCase();
        final origine = (data['origine'] ?? '').toString().toLowerCase();
        final categorie = (data['categorie'] ?? '').toString().toLowerCase();
        final mainCategory = (data['mainCategory'] ?? '').toString().toLowerCase();
        final description = (data['description'] ?? '').toString().toLowerCase();

        // Search in tags array
        final tags = (data['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        final tagsString = tags.join(' ').toLowerCase();

        // Return true if query matches any field
        return nom.contains(queryLower) ||
            marque.contains(queryLower) ||
            reference.contains(queryLower) ||
            origine.contains(queryLower) ||
            categorie.contains(queryLower) ||
            mainCategory.contains(queryLower) ||
            description.contains(queryLower) ||
            tagsString.contains(queryLower);
      }).toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Erreur de recherche'),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ NEW: Change background slightly if in selection mode to indicate context
      backgroundColor: widget.isSelectionMode ? Colors.grey[50] : null,
      body: Container(
        decoration: widget.isSelectionMode
            ? null // Use simple background for selection mode
            : BoxDecoration(
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
                  child: _buildSearchResults(),
                ),
              ),
            ],
          ),
        ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recherche',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  // ✅ NEW: Dynamic title based on mode
                  widget.isSelectionMode ? 'Sélectionner Produit' : 'Globale',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
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
          autofocus: true,
          onChanged: (value) {
            _performSearch(value);
          },
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
          decoration: InputDecoration(
            hintText: 'Rechercher par nom, marque, référence, origine...',
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
              child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF1F2937)),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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

    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade100.withOpacity(0.5),
                    Colors.purple.shade100.withOpacity(0.3),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_rounded,
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              // ✅ NEW: Context aware text
              widget.isSelectionMode ? 'Sélectionnez un système' : 'Rechercher un produit',
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
                'Tapez un nom, marque, référence, origine\nou toute autre information',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667EEA).withOpacity(0.1),
                  const Color(0xFF764BA2).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 12),
                Text(
                  '${_searchResults.length} produit${_searchResults.length > 1 ? 's' : ''} trouvé${_searchResults.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final productDoc = _searchResults[index];
              final data = productDoc.data() as Map<String, dynamic>;

              return TweenAnimationBuilder(
                duration: Duration(milliseconds: 300 + (index * 50)),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: _buildProductCard(productDoc, data),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(DocumentSnapshot productDoc, Map<String, dynamic> data) {
    final imageUrls = (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    final mainCategory = data['mainCategory'] as String?;

    Color categoryColor = const Color(0xFF667EEA);
    IconData categoryIcon = Icons.inventory_rounded;

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

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          // ✅ NEW: OnTap logic to handle Selection vs View Details
          onTap: () {
            if (widget.isSelectionMode) {
              // ✅ NEW: Show quantity dialog instead of immediate return
              _showQuantityDialog(context, data, productDoc.id);
            } else {
              // Normal behavior: Go to details
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailsPage(productDoc: productDoc),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Product Image or Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: imageUrls.isEmpty
                        ? LinearGradient(
                      colors: [categoryColor, categoryColor.withOpacity(0.7)],
                    )
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: categoryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: imageUrls.isEmpty
                      ? Icon(categoryIcon, color: Colors.white, size: 40)
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [categoryColor, categoryColor.withOpacity(0.7)],
                            ),
                          ),
                          child: Icon(categoryIcon, color: Colors.white, size: 40),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // ✅ VISUAL FIX: Wrapped Text Info in Expanded to fix RenderFlex Overflow
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['nom'] ?? 'Produit sans nom',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      if (data['marque'] != null)
                        Row(
                          children: [
                            Icon(Icons.business_rounded, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            // ✅ Fix for "Right overflow" in Row
                            Expanded(
                              child: Text(
                                data['marque'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      if (data['reference'] != null)
                        Row(
                          children: [
                            Icon(Icons.qr_code_rounded, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            // ✅ Fix for "Right overflow" in Row
                            Expanded(
                              child: Text(
                                data['reference'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      // ✅ Fix for category pills overflow
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(categoryIcon, size: 12, color: categoryColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    mainCategory ?? 'N/A',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: categoryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (data['origine'] != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  data['origine'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Indicator
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isSelectionMode
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    // Show "Plus" icon if selecting, "Arrow" if viewing details
                    widget.isSelectionMode ? Icons.add_circle_outline_rounded : Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: widget.isSelectionMode ? const Color(0xFF10B981) : categoryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
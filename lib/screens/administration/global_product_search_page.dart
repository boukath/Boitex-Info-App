// lib/screens/administration/global_product_search_page.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 📳 Feature 1: Haptics
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/product_details_page.dart';
import 'package:boitex_info_app/screens/administration/product_scanner_page.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class GlobalProductSearchPage extends StatefulWidget {
  final bool isSelectionMode;
  final Function(Map<String, dynamic>)? onProductSelected;

  const GlobalProductSearchPage({
    super.key,
    this.isSelectionMode = false,
    this.onProductSelected,
  });

  @override
  State<GlobalProductSearchPage> createState() => _GlobalProductSearchPageState();
}

class _GlobalProductSearchPageState extends State<GlobalProductSearchPage>
    with TickerProviderStateMixin {

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  Timer? _debounceTimer;
  // 🎙️ Feature 4: Voice Search State
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;

  final List<String> _categories = ['Tous', 'Antivol', 'TPV', 'Compteur Client', 'Consommable', 'Logiciel'];
  String _selectedCategory = 'Tous';

  // Infinite Scrolling State
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _products = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _pageSize = 20;

  // 💊 Feature 3: Dynamic Island State
  bool _showIsland = false;
  String _islandMessage = '';

  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _bgController;
  late AnimationController _glowController; // 🎙️ Feature 4
  late AnimationController _shimmerController; // ✨ Feature 2

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _fadeController.forward();

    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);

    // 🎙️ Glow Animation for Mic
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

    // ✨ Shimmer Animation for Skeletons
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

    _fetchProducts(refresh: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMore && _searchQuery.isEmpty) _fetchProducts();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _bgController.dispose();
    _glowController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // 💊 Feature 3: Trigger Dynamic Island
  void _triggerDynamicIsland(String message) {
    HapticFeedback.heavyImpact(); // 📳 Haptic Success
    setState(() {
      _islandMessage = message;
      _showIsland = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showIsland = false);
    });
  }

  void _onSearchChanged(String query) {
    HapticFeedback.selectionClick(); // 📳 Micro-interaction
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    setState(() {
      _searchQuery = query;
      _isSearching = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isEmpty) {
        _fetchProducts(refresh: true);
      } else {
        _performClientSideSearch(query);
      }
    });
  }

  Future<void> _fetchProducts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _products = [];
        _lastDocument = null;
        _hasMore = true;
        _isSearching = true;
      });
    }
    if (!_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      Query query = FirebaseFirestore.instance.collection('produits').limit(_pageSize);
      if (_selectedCategory != 'Tous') query = query.where('mainCategory', isEqualTo: _selectedCategory);
      if (_lastDocument != null) query = query.startAfterDocument(_lastDocument!);

      final snapshot = await query.get();
      if (snapshot.docs.length < _pageSize) _hasMore = false;
      if (snapshot.docs.isNotEmpty) _lastDocument = snapshot.docs.last;

      setState(() {
        _products.addAll(snapshot.docs);
        _isSearching = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() { _isSearching = false; _isLoadingMore = false; });
    }
  }

  Future<void> _performClientSideSearch(String query) async {
    try {
      final queryLower = query.toLowerCase();
      Query fsQuery = FirebaseFirestore.instance.collection('produits');

      if (_selectedCategory != 'Tous') {
        fsQuery = fsQuery.where('mainCategory', isEqualTo: _selectedCategory);
      }

      // 🚨 FIX 1: Removed .limit(200) so it searches the ENTIRE catalog accurately
      final snapshot = await fsQuery.get();

      final results = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // 🚨 FIX 2: Added more fields to make the search much smarter
        final nom = (data['nom'] ?? '').toString().toLowerCase();
        final marque = (data['marque'] ?? '').toString().toLowerCase();
        final reference = (data['reference'] ?? '').toString().toLowerCase();
        final origine = (data['origine'] ?? '').toString().toLowerCase();
        final description = (data['description'] ?? '').toString().toLowerCase();
        final tags = (data['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        final tagsString = tags.join(' ').toLowerCase();

        return nom.contains(queryLower) ||
            marque.contains(queryLower) ||
            reference.contains(queryLower) ||
            origine.contains(queryLower) ||
            description.contains(queryLower) ||
            tagsString.contains(queryLower);
      }).toList();

      setState(() {
        _products = results;
        _isSearching = false;
        _hasMore = false; // Disable pagination during active search
      });
    } catch (e) {
      setState(() { _isSearching = false; });
    }
  }
  // 🎙️ Feature 4: Voice Search Logic
  void _toggleVoiceSearch() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
            _glowController.stop();
            _glowController.reset();
          }
        },
        onError: (error) {
          setState(() => _isListening = false);
          _glowController.stop();
          _glowController.reset();
          _triggerDynamicIsland("Erreur micro: vérifiez les permissions");
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _glowController.repeat(reverse: true); // Start the pulsing glow
        HapticFeedback.heavyImpact();
        _triggerDynamicIsland("Écoute en cours...");

        _speechToText.listen(
          localeId: 'fr_FR', // Set to French for accurate catalog searching
          onResult: (result) {
            setState(() {
              _searchController.text = result.recognizedWords;
            });
            // Instantly trigger search as words are recognized
            _onSearchChanged(result.recognizedWords);
          },
        );
      } else {
        _triggerDynamicIsland("Permission microphone refusée.");
      }
    } else {
      // Manual Stop
      setState(() => _isListening = false);
      _glowController.stop();
      _glowController.reset();
      _speechToText.stop();
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _openScanner() async {
    HapticFeedback.lightImpact();
    final scannedCode = await Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => const ProductScannerPage()),
    );
    if (scannedCode != null && scannedCode is String && scannedCode.isNotEmpty) {
      _searchController.text = scannedCode;
      _onSearchChanged(scannedCode);
    }
  }

  // ✅ Extracted Add Logic for Reusability (Dialog & Swipe)
  void _executeAddProduct(Map<String, dynamic> data, String productId, int qty) {
    final selectedProduct = {
      'productId': productId,
      'productName': data['nom'],
      'quantity': qty,
      'partNumber': data['reference'] ?? '',
      'marque': data['marque'] ?? 'N/A',
      'isConsumable': data['isConsumable'] == true,
      'isSoftware': data['isSoftware'] == true,
    };

    if (widget.onProductSelected != null) {
      widget.onProductSelected!(selectedProduct);
      _triggerDynamicIsland("${data['nom']} ajouté ($qty)"); // 💊 Use Dynamic Island!
    } else {
      Navigator.pop(context, selectedProduct);
    }
  }

  void _showQuantityDialog(BuildContext context, Map<String, dynamic> data, String productId) {
    HapticFeedback.lightImpact();
    final quantityController = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.cube_box, size: 48, color: Colors.black87),
                  const SizedBox(height: 16),
                  Text("Quantité pour\n${data['nom']}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.2)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade100, contentPadding: const EdgeInsets.symmetric(vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                    onSubmitted: (_) {
                      Navigator.pop(ctx);
                      _executeAddProduct(data, productId, int.tryParse(quantityController.text) ?? 1);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("Annuler", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _executeAddProduct(data, productId, int.tryParse(quantityController.text) ?? 1);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: const Text("Ajouter", style: TextStyle(fontWeight: FontWeight.bold))
                      )),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, double radius = 24, EdgeInsets? padding, double opacity = 0.6}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Background Animation
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: size.height * 0.1 * _bgController.value, left: -size.width * 0.2,
                    child: Container(width: size.width * 0.8, height: size.width * 0.8, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.isSelectionMode ? const Color(0xFF34D399).withOpacity(0.4) : const Color(0xFF818CF8).withOpacity(0.4))).blur(sigma: 80),
                  ),
                  Positioned(
                    bottom: -size.height * 0.1 * (1 - _bgController.value), right: -size.width * 0.1,
                    child: Container(width: size.width * 0.9, height: size.width * 0.9, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF472B6).withOpacity(0.3))).blur(sigma: 100),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSleekAppBar(),
                _buildSleekSearchBar(),
                _buildFilterChips(),
                const SizedBox(height: 8),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildAdaptiveSearchResults(),
                  ),
                ),
              ],
            ),
          ),

          // 💊 Feature 3: Dynamic Island Overlay
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut, // ✅ Correct Flutter curve
            top: _showIsland ? MediaQuery.of(context).padding.top + 10 : -100,
            left: 20, right: 20,
            child: SafeArea(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFF34D399), size: 22),
                          const SizedBox(width: 12),
                          Flexible(child: Text(_islandMessage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleekAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: _buildGlassContainer(
        radius: 100, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), opacity: 0.7,
        child: Row(
          children: [
            Container(
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: IconButton(icon: const Icon(CupertinoIcons.back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.isSelectionMode ? 'SÉLECTION' : 'CATALOGUE', style: const TextStyle(color: Colors.black54, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                  Text(widget.isSelectionMode ? 'Sélectionner un Produit' : 'Recherche Globale', style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleekSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: _buildGlassContainer(
        radius: 24, padding: EdgeInsets.zero, opacity: 0.85,
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Nom, marque, référence...',
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 16, fontWeight: FontWeight.w500),
            prefixIcon: const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Icon(CupertinoIcons.search, color: Colors.black87, size: 24)),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle), child: const Icon(CupertinoIcons.clear, size: 14, color: Colors.black54)),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),

                // 🎙️ Feature 4: Glowing Voice Search Icon
                AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: _isListening ? [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withOpacity(0.4 * _glowController.value), // Premium Red Glow
                              blurRadius: 20 * _glowController.value,
                              spreadRadius: 4 * _glowController.value,
                            )
                          ] : [],
                        ),
                        child: IconButton(
                          icon: Icon(
                              _isListening ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
                              color: _isListening ? const Color(0xFFEF4444) : Colors.black87.withOpacity(0.6),
                              size: 24
                          ),
                          onPressed: _toggleVoiceSearch,
                        ),
                      );
                    }
                ),


                // 📸 Scanner
                IconButton(
                  padding: const EdgeInsets.only(right: 16),
                  icon: const Icon(CupertinoIcons.barcode_viewfinder, color: Colors.black87, size: 28),
                  onPressed: _openScanner,
                ),
              ],
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact(); // 📳 Haptics
                setState(() => _selectedCategory = category);
                if (_searchQuery.isEmpty) {
                  _fetchProducts(refresh: true);
                } else {
                  _performClientSideSearch(_searchQuery);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black87 : Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? Colors.black87 : Colors.white, width: 1.5),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4))] : [],
                ),
                child: Center(
                  child: Text(category, style: TextStyle(color: isSelected ? Colors.white : Colors.black54, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 13)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ✨ Feature 2: Glass Shimmer Skeletons
  Widget _buildSkeletonLoader() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.6), Colors.white.withOpacity(0.1)],
              stops: const [0.0, 0.5, 1.0],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              transform: SlideGradientTransform(percent: _shimmerController.value),
            ).createShader(bounds);
          },
          child: _buildGlassContainer(
            radius: 28, opacity: 0.3, padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: double.infinity, height: 16, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8))),
                      const SizedBox(height: 12),
                      Container(width: 140, height: 12, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8))),
                      const SizedBox(height: 12),
                      Container(width: 80, height: 20, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdaptiveSearchResults() {
    if (_isSearching && _products.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildSkeletonLoader()),
      );
    }

    if (_products.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.cube_box,
        title: 'Aucun Produit',
        subtitle: _searchQuery.isNotEmpty
            ? 'Nous n\'avons rien trouvé pour\n"$_searchQuery".'
            : 'Aucun produit disponible dans cette catégorie.',
      );
    }

    final bool isWideScreen = MediaQuery.of(context).size.width > 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            _searchQuery.isEmpty ? 'TENDANCES & CATALOGUE' : '${_products.length} RÉSULTAT${_products.length > 1 ? 'S' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 1.5),
          ),
        ),
        Expanded(
          child: isWideScreen
              ? GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400, childAspectRatio: 2.5, crossAxisSpacing: 16, mainAxisSpacing: 16,
            ),
            itemCount: _products.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _products.length) return _buildSkeletonLoader();
              return _animateCardEntry(index, _buildProductCard(context, _products[index]));
            },
          )
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            itemCount: _products.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _products.length) {
                return Padding(padding: const EdgeInsets.all(16.0), child: _buildSkeletonLoader());
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _animateCardEntry(index, _buildProductCard(context, _products[index])),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildGlassContainer(radius: 40, padding: const EdgeInsets.all(32), child: Icon(icon, size: 64, color: Colors.black87)),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: -0.5)),
          const SizedBox(height: 12),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.5)),
        ],
      ),
    );
  }

  Widget _animateCardEntry(int index, Widget child) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 20).clamp(0, 300)),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutQuart,
      builder: (context, double value, child) {
        return Transform.translate(offset: Offset(0, 20 * (1 - value)), child: Opacity(opacity: value, child: child));
      },
      child: child,
    );
  }

  Widget _buildProductCard(BuildContext context, DocumentSnapshot productDoc) {
    final data = productDoc.data() as Map<String, dynamic>;
    final imageUrls = (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    final mainCategory = data['mainCategory'] as String?;

    Color themeColor = Colors.black87;
    IconData categoryIcon = CupertinoIcons.cube_box;

    if (mainCategory == 'Antivol') { themeColor = const Color(0xFF6366F1); categoryIcon = CupertinoIcons.shield_fill; }
    else if (mainCategory == 'TPV') { themeColor = const Color(0xFFEC4899); categoryIcon = CupertinoIcons.desktopcomputer; }
    else if (mainCategory == 'Compteur Client') { themeColor = const Color(0xFF10B981); categoryIcon = CupertinoIcons.person_3_fill; }

    Widget cardContent = GestureDetector(
      onTap: () {
        if (widget.isSelectionMode) {
          _showQuantityDialog(context, data, productDoc.id);
        } else {
          Navigator.push(context, CupertinoPageRoute(builder: (context) => ProductDetailsPage(productDoc: productDoc)));
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: _buildGlassContainer(
          radius: 28, opacity: 0.85, padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: themeColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                child: imageUrls.isEmpty
                    ? Icon(categoryIcon, color: themeColor, size: 36)
                    : ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(imageUrls.first, fit: BoxFit.cover)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(data['nom'] ?? 'Sans nom', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    if (data['reference'] != null || data['marque'] != null)
                      Text([data['marque'], data['reference']].where((e) => e != null && e.toString().isNotEmpty).join(' • '), style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(categoryIcon, size: 12, color: themeColor), const SizedBox(width: 4), Text(mainCategory ?? 'Général', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: themeColor))])),
                          if (data['origine'] != null) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), child: Text(data['origine'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)))],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: widget.isSelectionMode ? Colors.black87 : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black12), boxShadow: [if (widget.isSelectionMode) const BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]),
                child: Icon(widget.isSelectionMode ? CupertinoIcons.add : CupertinoIcons.right_chevron, size: widget.isSelectionMode ? 20 : 18, color: widget.isSelectionMode ? Colors.white : Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );

    // 🎚️ Feature 5: Swipe-to-Action (Only enabled if in Selection Mode)
    if (widget.isSelectionMode) {
      return Dismissible(
        key: Key(productDoc.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          // Add item without actually dismissing the widget
          _executeAddProduct(data, productDoc.id, 1);
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF34D399),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text("Ajout Rapide", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(width: 12),
              Icon(CupertinoIcons.add_circled_solid, color: Colors.white, size: 28),
            ],
          ),
        ),
        child: cardContent,
      );
    }

    return cardContent;
  }
}

// Custom Slide Gradient for Shimmer Effect
class SlideGradientTransform extends GradientTransform {
  final double percent;
  const SlideGradientTransform({required this.percent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (percent * 2 - 1), 0, 0);
  }
}

// Extension to easily apply image filters to widgets directly
extension BlurExtension on Widget {
  Widget blur({double sigma = 10}) {
    return ImageFilterWidget(sigma: sigma, child: this);
  }
}

class ImageFilterWidget extends StatelessWidget {
  final double sigma;
  final Widget child;
  const ImageFilterWidget({Key? key, required this.sigma, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}
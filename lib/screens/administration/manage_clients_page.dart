// lib/screens/administration/manage_clients_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/add_client_page.dart';
import 'package:boitex_info_app/screens/administration/manage_stores_page.dart';
import 'package:google_fonts/google_fonts.dart'; // Added for modern fonts
import 'dart:ui'; // Added for frosted glass effect
import 'dart:async'; // --- ADVANCED SEARCH ADDED --- For debounce Timer

class ManageClientsPage extends StatefulWidget {
  final String userRole;
  const ManageClientsPage({super.key, required this.userRole});

  @override
  State<ManageClientsPage> createState() => _ManageClientsPageState();
}

// 🎨 --- DESIGN CONSTANTS --- 🎨
// Using the 2025 palette you requested
const kPrimaryColor = Color(0xFF7B61FF);
const kAccentColor = Color(0xFF00B4D8);
const kErrorColor = Color(0xFFFF6F91);
const kBackgroundColorTop = Color(0xFFE8E1FF);
const kBackgroundColorBottom = Color(0xFFFBEAFF);
const kTextPrimary = Color(0xFF1E1E2A);
const kTextSecondary = Color(0xFF7A7A8C);
const kCardColor = Color.fromRGBO(255, 255, 255, 0.85); // Frosted glass white

class _ManageClientsPageState extends State<ManageClientsPage>
    with SingleTickerProviderStateMixin {
  // --- ⚙️ ORIGINAL LOGIC (PARTIALLY MODIFIED) ⚙️ ---
  // final TextEditingController _searchController = TextEditingController(); // OLD
  // String _searchQuery = ''; // OLD
  final List<String> _selectedServices = []; // Kept for service filter chips
  // final TextEditingController _storeSearchController = TextEditingController(); // OLD
  // String _storeSearchQuery = ''; // OLD
  late TabController _tabController; // Needed for animated tab index

  // --- ADVANCED SEARCH START ---
  // New controllers and state for advanced search
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _storeSearchController = TextEditingController();
  final FocusNode _clientFocusNode = FocusNode();
  final FocusNode _storeFocusNode = FocusNode();

  // We store the original query for highlighting and tokens for filtering
  String _clientSearchQuery = '';
  String _storeSearchQuery = '';
  List<String> _clientSearchTokens = [];
  List<String> _storeSearchTokens = [];

  Timer? _clientDebounce;
  Timer? _storeDebounce;

  bool _isClientFocused = false;
  bool _isStoreFocused = false;
  // --- ADVANCED SEARCH END ---

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Refresh state to animate FAB
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    // --- ADVANCED SEARCH START ---
    // Replaced old listeners with debounced advanced search
    _clientSearchController.addListener(_onClientSearchChanged);
    _storeSearchController.addListener(_onStoreSearchChanged);
    _clientFocusNode.addListener(() {
      setState(() => _isClientFocused = _clientFocusNode.hasFocus);
    });
    _storeFocusNode.addListener(() {
      setState(() => _isStoreFocused = _storeFocusNode.hasFocus);
    });
    // --- ADVANCED SEARCH END ---

    // _searchController.addListener(() { // OLD
    //   setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    // });
    // _storeSearchController.addListener(() { // OLD
    //   setState(() => _storeSearchQuery = _storeSearchController.text.trim().toLowerCase());
    // });
  }

  @override
  void dispose() {
    // _searchController.dispose(); // OLD
    // _storeSearchController.dispose(); // OLD

    // --- ADVANCED SEARCH START ---
    _clientSearchController.removeListener(_onClientSearchChanged);
    _storeSearchController.removeListener(_onStoreSearchChanged);
    _clientSearchController.dispose();
    _storeSearchController.dispose();
    _clientFocusNode.dispose();
    _storeFocusNode.dispose();
    _clientDebounce?.cancel();
    _storeDebounce?.cancel();
    // --- ADVANCED SEARCH END ---

    _tabController.dispose();
    super.dispose();
  }

  // --- ADVANCED SEARCH START ---

  /// Debounced handler for the client search input.
  void _onClientSearchChanged() {
    if (_clientDebounce?.isActive ?? false) _clientDebounce!.cancel();
    _clientDebounce = Timer(const Duration(milliseconds: 300), () {
      final query = _clientSearchController.text;
      final normalizedQuery = _normalize(query);
      setState(() {
        _clientSearchQuery = query; // Keep original case for highlighting
        _clientSearchTokens =
            normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList();
      });
      // TODO: For very large lists (>1000), consider moving filtering
      // to an isolate using compute() here instead of in the StreamBuilder.
    });
  }

  /// Debounced handler for the store search input.
  void _onStoreSearchChanged() {
    if (_storeDebounce?.isActive ?? false) _storeDebounce!.cancel();
    _storeDebounce = Timer(const Duration(milliseconds: 300), () {
      final query = _storeSearchController.text;
      final normalizedQuery = _normalize(query);
      setState(() {
        _storeSearchQuery = query; // Keep original case for highlighting
        _storeSearchTokens =
            normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList();
      });
    });
  }
  // --- ADVANCED SEARCH END ---

  Color _getAvatarColor(String text) {
    return Colors.primaries[text.hashCode % Colors.primaries.length].shade300;
  }

  bool _matchesClient(Map data) {
    // --- ⚙️ ORIGINAL LOGIC (Service filtering) ⚙️ ---
    // This part is preserved and runs first.
    final services = List<String>.from(data['services'] ?? []);
    final matchesService = _selectedServices.isEmpty ||
        services.any((s) => _selectedServices.contains(s));

    if (!matchesService) return false;

    // --- ADVANCED SEARCH START ---
    // New token-based search logic
    if (_clientSearchTokens.isEmpty) return true; // Matches if no search query

    final name = data['name'] as String? ?? '';

    // Create a single searchable string from relevant fields.
    // Using 'name' and 'services' as 'tags' are not in the model.
    final searchable = [
      _normalize(name),
      services.map(_normalize).join(' '),
    ].join(' ');

    // Return true if all tokens are found in the searchable string
    return _clientSearchTokens.every((token) => searchable.contains(token));
    // --- ADVANCED SEARCH END ---

    // final name = (data['name'] as String? ?? '').toLowerCase(); // OLD
    // final matchesName = name.contains(_searchQuery); // OLD
    // return matchesName && matchesService; // OLD
  }

  bool _matchesStore(Map data) {
    // --- ADVANCED SEARCH START ---
    if (_storeSearchTokens.isEmpty) return true; // Matches if no search query

    final name = data['name'] as String? ?? '';
    final location = data['location'] as String? ?? '';

    // Create a single searchable string.
    // Using 'name' and 'location' as 'mall'/'tags' are not in the model.
    // 'location' likely serves the purpose of 'mall'.
    final searchable = [
      _normalize(name),
      _normalize(location),
    ].join(' ');

    // Return true if all tokens are found in the searchable string
    return _storeSearchTokens.every((token) => searchable.contains(token));
    // --- ADVANCED SEARCH END ---

    // final name = (data['name'] as String? ?? '').toLowerCase(); // OLD
    // return name.contains(_storeSearchQuery); // OLD
  }
  // --- End of Original Logic ---

  @override
  Widget build(BuildContext context) {
    const availableServices = ['Service Technique', 'Service IT'];

    // Use LayoutBuilder for responsiveness (List on mobile, Grid on web/tablet)
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 700;

        return Container(
          // 🎨 --- BACKGROUND GRADIENT --- 🎨
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kBackgroundColorTop, kBackgroundColorBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent, // Crucial for gradient
            // 🎨 --- FLOATING ACTION BUTTON (FAB) --- 🎨
            floatingActionButton: _buildAnimatedFab(),
            body: SafeArea(
              child: GestureDetector(
                // --- ADVANCED SEARCH START ---
                // Dismiss keyboard on tap outside
                onTap: () {
                  _clientFocusNode.unfocus();
                  _storeFocusNode.unfocus();
                },
                // --- ADVANCED SEARCH END ---
                child: Column(
                  children: [
                    // 🎨 --- MODERN HEADER --- 🎨
                    _buildHeader(),

                    // 🎨 --- STYLED TAB BAR --- 🎨
                    _buildTabBar(),

                    // 🎨 --- TAB BAR VIEW --- 🎨
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // --- 🔵 CLIENTS TAB 🔵 ---
                          _buildClientTab(availableServices, isWide),

                          // --- 🟣 STORES TAB 🟣 ---
                          _buildStoreTab(isWide),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 🎨 --- WIDGET: Modern Header --- 🎨
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          // Soft back button
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: kPrimaryColor.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: kTextPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Title
          Text(
            'Clients & Magasins',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 --- WIDGET: Styled TabBar --- 🎨
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: kTextSecondary,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kPrimaryColor, Color(0xFFA08FFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: kPrimaryColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          tabs: const [
            Tab(text: 'Clients'),
            Tab(text: 'Magasins'),
          ],
        ),
      ),
    );
  }

  // 🎨 --- WIDGET: Gradient Search Bar (OLD) --- 🎨
  // This is no longer used, replaced by _buildAdvancedSearchBar
  // Widget _buildSearchBar({ ... }) { ... }

  // --- ADVANCED SEARCH START ---
  /// A beautiful, animated, and functional search bar.
  Widget _buildAdvancedSearchBar({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    required bool isFocused,
  }) {
    return AnimatedScale(
      scale: isFocused ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(24), // More rounded
          boxShadow: [
            BoxShadow(
              color: isFocused
                  ? kPrimaryColor.withOpacity(0.15)
                  : kPrimaryColor.withOpacity(0.05),
              blurRadius: isFocused ? 25 : 15,
              offset: Offset(0, isFocused ? 8 : 5),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: GoogleFonts.poppins(color: kTextPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle:
            GoogleFonts.poppins(color: kTextSecondary.withOpacity(0.7)),
            prefixIcon: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(12), // Slightly larger
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kPrimaryColor, kAccentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20), // More rounded
                boxShadow: [
                  BoxShadow(
                    color: kPrimaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            // Trailing clear button
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
              icon:
              const Icon(Icons.close_rounded, color: kTextSecondary),
              onPressed: () {
                controller.clear();
                // The listener will pick this up and update the query
              },
              splashRadius: 20,
              tooltip: 'Effacer',
            )
                : null,
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 22, horizontal: 10), // Taller
          ),
        ),
      ),
    );
  }
  // --- ADVANCED SEARCH END ---

  // 🎨 --- WIDGET: Client Tab Content --- 🎨
  Widget _buildClientTab(List<String> availableServices, bool isWide) {
    return Column(
      children: [
        // Client search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          // --- ADVANCED SEARCH START ---
          // Replaced _buildSearchBar with _buildAdvancedSearchBar
          child: _buildAdvancedSearchBar(
            controller: _clientSearchController,
            focusNode: _clientFocusNode,
            hintText: 'Rechercher un client ou service...',
            icon: Icons.search_rounded,
            isFocused: _isClientFocused,
          ),
          // --- ADVANCED SEARCH END ---
          // child: _buildSearchBar( // OLD
          //   controller: _searchController,
          //   hintText: 'Rechercher un client...',
          //   icon: Icons.search_rounded,
          // ),
        ),
        const SizedBox(height: 16),
        // Service chips (Original logic unchanged)
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: availableServices.map((svc) {
              final selected = _selectedServices.contains(svc);
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: FilterChip(
                  label: Text(svc),
                  labelStyle: GoogleFonts.poppins(
                    color: selected ? kPrimaryColor : kTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  selected: selected,
                  onSelected: (on) {
                    // ⚙️ --- ORIGINAL LOGIC --- ⚙️
                    setState(() {
                      if (on)
                        _selectedServices.add(svc);
                      else
                        _selectedServices.remove(svc);
                    });
                    // ⚙️ ------------------------ ⚙️
                  },
                  backgroundColor: kCardColor,
                  selectedColor: kPrimaryColor.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected
                          ? kPrimaryColor
                          : kTextSecondary.withOpacity(0.2),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        // Client list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // ⚙️ --- ORIGINAL LOGIC --- ⚙️
            stream: FirebaseFirestore.instance
                .collection('clients')
                .orderBy('name')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: kPrimaryColor));
              }
              // ⚙️ --- MODIFIED LOGIC --- ⚙️
              // The filtering logic is now inside _matchesClient,
              // which is driven by the debounced _clientSearchTokens
              final docs = snapshot.data?.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return _matchesClient(data);
              }).toList() ??
                  [];

              if (docs.isEmpty) {
                // --- ADVANCED SEARCH START ---
                // Show a friendly "No results" message
                return _buildNoResultsCard();
                // --- ADVANCED SEARCH END ---
                // return Center( // OLD
                //     child: Text('Aucun client trouvé.',
                //         style: GoogleFonts.poppins(color: kTextSecondary)));
              }
              // ⚙️ ------------------------ ⚙️

              // 🎨 --- RESPONSIVE LIST/GRID --- 🎨
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isWide
                    ? _buildClientGrid(docs) // Grid for wide screens
                    : _buildClientList(docs), // List for mobile
              );
            },
          ),
        ),
      ],
    );
  }

  // 🎨 --- WIDGET: Client List (Mobile) --- 🎨
  Widget _buildClientList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      key: const ValueKey('client_list'), // Key for AnimatedSwitcher
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;

        // 🎨 --- LIST ITEM ANIMATION --- 🎨
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (i * 50)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildClientCard(doc, data),
        );
      },
    );
  }

  // 🎨 --- WIDGET: Client Grid (Web) --- 🎨
  Widget _buildClientGrid(List<QueryDocumentSnapshot> docs) {
    return GridView.builder(
      key: const ValueKey('client_grid'), // Key for AnimatedSwitcher
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.5, // Wider cards
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;

        // 🎨 --- GRID ITEM ANIMATION --- 🎨
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (i * 50)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.9 + (0.1 * value),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildClientCard(doc, data),
        );
      },
    );
  }

  // 🎨 --- WIDGET: Reusable Client Card --- 🎨
  Widget _buildClientCard(DocumentSnapshot doc, Map<String, dynamic> data) {
    // ⚙️ --- ORIGINAL LOGIC --- ⚙️
    final name = data['name'] as String? ?? '';
    final services = List<String>.from(data['services'] ?? []);
    // ⚙️ ------------------------ ⚙️

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              // ⚙️ --- ORIGINAL LOGIC (Navigation) --- ⚙️
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ManageStoresPage(clientId: doc.id, clientName: name),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _getAvatarColor(name).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CircleAvatar(
                        backgroundColor: _getAvatarColor(name),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text Info
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- ADVANCED SEARCH START ---
                          // Replaced Text with _buildHighlightText
                          _buildHighlightText(
                            name,
                            _clientSearchQuery,
                            GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                              fontSize: 16,
                            ),
                            GoogleFonts.poppins(
                              fontWeight: FontWeight.w700, // Bold
                              color: kPrimaryColor, // Accent color
                              fontSize: 16,
                              backgroundColor:
                              kPrimaryColor.withOpacity(0.15),
                            ),
                          ),
                          // --- ADVANCED SEARCH END ---

                          // ✅ ADDED: Fiscal Info Display
                          if (data['nif'] != null || data['rc'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                              child: Text(
                                "NIF: ${data['nif'] ?? '-'} | RC: ${data['rc'] ?? '-'}",
                                style: GoogleFonts.poppins(
                                  color: kTextSecondary,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          if (services.isNotEmpty)
                            Text(
                              // Not highlighting services as it's less critical
                              // and harder to parse from the joined string.
                              'Services: ${services.join(', ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: kTextSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Trailing Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              color: kAccentColor.withOpacity(0.8)),
                          // ⚙️ --- ORIGINAL LOGIC (Edit) --- ⚙️
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddClientPage(
                                clientId: doc.id,
                                initialData: data,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_ios,
                              size: 14, color: kPrimaryColor),
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
  }

  // 🎨 --- WIDGET: Store Tab Content --- 🎨
  Widget _buildStoreTab(bool isWide) {
    return Column(
      children: [
        // Store search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          // --- ADVANCED SEARCH START ---
          // Replaced _buildSearchBar with _buildAdvancedSearchBar
          child: _buildAdvancedSearchBar(
            controller: _storeSearchController,
            focusNode: _storeFocusNode,
            hintText: 'Rechercher un magasin ou lieu...',
            icon: Icons.storefront_rounded,
            isFocused: _isStoreFocused,
          ),
          // --- ADVANCED SEARCH END ---
          // child: _buildSearchBar( // OLD
          //   controller: _storeSearchController,
          //   hintText: 'Rechercher un magasin...',
          //   icon: Icons.storefront_rounded,
          // ),
        ),
        const SizedBox(height: 20),
        // Store list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // ⚙️ --- ORIGINAL LOGIC --- ⚙️
            stream: FirebaseFirestore.instance
                .collectionGroup('stores')
                .orderBy('name')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: kPrimaryColor));
              }
              // ⚙️ --- MODIFIED LOGIC --- ⚙️
              final docs = snapshot.data?.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return _matchesStore(data);
              }).toList() ??
                  [];

              if (docs.isEmpty) {
                // --- ADVANCED SEARCH START ---
                return _buildNoResultsCard();
                // --- ADVANCED SEARCH END ---
                // return Center( // OLD
                //     child: Text('Aucun magasin trouvé.',
                //         style: GoogleFonts.poppins(color: kTextSecondary)));
              }
              // ⚙️ ------------------------ ⚙️

              // 🎨 --- RESPONSIVE LIST/GRID --- 🎨
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isWide
                    ? _buildStoreGrid(docs) // Grid for wide screens
                    : _buildStoreList(docs), // List for mobile
              );
            },
          ),
        ),
      ],
    );
  }

  // 🎨 --- WIDGET: Store List (Mobile) --- 🎨
  Widget _buildStoreList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      key: const ValueKey('store_list'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;

        // 🎨 --- LIST ITEM ANIMATION --- 🎨
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (i * 50)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildStoreCard(doc, data),
        );
      },
    );
  }

  // 🎨 --- WIDGET: Store Grid (Web) --- 🎨
  Widget _buildStoreGrid(List<QueryDocumentSnapshot> docs) {
    return GridView.builder(
      key: const ValueKey('store_grid'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.5,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;

        // 🎨 --- GRID ITEM ANIMATION --- 🎨
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (i * 50)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.9 + (0.1 * value),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildStoreCard(doc, data),
        );
      },
    );
  }

  // 🎨 --- WIDGET: Reusable Store Card --- 🎨
  Widget _buildStoreCard(DocumentSnapshot doc, Map<String, dynamic> data) {
    // ⚙️ --- ORIGINAL LOGIC --- ⚙️
    final name = data['name'] as String? ?? '';
    final location = data['location'] as String? ?? '';
    final clientId = doc.reference.parent.parent?.id;
    // ⚙️ ------------------------ ⚙️

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              // ⚙️ --- ORIGINAL LOGIC (Navigation) --- ⚙️
              onTap: clientId != null
                  ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ManageStoresPage(
                    clientId: clientId,
                    clientName: '', // Note: Original code passed ''
                  ),
                ),
              )
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _getAvatarColor(name).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CircleAvatar(
                        backgroundColor: _getAvatarColor(name),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text Info
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- ADVANCED SEARCH START ---
                          // Replaced Text with _buildHighlightText for name
                          _buildHighlightText(
                            name,
                            _storeSearchQuery,
                            GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                              fontSize: 16,
                            ),
                            GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: kPrimaryColor,
                              fontSize: 16,
                              backgroundColor:
                              kPrimaryColor.withOpacity(0.15),
                            ),
                          ),
                          // --- ADVANCED SEARCH END ---
                          // Text( // OLD
                          //   name,
                          //   style: GoogleFonts.poppins(
                          //     fontWeight: FontWeight.w600,
                          //     color: kTextPrimary,
                          //     fontSize: 16,
                          //   ),
                          // ),
                          if (location.isNotEmpty)
                          // --- ADVANCED SEARCH START ---
                          // Replaced Text with _buildHighlightText for location
                            _buildHighlightText(
                              'Lieu: $location',
                              _storeSearchQuery,
                              GoogleFonts.poppins(
                                color: kTextSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              GoogleFonts.poppins(
                                color: kPrimaryColor.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                backgroundColor:
                                kPrimaryColor.withOpacity(0.1),
                              ),
                            ),
                          // --- ADVANCED SEARCH END ---
                          // Text( // OLD
                          //   'Lieu: $location',
                          //   maxLines: 1,
                          //   overflow: TextOverflow.ellipsis,
                          //   style: GoogleFonts.poppins(
                          //     color: kTextSecondary,
                          //     fontSize: 12,
                          //     fontWeight: FontWeight.w500,
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                    // Trailing Arrow
                    if (clientId != null)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_ios,
                            size: 14, color: kPrimaryColor),
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

  // 🎨 --- WIDGET: Animated Gradient FAB --- 🎨
  Widget _buildAnimatedFab() {
    // Animate the FAB based on the tab index
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      offset: _tabController.index == 0 ? Offset.zero : const Offset(0, 2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _tabController.index == 0 ? 1.0 : 0.0,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [kPrimaryColor, kAccentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: kPrimaryColor.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: FloatingActionButton(
            // ⚙️ --- ORIGINAL LOGIC --- ⚙️
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddClientPage()),
            ),
            tooltip: 'Ajouter un client',
            // 🎨 --- STYLING --- 🎨
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            child: const Icon(Icons.add_rounded, size: 30),
          ),
        ),
      ),
    );
  }

  // --- ADVANCED SEARCH START ---

  /// A helper widget to show when no search results are found.
  Widget _buildNoResultsCard() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withOpacity(0.07),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: kPrimaryColor.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Essayez de modifier vos termes de recherche.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: kTextSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Normalizes a string by lowercasing and removing diacritics (accents).
  String _normalize(String s) {
    const diacritics =
        'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñ';
    const nonDiacritics =
        'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuuyNn';

    String normalized = s;
    for (int i = 0; i < diacritics.length; i++) {
      normalized = normalized.replaceAll(diacritics[i], nonDiacritics[i]);
    }
    // Collapse multiple spaces and trim
    return normalized.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Creates a RichText widget that highlights the search query.
  Widget _buildHighlightText(
      String text,
      String query,
      TextStyle defaultStyle,
      TextStyle highlightStyle,
      ) {
    if (query.isEmpty) {
      return Text(text,
          style: defaultStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final normalizedText = _normalize(text);
    final queryTokens =
    _normalize(query).split(' ').where((t) => t.isNotEmpty).toList();

    if (queryTokens.isEmpty) {
      return Text(text,
          style: defaultStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    List<TextSpan> spans = [];
    int start = 0;

    // Find all matches for all tokens
    List<List<int>> allMatches = [];
    for (final token in queryTokens) {
      int index = normalizedText.indexOf(token, 0);
      while (index != -1) {
        allMatches.add([index, index + token.length]);
        index = normalizedText.indexOf(token, index + 1);
      }
    }

    if (allMatches.isEmpty) {
      return Text(text,
          style: defaultStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    // Sort and merge overlapping matches
    allMatches.sort((a, b) => a[0].compareTo(b[0]));
    List<List<int>> mergedMatches = [];
    if (allMatches.isNotEmpty) {
      mergedMatches.add(allMatches[0]);
      for (var i = 1; i < allMatches.length; i++) {
        List<int> current = allMatches[i];
        List<int> last = mergedMatches.last;
        if (current[0] <= last[1]) {
          // Overlap or contiguous
          last[1] = current[1] > last[1] ? current[1] : last[1];
        } else {
          mergedMatches.add(current);
        }
      }
    }

    // Build TextSpans from the original string using merged indices
    for (final match in mergedMatches) {
      if (match[0] > start) {
        spans.add(
            TextSpan(text: text.substring(start, match[0]), style: defaultStyle));
      }
      // Ensure match indices are within bounds of the original string
      final int end = match[1] < text.length ? match[1] : text.length;
      if (match[0] < end) {
        spans.add(TextSpan(
            text: text.substring(match[0], end), style: highlightStyle));
      }
      start = end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: defaultStyle));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
// --- ADVANCED SEARCH END ---
}
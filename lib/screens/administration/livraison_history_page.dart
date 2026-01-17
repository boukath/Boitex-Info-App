// lib/screens/administration/livraison_history_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Typography
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';

class LivraisonHistoryPage extends StatefulWidget {
  final String serviceType;
  const LivraisonHistoryPage({super.key, required this.serviceType});

  @override
  State<LivraisonHistoryPage> createState() => _LivraisonHistoryPageState();
}

class _LivraisonHistoryPageState extends State<LivraisonHistoryPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // -- State Variables --
  List<DocumentSnapshot> _livraisons = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isSearching = false;
  DocumentSnapshot? _lastDocument;

  // ✅ STATE: Year Selection (Default to current year)
  int _selectedYear = DateTime.now().year;

  // Generate a list of years (Current year back 4 years)
  List<int> get _availableYears {
    final currentYear = DateTime.now().year;
    return List.generate(4, (index) => currentYear - index);
  }

  // Constants
  static const int _limit = 15;

  // 🎨 THEME COLORS
  final Color _primaryBlue = const Color(0xFF2962FF);
  final Color _accentGreen = const Color(0xFF00E676);
  final Color _bgLight = const Color(0xFFF4F6F9);
  final Color _cardWhite = Colors.white;
  final Color _textDark = const Color(0xFF2D3436);

  @override
  void initState() {
    super.initState();
    _fetchLivraisons();

    // Infinite Scroll Listener
    _scrollController.addListener(() {
      double maxScroll = _scrollController.position.maxScrollExtent;
      double currentScroll = _scrollController.position.pixels;

      // Load more when user is 200px from the bottom
      if (maxScroll - currentScroll <= 200 && !_isLoading && _hasMore) {
        _fetchLivraisons();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches data from Firestore with Pagination AND Year Filter
  Future<void> _fetchLivraisons({bool isRefresh = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (isRefresh) {
        _livraisons = [];
        _lastDocument = null;
        _hasMore = true;
      }

      // ✅ LOGIC: Define the Date Range for the selected year
      final startOfYear = DateTime(_selectedYear, 1, 1);
      final endOfYear = DateTime(_selectedYear, 12, 31, 23, 59, 59);

      Query query = FirebaseFirestore.instance
          .collection('livraisons')
          .where('serviceType', isEqualTo: widget.serviceType)
          .where('status', isEqualTo: 'Livré')
      // ✅ QUERY: Filter by Date Range (Time Machine Logic)
          .where('createdAt', isGreaterThanOrEqualTo: startOfYear)
          .where('createdAt', isLessThanOrEqualTo: endOfYear)
      // ✅ SORT: Must sort by 'createdAt' first for range filter
          .orderBy('createdAt', descending: true)
          .limit(_limit);

      // If we have a last document, start after it (Pagination)
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.length < _limit) {
        _hasMore = false; // No more data to load
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        _livraisons.addAll(snapshot.docs);
      }

      setState(() {});
    } catch (e) {
      debugPrint("Error fetching history: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Performs a specific search (Server-Side)
  Future<void> _performSearch(String queryText) async {
    if (queryText.trim().isEmpty) {
      // If empty, go back to normal list
      setState(() => _isSearching = false);
      _fetchLivraisons(isRefresh: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
      _livraisons = []; // Clear list for search results
    });

    try {
      // 1. Search by BL Code
      final blQuery = await FirebaseFirestore.instance
          .collection('livraisons')
          .where('serviceType', isEqualTo: widget.serviceType)
          .where('bonLivraisonCode', isEqualTo: queryText.trim())
          .get();

      // 2. Search by Client Name
      final clientQuery = await FirebaseFirestore.instance
          .collection('livraisons')
          .where('serviceType', isEqualTo: widget.serviceType)
          .where('clientName', isEqualTo: queryText.trim())
          .get();

      // Combine results
      final Set<String> docIds = {};
      final List<DocumentSnapshot> combinedResults = [];

      for (var doc in blQuery.docs) {
        if (docIds.add(doc.id)) combinedResults.add(doc);
      }
      for (var doc in clientQuery.docs) {
        if (docIds.add(doc.id)) combinedResults.add(doc);
      }

      setState(() {
        _livraisons = combinedResults;
        _hasMore = false; // Search results are not paginated here for simplicity
      });
    } catch (e) {
      debugPrint("Search error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🎨 WIDGET: Year Selector Chips
  Widget _buildYearSelector() {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _availableYears.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final int year = _availableYears[index];
          final bool isSelected = year == _selectedYear;
          return ChoiceChip(
            label: Text(year.toString()),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedYear = year;
                  _fetchLivraisons(isRefresh: true);
                });
              }
            },
            selectedColor: _primaryBlue,
            labelStyle: GoogleFonts.poppins(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.transparent)),
            elevation: isSelected ? 4 : 0,
          );
        },
      ),
    );
  }

  // 🎨 WIDGET: Modern History Card
  Widget _buildHistoryCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bonNumber = data['bonLivraisonCode'] ?? 'N/A';
    final clientName = data['clientName'] ?? 'Client inconnu';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final completedAt = (data['completedAt'] as Timestamp?)?.toDate();

    // ✅ DETECT PARTIAL DELIVERY
    // Check our new 'hasReturns' flag OR calculate manually if older data
    bool isPartial = data['hasReturns'] == true;

    // Fallback manual check for older records
    if (!isPartial && data['products'] != null) {
      // (Optional simple check if needed, but 'hasReturns' is safest from new logic)
    }

    final displayDate = completedAt ?? createdAt;
    final formattedDate = displayDate != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(displayDate)
        : 'Date inconnue';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LivraisonDetailsPage(livraisonId: doc.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon Box - UPDATED for Partial State
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: isPartial ? Colors.orange.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                    isPartial ? Icons.warning_amber_rounded : Icons.check_circle,
                    color: isPartial ? Colors.orange : Colors.green,
                    size: 24
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          bonNumber,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _textDark,
                          ),
                        ),
                        if (isPartial) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4)
                            ),
                            child: Text(
                              "PARTIEL",
                              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                            ),
                          )
                        ]
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(Icons.chevron_right, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: Text(
          'ARCHIVES ${widget.serviceType.toUpperCase()}',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: _textDark,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // -- Search Bar --
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher BL ou Client...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: _primaryBlue),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: _bgLight,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              ),
              style: GoogleFonts.poppins(),
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
            ),
          ),

          const SizedBox(height: 10),

          // -- Year Selector --
          if (!_isSearching) _buildYearSelector(),

          const SizedBox(height: 10),

          // -- List --
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchLivraisons(isRefresh: true),
              color: _primaryBlue,
              child: _livraisons.isEmpty && !_isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_edu, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      _isSearching
                          ? 'Aucun résultat trouvé.'
                          : 'Aucune archive pour $_selectedYear.',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _livraisons.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _livraisons.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _buildHistoryCard(_livraisons[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
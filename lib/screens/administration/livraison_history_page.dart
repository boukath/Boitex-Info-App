// lib/screens/administration/livraison_history_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Constants
  static const int _limit = 15;

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

  /// Fetches data from Firestore with Pagination
  Future<void> _fetchLivraisons({bool isRefresh = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (isRefresh) {
        _livraisons = [];
        _lastDocument = null;
        _hasMore = true;
      }

      Query query = FirebaseFirestore.instance
          .collection('livraisons')
          .where('serviceType', isEqualTo: widget.serviceType)
          .where('status', isEqualTo: 'Livré')
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
  /// Note: Firestore search is limited. We search by Exact BL Code or Client Name.
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

      // 2. Search by Client Name (Exact match or simple prefix if configured)
      final clientQuery = await FirebaseFirestore.instance
          .collection('livraisons')
          .where('serviceType', isEqualTo: widget.serviceType)
          .where('clientName', isEqualTo: queryText.trim())
          .get();

      // Combine results (removing duplicates manually)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique - ${widget.serviceType}'),
        centerTitle: false,
        elevation: 2,
      ),
      body: Column(
        children: [
          // -- Search Bar --
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par Code BL ou Client...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
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
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
            ),
          ),

          // -- List --
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchLivraisons(isRefresh: true),
              child: _livraisons.isEmpty && !_isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      _isSearching ? 'Aucun résultat trouvé.' : 'Aucun historique disponible.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                // Add +1 item for the loading indicator at bottom
                itemCount: _livraisons.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {

                  // Show Loading Indicator at the bottom
                  if (index == _livraisons.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final doc = _livraisons[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final bonNumber = data['bonLivraisonCode'] ?? 'N/A';
                  final clientName = data['clientName'] ?? 'Client inconnu';
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final completedAt = (data['completedAt'] as Timestamp?)?.toDate();

                  // Use completed date if available, else created date
                  final displayDate = completedAt ?? createdAt;
                  final formattedDate = displayDate != null
                      ? DateFormat('dd/MM/yyyy HH:mm').format(displayDate)
                      : 'Date inconnue';

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade50,
                        child: Icon(Icons.assignment_turned_in, color: Colors.green.shade700),
                      ),
                      title: Text(
                        'Bon $bonNumber',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.business, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(child: Text(clientName, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(formattedDate, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LivraisonDetailsPage(livraisonId: doc.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
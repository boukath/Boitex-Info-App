import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';

class UniversalInterventionSearchPage extends StatefulWidget {
  final String serviceType;
  const UniversalInterventionSearchPage({super.key, required this.serviceType});

  @override
  State<UniversalInterventionSearchPage> createState() =>
      _UniversalInterventionSearchPageState();
}

class _UniversalInterventionSearchPageState
    extends State<UniversalInterventionSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _interventions = [];
  bool _isLoading = false;
  String _searchFilter = 'clientName'; // Default search field

  @override
  void initState() {
    super.initState();
    _loadRecentInterventions();
  }

  // ✅ SAFETY FIX: Only load the last 20 items initially
  Future<void> _loadRecentInterventions() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('interventions')
          .where('serviceType', isEqualTo: widget.serviceType)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      setState(() {
        _interventions = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading recent: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ PERFORMANCE FIX: Search using Firestore Queries, not client-side loops
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      _loadRecentInterventions();
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Note: This performs a prefix search (e.g., "Zar" finds "Zara")
      // Ideally, ensure you have Firestore Indexes created for these queries.
      final snapshot = await FirebaseFirestore.instance
          .collection('interventions')
          .where('serviceType', isEqualTo: widget.serviceType)
          .where(_searchFilter, isGreaterThanOrEqualTo: query)
          .where(_searchFilter, isLessThan: '${query}z')
          .limit(50) // Safety limit
          .get();

      setState(() {
        _interventions = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Search Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de recherche: ${e.toString()}')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Recherche Globale', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // --- Search Bar Section ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Filter Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _searchFilter,
                          items: const [
                            DropdownMenuItem(value: 'clientName', child: Text('Client')),
                            DropdownMenuItem(value: 'storeName', child: Text('Magasin')),
                            DropdownMenuItem(value: 'code', child: Text('Code')),
                          ],
                          onChanged: (val) => setState(() => _searchFilter = val!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Search Input
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () => _performSearch(_searchController.text),
                          ),
                        ),
                        onSubmitted: _performSearch,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- Results List ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _interventions.isEmpty
                ? Center(
              child: Text(
                'Aucun résultat trouvé',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _interventions.length,
              itemBuilder: (context, index) {
                final data = _interventions[index].data() as Map<String, dynamic>;
                return _buildInterventionCard(context, _interventions[index], data);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterventionCard(
      BuildContext context, DocumentSnapshot doc, Map<String, dynamic> data) {
    final status = data['status'] ?? 'N/A';
    final isClosed = status == 'Clôturé';
    final date = (data['createdAt'] as Timestamp?)?.toDate();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isClosed ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
          child: Icon(
            isClosed ? Icons.check_circle : Icons.pending,
            color: isClosed ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          data['storeName'] ?? 'Magasin Inconnu',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${data['clientName']} - ${data['storeLocation'] ?? ''}'),
            if (date != null)
              Text(
                DateFormat('dd MMM yyyy').format(date),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => InterventionDetailsPage(
                // ✅ FIX: Explicitly cast the doc to the required type
                interventionDoc: doc as DocumentSnapshot<Map<String, dynamic>>,
              ),
            ),
          );
        },
      ),
    );
  }
}
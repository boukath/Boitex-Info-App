// lib/screens/service_technique/universal_intervention_search_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  String _searchQuery = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allInterventions = [];      // typed
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredInterventions = []; // typed
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAllInterventions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllInterventions() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
      await FirebaseFirestore.instance
          .collection('interventions')
          .where('serviceType', isEqualTo: widget.serviceType)
          .where('status', isEqualTo: 'Clôturé')
          .orderBy('closedAt', descending: true)
          .get();

      setState(() {
        _allInterventions = snapshot.docs;
        _filteredInterventions = _allInterventions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error fetching interventions: $e");
    }
  }

  void _filterInterventions(String query) {
    final lowerCaseQuery = query.toLowerCase();

    setState(() {
      _searchQuery = query;
      _filteredInterventions = _allInterventions.where((doc) {
        final data = doc.data();
        final clientName = (data['clientName'] as String? ?? '').toLowerCase();
        final storeName = (data['storeName'] as String? ?? '').toLowerCase();
        final storeLocation =
        (data['storeLocation'] as String? ?? '').toLowerCase();
        final interventionCode =
        (data['interventionCode'] as String? ?? '').toLowerCase();

        return clientName.contains(lowerCaseQuery) ||
            storeName.contains(lowerCaseQuery) ||
            storeLocation.contains(lowerCaseQuery) ||
            interventionCode.contains(lowerCaseQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recherche d'Intervention"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _filterInterventions,
              decoration: InputDecoration(
                labelText: 'Rechercher (Client, Magasin, Code...)',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12.0)),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterInterventions('');
                  },
                )
                    : null,
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filteredInterventions.isEmpty && _searchQuery.isNotEmpty)
            const Expanded(
                child: Center(child: Text('Aucune intervention trouvée.')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filteredInterventions.length,
                itemBuilder: (context, index) {
                  final interventionDoc = _filteredInterventions[index];
                  final data = interventionDoc.data();
                  final DateTime? closedDate =
                  (data['closedAt'] as Timestamp?)?.toDate();

                  return Card(
                    margin:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: ListTile(
                      title: Text(
                        '${data['storeName']} - ${data['storeLocation']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Client: ${data['clientName']}\n'
                            'Clôturée le: ${closedDate != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(closedDate) : 'N/A'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => InterventionDetailsPage(
                              interventionDoc: interventionDoc,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

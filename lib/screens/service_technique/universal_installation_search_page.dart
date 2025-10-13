// lib/screens/service_technique/universal_installation_search_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart'; // Assuming userRole might be needed

class UniversalInstallationSearchPage extends StatefulWidget {
  final String serviceType;
  final String userRole; // Pass userRole for navigation to details page

  const UniversalInstallationSearchPage({
    super.key,
    required this.serviceType,
    required this.userRole,
  });

  @override
  State<UniversalInstallationSearchPage> createState() =>
      _UniversalInstallationSearchPageState();
}

class _UniversalInstallationSearchPageState
    extends State<UniversalInstallationSearchPage> {
  String _searchQuery = '';
  List<DocumentSnapshot> _allInstallations = [];
  List<DocumentSnapshot> _filteredInstallations = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAllInstallations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllInstallations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('installations')
          .where('serviceType', isEqualTo: widget.serviceType)
          .where('status', isEqualTo: 'Terminée')
          .orderBy('createdAt', descending: true)
          .get();
      setState(() {
        _allInstallations = snapshot.docs;
        _filteredInstallations = _allInstallations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print("Error fetching installations: $e");
    }
  }

  void _filterInstallations(String query) {
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      _searchQuery = query;
      _filteredInstallations = _allInstallations.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final clientName =
        (data['clientName'] as String? ?? '').toLowerCase();
        final storeName =
        (data['storeName'] as String? ?? '').toLowerCase();
        final storeLocation =
        (data['storeLocation'] as String? ?? '').toLowerCase();
        // NOTE: Make sure your installations collection has this field.
        final installationCode =
        (data['installationCode'] as String? ?? '').toLowerCase();

        return clientName.contains(lowerCaseQuery) ||
            storeName.contains(lowerCaseQuery) ||
            storeLocation.contains(lowerCaseQuery) ||
            installationCode.contains(lowerCaseQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche d\'Installation'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _filterInstallations,
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
                    _filterInstallations('');
                  },
                )
                    : null,
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredInstallations.isEmpty && _searchQuery.isNotEmpty)
            const Expanded(
              child: Center(child: Text('Aucune installation trouvée.')),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filteredInstallations.length,
                itemBuilder: (context, index) {
                  final installationDoc = _filteredInstallations[index];
                  final data =
                  installationDoc.data() as Map<String, dynamic>;
                  final createdDate =
                  (data['createdAt'] as Timestamp?)?.toDate();

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 4.0),
                    child: ListTile(
                      title: Text(
                        '${data['storeName']} - ${data['storeLocation']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Client: ${data['clientName']}\nCréée le: ${createdDate != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(createdDate) : 'N/A'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => InstallationDetailsPage(
                              installationDoc: installationDoc,
                              userRole: widget.userRole,
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
// lib/screens/service_technique/installation_history_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/universal_installation_search_page.dart';

class InstallationHistoryListPage extends StatefulWidget {
  final String serviceType;
  final String userRole;

  const InstallationHistoryListPage({
    super.key,
    required this.serviceType,
    required this.userRole,
  });

  @override
  State<InstallationHistoryListPage> createState() =>
      _InstallationHistoryListPageState();
}

class _InstallationHistoryListPageState
    extends State<InstallationHistoryListPage> {
  // ✅ STATE: Default to current year
  int _selectedYear = DateTime.now().year;

  // Generate a list of years (Current year back 4 years)
  List<int> get _availableYears {
    final currentYear = DateTime.now().year;
    return List.generate(4, (index) => currentYear - index);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ LOGIC: Define the Date Range for the selected year
    final startOfYear = DateTime(_selectedYear, 1, 1);
    final endOfYear = DateTime(_selectedYear, 12, 31, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Installations'),
        actions: [
          // ✅ UI: Year Selector Dropdown (The "Time Machine")
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down,
                    color: Colors.blue, size: 24),
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                items: _availableYears.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text("Année $year"),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedYear = val);
                  }
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UniversalInstallationSearchPage(
                    serviceType: widget.serviceType,
                    userRole: widget.userRole,
                  ),
                ),
              );
            },
            tooltip: 'Rechercher une installation',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('installations')
            .where('serviceType', isEqualTo: widget.serviceType)
            .where('status', isEqualTo: 'Terminée')
        // ✅ QUERY: Filter by Date Range (Time Machine Logic)
            .where('createdAt', isGreaterThanOrEqualTo: startOfYear)
            .where('createdAt', isLessThanOrEqualTo: endOfYear)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Text('Aucune installation terminée en $_selectedYear.'));
          }

          final installationDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: installationDocs.length,
            itemBuilder: (context, index) {
              final doc = installationDocs[index];
              final data = doc.data() as Map<String, dynamic>;

              // ✅ EXTRACTED INSTALLATION CODE
              final installationCode = data['installationCode'] ?? 'N/A';
              final clientName = data['clientName'] ?? 'N/A';
              final storeName = data['storeName'] ?? 'N/A';
              final storeLocation = data['storeLocation'] ?? '';
              final createdDate = (data['createdAt'] as Timestamp).toDate();
              final status = data['status'] ?? 'N/A';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => InstallationDetailsPage(
                        installationDoc: doc,
                        userRole: widget.userRole,
                      ),
                    ));
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // ✅ UPDATED: Title is now the installation code
                            Flexible(
                              child: Text(
                                installationCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF1E3A8A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        // ✅ UPDATED: Subtitle now contains store and client info
                        Text(
                          '$storeName ${storeLocation.isNotEmpty ? '- $storeLocation' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Client: $clientName',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Date: ${DateFormat('dd MMM yyyy', 'fr_FR').format(createdDate)}',
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
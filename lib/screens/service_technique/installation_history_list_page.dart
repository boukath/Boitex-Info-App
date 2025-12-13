// lib/screens/service_technique/installation_history_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/universal_installation_search_page.dart';

class InstallationHistoryListPage extends StatelessWidget {
  final String serviceType;
  final String userRole;

  const InstallationHistoryListPage({
    super.key,
    required this.serviceType,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Installations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UniversalInstallationSearchPage(
                    serviceType: serviceType,
                    userRole: userRole,
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
            .where('serviceType', isEqualTo: serviceType)
            .where('status', isEqualTo: 'Terminée')
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
            return const Center(
                child: Text('Aucune installation terminée trouvée.'));
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
                        userRole: userRole,
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
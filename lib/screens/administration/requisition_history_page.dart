// lib/screens/administration/requisition_history_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';

class RequisitionHistoryPage extends StatefulWidget {
  final String userRole;
  const RequisitionHistoryPage({super.key, required this.userRole});

  @override
  State<RequisitionHistoryPage> createState() => _RequisitionHistoryPageState();
}

class _RequisitionHistoryPageState extends State<RequisitionHistoryPage> {
  // ✅ NEW: Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _canAccessPOReference() {
    return widget.userRole == 'PDG' ||
        widget.userRole == 'Admin' ||
        widget.userRole == 'Responsable Administratif';
  }

  Widget _getStatusChip(String status) {
    Color color;
    switch (status) {
      case 'Reçue':
        color = Colors.green;
        break;
      case 'Reçue avec Écarts':
        color = Colors.orange;
        break;
      case 'Refusée':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Achats'),
        // ✅ NEW: Add search bar below title
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher (CM-XX/2025 ou N° BC)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requisitions')
            .where('status', whereIn: ['Reçue', 'Reçue avec Écarts', 'Refusée'])
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
            return const Center(child: Text('Aucun historique disponible.'));
          }

          // ✅ NEW: Filter documents based on search query
          var filteredDocs = snapshot.data!.docs.where((doc) {
            if (_searchQuery.isEmpty) return true;

            final data = doc.data() as Map<String, dynamic>;
            final requisitionCode = (data['requisitionCode'] ?? '').toString().toLowerCase();
            final poReference = (data['purchaseOrderReference'] ?? '').toString().toLowerCase();
            final requestedBy = (data['requestedBy'] ?? '').toString().toLowerCase();

            // Search in CM code, PO reference, and requester name
            return requisitionCode.contains(_searchQuery) ||
                poReference.contains(_searchQuery) ||
                requestedBy.contains(_searchQuery);
          }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(
              child: Text('Aucun résultat trouvé.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] as String;
              final requisitionCode = data['requisitionCode'] ?? 'N/A';
              final requestedBy = data['requestedBy'] ?? 'Inconnu';
              final createdAt = data['createdAt'] as Timestamp?;
              final poReference = data['purchaseOrderReference'] as String?;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Row(
                    children: [
                      Text(
                        requisitionCode,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      // Show PO reference if exists and user has access
                      if (poReference != null &&
                          poReference.isNotEmpty &&
                          _canAccessPOReference()) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            '📦 $poReference',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Demandé par: $requestedBy'),
                      if (createdAt != null)
                        Text(
                          'Date: ${DateFormat('dd/MM/yyyy').format(createdAt.toDate())}',
                        ),
                    ],
                  ),
                  trailing: _getStatusChip(status),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RequisitionDetailsPage(
                          requisitionId: doc.id,
                          userRole: widget.userRole,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

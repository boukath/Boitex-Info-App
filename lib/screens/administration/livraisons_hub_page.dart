// lib/screens/administration/livraisons_hub_page.dart

import 'package:boitex_info_app/screens/administration/add_livraison_page.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LivraisonsHubPage extends StatefulWidget {
  final String? serviceType;
  const LivraisonsHubPage({super.key, this.serviceType});

  @override
  State<LivraisonsHubPage> createState() => _LivraisonsHubPageState();
}

class _LivraisonsHubPageState extends State<LivraisonsHubPage> {
  bool _canEdit = false;

  @override
  void initState() {
    super.initState();
    _checkUserPermissions();
  }

  /// Checks the current user's role to determine if they have permission to edit.
  Future<void> _checkUserPermissions() async {
    // This calls the centralized permission logic from your user_roles.dart file.
    final canEdit = await RolePermissions.canCurrentUserEditLivraison();
    if (mounted) {
      setState(() {
        _canEdit = canEdit;
      });
    }
  }

  /// Returns a colored chip based on the delivery status.
  Widget _getStatusChip(String status) {
    Color color;
    switch (status) {
      case 'À Préparer':
        color = Colors.orange;
        break;
      case 'En Cours de Livraison':
        color = Colors.blue;
        break;
      case 'Livré':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(status,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Base query for the 'livraisons' collection
    Query query = FirebaseFirestore.instance.collection('livraisons');

    // Filter by service type if one is provided
    if (widget.serviceType != null) {
      query = query.where('serviceType', isEqualTo: widget.serviceType);
    }

    // Final stream filters for active statuses and orders by creation date
    final Stream<QuerySnapshot> livraisonsStream = query
        .where('status', whereIn: ['À Préparer', 'En Cours de Livraison'])
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.serviceType == null
            ? 'Livraisons Actives'
            : 'Livraisons Actives - ${widget.serviceType}'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: livraisonsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune livraison active',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final livraisons = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: livraisons.length,
            itemBuilder: (context, index) {
              final doc = livraisons[index];
              final data = doc.data() as Map<String, dynamic>;
              final bonNumber = data['bonLivraisonCode'] ?? 'N/A';
              final clientName = data['clientName'] ?? 'Client inconnu';
              final status = data['status'] ?? 'À Préparer';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final formattedDate = createdAt != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt)
                  : 'Date inconnue';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(Icons.local_shipping,
                          color: Colors.blue.shade700),
                    ),
                    title: Text(
                      'Bon $bonNumber',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Client: $clientName'),
                        Text('Date: $formattedDate',
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        _getStatusChip(status),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          // Navigate to the Add/Edit page with the livraisonId
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddLivraisonPage(
                                serviceType: widget.serviceType,
                                livraisonId: doc.id,
                              ),
                            ),
                          );
                        } else if (value == 'details') {
                          // Navigate to the details page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    LivraisonDetailsPage(livraisonId: doc.id)),
                          );
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'details',
                          child: Text('Voir Détails'),
                        ),
                        // Conditionally show the "Modifier" option based on user role
                        if (_canEdit)
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Modifier'),
                          ),
                      ],
                    ),
                    onTap: () {
                      // Default tap action is to view details
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                LivraisonDetailsPage(livraisonId: doc.id)),
                      );
                    }),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddLivraisonPage(serviceType: widget.serviceType),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle Livraison'),
      ),
    );
  }
}
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

class _LivraisonsHubPageState extends State<LivraisonsHubPage>
    with SingleTickerProviderStateMixin {
  // ✅ Added Mixin for Tabs

  late TabController _tabController;
  bool _canEdit = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    // Initialize TabController for 2 tabs
    _tabController = TabController(length: 2, vsync: this);
    _checkUserPermissions();
  }

  /// Checks the current user's role to determine if they have permission to edit.
  Future<void> _checkUserPermissions() async {
    final canEdit = await RolePermissions.canCurrentUserEditLivraison();
    final canDelete = await RolePermissions.canCurrentUserDeleteLivraison();

    if (mounted) {
      setState(() {
        _canEdit = canEdit;
        _canDelete = canDelete;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _deleteLivraison(String livraisonId, String bonNumber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer définitivement le Bon de Livraison $bonNumber? Cette action est irréversible.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child:
              const Text('Supprimer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('livraisons')
            .doc(livraisonId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Livraison supprimée.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Erreur lors de la suppression de la livraison: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur de suppression: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ✅ NEW: Reusable List Builder to support Tabs efficiently
  Widget _buildLivraisonList(
      String statusFilter, IconData emptyIcon, String emptyText) {
    Query query = FirebaseFirestore.instance.collection('livraisons');

    if (widget.serviceType != null) {
      query = query.where('serviceType', isEqualTo: widget.serviceType);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query
          .where('status', isEqualTo: statusFilter) // ✅ Filter by tab status
          .orderBy('createdAt', descending: true)
          .snapshots(),
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
                Icon(emptyIcon, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  emptyText,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
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

            // ✅ Picking Progress Indicator
            final products = data['products'] as List? ?? [];
            int totalItems = 0;
            int pickedItems = 0;
            if (status == 'À Préparer') {
              for (var p in products) {
                totalItems += (p['quantity'] as int? ?? 0);
                pickedItems += (p['serialNumbers'] as List? ?? []).length;
              }
            }

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: status == 'À Préparer'
                        ? Colors.orange.shade100
                        : Colors.blue.shade100,
                    child: Icon(
                      status == 'À Préparer'
                          ? Icons.inventory
                          : Icons.local_shipping,
                      color: status == 'À Préparer'
                          ? Colors.orange.shade800
                          : Colors.blue.shade800,
                    ),
                  ),
                  title: Text(
                    'Bon $bonNumber',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Client: $clientName',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(formattedDate,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),

                      // Show progress bar only for items in preparation
                      if (status == 'À Préparer' && totalItems > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: totalItems > 0 ? pickedItems / totalItems : 0,
                                  backgroundColor: Colors.grey.shade200,
                                  color: Colors.orange,
                                  minHeight: 4,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('$pickedItems/$totalItems',
                                  style: const TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      else if (status != 'À Préparer') ...[
                        const SizedBox(height: 4),
                        _getStatusChip(status),
                      ]
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  LivraisonDetailsPage(livraisonId: doc.id)),
                        );
                      } else if (value == 'delete') {
                        _deleteLivraison(doc.id, bonNumber);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'details',
                        child: Text('Voir Détails'),
                      ),
                      if (_canEdit)
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Modifier'),
                        ),
                      if (_canDelete)
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Supprimer',
                              style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                  onTap: () {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.serviceType == null
            ? 'Centre de Livraisons'
            : 'Livraisons - ${widget.serviceType}'),
        // ✅ TabBar added to the AppBar
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(
                text: 'À PRÉPARER (STOCK)',
                icon: Icon(Icons.inventory_2_outlined)),
            Tab(
                text: 'EN COURS (ROUTE)',
                icon: Icon(Icons.local_shipping_outlined)),
          ],
        ),
      ),
      // ✅ TabBarView to switch between lists
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Stock Team View (Preparation)
          _buildLivraisonList('À Préparer', Icons.playlist_add_check,
              'Aucune commande à préparer.'),

          // Tab 2: Logistics/Driver View (In Progress)
          _buildLivraisonList('En Cours de Livraison',
              Icons.local_shipping_outlined, 'Aucune livraison en cours.'),
        ],
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
        label: const Text('Nouvelle Demande'),
      ),
    );
  }
}
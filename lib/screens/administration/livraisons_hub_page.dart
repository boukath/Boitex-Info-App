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
  bool _canDelete = false; // ✅ AJOUTÉ: Variable d'état pour la permission de suppression

  @override
  void initState() {
    super.initState();
    _checkUserPermissions();
  }

  /// Checks the current user's role to determine if they have permission to edit.
  Future<void> _checkUserPermissions() async {
    // This calls the centralized permission logic from your user_roles.dart file.
    final canEdit = await RolePermissions.canCurrentUserEditLivraison();
    final canDelete = await RolePermissions.canCurrentUserDeleteLivraison(); // ✅ AJOUTÉ: Vérification de la permission de suppression

    if (mounted) {
      setState(() {
        _canEdit = canEdit;
        _canDelete = canDelete; // ✅ MISE À JOUR
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

  // ✅ NOUVEAU: Fonction de suppression avec dialogue de confirmation
  /// Affiche une boîte de dialogue de confirmation et supprime la livraison si confirmé.
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
              child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
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

        // Afficher la confirmation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Livraison supprimée.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Gérer l'erreur de suppression
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
                        } else if (value == 'delete') { // ✅ AJOUTÉ: Gestion de la suppression
                          _deleteLivraison(doc.id, bonNumber);
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
                        // ✅ NOUVEAU: Option de suppression conditionnelle
                        if (_canDelete)
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
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
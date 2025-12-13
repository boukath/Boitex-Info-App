// lib/screens/service_technique/sav_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/screens/service_technique/add_sav_ticket_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/utils/user_roles.dart'; // Import for role check
import 'package:firebase_auth/firebase_auth.dart'; // Import for current user
// ✅ ADDED: Import for SAV History Page
import 'package:boitex_info_app/screens/service_technique/sav_ticket_history_page.dart';

// ✅ MODIFIED: Converted to StatefulWidget to fetch user role
class SavListPage extends StatefulWidget {
  final String serviceType;

  const SavListPage({super.key, required this.serviceType});

  @override
  State<SavListPage> createState() => _SavListPageState();
}

class _SavListPageState extends State<SavListPage> {
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();
  }

  // Define the roles considered managers for the delete permission.
  final List<String> _managerRoles = const [
    UserRoles.admin,
    UserRoles.pdg,
    UserRoles.responsableAdministratif,
    UserRoles.responsableCommercial,
    UserRoles.responsableTechnique,
    UserRoles.responsableIT,
    UserRoles.chefDeProjet,
  ];

  // Function to fetch the current user's role
  Future<void> _fetchCurrentUserRole() async {
    final role = await UserRoles.getCurrentUserRole();
    if (mounted) {
      setState(() {
        _currentUserRole = role;
      });
    }
  }

  // Helper to check if the current user is a manager (can delete)
  bool get _isManager {
    if (_currentUserRole == null) return false;
    return _managerRoles.contains(_currentUserRole!);
  }

  // ⭐️ FIXED (Error 4): Function must return Future<bool?> for 'confirmDismiss'
  Future<bool?> _deleteTicket(String docId, String savCode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation de Suppression'),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer le ticket SAV $savCode ? Cette action est irréversible.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ANNULER'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('SUPPRIMER'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('sav_tickets')
            .doc(docId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ticket SAV $savCode supprimé.')),
          );
        }
        return true; // Return true to dismiss the list tile
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression: $e')),
          );
        }
        return false; // Return false to keep the list tile (deletion failed)
      }
    }
    return false; // Return false if not confirmed
  }

  Widget _getStatusChip(String status) {
    Color color;
    String label = status;

    switch (status) {
      case 'Nouveau':
        color = Colors.blue;
        break;
      case 'En Diagnostic':
      case 'En Réparation':
        color = Colors.orange;
        break;
      case 'Terminé':
        color = Colors.green;
        break;
      case 'Irréparable - Remplacement Demandé':
        color = Colors.red;
        label = 'Remplacement Demandé';
        break;
      case 'Irréparable - Remplacement Approuvé':
        color = Colors.teal;
        label = 'Remplacement Approuvé';
        break;
      case 'En attente de pièce':
        color = Colors.purple;
        break;
      case 'Retourné':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserRole == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tickets SAV')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Get the status filter to exclude 'Retourné' tickets
    // ✅ MODIFIED: Added 'Dépose' to the excluded list
    final List<String> excludedStatuses = ['Retourné', 'Dépose'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Tickets SAV - ${widget.serviceType}'),
        backgroundColor: Colors.orange,
        // ✅ ADDED: History Action Button
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: "Historique SAV",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SavTicketHistoryPage(
                    serviceType: widget.serviceType,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sav_tickets')
            .where('serviceType', isEqualTo: widget.serviceType)
            .where('status', whereNotIn: excludedStatuses)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucun ticket SAV en cours.'));
          }

          final tickets = snapshot.data!.docs.map((doc) {
            return SavTicket.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>);
          }).toList();

          return ListView(
            children: tickets.map((ticket) {
              // We define the logic to open details here to reuse it
              void openDetails() {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SavTicketDetailsPage(ticket: ticket),
                  ),
                );
              }

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: InkWell(
                  onTap: openDetails,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.build_circle_outlined,
                            color: Colors.orange, size: 30),
                        const SizedBox(width: 12),
                        // Expanded Column for Text Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(ticket.savCode,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  _getStatusChip(ticket.status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ticket.clientName,
                                style: TextStyle(color: Colors.grey.shade700),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Produit: ${ticket.productName}',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // ✅ NEW: Popup Menu for Options
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              openDetails();
                            } else if (value == 'delete') {
                              _deleteTicket(ticket.id!, ticket.savCode);
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Ouvrir / Traiter'),
                                  ],
                                ),
                              ),
                              // Only show delete option if user is a manager
                              if (_isManager)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Supprimer'),
                                    ],
                                  ),
                                ),
                            ];
                          },
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) =>
                    AddSavTicketPage(serviceType: widget.serviceType)),
          );
        },
        tooltip: 'Nouveau Ticket SAV',
        child: const Icon(Icons.add),
      ),
    );
  }
}
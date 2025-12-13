// lib/screens/administration/requisition_approval_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
// ✅ NEW: Import the add requisition page
import 'package:boitex_info_app/screens/administration/add_requisition_page.dart';

class RequisitionApprovalPage extends StatefulWidget {
  final String userRole;
  const RequisitionApprovalPage({super.key, required this.userRole});

  @override
  State<RequisitionApprovalPage> createState() => _RequisitionApprovalPageState();
}

class _RequisitionApprovalPageState extends State<RequisitionApprovalPage> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _deleteRequisition(String docId) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text(
              'Voulez-vous vraiment supprimer cette demande ? Cette action est irréversible.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child:
              const Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('requisitions')
            .doc(docId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande supprimée avec succès.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Widget _getStatusChip(String status) {
    Color color;
    switch (status) {
      case 'Reçue':
        color = Colors.green;
        break;
      case 'Reçue avec Écarts':
      case "En attente d'approbation":
        color = Colors.orange;
        break;
      case 'Refusée':
        color = Colors.red;
        break;
      case 'Commandée':
        color = Colors.blue;
        break;
      case 'Partiellement Reçue':
        color = Colors.purple;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(
        status,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approbations Requises'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requisitions')
            .where('status', isEqualTo: "En attente d'approbation")
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('Aucune demande en attente d\'approbation.'));
          }

          final requisitionDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requisitionDocs.length,
            itemBuilder: (context, index) {
              final reqDoc = requisitionDocs[index];
              final reqData = reqDoc.data() as Map<String, dynamic>;
              final createdAt = reqData['createdAt'] as Timestamp?;
              final reqCode = reqData['requisitionCode'] ?? 'N/A';
              final requestedBy = reqData['requestedBy'] ?? 'N/A';
              final status = reqData['status'] ?? 'N/A';

              final bool canModify = RolePermissions.canManageRequisitions(widget.userRole);

              return Card(
                margin:
                const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  title: Text(reqCode,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _getStatusChip(status),

                      if (canModify)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'edit') {
                              //
                              // ✅✅✅ THIS IS THE CHANGED LINE ✅✅✅
                              //
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  // We now go to AddRequisitionPage
                                  builder: (context) => AddRequisitionPage(
                                    // And pass the ID to edit
                                    requisitionId: reqDoc.id,
                                  ),
                                ),
                              );
                            } else if (value == 'delete') {
                              _deleteRequisition(reqDoc.id);
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Modifier'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Supprimer'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      if (!canModify)
                        const SizedBox(width: 40),
                    ],
                  ),
                  onTap: () {
                    // Default tap (for PDG approval) still goes to details
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RequisitionDetailsPage(
                          requisitionId: reqDoc.id,
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
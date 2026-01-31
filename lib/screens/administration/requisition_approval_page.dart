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
  State<RequisitionApprovalPage> createState() =>
      _RequisitionApprovalPageState();
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Demande supprimée avec succès.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${e.toString()}')),
          );
        }
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
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8.0),
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
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('Tout est à jour !',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Aucune demande en attente.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final requisitionDocs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: requisitionDocs.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final reqDoc = requisitionDocs[index];
              final reqData = reqDoc.data() as Map<String, dynamic>;

              // Extract Data safely with fallbacks
              final createdAt = reqData['createdAt'] as Timestamp?;
              final reqCode = reqData['requisitionCode'] ?? 'N/A';
              final requestedBy = reqData['requestedBy'] ?? 'Inconnu';
              final status = reqData['status'] ?? 'Statut Inconnu';

              // ✅ NEW: Extract Title and Supplier
              final String title = reqData['title'] ?? 'Demande sans titre';
              final String supplier = reqData['supplierName'] ?? 'Fournisseur inconnu';

              final bool canModify =
              RolePermissions.canManageRequisitions(widget.userRole);

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // Navigate to details
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RequisitionDetailsPage(
                          requisitionId: reqDoc.id,
                          userRole: widget.userRole,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Header (Title + Status)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title, // ✅ Display the human readable title
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Menu Actions (Edit/Delete)
                            if (canModify)
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.more_horiz, size: 20),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AddRequisitionPage(
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
                              ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Row 2: Supplier info & Code (The Visual Anchor)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.store, size: 14, color: Colors.grey.shade700),
                              const SizedBox(width: 6),
                              Text(
                                supplier,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                  fontSize: 13,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text("•", style: TextStyle(color: Colors.grey.shade400)),
                              ),
                              Text(
                                reqCode,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Row 3: Footer (User, Date, Chip)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      requestedBy,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (createdAt != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      DateFormat('dd MMM yyyy, HH:mm').format(createdAt.toDate()),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            _getStatusChip(status),
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
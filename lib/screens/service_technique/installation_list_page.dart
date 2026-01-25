// lib/screens/service_technique/installation_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Typography
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/add_installation_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_history_list_page.dart';

class InstallationListPage extends StatelessWidget {
  final String userRole;
  final String serviceType;

  const InstallationListPage({
    super.key,
    required this.userRole,
    required this.serviceType,
  });

  // 🎨 THEME COLORS
  final Color _primaryBlue = const Color(0xFF2962FF);
  final Color _bgLight = const Color(0xFFF4F6F9);
  final Color _cardWhite = Colors.white;
  final Color _textDark = const Color(0xFF2D3436);

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'En Cours':
        return Colors.orange.shade700;
      case 'À Planifier':
        return Colors.blue.shade700;
      case 'Planifiée':
        return Colors.purple.shade700;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusBgColor(String? status) {
    return _getStatusColor(status).withOpacity(0.1);
  }

  void _navigateToDetails(BuildContext context, DocumentSnapshot doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstallationDetailsPage(
          installationDoc: doc,
          userRole: userRole,
        ),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, DocumentSnapshot doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddInstallationPage(
          userRole: userRole,
          serviceType: serviceType,
          installationToEdit: doc,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String docId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer ?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer cette installation ?',
            style: GoogleFonts.poppins()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
            Text('Annuler', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: Text('Supprimer',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('installations')
            .doc(docId)
            .delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Installation supprimée.'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = RolePermissions.canScheduleInstallation(userRole);

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'INSTALLATIONS ${serviceType.toUpperCase()}',
          style: GoogleFonts.poppins(
            color: _textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
                color: _bgLight, borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: const Icon(Icons.history_rounded, color: Colors.black87),
              tooltip: "Historique",
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => InstallationHistoryListPage(
                      serviceType: serviceType,
                      userRole: userRole,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('installations')
            .where('serviceType', isEqualTo: serviceType)
            .where('status', whereIn: ['À Planifier', 'Planifiée', 'En Cours'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: _primaryBlue));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Erreur',
                    style: GoogleFonts.poppins(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 10,
                            spreadRadius: 5)
                      ],
                    ),
                    child: Icon(Icons.router_outlined,
                        size: 50, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune installation active',
                    style: GoogleFonts.poppins(
                        fontSize: 16, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          final installations = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: installations.length,
            itemBuilder: (context, index) {
              final doc = installations[index];
              final data = doc.data() as Map<String, dynamic>;

              final installationCode = data['installationCode'] ?? 'N/A';
              final clientName = data['clientName'] ?? 'Client inconnu';
              final storeName = data['storeName'] ?? 'Magasin inconnu';
              final status = data['status'] ?? 'À Planifier';

              final DateTime? installationDate =
              (data['installationDate'] as Timestamp?)?.toDate();
              final String dateDisplay = installationDate != null
                  ? DateFormat('dd MMM yyyy', 'fr_FR').format(installationDate)
                  : 'Date non définie';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: Slidable(
                  key: ValueKey(doc.id),
                  endActionPane: canEdit
                      ? ActionPane(
                    motion: const StretchMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (ctx) => _navigateToEdit(context, doc),
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        icon: Icons.edit,
                        label: 'Modifier',
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(16)),
                      ),
                      SlidableAction(
                        onPressed: (ctx) =>
                            _confirmDelete(context, doc.id),
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: 'Supprimer',
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(16)),
                      ),
                    ],
                  )
                      : null,
                  child: InkWell(
                    onTap: () => _navigateToDetails(context, doc),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon Box
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.router_outlined,
                                    color: _primaryBlue, size: 24),
                              ),
                              const SizedBox(width: 16),

                              // Main Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      installationCode,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today,
                                            size: 12,
                                            color: Colors.grey.shade500),
                                        const SizedBox(width: 6),
                                        Text(
                                          dateDisplay,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: installationDate != null
                                                ? _textDark
                                                : Colors.red,
                                            fontWeight: installationDate != null
                                                ? FontWeight.w500
                                                : FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusBgColor(status),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  style: GoogleFonts.poppins(
                                    color: _getStatusColor(status),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          // Location Info
                          Row(
                            children: [
                              const Icon(Icons.business,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  clientName,
                                  style: GoogleFonts.poppins(
                                      fontSize: 14, color: _textDark),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.storefront,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  // ✅ UPDATED: Added Store Location
                                  '$storeName ${data['storeLocation'] != null ? "- ${data['storeLocation']}" : ""}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddInstallationPage(
                userRole: userRole,
                serviceType: serviceType,
              ),
            ),
          );
        },
        backgroundColor: _primaryBlue,
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('NOUVELLE',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.white)),
      )
          : null,
    );
  }
}
// lib/screens/administration/project_history_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ PREMIUM UI ADDITION
import 'package:boitex_info_app/screens/administration/project_details_page.dart';

class ProjectHistoryPage extends StatelessWidget {
  final String userRole;
  final String serviceType;

  const ProjectHistoryPage({
    super.key,
    required this.userRole,
    required this.serviceType,
  });

  // ✅ PREMIUM COLOR PALETTE
  static const Color bgColor = Color(0xFFF5F7FA);
  static const Color surfaceColor = Colors.white;
  static const Color textDark = Color(0xFF1E293B);
  static const Color textLight = Color(0xFF64748B);

  // Dynamic primary color based on service type
  Color get primaryColor => serviceType == 'Service IT' ? const Color(0xFF0EA5E9) : const Color(0xFF4F46E5);

  // Premium Custom Status Colors
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Transféré à l\'Installation':
        return const Color(0xFF10B981); // Emerald Green
      case 'Refusé':
        return const Color(0xFFEF4444); // Rose Red
      default:
        return const Color(0xFF64748B); // Slate Grey
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🧠 LOGIC: Check EITHER the boolean flag OR the legacy string
    // (Upgraded to match the active project list logic for consistency!)
    final String flagName = serviceType == 'Service IT' ? 'hasItModule' : 'hasTechniqueModule';
    final filter = Filter.or(
      Filter(flagName, isEqualTo: true),
      Filter('serviceType', isEqualTo: serviceType),
    );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Historique $serviceType', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textDark, fontSize: 18)),
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black.withOpacity(0.05), height: 1),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ This query fetches ONLY the "Archived" statuses using the robust dual-filter
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where(filter)
            .where('status', whereIn: [
          'Transféré à l\'Installation',
          'Refusé',
        ])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Une erreur est survenue.', style: GoogleFonts.inter(color: Colors.redAccent)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final projectDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            physics: const BouncingScrollPhysics(),
            itemCount: projectDocs.length,
            itemBuilder: (context, index) {
              final projectDoc = projectDocs[index];
              final projectData = projectDoc.data() as Map<String, dynamic>;
              final createdAt = (projectData['createdAt'] as Timestamp).toDate();

              final Color statusColor = _getStatusColor(projectData['status'] ?? '');

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))
                  ],
                  border: Border.all(color: Colors.black.withOpacity(0.02)),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ProjectDetailsPage(
                              projectId: projectDoc.id, userRole: userRole),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.04), // Neutral for history
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.archive_rounded, color: textLight, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      projectData['clientName'] ?? 'Client inconnu',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17, color: textDark),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.storefront_rounded, size: 14, color: textLight),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${projectData['storeName'] ?? 'Magasin'} - ${projectData['storeLocation'] ?? 'Lieu'}',
                                            style: GoogleFonts.inter(fontSize: 13, color: textLight, fontWeight: FontWeight.w500),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '📝 ${projectData['initialRequest'] ?? 'Aucune demande détaillée.'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 13, height: 1.5),
                            ),
                          ),

                          const SizedBox(height: 16),
                          Divider(color: Colors.black.withOpacity(0.04), height: 1),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 🚀 Premium Status Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text(
                                      projectData['status'] ?? 'Inconnu',
                                      style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                                    ),
                                  ],
                                ),
                              ),

                              // Date & Creator Info
                              Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded, size: 14, color: textLight),
                                  const SizedBox(width: 4),
                                  Text(
                                    projectData['createdByName'] ?? 'N/A',
                                    style: GoogleFonts.inter(fontSize: 12, color: textLight, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.calendar_today_rounded, size: 14, color: textLight),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy', 'fr_FR').format(createdAt),
                                    style: GoogleFonts.inter(fontSize: 12, color: textLight, fontWeight: FontWeight.w600),
                                  ),
                                ],
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
    );
  }

  // ✅ PREMIUM EMPTY STATE
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: textLight.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_toggle_off_rounded, size: 64, color: textLight.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun projet dans\nl\'historique.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textLight,
                height: 1.5
            ),
          ),
        ],
      ),
    );
  }
}
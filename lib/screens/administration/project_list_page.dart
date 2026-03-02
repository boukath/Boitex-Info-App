// lib/screens/administration/project_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ PREMIUM UI ADDITION
import 'package:boitex_info_app/screens/administration/project_details_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';

class ProjectListPage extends StatefulWidget {
  final String userRole;
  final String serviceType; // 'Service Technique' OR 'Service IT'

  const ProjectListPage({
    super.key,
    required this.userRole,
    required this.serviceType,
  });

  @override
  State<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends State<ProjectListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _canDelete = false;

  // ✅ PREMIUM COLOR PALETTE
  static const Color bgColor = Color(0xFFF5F7FA);
  static const Color surfaceColor = Colors.white;
  static const Color textDark = Color(0xFF1E293B);
  static const Color textLight = Color(0xFF64748B);

  // Dynamic primary color based on service type
  Color get primaryColor => widget.serviceType == 'Service IT' ? const Color(0xFF0EA5E9) : const Color(0xFF4F46E5);

  final List<Map<String, dynamic>> _pipelineStages = [
    {
      'title': 'Nouvelles',
      'statuses': ['Nouvelle Demande']
    },
    {
      'title': 'En Cours',
      'statuses': ['En Cours d\'Évaluation']
    },
    {
      'title': 'Éval. Terminée',
      'statuses': ['Évaluation Technique Terminé', 'Évaluation IT Terminé', 'Évaluation Terminée']
    },
    {
      'title': 'Finalisation',
      'statuses': ['Finalisation de la Commande']
    },
    {
      'title': 'À Planifier',
      'statuses': ['À Planifier']
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _pipelineStages.length, vsync: this);
    _checkUserPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkUserPermissions() async {
    final canDelete = await RolePermissions.canCurrentUserDeleteLivraison();
    if (mounted) {
      setState(() {
        _canDelete = canDelete;
      });
    }
  }

  Future<void> _deleteProject(String projectId, String clientName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Confirmer la suppression', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer définitivement le projet pour "$clientName"? Cette action est irréversible et supprime toutes les données associées.',
              style: GoogleFonts.inter(color: textDark, height: 1.5)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Annuler', style: GoogleFonts.inter(color: textLight, fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: Text('Supprimer', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Projet supprimé pour "$clientName".', style: GoogleFonts.inter()),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        debugPrint('Erreur lors de la suppression du projet: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur de suppression: ${e.toString()}', style: GoogleFonts.inter()),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Projets ${widget.serviceType}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textDark, fontSize: 18)),
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05))),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              physics: const BouncingScrollPhysics(),
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(color: primaryColor, width: 3),
                insets: const EdgeInsets.symmetric(horizontal: 16),
              ),
              labelColor: primaryColor,
              unselectedLabelColor: textLight,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: _pipelineStages.map((stage) {
                return _ProjectPipelineTab(
                  serviceType: widget.serviceType,
                  tabTitle: stage['title'] as String,
                  statuses: stage['statuses'] as List<String>,
                  primaryColor: primaryColor,
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: _pipelineStages.map((stage) {
          return _ProjectListStream(
            userRole: widget.userRole,
            serviceType: widget.serviceType,
            statuses: stage['statuses'] as List<String>,
            emptyMessage: 'Aucun projet dans\n"${stage['title']}".',
            canDelete: _canDelete,
            onDelete: _deleteProject,
            primaryColor: primaryColor,
          );
        }).toList(),
      ),
    );
  }
}

// ✅ PREMIUM BADGE TAB
class _ProjectPipelineTab extends StatelessWidget {
  final String serviceType;
  final String tabTitle;
  final List<String> statuses;
  final Color primaryColor;

  const _ProjectPipelineTab({
    required this.serviceType,
    required this.tabTitle,
    required this.statuses,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    // 🧠 LOGIC: Check EITHER the boolean flag OR the legacy string
    final String flagName = serviceType == 'Service IT' ? 'hasItModule' : 'hasTechniqueModule';
    final filter = Filter.or(
      Filter(flagName, isEqualTo: true),
      Filter('serviceType', isEqualTo: serviceType),
    );

    return StreamBuilder<int>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where(filter)
          .where('status', whereIn: statuses)
          .snapshots()
          .map((snapshot) => snapshot.size),
      builder: (context, snapshot) {
        final int count = snapshot.data ?? 0;

        if (count == 0) {
          return Tab(height: 56, text: tabTitle);
        }

        return Tab(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(tabTitle),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ✅ PREMIUM LIST STREAM
class _ProjectListStream extends StatelessWidget {
  final String userRole;
  final String serviceType;
  final List<String> statuses;
  final String emptyMessage;
  final bool canDelete;
  final Function(String, String) onDelete;
  final Color primaryColor;

  const _ProjectListStream({
    required this.userRole,
    required this.serviceType,
    required this.statuses,
    required this.emptyMessage,
    required this.canDelete,
    required this.onDelete,
    required this.primaryColor,
  });

  // Premium Custom Status Colors
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Nouvelle Demande':
        return const Color(0xFF3B82F6); // Blue
      case 'En Cours d\'Évaluation':
        return const Color(0xFFF59E0B); // Amber
      case 'Évaluation Technique Terminé':
      case 'Évaluation IT Terminé':
      case 'Évaluation Terminée':
        return const Color(0xFF10B981); // Emerald
      case 'Finalisation de la Commande':
        return const Color(0xFF14B8A6); // Teal
      case 'À Planifier':
        return const Color(0xFF8B5CF6); // Purple
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    final String flagName = serviceType == 'Service IT' ? 'hasItModule' : 'hasTechniqueModule';
    final filter = Filter.or(
      Filter(flagName, isEqualTo: true),
      Filter('serviceType', isEqualTo: serviceType),
    );

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where(filter)
          .where('status', whereIn: statuses)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.redAccent)));
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
            final String projectId = projectDoc.id;
            final createdAt = (projectData['createdAt'] as Timestamp).toDate();

            final Color statusColor = _getStatusColor(projectData['status'] ?? '');

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
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
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.business_center_rounded, color: primaryColor, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    projectData['clientName'] ?? 'Client inconnu',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17, color: const Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.storefront_rounded, size: 14, color: const Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${projectData['storeName'] ?? 'Magasin'} - ${projectData['storeLocation'] ?? 'Lieu'}',
                                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (canDelete)
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade400, size: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      onDelete(projectId, projectData['clientName'] ?? 'Projet Inconnu');
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                          const SizedBox(width: 8),
                                          Text('Supprimer', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
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
                            color: const Color(0xFFF5F7FA),
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

                            // Date Info
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade400),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('dd MMM yyyy', 'fr_FR').format(createdAt),
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
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
              color: primaryColor.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.folder_off_rounded, size: 64, color: primaryColor.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
                height: 1.5
            ),
          ),
        ],
      ),
    );
  }
}
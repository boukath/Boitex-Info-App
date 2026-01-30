// lib/screens/administration/administration_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boitex_info_app/screens/administration/manage_clients_page.dart';
import 'package:boitex_info_app/screens/administration/add_project_page.dart';
import 'package:boitex_info_app/screens/administration/manage_projects_page.dart';
import 'package:boitex_info_app/screens/administration/product_catalog_page.dart';
import 'package:boitex_info_app/screens/administration/stock_page.dart';
import 'package:boitex_info_app/screens/administration/manage_missions_page.dart';
import 'package:boitex_info_app/screens/administration/replacement_requests_hub_page.dart';
import 'package:boitex_info_app/screens/administration/requisition_approval_page.dart';
import 'package:boitex_info_app/screens/administration/purchasing_hub_page.dart';
import 'package:boitex_info_app/screens/administration/billing_hub_page.dart';
import 'package:boitex_info_app/screens/administration/activity_log_page.dart';
import 'package:boitex_info_app/screens/administration/livraisons_hub_page.dart';
import 'package:boitex_info_app/screens/administration/rappel_page.dart';
import 'package:boitex_info_app/screens/announce/announce_hub_page.dart';
import 'package:boitex_info_app/screens/administration/analytics_dashboard_page.dart';
import 'package:boitex_info_app/screens/administration/universal_map_page.dart';
import 'package:boitex_info_app/screens/administration/portal_requests_list_page.dart';

// ✅ NEW IMPORT: Reporting Hub
import 'package:boitex_info_app/screens/administration/reporting_hub_page.dart';

import 'dart:math' as math;

class AdministrationDashboardPage extends StatefulWidget {
  final String displayName;
  final String userRole;

  const AdministrationDashboardPage({
    super.key,
    required this.displayName,
    required this.userRole,
  });

  @override
  State<AdministrationDashboardPage> createState() =>
      _AdministrationDashboardPageState();
}

class _AdministrationDashboardPageState extends State<AdministrationDashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;

      final canSeeMgmt = <String>{
        'PDG',
        'Admin',
        'Responsable Administratif',
        'Responsable Commercial',
        'Responsable Technique',
        'Responsable IT',
        'Chef de Projet',
      }.contains(widget.userRole);

      if (width > 900) {
        return _buildWebDashboard(context, canSeeMgmt, width);
      } else {
        return _buildMobileDashboard(context, canSeeMgmt);
      }
    });
  }

  // ========================= WEB =========================

  Widget _buildWebDashboard(
      BuildContext context, bool canSeeMgmt, double width) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFFF093FB)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildWebHeader(),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: math.min((width - 1400) / 2, width * 0.1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT COLUMN - Actions Grid
                          Expanded(
                            flex: 3,
                            child: _buildGlassCard(
                                child: _buildWebActionsGrid(context)),
                          ),
                          const SizedBox(width: 24),
                          // RIGHT COLUMN - Urgent Tasks
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tâches Urgentes',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildWebUrgentTasksColumn(canSeeMgmt),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(40, 20, 40, 32),
        child: Row(
          children: [
            // Back Button
            _glassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            // Center chip: Name • Role (large, readable, no scaling)
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.15)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.userRole,
                            maxLines: 1,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.95),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            // Notification Button
            _glassIconButton(
              icon: Icons.notifications_rounded,
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const RappelPage())),
            ),

            // *** ANNOUNCE BUTTON (WEB) ***
            const SizedBox(width: 12),
            _glassIconButton(
              icon: Icons.campaign_rounded,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AnnounceHubPage())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassIconButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildWebActionsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions Rapides',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 1.0,
          children: _buildQuickActions(context),
        ),
      ],
    );
  }

  Widget _buildWebUrgentTasksColumn(bool canSeeMgmt) {
    final cards = <Widget>[
      const _ReplacementRequestsCard(),
      if (canSeeMgmt) _RequisitionPipelineCard(userRole: widget.userRole),
      if (canSeeMgmt) const _PendingBillingCard(),
      if (canSeeMgmt) const _PendingReplacementsCard(),
      if (canSeeMgmt) const _LivraisonsCard(),
    ];

    return Column(
      children: cards.asMap().entries.map((entry) {
        final index = entry.key;
        final card = entry.value;
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 600 + (index * 100)),
          tween: Tween(begin: 0, end: 1),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: card,
        );
      }).toList(),
    );
  }

  // ========================= MOBILE =========================

  Widget _buildMobileDashboard(BuildContext context, bool canSeeMgmt) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFFF093FB)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildUltraCompactHeader(),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGlassCard(child: _buildActionsGrid(context)),
                        const SizedBox(height: 24),
                        _buildUrgentTasksSection(canSeeMgmt),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Header with large readable text (no scale down) and overflow-safe ellipsis
  Widget _buildUltraCompactHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Row(
          children: [
            _glassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.15)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.userRole,
                            maxLines: 1,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.95),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _glassIconButton(
              icon: Icons.notifications_rounded,
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const RappelPage())),
            ),

            // *** ANNOUNCE BUTTON (MOBILE) ***
            const SizedBox(width: 12),
            _glassIconButton(
              icon: Icons.campaign_rounded,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AnnounceHubPage())),
            ),
          ],
        ),
      ),
    );
  }

  // Shared glass card container
  Widget _buildGlassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: child,
    );
  }

  // Mobile actions grid
  Widget _buildActionsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions Rapides',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.90,
          children: _buildQuickActions(context),
        ),
      ],
    );
  }

  List<Widget> _buildQuickActions(BuildContext context) {
    final items = <_ActionData>[
      // ✅ 1. PORTAL REQUESTS (INBOX) - FIRST ITEM
      _ActionData(
        'Demandes\nWeb',
        Icons.public_rounded,
        const Color(0xFFFF5722), // Deep Orange for Attention
            () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PortalRequestsListPage())),
        // 🔴 BADGE LISTENER
        badgeStream: FirebaseFirestore.instance
            .collection('interventions')
            .where('interventionCode', isEqualTo: 'PENDING')
            .snapshots(),
      ),

      _ActionData(
        'Nouveau\nProjet',
        Icons.note_add_rounded,
        const Color(0xFF10B981),
            () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddProjectPage())),
      ),
      _ActionData(
        'Clients',
        Icons.store_rounded,
        const Color(0xFF3B82F6),
            () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ManageClientsPage(userRole: widget.userRole)),
        ),
      ),
      _ActionData(
        'Projets',
        Icons.folder_rounded,
        const Color(0xFF8B5CF6),
            () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ManageProjectsPage(userRole: widget.userRole)),
        ),
      ),
      _ActionData(
        'Produits',
        Icons.inventory_2_rounded,
        const Color(0xFF14B8A6),
            () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProductCatalogPage())),
      ),
      _ActionData(
        'Stock',
        Icons.warehouse_rounded,
        const Color(0xFF6366F1),
            () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const StockPage())),
      ),
      _ActionData(
        'Missions',
        Icons.assignment_rounded,
        const Color(0xFFA855F7),
            () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ManageMissionsPage())),
      ),
      _ActionData(
        'Livraisons',
        Icons.local_shipping_rounded,
        const Color(0xFFF59E0B),
            () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LivraisonsHubPage())),
      ),

      // ✅ NEW: CENTRE D'ÉDITION (REPORTING HUB)
      _ActionData(
        "Centre\nd'Édition",
        Icons.print_rounded,
        const Color(0xFF546E7A), // BlueGrey for "Official/Admin" feel
            () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ReportingHubPage())),
      ),

      _ActionData(
        'Historique',
        Icons.history_rounded,
        const Color(0xFF78716C),
            () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ActivityLogPage(userRole: widget.userRole)),
        ),
      ),
      _ActionData(
        'Analytics',
        Icons.analytics_rounded,
        const Color(0xFFEC4899),
            () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AnalyticsDashboardPage())),
      ),
      _ActionData(
        'Carte',
        Icons.map_rounded,
        const Color(0xFF0284C7),
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UniversalMapPage()),
        ),
      ),
    ];

    return items.asMap().entries.map((entry) {
      final index = entry.key;
      final action = entry.value;

      return TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 400 + (index * 80)),
        tween: Tween(begin: 0, end: 1),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: action.badgeStream != null
            ? StreamBuilder<QuerySnapshot>(
          stream: action.badgeStream,
          builder: (context, snapshot) {
            int count = 0;
            if (snapshot.hasData) {
              count = snapshot.data!.docs.length;
            }
            return _ActionCard(
              label: action.label,
              icon: action.icon,
              color: action.color,
              onTap: action.onTap,
              badgeCount: count,
            );
          },
        )
            : _ActionCard(
          label: action.label,
          icon: action.icon,
          color: action.color,
          onTap: action.onTap,
          badgeCount: 0,
        ),
      );
    }).toList();
  }

  Widget _buildUrgentTasksSection(bool canSeeMgmt) {
    final cards = <Widget>[
      const _ReplacementRequestsCard(),
      if (canSeeMgmt) _RequisitionPipelineCard(userRole: widget.userRole),
      if (canSeeMgmt) const _PendingBillingCard(),
      if (canSeeMgmt) const _PendingReplacementsCard(),
      if (canSeeMgmt) const _LivraisonsCard(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Tâches Urgentes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: cards.asMap().entries.map((entry) {
            final index = entry.key;
            final card = entry.value;
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 600 + (index * 100)),
              tween: Tween(begin: 0, end: 1),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: card,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ========================= MODELS & CARDS =========================

class _ActionData {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Stream<QuerySnapshot>? badgeStream; // ✅ NEW FIELD FOR BADGE

  _ActionData(this.label, this.icon, this.color, this.onTap, {this.badgeStream});
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount; // ✅ NEW FIELD

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      // ✅ FIX: Force the background container to FILL the GridCell
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15)
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient:
                        LinearGradient(colors: [color, color.withOpacity(0.7)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 🔴 NOTIFICATION BADGE
        if (badgeCount > 0)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252), // Bright red
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                badgeCount > 99 ? '99+' : badgeCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ======= STAT CARDS (streams) =======

class _ReplacementRequestsCard extends StatelessWidget {
  const _ReplacementRequestsCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('replacementRequests')
          .where('requestStatus', isEqualTo: "En attente d'action")
          .snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildGlowingCard(
          context: context,
          title: 'Demandes de Remplacement',
          count: count.toString(),
          icon: Icons.sync_problem_rounded,
          gradient:
          const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ReplacementRequestsHubPage(
                pageTitle: 'Demandes en Attente',
                filterStatus: "En attente d'action",
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RequisitionPipelineCard extends StatelessWidget {
  final String userRole;
  const _RequisitionPipelineCard({required this.userRole});

  @override
  Widget build(BuildContext context) {
    return _buildGlowingCard(
      context: context,
      title: 'Commandes',
      count: '',
      icon: Icons.shopping_cart_rounded,
      gradient:
      const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
      customBody: Row(
        children: [
          Expanded(
            child: _buildMiniStat(
              context,
              'Approbation',
              FirebaseFirestore.instance
                  .collection('requisitions')
                  .where('status', isEqualTo: "En attente d'approbation")
                  .snapshots(),
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RequisitionApprovalPage(userRole: userRole)),
              ),
            ),
          ),
          Container(
            width: 2,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.0),
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.0)
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildMiniStat(
              context,
              'À Commander',
              FirebaseFirestore.instance
                  .collection('requisitions')
                  .where('status', isEqualTo: "Approuvée")
                  .snapshots(),
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PurchasingHubPage(userRole: userRole)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      BuildContext ctx,
      String title,
      Stream<QuerySnapshot> stream,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (c, s) {
                final cnt = s.hasData ? s.data!.docs.length : 0;
                return Text(
                  cnt.toString(),
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingBillingCard extends StatelessWidget {
  const _PendingBillingCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('interventions')
          .where('status', isEqualTo: "Terminé")
          .snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildGlowingCard(
          context: context,
          title: 'Facturation en Attente',
          count: count.toString(),
          icon: Icons.receipt_long_rounded,
          gradient:
          const LinearGradient(colors: [Color(0xFF14B8A6), Color(0xFF0D9488)]),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const BillingHubPage())),
        );
      },
    );
  }
}

class _PendingReplacementsCard extends StatelessWidget {
  const _PendingReplacementsCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('replacementRequests')
          .where('requestStatus', isEqualTo: "Approuvé - Produit en stock")
          .snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildGlowingCard(
          context: context,
          title: 'Remplacements à Préparer',
          count: count.toString(),
          icon: Icons.inventory_rounded,
          gradient:
          const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ReplacementRequestsHubPage(
                pageTitle: 'Remplacements à Préparer',
                filterStatus: "Approuvé - Produit en stock",
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LivraisonsCard extends StatelessWidget {
  const _LivraisonsCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('livraisons')
          .where('status',
          whereIn: const ["À Préparer", "En Cours de Livraison"])
          .snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildGlowingCard(
          context: context,
          title: 'Livraisons Actives',
          count: count.toString(),
          icon: Icons.local_shipping_rounded,
          gradient:
          const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LivraisonsHubPage())),
        );
      },
    );
  }
}

// Shared glowing stat card
Widget _buildGlowingCard({
  required BuildContext context,
  required String title,
  required String count,
  required IconData icon,
  required Gradient gradient,
  VoidCallback? onTap,
  Widget? customBody,
}) {
  final isWeb = MediaQuery.of(context).size.width > 900;

  return Container(
    margin: isWeb ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ]),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15)),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: gradient.colors.first.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: Colors.white.withOpacity(0.9)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              customBody ??
                  ShaderMask(
                    shaderCallback: (bounds) => gradient.createShader(bounds),
                    child: Text(
                      count,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    ),
  );
}
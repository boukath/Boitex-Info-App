// lib/screens/administration/administration_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
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

class AdministrationDashboardPage extends StatelessWidget {
  final String displayName;
  final String userRole;

  const AdministrationDashboardPage({
    super.key,
    required this.displayName,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final isDesktop = width >= 1200;
      final isTablet  = width >= 800 && width < 1200;
      final canSeeMgmt = <String>[
        'PDG',
        'Admin',
        'Responsable Administratif',
        'Responsable Commercial',
        'Responsable Technique',
        'Responsable IT',
        'Chef de Projet',
      ].contains(userRole);

      if (isDesktop || isTablet) {
        return _buildWebDashboard(context, canSeeMgmt, width);
      } else {
        return _buildMobileDashboard(context, canSeeMgmt);
      }
    });
  }

  Widget _buildWebDashboard(
      BuildContext context, bool canSeeMgmt, double width) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar
              Container(
                width: 280,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Logo & Title
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            width: 140,
                            height: 140,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'BoitexInfo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // User info card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border:
                          Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white,
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    userRole,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Logout button
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: ElevatedButton.icon(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text('Déconnexion'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: Column(
                  children: [
                    // Top Bar
                    Container(
                      height: 80,
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Tableau de Bord',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Vue d\'ensemble',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF3B82F6),
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dashboard body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bienvenue, $displayName 👋',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Responsive quick actions grid
                            LayoutBuilder(builder: (ctx, box) {
                              int cols = 2;
                              final w = box.maxWidth;
                              if (w >= 1600) cols = 5;
                              else if (w >= 1200) cols = 4;
                              else if (w >= 900) cols = 3;
                              return GridView.count(
                                crossAxisCount: cols,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 24,
                                crossAxisSpacing: 24,
                                childAspectRatio: 1.3,
                                children: _buildQuickActions(context),
                              );
                            }),

                            const SizedBox(height: 32),
                            const Text(
                              'Vue d\'ensemble',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 20),

                            Wrap(
                              spacing: 20,
                              runSpacing: 20,
                              children: [
                                const _ReplacementRequestsCard(),
                                if (canSeeMgmt)
                                  _RequisitionPipelineCard(userRole: userRole),
                                if (canSeeMgmt) const _PendingBillingCard(),
                                if (canSeeMgmt)
                                  const _PendingReplacementsCard(),
                                if (canSeeMgmt) const _LivraisonsCard(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Back button in top-left corner
          Positioned(
            top: 16,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDashboard(BuildContext context, bool canSeeMgmt) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMobileHeader(context),
              const SizedBox(height: 24),
              _buildQuickActionsGrid(context),
              const SizedBox(height: 24),
              const Text(
                'Tâches Urgentes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildStatCardsMobile(context, canSeeMgmt),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        const Expanded(
          child: Text(
            'Administration',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.history),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ActivityLogPage()),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildQuickActions(BuildContext context) {
    final actions = <_ActionItem>[
      _ActionItem(
        Icons.note_add_rounded,
        'Nouveau Projet',
        const Color(0xFF10B981),
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddProjectPage()),
        ),
      ),
      _ActionItem(
        Icons.store_rounded,
        'Clients',
        const Color(0xFF3B82F6),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ManageClientsPage(userRole: userRole),
          ),
        ),
      ),
      _ActionItem(
        Icons.folder_rounded,
        'Projets',
        const Color(0xFF8B5CF6),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ManageProjectsPage(userRole: userRole),
          ),
        ),
      ),
      _ActionItem(
        Icons.inventory_2_rounded,
        'Produits',
        const Color(0xFF14B8A6),
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductCatalogPage()),
        ),
      ),
      _ActionItem(
        Icons.warehouse_rounded,
        'Stock',
        const Color(0xFF6366F1),
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StockPage()),
        ),
      ),
      _ActionItem(
        Icons.assignment_rounded,
        'Missions',
        const Color(0xFFA855F7),
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManageMissionsPage()),
        ),
      ),
      _ActionItem(
        Icons.local_shipping_rounded,
        'Livraisons',
        const Color(0xFFF59E0B),
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LivraisonsHubPage()),
        ),
      ),
    ];
    return actions.map((a) => _buildActionCard(context, a)).toList();
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final cross = kIsWeb && MediaQuery.of(context).size.width >= 900 ? 4 : 2;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: cross,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: _buildQuickActions(context),
    );
  }

  Widget _buildActionCard(BuildContext context, _ActionItem action) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: action.onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [action.color, action.color.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: action.color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCardsMobile(BuildContext context, bool canSeeMgmt) {
    final cards = <Widget>[
      const _ReplacementRequestsCard(),
      if (canSeeMgmt) ...[
        _RequisitionPipelineCard(userRole: userRole),
        const _PendingBillingCard(),
        const _PendingReplacementsCard(),
        const _LivraisonsCard(),
      ],
    ];
    return Column(
      children: cards
          .map((card) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: card,
      ))
          .toList(),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionItem(this.icon, this.label, this.color, this.onTap);
}

// Stat card classes (_ReplacementRequestsCard, _RequisitionPipelineCard, etc.) remain unchanged.

// STAT CARDS

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
        return _buildPremiumCard(
          context: context,
          title: 'Demandes de Remplacement',
          count: count.toString(),
          icon: Icons.sync_problem_rounded,
          color: const Color(0xFFEF4444),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReplacementRequestsHubPage(
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
    return _buildPremiumCard(
      context: context,
      title: 'Commandes',
      count: '',
      icon: Icons.shopping_cart_rounded,
      color: const Color(0xFF6366F1),
      customBody: Row(
        children: [
          Expanded(child: _buildMiniStat(
            context,
            'Approbation',
            FirebaseFirestore.instance
                .collection('requisitions')
                .where('status', isEqualTo: "En attente d'approbation")
                .snapshots(),
                () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RequisitionApprovalPage(userRole: userRole),
              ),
            ),
          )),
          Container(width: 1, height: 50, color: Colors.grey.shade200),
          Expanded(child: _buildMiniStat(
            context,
            'À Commander',
            FirebaseFirestore.instance
                .collection('requisitions')
                .where('status', isEqualTo: "Approuvée")
                .snapshots(),
                () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PurchasingHubPage(userRole: userRole),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildMiniStat(BuildContext ctx, String title, Stream<QuerySnapshot> stream, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (c, s) {
                final cnt = s.hasData ? s.data!.docs.length : 0;
                return Text(cnt.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
              },
            ),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
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
        return _buildPremiumCard(
          context: context,
          title: 'Facturation en Attente',
          count: count.toString(),
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF14B8A6),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BillingHubPage()),
          ),
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
        return _buildPremiumCard(
          context: context,
          title: 'Remplacements à Préparer',
          count: count.toString(),
          icon: Icons.inventory_rounded,
          color: const Color(0xFFF59E0B),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReplacementRequestsHubPage(
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
          .where('status', whereIn: ["À Préparer", "En Cours de Livraison"])
          .snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildPremiumCard(
          context: context,
          title: 'Livraisons Actives',
          count: count.toString(),
          icon: Icons.local_shipping_rounded,
          color: const Color(0xFF8B5CF6),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LivraisonsHubPage()),
          ),
        );
      },
    );
  }
}

Widget _buildPremiumCard({
  required BuildContext context,
  required String title,
  required String count,
  required IconData icon,
  required Color color,
  VoidCallback? onTap,
  Widget? customBody,
}) {
  return MouseRegion(
    cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            customBody ??
                Text(
                  count,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
                ),
          ],
        ),
      ),
    ),
  );
}

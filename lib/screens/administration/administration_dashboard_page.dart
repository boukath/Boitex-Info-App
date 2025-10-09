// lib/screens/administration/administration_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    final isWeb = kIsWeb && MediaQuery.of(context).size.width >= 900;
    final canSeeManagementWidgets = ['PDG', 'Admin', 'Responsable Administratif', 'Responsable Commercial', 'Chef de Projet'].contains(userRole);

    if (isWeb) {
      return _buildWebDashboard(context, canSeeManagementWidgets);
    } else {
      return _buildMobileDashboard(context, canSeeManagementWidgets);
    }
  }

  Widget _buildWebDashboard(BuildContext context, bool canSeeManagementWidgets) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildTopBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeSection(),
                  const SizedBox(height: 32),
                  _buildQuickActionsGrid(context),
                  const SizedBox(height: 32),
                  const Text(
                    'Vue d\'ensemble',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1e293b)),
                  ),
                  const SizedBox(height: 20),
                  _buildStatsCardsWeb(context, canSeeManagementWidgets),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDashboard(BuildContext context, bool canSeeManagementWidgets) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMobileHeader(context),
              const SizedBox(height: 24),
              _buildQuickActionsGrid(context),
              const SizedBox(height: 24),
              const Text('Tâches Urgentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildStatCardsMobile(context, canSeeManagementWidgets),
              const SizedBox(height: 80), // ✅ ADDED BOTTOM PADDING
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          const Text(
            'Administration',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1e293b)),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.history, size: 24, color: Color(0xFF64748b)),
            tooltip: 'Historique',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityLogPage())),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 24, color: Color(0xFF64748b)),
            onPressed: () {},
          ),
        ],
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
          child: Text('Administration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          icon: const Icon(Icons.history),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityLogPage())),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bonjour, $displayName 👋',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0f172a)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Gérez vos opérations administratives',
          style: TextStyle(fontSize: 16, color: Color(0xFF64748b)),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final actions = [
      _ActionItem(Icons.note_add_rounded, 'Nouveau Projet', const Color(0xFF10b981), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProjectPage()))),
      _ActionItem(Icons.store_rounded, 'Clients', const Color(0xFF3b82f6), () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageClientsPage(userRole: userRole)))),
      _ActionItem(Icons.folder_rounded, 'Projets', const Color(0xFF8b5cf6), () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageProjectsPage(userRole: userRole)))),
      _ActionItem(Icons.inventory_2_rounded, 'Produits', const Color(0xFF14b8a6), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductCatalogPage()))),
      _ActionItem(Icons.warehouse_rounded, 'Stock', const Color(0xFF6366f1), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockPage()))),
      _ActionItem(Icons.assignment_rounded, 'Missions', const Color(0xFFa855f7), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageMissionsPage()))),
      _ActionItem(Icons.local_shipping_rounded, 'Livraisons', const Color(0xFFf59e0b), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LivraisonsHubPage()))),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: kIsWeb && MediaQuery.of(context).size.width >= 900 ? 4 : 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.3, // ✅ CHANGED FROM 1.5 TO 1.3
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) => _buildActionCard(actions[index]),
    );
  }

  Widget _buildActionCard(_ActionItem action) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: action.onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [action.color, action.color.withOpacity(0.8)],
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
          child: Padding(
            padding: const EdgeInsets.all(16), // ✅ REDUCED FROM 20 TO 16
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(action.icon, color: Colors.white, size: 22), // ✅ REDUCED FROM 24 TO 22
                ),
                const SizedBox(height: 8), // ✅ REDUCED FROM 12 TO 8
                Text(
                  action.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14, // ✅ REDUCED FROM 16 TO 14
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2, // ✅ ADDED MAX LINES
                  overflow: TextOverflow.ellipsis, // ✅ ADDED OVERFLOW HANDLING
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCardsWeb(BuildContext context, bool canSeeManagementWidgets) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        SizedBox(width: 300, child: const _ReplacementRequestsCard()),
        if (canSeeManagementWidgets) SizedBox(width: 300, child: _RequisitionPipelineCard(userRole: userRole)),
        if (canSeeManagementWidgets) SizedBox(width: 300, child: const _PendingBillingCard()),
        if (canSeeManagementWidgets) SizedBox(width: 300, child: const _PendingReplacementsCard()),
        if (canSeeManagementWidgets) SizedBox(width: 300, child: const _LivraisonsCard()),
      ],
    );
  }

  Widget _buildStatCardsMobile(BuildContext context, bool canSeeManagementWidgets) {
    return Column(
      children: [
        const _ReplacementRequestsCard(),
        const SizedBox(height: 16),
        if (canSeeManagementWidgets) ...[
          _RequisitionPipelineCard(userRole: userRole),
          const SizedBox(height: 16),
          const _PendingBillingCard(),
          const SizedBox(height: 16),
          const _PendingReplacementsCard(),
          const SizedBox(height: 16),
          const _LivraisonsCard(),
        ],
      ],
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _ActionItem(this.icon, this.label, this.color, this.onTap);
}

// PREMIUM STAT CARDS
class _ReplacementRequestsCard extends StatelessWidget {
  const _ReplacementRequestsCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('replacementRequests').where('requestStatus', isEqualTo: "En attente d'action").snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return _buildPremiumCard(
          context: context,
          title: 'Demandes de Remplacement',
          count: count.toString(),
          icon: Icons.sync_problem_rounded,
          color: const Color(0xFFef4444),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReplacementRequestsHubPage(pageTitle: 'Demandes en Attente', filterStatus: "En attente d'action"))),
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
      color: const Color(0xFF6366f1),
      customBody: Row(
        children: [
          Expanded(
            child: _buildMiniStat(
              context,
              'Approbation',
              FirebaseFirestore.instance.collection('requisitions').where('status', isEqualTo: "En attente d'approbation").snapshots(),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequisitionApprovalPage(userRole: userRole))),
            ),
          ),
          Container(width: 1, height: 50, color: Colors.grey.shade200),
          Expanded(
            child: _buildMiniStat(
              context,
              'À Commander',
              FirebaseFirestore.instance.collection('requisitions').where('status', isEqualTo: "Approuvée").snapshots(),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => PurchasingHubPage(userRole: userRole))),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildMiniStat(BuildContext context, String title, Stream<QuerySnapshot> stream, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Text(count.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
            },
          ),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _PendingBillingCard extends StatelessWidget {
  const _PendingBillingCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('interventions').where('status', isEqualTo: "Terminé").snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return _buildPremiumCard(
          context: context,
          title: 'Facturation en Attente',
          count: count.toString(),
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF14b8a6),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingHubPage())),
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
      stream: FirebaseFirestore.instance.collection('replacementRequests').where('requestStatus', isEqualTo: "Approuvé - Produit en stock").snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return _buildPremiumCard(
          context: context,
          title: 'Remplacements à Préparer',
          count: count.toString(),
          icon: Icons.inventory_rounded,
          color: const Color(0xFFf59e0b),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReplacementRequestsHubPage(pageTitle: 'Remplacements à Préparer', filterStatus: "Approuvé - Produit en stock"))),
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
      stream: FirebaseFirestore.instance.collection('livraisons').where('status', whereIn: ["À Préparer", "En Cours de Livraison"]).snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return _buildPremiumCard(
          context: context,
          title: 'Livraisons Actives',
          count: count.toString(),
          icon: Icons.local_shipping_rounded,
          color: const Color(0xFF8b5cf6),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LivraisonsHubPage())),
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
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748b), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (customBody != null)
              customBody
            else
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

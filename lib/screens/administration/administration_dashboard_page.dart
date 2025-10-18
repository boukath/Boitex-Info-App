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
import 'package:boitex_info_app/screens/administration/rappel_page.dart';

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
      final isTablet = width >= 800 && width < 1200;
      final canSeeMgmt = [
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Administration',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),

                  // --- ✅ START: ICON BUTTON ADDED ---
                  const SizedBox(width: 24),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1E3A8A)),
                    tooltip: 'Rappels',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RappelPage()),
                      );
                    },
                  ),
                  // --- ✅ END: ICON BUTTON ADDED ---

                  const Spacer(),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF1E3A8A),
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Bienvenue, $displayName 👋',
                style:
                const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              // Quick actions grid
              LayoutBuilder(builder: (ctx, box) {
                final w = box.maxWidth;
                int cols = 3;
                if (w >= 1600) {
                  cols = 6;
                } else if (w >= 1200) {
                  cols = 5;
                } else if (w >= 900) {
                  cols = 4;
                }
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: 1.4,
                  children: _buildQuickActions(context),
                );
              }),
              const SizedBox(height: 40),
              const Text(
                'Vue d\'ensemble',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 20),
              // Responsive stats grid (no overflow)
              LayoutBuilder(builder: (ctx, box) {
                final w = box.maxWidth;
                int cols;
                if (w >= 1800) {
                  cols = 5;
                } else if (w >= 1400) {
                  cols = 4;
                } else if (w >= 1000) {
                  cols = 3;
                } else {
                  cols = 2;
                }
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: 240 / 140,
                  children: [
                    const _ReplacementRequestsCard(),
                    if (canSeeMgmt)
                      _RequisitionPipelineCard(userRole: userRole),
                    if (canSeeMgmt) const _PendingBillingCard(),
                    if (canSeeMgmt) const _PendingReplacementsCard(),
                    if (canSeeMgmt) const _LivraisonsCard(),
                  ],
                );
              }),
              const SizedBox(height: 40),
            ],
          ),
        ),
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
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Administration',
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // --- ✅ START: ICON BUTTON ADDED ---
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1E3A8A)),
                    tooltip: 'Rappels',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RappelPage()),
                      );
                    },
                  ),
                  // --- ✅ END: ICON BUTTON ADDED ---

                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (ctx, box) {
                final cols = (kIsWeb && box.maxWidth >= 900) ? 4 : 2;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.3,
                  children: _buildQuickActions(context),
                );
              }),
              const SizedBox(height: 24),
              const Text('Tâches Urgentes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Column(
                children: [
                  const _ReplacementRequestsCard(),
                  if (canSeeMgmt)
                    _RequisitionPipelineCard(userRole: userRole),
                  if (canSeeMgmt) const _PendingBillingCard(),
                  if (canSeeMgmt) const _PendingReplacementsCard(),
                  if (canSeeMgmt) const _LivraisonsCard(),
                ]
                    .map((card) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: card,
                ))
                    .toList(),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildQuickActions(BuildContext context) {
    return [
      _ActionItem(
        Icons.note_add_rounded,
        'Nouveau Projet',
        const Color(0xFF10B981),
            () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddProjectPage())),
      ),
      _ActionItem(
        Icons.store_rounded,
        'Clients',
        const Color(0xFF3B82F6),
            () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ManageClientsPage(userRole: userRole)),
        ),
      ),
      _ActionItem(
        Icons.folder_rounded,
        'Projets',
        const Color(0xFF8B5CF6),
            () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ManageProjectsPage(userRole: userRole)),
        ),
      ),
      _ActionItem(
        Icons.inventory_2_rounded,
        'Produits',
        const Color(0xFF14B8A6),
            () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ProductCatalogPage())),
      ),
      _ActionItem(
        Icons.warehouse_rounded,
        'Stock',
        const Color(0xFF6366F1),
            () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const StockPage())),
      ),
      _ActionItem(
        Icons.assignment_rounded,
        'Missions',
        const Color(0xFFA855F7),
            () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ManageMissionsPage())),
      ),
      _ActionItem(
        Icons.local_shipping_rounded,
        'Livraisons',
        const Color(0xFFF59E0B),
            () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const LivraisonsHubPage())),
      ),
      _ActionItem(
        Icons.history_rounded,
        'Historique',
        const Color(0xFF78716C),
            () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ActivityLogPage())),
      ),
    ];
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionItem(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    final bool webWide = kIsWeb && MediaQuery.of(context).size.width >= 900;
    final iconSize = webWide ? 36.0 : 28.0;
    final textSize = webWide ? 18.0 : 13.0;
    final padding = webWide ? 16.0 : 12.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: iconSize),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                  fontSize: textSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Stat cards and _buildPremiumCard remain unchanged...

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
                    builder: (_) => RequisitionApprovalPage(userRole: userRole),
                  ),
                ),
              )),
          Container(width: 1, height: 50, color: Colors.grey.shade200),
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
                    builder: (_) => PurchasingHubPage(userRole: userRole),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      BuildContext ctx, String title, Stream<QuerySnapshot> stream, VoidCallback onTap) {
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
                return Text(cnt.toString(),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold));
              },
            ),
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center),
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
                  style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold, color: color),
                ),
          ],
        ),
      ),
    ),
  );
}
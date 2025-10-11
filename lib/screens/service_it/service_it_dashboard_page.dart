// lib/screens/service_it/service_it_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boitex_info_app/screens/service_technique/intervention_list_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_list_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_list_page.dart';
import 'package:boitex_info_app/screens/service_technique/ready_replacements_list_page.dart';
import 'package:boitex_info_app/screens/service_technique/historic_interventions_page.dart';
import 'package:boitex_info_app/screens/administration/manage_missions_page.dart';
import 'package:boitex_info_app/screens/administration/livraisons_hub_page.dart';

class ServiceItDashboardPage extends StatelessWidget {
  final String displayName;
  final String userRole;

  const ServiceItDashboardPage({
    super.key,
    required this.displayName,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final isWideWeb = kIsWeb && width >= 900;

      if (isWideWeb) {
        // Web layout
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Custom app bar
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Service IT',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF0891b2),
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
                  const SizedBox(height: 24),
                  _buildWelcomeCard(),
                  const SizedBox(height: 32),

                  // Responsive quick actions grid
                  LayoutBuilder(builder: (ctx, box) {
                    final w = box.maxWidth;
                    int cols = 3;
                    if (w >= 1600) cols = 6;
                    else if (w >= 1400) cols = 5;
                    else if (w >= 1100) cols = 4;
                    return GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 24,
                      childAspectRatio: 1.5,
                      children: _buildQuickActions(context),
                    );
                  }),
                  const SizedBox(height: 40),

                  // Responsive stats grid (fix overflow)
                  LayoutBuilder(builder: (ctx, box) {
                    final w = box.maxWidth;
                    int cols;
                    if (w >= 1800) cols = 5;
                    else if (w >= 1400) cols = 4;
                    else if (w >= 1000) cols = 3;
                    else cols = 2;
                    return GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 24,
                      childAspectRatio: 240 / 140,
                      children: [
                        _InterventionsCard(userRole: userRole),
                        _InstallationsCard(userRole: userRole),
                        _SavTicketsCard(userRole: userRole),
                        _ReadyReplacementsCard(userRole: userRole),
                        _MissionsCard(userRole: userRole),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      }

      // Mobile layout
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                pinned: true,
                backgroundColor: const Color(0xFF0891b2),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'Service IT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: kIsWeb ? 24 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0891b2), Color(0xFF06b6d4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildWelcomeCard(),
                    const SizedBox(height: 20),
                    LayoutBuilder(builder: (ctx, box) {
                      // For mobile, 2 columns
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.2,
                        children: _buildQuickActions(context),
                      );
                    }),
                    const SizedBox(height: 20),
                    _InterventionsCard(userRole: userRole),
                    const SizedBox(height: 16),
                    _InstallationsCard(userRole: userRole),
                    const SizedBox(height: 16),
                    _SavTicketsCard(userRole: userRole),
                    const SizedBox(height: 16),
                    _ReadyReplacementsCard(userRole: userRole),
                    const SizedBox(height: 16),
                    _MissionsCard(userRole: userRole),
                  ]),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0891b2), Color(0xFF06b6d4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0891b2).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenue, $displayName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gérez les interventions IT et support technique',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.computer,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQuickActions(BuildContext context) {
    return [
      _ActionItem(
        Icons.support_agent_rounded,
        'Interventions',
        const Color(0xFF10b981),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InterventionListPage(
              userRole: userRole,
              serviceType: 'Service IT',
            ),
          ),
        ),
      ),
      _ActionItem(
        Icons.router_rounded,
        'Installations',
        const Color(0xFF3b82f6),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstallationListPage(
              userRole: userRole,
              serviceType: 'Service IT',
            ),
          ),
        ),
      ),
      _ActionItem(
        Icons.support_agent_rounded,
        'Tickets SAV',
        const Color(0xFFf59e0b),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SavListPage(serviceType: 'Service IT'),
          ),
        ),
      ),
      _ActionItem(
        Icons.inventory_2_rounded,
        'Remplacements',
        const Color(0xFFec4899),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
            const ReadyReplacementsListPage(serviceType: 'Service IT'),
          ),
        ),
      ),
      _ActionItem(
        Icons.assignment_rounded,
        'Missions',
        const Color(0xFF8b5cf6),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ManageMissionsPage(serviceType: 'Service IT'),
          ),
        ),
      ),
      _ActionItem(
        Icons.local_shipping_rounded,
        'Livraisons',
        const Color(0xFFec4899),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LivraisonsHubPage(serviceType: 'Service IT'),
          ),
        ),
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
    final double iconSize = webWide ? 36 : 28;
    final double textSize = webWide ? 18 : 13;
    final double padding = webWide ? 16 : 12;

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
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: iconSize),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: textSize,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Statistic Cards

Widget _buildPremiumCard({
  required BuildContext context,
  required String title,
  required IconData icon,
  required Color color,
  Stream<QuerySnapshot>? stream,
  VoidCallback? onTap,
  Widget? customBody,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            if (stream != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: StreamBuilder<QuerySnapshot>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final count = snapshot.data!.docs.length;
                    return Text(
                      '$count',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
                    );
                  },
                ),
              )
            else if (customBody != null) ...[
              customBody,
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ),
  );
}

class _InterventionsCard extends StatelessWidget {
  final String userRole;
  const _InterventionsCard({required this.userRole});

  @override
  Widget build(BuildContext context) {
    return _buildPremiumCard(
      context: context,
      title: 'Interventions',
      icon: Icons.support_agent_rounded,
      color: const Color(0xFF10b981),
      stream: FirebaseFirestore.instance
          .collection('interventions')
          .where('serviceType', isEqualTo: 'Service IT')
          .where('status', isEqualTo: 'Nouveau')
          .snapshots(),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InterventionListPage(
            userRole: userRole,
            serviceType: 'Service IT',
          ),
        ),
      ),
    );
  }
}

class _InstallationsCard extends StatelessWidget {
  final String userRole;
  const _InstallationsCard({required this.userRole});

  @override
  Widget build(BuildContext context) {
    return _buildPremiumCard(
      context: context,
      title: 'Installations',
      icon: Icons.router_rounded,
      color: const Color(0xFF3b82f6),
      stream: FirebaseFirestore.instance
          .collection('installations')
          .where('serviceType', isEqualTo: 'Service IT')
          .where('status', isEqualTo: 'Nouveau')
          .snapshots(),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InstallationListPage(
            userRole: userRole,
            serviceType: 'Service IT',
          ),
        ),
      ),
    );
  }
}

class _SavTicketsCard extends StatelessWidget {
  final String userRole;
  const _SavTicketsCard({required this.userRole});

  @override
  Widget build(BuildContext context) {
    return _buildPremiumCard(
      context: context,
      title: 'Tickets SAV',
      icon: Icons.support_agent_rounded,
      color: const Color(0xFFf59e0b),
      stream: FirebaseFirestore.instance
          .collection('sav_tickets')
          .where('serviceType', isEqualTo: 'Service IT')
          .where('status', isEqualTo: 'Nouveau')
          .snapshots(),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SavListPage(serviceType: 'Service IT')),
      ),
    );
  }
}

class _ReadyReplacementsCard extends StatelessWidget {
  final String userRole;
  const _ReadyReplacementsCard({required this.userRole});

  @override
  Widget build(BuildContext context) {
    return _buildPremiumCard(
      context: context,
      title: 'Remplacements Prêts',
      icon: Icons.inventory_2_rounded,
      color: const Color(0xFFec4899),
      stream: FirebaseFirestore.instance
          .collection('replacementRequests')
          .where('serviceType', isEqualTo: 'Service IT')
          .where('requestStatus', isEqualTo: 'Prêt pour Technicien')
          .snapshots(),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReadyReplacementsListPage(serviceType: 'Service IT')),
      ),
    );
  }
}

class _MissionsCard extends StatelessWidget {
  final String userRole;
  const _MissionsCard({required this.userRole});

  @override
  Widget build(BuildContext context) {
    return _buildPremiumCard(
      context: context,
      title: 'Missions Actives',
      icon: Icons.assignment_rounded,
      color: const Color(0xFF8b5cf6),
      stream: FirebaseFirestore.instance
          .collection('missions')
          .where('serviceType', isEqualTo: 'Service IT')
          .where('status', whereIn: ['En cours', 'Planifiée'])
          .snapshots(),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ManageMissionsPage(serviceType: 'Service IT')),
      ),
    );
  }
}

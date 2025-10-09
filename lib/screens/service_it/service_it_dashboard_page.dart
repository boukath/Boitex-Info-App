// lib/screens/service_it/service_it_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_list_page.dart';
import 'package:boitex_info_app/screens/service_technique/historic_interventions_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_list_page.dart';
import 'package:boitex_info_app/screens/administration/manage_missions_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_list_page.dart';
import 'package:boitex_info_app/screens/administration/livraisons_hub_page.dart';
import 'package:boitex_info_app/screens/service_technique/add_intervention_page.dart';
import 'package:boitex_info_app/screens/service_technique/ready_replacements_list_page.dart';

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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFF0891b2), // Cyan for IT
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
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF0891b2), // Cyan
                        const Color(0xFF06b6d4), // Lighter cyan
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Welcome Card
                  _buildWelcomeCard(),
                  const SizedBox(height: 20),

                  // Quick Actions Grid
                  _buildQuickActionsGrid(context),
                  const SizedBox(height: 20),

                  // Statistics Cards
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
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0891b2), Color(0xFF06b6d4)], // Cyan gradient for IT
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

  Widget _buildQuickActionsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: kIsWeb ? 4 : 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: kIsWeb ? 1.5 : 1.2,
      children: [
        _ActionItem(
          Icons.support_agent_rounded,
          'Interventions IT',
          const Color(0xFF0891b2),
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
          Icons.dns_rounded,
          'Installations IT',
          const Color(0xFF14b8a6),
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
          Icons.laptop_chromebook_rounded,
          'Tickets SAV',
          const Color(0xFF64748b),
              () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SavListPage(
                serviceType: 'Service IT',
              ),
            ),
          ),
        ),
        _ActionItem(
          Icons.assignment_rounded,
          'Missions IT',
          const Color(0xFF8b5cf6),
              () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ManageMissionsPage(
                serviceType: 'Service IT',
              ),
            ),
          ),
        ),
        _ActionItem(
          Icons.history_rounded,
          'Historique',
          const Color(0xFF6b7280),
              () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const HistoricInterventionsPage(serviceType: 'Service IT'),
            ),
          ),
        ),
        _ActionItem(
          Icons.local_shipping_rounded,
          'Livraisons',
          const Color(0xFFec4899),
              () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LivraisonsHubPage(serviceType: 'Service IT')),
          ),
        ),
      ],
    );
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// UPDATED: Show only "Nouveau" count for Service IT
class _InterventionsCard extends StatelessWidget {
  final String userRole;

  const _InterventionsCard({required this.userRole});

  @override
  Widget build(BuildContext context) {
    return _buildPremiumCard(
      context: context,
      title: 'Interventions IT',
      icon: Icons.support_agent_rounded,
      color: const Color(0xFF0891b2),
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

// UPDATED: Show only "Nouveau" count for Service IT
class _InstallationsCard extends StatelessWidget {
  final String userRole;

  const _InstallationsCard({required this.userRole});

  @override
  Widget build(BuildContext context) {
    return _buildPremiumCard(
      context: context,
      title: 'Installations IT',
      icon: Icons.dns_rounded,
      color: const Color(0xFF14b8a6),
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

// UPDATED: Show only "Nouveau" count for Service IT
class _SavTicketsCard extends StatelessWidget {
  final String userRole;

  const _SavTicketsCard({required this.userRole});

  @override
  Widget build(BuildContext context) {
    return _buildPremiumCard(
      context: context,
      title: 'Tickets SAV IT',
      icon: Icons.laptop_chromebook_rounded,
      color: const Color(0xFF64748b),
      stream: FirebaseFirestore.instance
          .collection('sav_tickets')
          .where('serviceType', isEqualTo: 'Service IT')
          .where('status', isEqualTo: 'Nouveau')
          .snapshots(),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SavListPage(
            serviceType: 'Service IT',
          ),
        ),
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
        MaterialPageRoute(
          builder: (_) => const ReadyReplacementsListPage(serviceType: 'Service IT'),
        ),
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
      title: 'Missions IT Actives',
      icon: Icons.assignment_rounded,
      color: const Color(0xFF8b5cf6),
      stream: FirebaseFirestore.instance
          .collection('missions')
          .where('serviceType', isEqualTo: 'Service IT')

          .where('status', whereIn: ['En cours', 'Planifiée']).snapshots(),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManageMissionsPage(
            serviceType: 'Service IT',
          ),
        ),
      ),
    );
  }
}

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
            if (customBody != null) ...[
              customBody,
              const SizedBox(height: 8),
            ] else if (stream != null) ...[
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
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

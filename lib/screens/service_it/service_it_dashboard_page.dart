// lib/screens/service_it/service_it_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boitex_info_app/screens/service_technique/intervention_list_page.dart';
import 'package:boitex_info_app/screens/service_technique/historic_interventions_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_list_page.dart';
import 'package:boitex_info_app/screens/administration/manage_missions_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_list_page.dart';
import 'package:boitex_info_app/screens/administration/livraisons_hub_page.dart';
import 'package:boitex_info_app/screens/service_technique/ready_replacements_list_page.dart';

// ***** START CODE TO ADD *****
// Import the AnnounceHubPage (already present in your code)
import 'package:boitex_info_app/screens/announce/announce_hub_page.dart';
// Import the new IT evaluations list page
import 'package:boitex_info_app/screens/service_it/pending_it_evaluations_list.dart';
// ***** END CODE TO ADD *****


import 'dart:math' as math;

class ServiceItDashboardPage extends StatefulWidget {
  final String displayName;
  final String userRole;

  const ServiceItDashboardPage({
    super.key,
    required this.displayName,
    required this.userRole,
  });

  @override
  State<ServiceItDashboardPage> createState() => _ServiceItDashboardPageState();
}

class _ServiceItDashboardPageState extends State<ServiceItDashboardPage>
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
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
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
    // ***** START MODIFIED CODE *****
    // Wrap LayoutBuilder in StreamBuilder to get the count
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where('status', isEqualTo: 'Nouvelle Demande') // Query for pending projects
          .snapshots(),
      builder: (context, projectSnapshot) {
        // Calculate the count (0 if loading or no data)
        final int evaluationCount =
        projectSnapshot.hasData ? projectSnapshot.data!.docs.length : 0;

        // Keep your original LayoutBuilder
        return LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width > 900) {
            // Pass the count to the web layout
            return _buildWebDashboard(context, width, evaluationCount);
          } else {
            // Pass the count to the mobile layout
            return _buildMobileDashboard(context, evaluationCount);
          }
        });
      },
    );
    // ***** END MODIFIED CODE *****
  }

  // ========================= WEB =========================

  // ***** START MODIFIED CODE *****
  // Add evaluationCount parameter
  Widget _buildWebDashboard(BuildContext context, double width, int evaluationCount) {
    // ***** END MODIFIED CODE *****
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Keeping your IT gradient
            colors: [Color(0xFF06B6D4), Color(0xFF0891B2), Color(0xFF0E7490)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildWebHeader(), // Uses your web header
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
                          Expanded(
                            flex: 3,
                            child: _buildGlassCard(child: _buildWebActionsGrid(context)),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Statistiques', // Your original title
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // ***** START MODIFIED CODE *****
                                // Pass the count to the stats column
                                _buildWebStatsColumn(evaluationCount),
                                // ***** END MODIFIED CODE *****
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
    // No changes needed here, keep your original code
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(40, 20, 40, 32),
        child: Row(
          children: [
            _glassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            Expanded( // Keeping your user info chip
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.white.withOpacity(0.25), Colors.white.withOpacity(0.15)],),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: Row( // Keeping inner row
                      children: [
                        Expanded(child: Text(widget.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.2,),)),
                        Container(margin: const EdgeInsets.symmetric(horizontal: 12), width: 6, height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), shape: BoxShape.circle,),),
                        Expanded(child: Text(widget.userRole, maxLines: 1, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.95), letterSpacing: 0.2,),)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            _glassIconButton( // Using computer icon for IT
              icon: Icons.computer_rounded,
              onTap: () {},
            ),
            const SizedBox(width: 12),
            _glassIconButton( // Announcements icon (already present in your code)
              icon: Icons.campaign_outlined,
              tooltip: 'Announcements',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AnnounceHubPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebActionsGrid(BuildContext context) {
    // No changes needed here, keep your original code
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Actions Rapides', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5,),),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 20, crossAxisSpacing: 20, childAspectRatio: 1.0,
          children: _buildQuickActions(context), // Uses your builder
        ),
      ],
    );
  }

  // ***** START MODIFIED CODE *****
  // Add evaluationCount parameter
  Widget _buildWebStatsColumn(int evaluationCount) {
    // ***** END MODIFIED CODE *****
    // Keeping your original web stats column structure
    final cards = <Widget>[
      // ***** START CODE TO ADD *****
      // Add the new IT Evaluation Card first
      _ItEvaluationsCard(userRole: widget.userRole, evaluationCount: evaluationCount),
      const SizedBox(height: 16),
      // ***** END CODE TO ADD *****

      // Your existing cards remain
      _InterventionsCard(userRole: widget.userRole), const SizedBox(height: 16),
      _InstallationsCard(userRole: widget.userRole), const SizedBox(height: 16),
      _SavTicketsCard(userRole: widget.userRole), const SizedBox(height: 16),
      _ReadyReplacementsCard(userRole: widget.userRole), const SizedBox(height: 16),
      _MissionsCard(userRole: widget.userRole),
    ];
    // Keep your animation logic
    return Column(
      children: cards.asMap().entries.map((entry) {
        final index = entry.key; final card = entry.value;
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 600 + (index * 100)), tween: Tween(begin: 0, end: 1),
          builder: (context, value, child) { return Transform.translate(offset: Offset(0, 30 * (1 - value)), child: Opacity(opacity: value, child: child),); },
          child: card,
        );
      }).toList(),
    );
  }

  // ========================= MOBILE =========================

  // ***** START MODIFIED CODE *****
  // Add evaluationCount parameter
  Widget _buildMobileDashboard(BuildContext context, int evaluationCount) {
    // ***** END MODIFIED CODE *****
    // Keeping your original mobile dashboard structure
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            // Keeping your IT gradient
            colors: [Color(0xFF06B6D4), Color(0xFF0891B2), Color(0xFF0E7490)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildUltraCompactHeader(), // Uses your mobile header
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGlassCard(child: _buildActionsGrid(context)), // Uses your mobile grid
                        const SizedBox(height: 24),
                        // ***** START MODIFIED CODE *****
                        // Pass the count to the mobile stats section
                        _buildStatsSection(evaluationCount),
                        // ***** END MODIFIED CODE *****
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

  Widget _buildUltraCompactHeader() {
    // No changes needed here, keep your original code
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Row(
          children: [
            _glassIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.pop(context),),
            const SizedBox(width: 12),
            Expanded( // Keeping your user info chip
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.white.withOpacity(0.25), Colors.white.withOpacity(0.15)],),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: Row( // Keeping inner row
                      children: [
                        Expanded(child: Text(widget.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.2,),)),
                        Container(margin: const EdgeInsets.symmetric(horizontal: 10), width: 5, height: 5, decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), shape: BoxShape.circle,),),
                        Expanded(child: Text(widget.userRole, maxLines: 1, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2,),)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _glassIconButton( // Using computer icon for IT
              icon: Icons.computer_rounded,
              onTap: () {},
            ),
            const SizedBox(width: 12),
            _glassIconButton( // Announcements icon (already present in your code)
              icon: Icons.campaign_outlined,
              tooltip: 'Announcements',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AnnounceHubPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ========================= SHARED UI =========================

  // Keeping your original _glassIconButton function
  Widget _glassIconButton({required IconData icon, required VoidCallback onTap, String? tooltip}) { // Added tooltip back
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
        tooltip: tooltip, // Use tooltip
      ),
    );
  }

  // Keeping your original _buildGlassCard function
  Widget _buildGlassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20),),],
      ),
      child: child,
    );
  }

  // ========================= ACTIONS GRID =========================

  // Keeping your original _buildActionsGrid function
  Widget _buildActionsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Actions Rapides', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5,),),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.90,
          children: _buildQuickActions(context), // Uses your builder
        ),
      ],
    );
  }

  // Keeping your original _buildQuickActions function
  List<Widget> _buildQuickActions(BuildContext context) {
    // Uses your specific actions for Service IT
    final actions = <_ActionData>[
      _ActionData('Interventions', Icons.build_rounded, const Color(0xFF10B981), () => Navigator.push(context, MaterialPageRoute(builder: (_) => InterventionListPage(userRole: widget.userRole, serviceType: 'Service IT'),),),),
      _ActionData('Installations', Icons.dns_rounded, const Color(0xFF3B82F6), () => Navigator.push(context, MaterialPageRoute(builder: (_) => InstallationListPage(userRole: widget.userRole, serviceType: 'Service IT'),),),),
      _ActionData('Tickets SAV', Icons.support_agent_rounded, const Color(0xFFF59E0B), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavListPage(serviceType: 'Service IT')),),),
      _ActionData('Remplacements', Icons.swap_horiz_rounded, const Color(0xFFEC4899), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadyReplacementsListPage(serviceType: 'Service IT'),),),),
      _ActionData('Missions', Icons.assignment_rounded, const Color(0xFF8B5CF6), () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageMissionsPage(serviceType: 'Service IT')),),),
      _ActionData('Livraisons', Icons.local_shipping_rounded, const Color(0xFF14B8A6), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LivraisonsHubPage(serviceType: 'Service IT')),),),
      _ActionData('Historique', Icons.history, const Color(0xFF78716C), () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoricInterventionsPage(serviceType: 'Service IT', userRole: widget.userRole),),),),
    ];

    // Keep your animation logic
    return actions.asMap().entries.map((entry) {
      final index = entry.key; final action = entry.value;
      return TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 400 + (index * 80)), tween: Tween(begin: 0, end: 1),
        builder: (context, value, child) { return Transform.scale(scale: 0.8 + (0.2 * value), child: Opacity(opacity: value, child: child),); },
        child: _ActionCard( label: action.label, icon: action.icon, color: action.color, onTap: action.onTap, ),
      );
    }).toList();
  }

  // ========================= STATS (MOBILE) =========================

  // ***** START MODIFIED CODE *****
  // Add evaluationCount parameter
  Widget _buildStatsSection(int evaluationCount) {
    // ***** END MODIFIED CODE *****
    final cards = <Widget>[
      // ***** START CODE TO ADD *****
      // Add the new IT Evaluation Card first
      _ItEvaluationsCard(userRole: widget.userRole, evaluationCount: evaluationCount),
      // ***** END CODE TO ADD *****

      // Your existing cards remain
      _InterventionsCard(userRole: widget.userRole),
      _InstallationsCard(userRole: widget.userRole),
      _SavTicketsCard(userRole: widget.userRole),
      _ReadyReplacementsCard(userRole: widget.userRole),
      _MissionsCard(userRole: widget.userRole),
    ];

    // Keep your layout and animation logic
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Statistiques', style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5,),),
        ),
        const SizedBox(height: 16),
        Column(
          children: cards.asMap().entries.map((entry) {
            final index = entry.key; final card = entry.value;
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 600 + (index * 100)), tween: Tween(begin: 0, end: 1),
              builder: (context, value, child) { return Transform.translate(offset: Offset(0, 30 * (1 - value)), child: Opacity(opacity: value, child: child),); },
              child: Padding(padding: const EdgeInsets.only(bottom: 16), child: card,),
            );
          }).toList(),
        ),
      ],
    );
  }
} // End of State Class

// ========================= MODELS & CARDS =========================

// Keeping your original _ActionData class
class _ActionData {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _ActionData(this.label, this.icon, this.color, this.onTap);
}

// Keeping your original _ActionCard widget
class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({ required this.label, required this.icon, required this.color, required this.onTap, });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.25), Colors.white.withOpacity(0.15)],),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)), ],
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
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [ BoxShadow(color: color.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8)), ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3,),
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========================= STAT CARDS =========================

// ***** START CODE TO ADD *****
// New Stat Card Widget for IT Evaluations
class _ItEvaluationsCard extends StatelessWidget {
  final String userRole;
  final int evaluationCount; // Takes count as parameter
  const _ItEvaluationsCard({required this.userRole, required this.evaluationCount});

  @override
  Widget build(BuildContext context) {
    return _buildGlowingCard(
      context: context,
      title: 'Évaluations IT à Faire',
      count: evaluationCount.toString(),
      icon: Icons.dns_rounded, // Specific IT icon
      // Using a different gradient for distinction, maybe purple?
      gradient: const LinearGradient(colors: [Color(0xFFa78bfa), Color(0xFF7c3aed)]),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          // Navigate to the new IT evaluations list page
          builder: (_) => PendingItEvaluationsListPage(userRole: userRole),
        ),
      ),
    );
  }
}
// ***** END CODE TO ADD *****

// Keeping your original Stat Card widgets (_InterventionsCard, _InstallationsCard, etc.)
// These should already use 'Service IT' in their queries based on your previous file.
class _InterventionsCard extends StatelessWidget {
  final String userRole;
  const _InterventionsCard({required this.userRole});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('interventions').where('serviceType', isEqualTo: 'Service IT').where('status', isEqualTo: 'Nouveau').snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildGlowingCard(context: context, title: 'Interventions', count: count.toString(), icon: Icons.build_rounded, gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InterventionListPage(userRole: userRole, serviceType: 'Service IT'),),),);
      },
    );
  }
}

class _InstallationsCard extends StatelessWidget {
  final String userRole;
  const _InstallationsCard({required this.userRole});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('installations').where('serviceType', isEqualTo: 'Service IT').where('status', isEqualTo: 'Nouveau').snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildGlowingCard(context: context, title: 'Installations', count: count.toString(), icon: Icons.dns_rounded, gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InstallationListPage(userRole: userRole, serviceType: 'Service IT'),),),);
      },
    );
  }
}

class _SavTicketsCard extends StatelessWidget {
  final String userRole;
  const _SavTicketsCard({required this.userRole});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sav_tickets').where('serviceType', isEqualTo: 'Service IT').where('status', isEqualTo: 'Nouveau').snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildGlowingCard(context: context, title: 'Tickets SAV', count: count.toString(), icon: Icons.support_agent_rounded, gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavListPage(serviceType: 'Service IT')),),);
      },
    );
  }
}

class _ReadyReplacementsCard extends StatelessWidget {
  final String userRole;
  const _ReadyReplacementsCard({required this.userRole});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('replacementRequests').where('serviceType', isEqualTo: 'Service IT').where('requestStatus', isEqualTo: 'Prêt pour Technicien').snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildGlowingCard(context: context, title: 'Remplacements Prêts', count: count.toString(), icon: Icons.swap_horiz_rounded, gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFDB2777)]), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadyReplacementsListPage(serviceType: 'Service IT'),),),);
      },
    );
  }
}

class _MissionsCard extends StatelessWidget {
  final String userRole;
  const _MissionsCard({required this.userRole});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('missions').where('serviceType', isEqualTo: 'Service IT').where('status', whereIn: ['En cours', 'Planifiée']).snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildGlowingCard(context: context, title: 'Missions Actives', count: count.toString(), icon: Icons.assignment_rounded, gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageMissionsPage(serviceType: 'Service IT')),),);
      },
    );
  }
}

// Keeping your original _buildGlowingCard function
Widget _buildGlowingCard({
  required BuildContext context,
  required String title,
  required String count,
  required IconData icon,
  required Gradient gradient,
  VoidCallback? onTap,
}) {
  final isWeb = MediaQuery.of(context).size.width > 900;

  return Container(
    margin: isWeb ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 15)), ],
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
                      gradient: gradient, borderRadius: BorderRadius.circular(16),
                      boxShadow: [ BoxShadow(color: gradient.colors.first.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10),),],
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0.3,),),),
                  if (onTap != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10),),
                      child: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white.withOpacity(0.9)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              ShaderMask(
                shaderCallback: (bounds) => gradient.createShader(bounds),
                child: Text(
                  count, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1,),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
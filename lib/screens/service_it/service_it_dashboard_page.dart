// lib/screens/service_it/service_it_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ✅ ADDED: To detect Web platform for resizing
import 'package:flutter/foundation.dart' show kIsWeb;

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

// ✅✅✅ NOUVELLE IMPORTATION AJOUTÉE ✅✅✅
import 'package:boitex_info_app/screens/service_it/it_activity_feed_page.dart';

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
    // ✅ REMOVED: Root StreamBuilder is no longer needed
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width > 900) {
        // ✅ REMOVED: evaluationCount
        return _buildWebDashboard(context, width);
      } else {
        // ✅ REMOVED: evaluationCount
        return _buildMobileDashboard(context);
      }
    });
  }

  // ========================= WEB =========================

  // ✅ REMOVED: evaluationCount parameter
  Widget _buildWebDashboard(BuildContext context, double width) {
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
                      // ✅ MODIFIED: Removed Row and Stats column
                      // The Actions Grid now takes all the space
                      child: _buildGlassCard(
                        child: _buildWebActionsGrid(context),
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
            Expanded(
              // Keeping your user info chip
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
                      // Keeping inner row
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
                            )),
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
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            _glassIconButton(
              // Using computer icon for IT
              icon: Icons.computer_rounded,
              onTap: () {},
            ),
            const SizedBox(width: 12),
            _glassIconButton(
              // Announcements icon (already present in your code)
              icon: Icons.campaign_outlined,
              tooltip: 'Announcements',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AnnounceHubPage()),
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
          // ✅ ADAPTED FOR WEB: Changed aspect ratio to 1.3 to fit bigger text/icons better
          childAspectRatio: 1.3,
          children: _buildQuickActions(context), // Uses your builder
        ),
      ],
    );
  }

  // ✅ REMOVED: _buildWebStatsColumn function

  // ========================= MOBILE =========================

  // ✅ REMOVED: evaluationCount parameter
  Widget _buildMobileDashboard(BuildContext context) {
    // Keeping your original mobile dashboard structure
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
              _buildUltraCompactHeader(), // Uses your mobile header
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGlassCard(
                            child:
                            _buildActionsGrid(context)), // Uses your mobile grid
                        // ✅ REMOVED: Stats Section and SizedBox
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
            _glassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              // Keeping your user info chip
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
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
                      // Keeping inner row
                      children: [
                        Expanded(
                            child: Text(
                              widget.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            )),
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
                                color: Colors.white.withOpacity(0.95),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _glassIconButton(
              // Using computer icon for IT
              icon: Icons.computer_rounded,
              onTap: () {},
            ),
            const SizedBox(width: 12),
            _glassIconButton(
              // Announcements icon (already present in your code)
              icon: Icons.campaign_outlined,
              tooltip: 'Announcements',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AnnounceHubPage()),
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
  Widget _glassIconButton(
      {required IconData icon, required VoidCallback onTap, String? tooltip}) {
    // Added tooltip back
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
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

  // ========================= ACTIONS GRID =========================

  // Keeping your original _buildActionsGrid function
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
          children: _buildQuickActions(context), // Uses your builder
        ),
      ],
    );
  }

  // ✅ MODIFIED: Added streams to _ActionData
  List<Widget> _buildQuickActions(BuildContext context) {
    // Uses your specific actions for Service IT
    final actions = <_ActionData>[
      _ActionData(
        'Interventions',
        Icons.build_rounded,
        const Color(0xFF10B981),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InterventionListPage(
                userRole: widget.userRole, serviceType: 'Service IT'),
          ),
        ),
        countStream: FirebaseFirestore.instance
            .collection('interventions')
            .where('serviceType', isEqualTo: 'Service IT')
            .where('status', isEqualTo: 'Nouveau')
            .snapshots(),
      ),
      _ActionData(
        'Installations',
        Icons.dns_rounded,
        const Color(0xFF3B82F6),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstallationListPage(
                userRole: widget.userRole, serviceType: 'Service IT'),
          ),
        ),
        countStream: FirebaseFirestore.instance
            .collection('installations')
            .where('serviceType', isEqualTo: 'Service IT')
            .where('status', isEqualTo: 'Nouveau')
            .snapshots(),
      ),
      _ActionData(
        'Tickets SAV',
        Icons.support_agent_rounded,
        const Color(0xFFF59E0B),
            () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const SavListPage(serviceType: 'Service IT')),
        ),
        countStream: FirebaseFirestore.instance
            .collection('sav_tickets')
            .where('serviceType', isEqualTo: 'Service IT')
            .where('status', isEqualTo: 'Nouveau')
            .snapshots(),
      ),
      _ActionData(
        'Remplacements',
        Icons.swap_horiz_rounded,
        const Color(0xFFEC4899),
            () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
              const ReadyReplacementsListPage(serviceType: 'Service IT')),
        ),
        countStream: FirebaseFirestore.instance
            .collection('replacementRequests')
            .where('serviceType', isEqualTo: 'Service IT')
            .where('requestStatus', isEqualTo: 'Prêt pour Technicien')
            .snapshots(),
      ),
      _ActionData(
        'Missions',
        Icons.assignment_rounded,
        const Color(0xFF8B5CF6),
            () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ManageMissionsPage(serviceType: 'Service IT')),
        ),
        countStream: FirebaseFirestore.instance
            .collection('missions')
            .where('serviceType', isEqualTo: 'Service IT')
            .where('status', whereIn: ['En cours', 'Planifiée']).snapshots(),
      ),
      _ActionData(
        'Livraisons',
        Icons.local_shipping_rounded,
        const Color(0xFF14B8A6),
            () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
              const LivraisonsHubPage(serviceType: 'Service IT')),
        ),
        countStream: FirebaseFirestore.instance
            .collection('livraisons')
            .where('serviceType', isEqualTo: 'Service IT')
            .where('status', isEqualTo: 'À Préparer')
            .snapshots(),
      ),
      _ActionData(
        'Historique',
        Icons.history,
        const Color(0xFF78716C),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HistoricInterventionsPage(
                serviceType: 'Service IT', userRole: widget.userRole),
          ),
        ),
      ),

      // ✅✅✅ NOUVELLE ACTION AJOUTÉE ICI ✅✅✅
      _ActionData(
        "Journal d'activité",
        Icons.timeline_rounded, // Nouvelle icône
        const Color(0xFFfd746c), // Nouveau dégradé
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ItActivityFeedPage()),
        ),
      ),
      // ✅✅✅ FIN DE L'AJOUT ✅✅✅

      // ✅ NEW "ÉVALUATIONS" BUTTON
      _ActionData(
        'Évaluations',
        Icons.dns_rounded, // Specific IT icon
        const Color(0xFFa78bfa), // Purple color
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PendingItEvaluationsListPage(userRole: widget.userRole),
          ),
        ),
        // Stream for pending evaluations
        countStream: FirebaseFirestore.instance
            .collection('projects')
            .where('status', isEqualTo: 'Nouvelle Demande')
            .where('serviceType', isEqualTo: 'Service IT')
            .snapshots(),
      ),
    ];

    // Keep your animation logic
    return actions.asMap().entries.map((entry) {
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
        child: _ActionCard(
          label: action.label,
          icon: action.icon,
          color: action.color,
          onTap: action.onTap,
          countStream: action.countStream, // ✅ Pass the stream
        ),
      );
    }).toList();
  }

// ✅ REMOVED: _buildStatsSection function
} // End of State Class

// ========================= MODELS & CARDS =========================

// ✅ MODIFIED: Added countStream
class _ActionData {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Stream<QuerySnapshot>? countStream; // ✅ New field

  _ActionData(
      this.label,
      this.icon,
      this.color,
      this.onTap, {
        this.countStream, // ✅ Made optional
      });
}

// ✅ MODIFIED: Added StreamBuilder, Stack for badge, and alignment fix
class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Stream<QuerySnapshot>? countStream; // ✅ New field

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.countStream, // ✅ Added to constructor
  });

  @override
  Widget build(BuildContext context) {
    // StreamBuilder to get the count
    return StreamBuilder<QuerySnapshot>(
      stream: countStream,
      builder: (context, snapshot) {
        final int count =
        snapshot.hasData ? snapshot.data!.docs.length : 0;

        // Stack to overlay the badge
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // The main card
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
                border: Border.all(
                    color: Colors.white.withOpacity(0.3), width: 1.5),
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
                            gradient: LinearGradient(
                                colors: [color, color.withOpacity(0.7)]),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: color.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8)),
                            ],
                          ),
                          // ✅✅✅ MODIFIED: BIGGER ICON ON WEB
                          child: Icon(icon,
                              color: Colors.white, size: kIsWeb ? 48 : 28),
                        ),

                        // ===== START OF ALIGNMENT FIX =====
                        Container(
                          // ✅✅✅ MODIFIED: BIGGER CONTAINER HEIGHT ON WEB
                          height: kIsWeb ? 60.0 : 44.0,
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            style: TextStyle(
                              // ✅✅✅ MODIFIED: BIGGER FONT ON WEB
                              fontSize: kIsWeb ? 18 : 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // ===== END OF ALIGNMENT FIX =====
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // The Badge
            if (count > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.5), width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  child: Center(
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ========================= STAT CARDS =========================
// ✅ REMOVED: All Stat Card widgets
// (_ItEvaluationsCard, _InterventionsCard, _InstallationsCard,
// _SavTicketsCard, _ReadyReplacementsCard, _MissionsCard)
// and the _buildGlowingCard helper function.
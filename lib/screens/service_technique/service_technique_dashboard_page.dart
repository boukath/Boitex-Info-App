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
// Import the AnnounceHubPage (This was in your original code)
import 'package:boitex_info_app/screens/announce/announce_hub_page.dart';

// This is the new import for the evaluations page
import 'package:boitex_info_app/screens/service_technique/pending_evaluations_list.dart';

// ✅✅✅ NEW IMPORT FOR THE JOURNAL PAGE ✅✅✅
import 'package:boitex_info_app/screens/service_technique/daily_activity_feed_page.dart';

// ===== NOUVEL IMPORT POUR LA PAGE FORMATION =====
import 'package:boitex_info_app/screens/service_technique/training_hub_page.dart';
// ===== FIN DE L'IMPORT =====
// ***** END CODE TO ADD *****

import 'dart:math' as math;

class ServiceTechniqueDashboardPage extends StatefulWidget {
  final String displayName;
  final String userRole;

  const ServiceTechniqueDashboardPage({
    super.key,
    required this.displayName,
    required this.userRole,
  });

  @override
  State<ServiceTechniqueDashboardPage> createState() =>
      _ServiceTechniqueDashboardPageState();
}

class _ServiceTechniqueDashboardPageState
    extends State<ServiceTechniqueDashboardPage>
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
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
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
            // Keeping your original gradient colors
            colors: [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFFF093FB)],
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
    return SliverToBoxAdapter(
      child: Container(
        // ***** START FIXED CODE *****
        // Typo 'fromLBRB' corrected to 'fromLTRB'
        padding: const EdgeInsets.fromLTRB(40, 20, 40, 32),
        // ***** END FIXED CODE *****
        child: Row(
          children: [
            _glassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            Expanded(
              // Keeping your user info chip structure
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
            // Keeping your original engineering icon button
            _glassIconButton(
              icon: Icons.engineering,
              onTap: () {},
            ),
            // This is your existing code
            const SizedBox(width: 12),
            _glassIconButton(
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
            // This is your existing code
          ],
        ),
      ),
    );
  }

  Widget _buildWebActionsGrid(BuildContext context) {
    // Keeping your original web actions grid structure
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
          children:
          _buildQuickActions(context), // Uses your quick actions builder
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
            // Keeping your original gradient
            colors: [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFFF093FB)],
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
                            child: _buildActionsGrid(
                                context)), // Uses your mobile actions grid
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
    // Keeping your original mobile header structure
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
                      // Keeping inner structure
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
                                fontSize: 16,
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
            const SizedBox(width: 12),
            // Keeping your original engineering icon button
            _glassIconButton(
              icon: Icons.engineering,
              onTap: () {},
            ),
            // This is your existing code
            const SizedBox(width: 12),
            _glassIconButton(
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
            // This is your existing code
          ],
        ),
      ),
    );
  }

  // ========================= SHARED UI =========================

  // Keeping your original _glassIconButton function
  Widget _glassIconButton(
      {required IconData icon, required VoidCallback onTap, String? tooltip}) {
    // Added tooltip parameter back
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
        tooltip: tooltip, // Use tooltip parameter
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
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1)
          ],
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
          children:
          _buildQuickActions(context), // Uses your quick actions builder
        ),
      ],
    );
  }

  // This function is correct and contains the new button
  List<Widget> _buildQuickActions(BuildContext context) {
    final actions = <_ActionData>[
      _ActionData(
        'Interventions',
        Icons.construction_rounded,
        const Color(0xFF10B981),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InterventionListPage(
              userRole: widget.userRole,
              serviceType: 'Service Technique',
            ),
          ),
        ),
        // Stream for pending interventions
        countStream: FirebaseFirestore.instance
            .collection('interventions')
            .where('serviceType', isEqualTo: 'Service Technique')
            .where('status', isEqualTo: 'Nouvelle Demande')
            .snapshots(),
      ),
      _ActionData(
        'Installations',
        Icons.router_rounded,
        const Color(0xFF3B82F6),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstallationListPage(
              userRole: widget.userRole,
              serviceType: 'Service Technique',
            ),
          ),
        ),
        // Stream for pending installations
        countStream: FirebaseFirestore.instance
            .collection('installations')
            .where('serviceType', isEqualTo: 'Service Technique')
            .where('status', whereIn: ['Nouveau', 'Planifiée']).snapshots(),
      ),
      _ActionData(
        'Tickets SAV',
        Icons.support_agent_rounded,
        const Color(0xFFF59E0B),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SavListPage(serviceType: 'Service Technique'),
          ),
        ),
        // Stream for pending SAV tickets
        countStream: FirebaseFirestore.instance
            .collection('sav_tickets')
            .where('serviceType', isEqualTo: 'Service Technique')
            .where('status', isEqualTo: 'Nouveau')
            .snapshots(),
      ),
      _ActionData(
        'Remplacements',
        Icons.inventory_2_rounded,
        const Color(0xFFEC4899),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ReadyReplacementsListPage(
                serviceType: 'Service Technique'),
          ),
        ),
        // Stream for pending replacements
        countStream: FirebaseFirestore.instance
            .collection('replacementRequests')
            .where('serviceType', isEqualTo: 'Service Technique')
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
              builder: (_) =>
                  ManageMissionsPage(serviceType: 'Service Technique')),
        ),
        // Stream for pending missions
        countStream: FirebaseFirestore.instance
            .collection('missions')
            .where('serviceType', isEqualTo: 'Service Technique')
            .where('status', whereIn: ['En Cours', 'Planifiée']).snapshots(),
      ),
      _ActionData(
        'Livraisons',
        Icons.local_shipping_rounded,
        const Color(0xFF14B8A6),
            () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
              const LivraisonsHubPage(serviceType: 'Service Technique')),
        ),
        // Stream for pending livraisons (assumes 'En Attente de Livraison' status)
        countStream: FirebaseFirestore.instance
            .collection('livraisons')
            .where('serviceType', isEqualTo: 'Service Technique')
            .where('status', isEqualTo: 'À Préparer')
            .snapshots(),
      ),

      // ===== NOUVELLE CARTE AJOUTÉE ICI =====
      _ActionData(
        'Formation', // "Training"
        Icons.school_rounded, // Icon for learning/school
        const Color(0xFFEF4444), // A new color (Red)
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TrainingHubPage(),
          ),
        ),
        // No stream needed
      ),
      // ===== FIN DE LA NOUVELLE CARTE =====

      _ActionData(
        'Historique',
        Icons.history,
        const Color(0xFF78716C),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HistoricInterventionsPage(
              serviceType: 'Service Technique',
              userRole: widget.userRole,
            ),
          ),
        ),
        // No stream needed
      ),
      // ✅✅✅ NEW BUTTON ADDED HERE ✅✅✅
      _ActionData(
        'Journal',
        Icons.timeline, // A fitting icon for a timeline/log
        const Color(0xFF6366F1), // A new color (indigo)
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DailyActivityFeedPage(),
          ),
        ),
        // No stream needed
      ),
      // ✅✅✅ END OF NEW BUTTON ✅✅✅

      // ✅ NEW "ÉVALUATIONS" BUTTON
      _ActionData(
        'Évaluations',
        Icons.pending_actions_rounded,
        const Color(0xFFEC4899), // Using pink color
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PendingEvaluationsListPage(userRole: widget.userRole),
          ),
        ),
        // Stream for pending evaluations
        countStream: FirebaseFirestore.instance
            .collection('projects')
            .where('status', isEqualTo: 'Nouvelle Demande')
            .where('serviceType', isEqualTo: 'Service Technique')
            .snapshots(),
      ),
    ];

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
          countStream: action.countStream, // ✅ Pass the stream to the card
        ),
      );
    }).toList();
  }

// ✅ REMOVED: _buildStatsSection function
} // End of State Class

// ========================= MODELS & CARDS =========================

// Keeping your original _ActionData class
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
        this.countStream, // ✅ Made optional in constructor
      });
}

// Keeping your original _ActionCard widget (with the alignment fix)
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
        final int count = snapshot.hasData ? snapshot.data!.docs.length : 0;

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

                        // ===== START OF FIX =====
                        // This Container replaces the SizedBox(height: 10) and Text
                        // to ensure a fixed height for the text area.

                        Container(
                          // ✅✅✅ MODIFIED: BIGGER CONTAINER HEIGHT ON WEB
                          height: kIsWeb ? 60.0 : 44.0,
                          alignment: Alignment
                              .center, // Center the text (1 or 2 lines)
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              // ✅✅✅ MODIFIED: BIGGER FONT ON WEB
                              fontSize: kIsWeb ? 18 : 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        // ===== END OF FIX =====
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
// (_EvaluationsCard, _InterventionsCard, _InstallationsCard,
// _SavTicketsCard, _ReadyReplacementsCard, _MissionsCard)
// and the _buildGlowingCard helper function.
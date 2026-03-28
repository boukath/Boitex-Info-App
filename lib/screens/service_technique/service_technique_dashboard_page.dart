import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ✅ ADDED: To detect Web platform for resizing
import 'package:flutter/foundation.dart' show kIsWeb;
// ✅ ADDED: For ImageFilter.blur (Glassmorphism)
import 'dart:ui';
// ✅ ADDED: For premium 4K fonts
import 'package:google_fonts/google_fonts.dart';
// ✅ ADDED: For Android Home Screen Widget
import 'package:home_widget/home_widget.dart';
import 'dart:async'; // Needed for the Timer
import 'package:boitex_info_app/screens/service_technique/intervention_list_page.dart';
import 'package:boitex_info_app/screens/service_technique/historic_interventions_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_list_page.dart';
import 'package:boitex_info_app/screens/administration/manage_missions_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_list_page.dart';
import 'package:boitex_info_app/screens/administration/livraisons_hub_page.dart';

// Import the AnnounceHubPage
import 'package:boitex_info_app/screens/announce/announce_hub_page.dart';
// This is the import for the evaluations page
import 'package:boitex_info_app/screens/service_technique/pending_evaluations_list.dart';
// Import for the Training page
import 'package:boitex_info_app/screens/service_technique/training_hub_page.dart';

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
  late Timer _timeTimer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
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

    // ✅ TRIGGER WIDGET UPDATE ON DASHBOARD LOAD
    if (!kIsWeb) {
      updateHomeWidgetCounts();
    }
  }

  @override
  void dispose() {
    _timeTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ✅ ADDED: Adaptive Color Logic
  List<Color> _getTimeBasedGradientColors() {
    final hour = _currentTime.hour;
    if (hour >= 6 && hour < 12) {
      // Morning
      return const [Color(0xFF8CA6DB), Color(0xFFFFB347), Color(0xFFFF7B54)];
    } else if (hour >= 12 && hour < 18) {
      // Afternoon
      return const [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFFF093FB)];
    } else {
      // Evening/Night
      return const [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2A0845)];
    }
  }

  // ✅ UPDATED FUNCTION: Update the Android Home Screen Widget
  Future<void> updateHomeWidgetCounts() async {
    // 1. 🔥 DELAY ADDED: Gives Firebase Auth time to resolve and sync locally
    await Future.delayed(const Duration(seconds: 2));

    final firestore = FirebaseFirestore.instance;

    try {
      // 2. 🚀 FORCE SERVER FETCH: Prevents it from reading an empty local offline cache
      final interventionsSnap = await firestore
          .collection('interventions')
          .where('serviceType', isEqualTo: 'Service Technique')
          .where('status', isEqualTo: 'Nouvelle Demande')
          .get(const GetOptions(source: Source.serverAndCache));

      final installationsSnap = await firestore
          .collection('installations')
          .where('serviceType', isEqualTo: 'Service Technique')
          .where('status', whereIn: ['Nouveau', 'Planifiée'])
          .get(const GetOptions(source: Source.serverAndCache));

      final savSnap = await firestore
          .collection('sav_tickets')
          .where('serviceType', isEqualTo: 'Service Technique')
          .where('status', isEqualTo: 'Nouveau')
          .get(const GetOptions(source: Source.serverAndCache));

      final missionsSnap = await firestore
          .collection('missions')
          .where('serviceType', isEqualTo: 'Service Technique')
          .where('status', whereIn: ['En Cours', 'Planifiée'])
          .get(const GetOptions(source: Source.serverAndCache));

      // 3. Save the new counts
      await HomeWidget.saveWidgetData<String>(
          'interventions_count', interventionsSnap.docs.length.toString());
      await HomeWidget.saveWidgetData<String>(
          'installations_count', installationsSnap.docs.length.toString());
      await HomeWidget.saveWidgetData<String>(
          'sav_count', savSnap.docs.length.toString());
      await HomeWidget.saveWidgetData<String>(
          'missions_count', missionsSnap.docs.length.toString());

      // 4. 🔥 EXPLICIT ANDROID TARGETING: Wake up the native Android code
      await HomeWidget.updateWidget(
        name: 'ServiceDashboardWidgetProvider',
        androidName: 'ServiceDashboardWidgetProvider',
      );

      debugPrint("✅ Widget successfully updated with live data!");
    } catch (e) {
      debugPrint("❌ Error updating widget: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CLEANED UP: Only routes to the correct layout without dead code
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width > 900) {
        return _buildWebDashboard(context, width);
      } else {
        return _buildMobileDashboard(context, width);
      }
    });
  }

  // ========================= WEB =========================

  Widget _buildWebDashboard(BuildContext context, double width) {
    return Scaffold(
      // ✅ APPLIED: AnimatedContainer with dynamic time-based colors
      body: AnimatedContainer(
        duration: const Duration(seconds: 4),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getTimeBasedGradientColors(),
            stops: const [0.0, 0.5, 1.0],
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
                        horizontal:
                        width > 1200 ? (width - 1200) / 2 : width * 0.05,
                      ),
                      child: _buildGlassCard(
                        child: _buildWebActionsGrid(context, width),
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
            _glassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
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
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
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
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
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
            _glassIconButton(
              icon: Icons.engineering,
              onTap: () {},
            ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildWebActionsGrid(BuildContext context, double width) {
    int crossAxisCount = width > 1100 ? 4 : 3;
    double aspectRatio = width > 1100 ? 1.3 : 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions Rapides',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 24,
          crossAxisSpacing: 24,
          childAspectRatio: aspectRatio,
          children: _buildQuickActions(context),
        ),
      ],
    );
  }

  // ========================= MOBILE =========================

  Widget _buildMobileDashboard(BuildContext context, double width) {
    return Scaffold(
      // ✅ APPLIED: AnimatedContainer with dynamic time-based colors
      body: AnimatedContainer(
        duration: const Duration(seconds: 4),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getTimeBasedGradientColors(),
            stops: const [0.0, 0.5, 1.0],
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
                        _buildGlassCard(
                            child: _buildActionsGrid(context, width)),
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
                      children: [
                        Expanded(
                            child: Text(
                              widget.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
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
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
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
            _glassIconButton(
              icon: Icons.engineering,
              onTap: () {},
            ),
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
          ],
        ),
      ),
    );
  }

  // ========================= SHARED UI =========================

  Widget _glassIconButton(
      {required IconData icon, required VoidCallback onTap, String? tooltip}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
        tooltip: tooltip,
      ),
    );
  }

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

  Widget _buildActionsGrid(BuildContext context, double width) {
    int crossAxisCount = width > 600 ? 3 : 2;
    double aspectRatio = width > 600 ? 1.0 : 0.78;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions Rapides',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: aspectRatio,
          children: _buildQuickActions(context),
        ),
      ],
    );
  }

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
        countStream: FirebaseFirestore.instance
            .collection('installations')
            .where('serviceType', isEqualTo: 'Service Technique')
            .where('status', whereIn: ['Nouveau', 'Planifiée']).snapshots(),
      ),
      _ActionData(
        'SAV',
        Icons.support_agent_rounded,
        const Color(0xFFF59E0B),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SavListPage(serviceType: 'Service Technique'),
          ),
        ),
        countStream: FirebaseFirestore.instance
            .collection('sav_tickets')
            .where('serviceType', isEqualTo: 'Service Technique')
            .where('status', isEqualTo: 'Nouveau')
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
        countStream: FirebaseFirestore.instance
            .collection('livraisons')
            .where('serviceType', isEqualTo: 'Service Technique')
            .where('status', isEqualTo: 'À Préparer')
            .snapshots(),
      ),
      _ActionData(
        'Formation',
        Icons.school_rounded,
        const Color(0xFFEF4444),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TrainingHubPage(),
          ),
        ),
      ),
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
      ),
      _ActionData(
        'Évaluations',
        Icons.pending_actions_rounded,
        const Color(0xFFEC4899),
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PendingEvaluationsListPage(userRole: widget.userRole),
          ),
        ),
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
          countStream: action.countStream,
        ),
      );
    }).toList();
  }
}

// ========================= MODELS & CARDS =========================

class _ActionData {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Stream<QuerySnapshot>? countStream;

  _ActionData(
      this.label,
      this.icon,
      this.color,
      this.onTap, {
        this.countStream,
      });
}

// ✅ APPLE IOS 26 PREMIUM GLASS CARD
class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Stream<QuerySnapshot>? countStream;

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.countStream,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 900;

    return StreamBuilder<QuerySnapshot>(
      stream: countStream,
      builder: (context, snapshot) {
        final int count = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(32),
                        splashColor: Colors.white.withOpacity(0.2),
                        highlightColor: Colors.white.withOpacity(0.1),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: isWide ? 20 : 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(isWide ? 18 : 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      color.withOpacity(0.9),
                                      color.withOpacity(0.6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(0.5),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.5),
                                      blurRadius: 10,
                                      offset: const Offset(-2, -2),
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  icon,
                                  color: Colors.white,
                                  size: isWide ? 42 : 28,
                                ),
                              ),
                              SizedBox(height: isWide ? 16 : 8),
                              Container(
                                height: isWide ? 54.0 : 40.0,
                                alignment: Alignment.center,
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: isWide ? 16 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF453A), Color(0xFFC40000)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.9),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.6),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  child: Center(
                    child: Text(
                      count.toString(),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
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
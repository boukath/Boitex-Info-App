// lib/screens/home/home_page.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:boitex_info_app/screens/service_technique/service_technique_dashboard_page.dart';
import 'package:boitex_info_app/screens/administration/administration_dashboard_page.dart';
import 'package:boitex_info_app/screens/service_it/service_it_dashboard_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/api/firebase_api.dart';

class HomePage extends StatefulWidget {
  final String userRole;
  final String displayName;

  const HomePage({
    super.key,
    required this.userRole,
    required this.displayName,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ✅ NEW: Smart greeting based on time of day
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 12) {
      return 'Bonjour,';
    } else if (hour >= 12 && hour < 18) {
      return 'Bon après-midi,';
    } else {
      return 'Bonsoir,';  // 18:00 - 23:59
    }
  }

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    final api = FirebaseApi();
    await api.initNotifications();
    try {
      await api.unsubscribeFromAllTopics();
      await api.subscribeToTopics(widget.userRole);
    } catch (_) {}
    await api.saveTokenForCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    final isWebWide = kIsWeb && MediaQuery.of(context).size.width >= 900;
    if (isWebWide) {
      return _buildPremiumWebLayout();
    } else {
      return _buildModernMobileLayout();
    }
  }

  // ✅ KEEP WEB VERSION UNCHANGED
  Widget _buildPremiumWebLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1e3a8a),
                  Color(0xFF3b82f6),
                ],
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
                // Logo
                Container(
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
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // User card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white,
                        child: Text(
                          widget.displayName.isNotEmpty
                              ? widget.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Color(0xFF1e3a8a),
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
                              widget.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.userRole,
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
                const Spacer(),
                // Logout
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await FirebaseApi().unsubscribeFromAllTopics();
                      } catch (_) {}
                      await FirebaseAuth.instance.signOut();
                    },
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
                        backgroundColor: const Color(0xFF3b82f6),
                        child: Text(
                          widget.displayName.isNotEmpty
                              ? widget.displayName[0].toUpperCase()
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
                // Dashboard grid
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenue, ${widget.displayName} 👋',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 40),
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 24,
                          childAspectRatio: 1.3,
                          children: _buildPremiumCards(),
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
    );
  }

  List<Widget> _buildPremiumCards() {
    final cards = <Widget>[];
    if (RolePermissions.canSeeAdminCard(widget.userRole)) {
      cards.add(_premiumCard(
        Icons.admin_panel_settings_rounded,
        'Administration',
        [const Color(0xFF6366f1), const Color(0xFF8b5cf6)],
            () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AdministrationDashboardPage(
              displayName: widget.displayName,
              userRole: widget.userRole,
            ),
          ));
        },
      ));
    }

    if (RolePermissions.canSeeTechServiceCard(widget.userRole)) {
      cards.add(_premiumCard(
        Icons.engineering_rounded,
        'Service Technique',
        [const Color(0xFF10b981), const Color(0xFF059669)],
            () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ServiceTechniqueDashboardPage(
              displayName: widget.displayName,
              userRole: widget.userRole,
            ),
          ));
        },
      ));
    }

    if (RolePermissions.canSeeITServiceCard(widget.userRole)) {
      cards.add(_premiumCard(
        Icons.computer_rounded,
        'Service IT',
        [const Color(0xFF06b6d4), const Color(0xFF0891b2)],
            () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ServiceItDashboardPage(
              displayName: widget.displayName,
              userRole: widget.userRole,
            ),
          ));
        },
      ));
    }

    return cards;
  }

  Widget _premiumCard(
      IconData icon,
      String title,
      List<Color> colors,
      VoidCallback onTap,
      ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors[0].withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 NEW: 2025 ULTRA-PREMIUM MOBILE DESIGN
  Widget _buildModernMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ✨ Ultra-Premium Header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Logo + Role Badge
                    Row(
                      children: [
                        // ✅ BoitexInfo Logo - NO BACKGROUND, BIGGER SIZE
                        SizedBox(
                          width: 120,  // ✅ Bigger: was 64, now 120
                          height: 120, // ✅ Bigger: was 64, now 120
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const Spacer(),
                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366f1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF6366f1).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF6366f1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.userRole,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6366f1),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // ✅ UPDATED: Dynamic greeting
                    Text(
                      _getGreeting(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.displayName,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -1,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ✨ Service Cards Section (NO "Services" TITLE)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ❌ REMOVED: "Services" heading

                  // Administration Card
                  if (RolePermissions.canSeeAdminCard(widget.userRole)) ...[
                    _ultraPremiumServiceCard(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Administration',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shadowColor: const Color(0xFF6366f1),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => AdministrationDashboardPage(
                            displayName: widget.displayName,
                            userRole: widget.userRole,
                          ),
                        ));
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Service Technique Card
                  if (RolePermissions.canSeeTechServiceCard(widget.userRole)) ...[
                    _ultraPremiumServiceCard(
                      icon: Icons.engineering_rounded,
                      title: 'Service Technique',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10b981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shadowColor: const Color(0xFF10b981),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ServiceTechniqueDashboardPage(
                            displayName: widget.displayName,
                            userRole: widget.userRole,
                          ),
                        ));
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Service IT Card
                  if (RolePermissions.canSeeITServiceCard(widget.userRole)) ...[
                    _ultraPremiumServiceCard(
                      icon: Icons.computer_rounded,
                      title: 'Service IT',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06b6d4), Color(0xFF0891b2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shadowColor: const Color(0xFF06b6d4),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ServiceItDashboardPage(
                            displayName: widget.displayName,
                            userRole: widget.userRole,
                          ),
                        ));
                      },
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎨 Ultra-Premium Service Card (2025 Style)
  Widget _ultraPremiumServiceCard({
    required IconData icon,
    required String title,
    required Gradient gradient,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Subtle gradient accent on left
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 5,
                child: Container(
                  decoration: BoxDecoration(gradient: gradient),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // Icon Container (4K Quality Style)
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 36),
                    ),
                    const SizedBox(width: 20),

                    // Title
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),

                    // Arrow Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

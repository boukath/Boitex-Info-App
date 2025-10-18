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
      return _buildMobileLayout();
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

// 🎨 UPDATED: Fixed overflow and removed subtitles
  Widget _buildMobileLayout() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8FAFF), // Very light blue-white
              Color(0xFFFFFFFF), // Pure white
              Color(0xFFFAF5FF), // Very light purple-white
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App Bar with glassmorphism
              SliverAppBar(
                expandedHeight: 180,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.9),
                          Colors.white.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 50, 24, 16), // ✅ Reduced top padding from 60 to 50
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6366f1).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    widget.displayName.isNotEmpty
                                        ? widget.displayName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min, // ✅ Added this
                                  children: [
                                    const Text(
                                      'Bonjour,',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.displayName,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10), // ✅ Reduced from 12 to 10
                          Container(
                            constraints: const BoxConstraints(
                              maxWidth: 250,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366f1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF6366f1).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF6366f1),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    widget.userRole,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6366f1),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Services Cards
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const Text(
                      'Services',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (RolePermissions.canSeeAdminCard(widget.userRole))
                      _modernServiceCard(
                        Icons.admin_panel_settings_rounded,
                        'Administration',
                        const LinearGradient(
                          colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                        ),
                            () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => AdministrationDashboardPage(
                              displayName: widget.displayName,
                              userRole: widget.userRole,
                            ),
                          ));
                        },
                      ),
                    if (RolePermissions.canSeeAdminCard(widget.userRole))
                      const SizedBox(height: 16),
                    if (RolePermissions.canSeeTechServiceCard(widget.userRole))
                      _modernServiceCard(
                        Icons.engineering_rounded,
                        'Service Technique',
                        const LinearGradient(
                          colors: [Color(0xFF10b981), Color(0xFF059669)],
                        ),
                            () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ServiceTechniqueDashboardPage(
                              displayName: widget.displayName,
                              userRole: widget.userRole,
                            ),
                          ));
                        },
                      ),
                    if (RolePermissions.canSeeTechServiceCard(widget.userRole))
                      const SizedBox(height: 16),
                    if (RolePermissions.canSeeITServiceCard(widget.userRole))
                      _modernServiceCard(
                        Icons.computer_rounded,
                        'Service IT',
                        const LinearGradient(
                          colors: [Color(0xFF06b6d4), Color(0xFF0891b2)],
                        ),
                            () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ServiceItDashboardPage(
                              displayName: widget.displayName,
                              userRole: widget.userRole,
                            ),
                          ));
                        },
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// ✅ UPDATED: Removed subtitle, reduced height
  Widget _modernServiceCard(
      IconData icon,
      String title,
      Gradient gradient,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100, // ✅ Reduced from 140 to 100
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Gradient accent on left
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: Container(
                  decoration: BoxDecoration(gradient: gradient),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Icon container
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: gradient.colors[0].withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 20),
                    // Text content - ✅ Removed subtitle
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    // Arrow icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
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

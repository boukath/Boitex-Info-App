// lib/screens/home/home_page.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:boitex_info_app/screens/service_technique/service_technique_dashboard_page.dart';
import 'package:boitex_info_app/screens/administration/administration_dashboard_page.dart';
import 'package:boitex_info_app/screens/service_it/service_it_dashboard_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/api/firebase_api.dart';
import 'dart:math' as math;

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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 12) {
      return 'Bonjour,';
    } else if (hour >= 12 && hour < 18) {
      return 'Bon après-midi,';
    } else {
      return 'Bonsoir,';
    }
  }

  @override
  void initState() {
    super.initState();
    _setupNotifications();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width > 900) {
        return _buildWebLayout(context, width);
      } else {
        return _buildMobileLayout(context);
      }
    });
  }

  // 🎨 WEB LAYOUT
  Widget _buildWebLayout(BuildContext context, double width) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667EEA),
              const Color(0xFF764BA2),
              const Color(0xFFF093FB),
            ],
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
                        horizontal: math.min((width - 1200) / 2, width * 0.1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 40),
                          // Greeting
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.displayName,
                            style: const TextStyle(
                              fontSize: 42,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 60),
                          // Service Cards
                          _buildWebServiceCards(context),
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
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 20, 40, 0),
        child: Row(
          children: [
            // ✨ Logo (BIGGER - 80px height)
            Image.asset(
              'assets/images/logo.png',
              height: 80,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.business, size: 80, color: Colors.white);
              },
            ),
            const Spacer(),
            // Role Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.userRole,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Logout Button
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                onPressed: () async {
                  try {
                    await FirebaseApi().unsubscribeFromAllTopics();
                  } catch (_) {}
                  await FirebaseAuth.instance.signOut();
                },
                tooltip: 'Déconnexion',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebServiceCards(BuildContext context) {
    final cards = <Widget>[];

    if (RolePermissions.canSeeAdminCard(widget.userRole)) {
      cards.add(Expanded(
        child: _webServiceCard(
          context: context,
          title: 'Administration',
          icon: Icons.shield_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
          delay: 0,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdministrationDashboardPage(
                displayName: widget.displayName,
                userRole: widget.userRole,
              ),
            ),
          ),
        ),
      ));
    }

    if (RolePermissions.canSeeTechServiceCard(widget.userRole)) {
      if (cards.isNotEmpty) cards.add(const SizedBox(width: 20));
      cards.add(Expanded(
        child: _webServiceCard(
          context: context,
          title: 'Service Technique',
          icon: Icons.engineering_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          delay: 100,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceTechniqueDashboardPage(
                displayName: widget.displayName,
                userRole: widget.userRole,
              ),
            ),
          ),
        ),
      ));
    }

    if (RolePermissions.canSeeITServiceCard(widget.userRole)) {
      if (cards.isNotEmpty) cards.add(const SizedBox(width: 20));
      cards.add(Expanded(
        child: _webServiceCard(
          context: context,
          title: 'Service IT',
          icon: Icons.computer_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
          ),
          delay: 200,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceItDashboardPage(
                displayName: widget.displayName,
                userRole: widget.userRole,
              ),
            ),
          ),
        ),
      ));
    }

    return Row(children: cards);
  }

  Widget _webServiceCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Gradient gradient,
    required int delay,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 600 + delay),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.2),
              Colors.white.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(32),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: gradient.colors.first.withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 MOBILE LAYOUT
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667EEA),
              const Color(0xFF764BA2),
              const Color(0xFFF093FB),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ✨ NEW HEADER (Logo + Greeting + PDG Badge horizontally)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    children: [
                      // Row 1: Logo on left
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.business, size: 40, color: Colors.white);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Row 2: Greeting + Name + PDG Badge (horizontally)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Greeting + Name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.displayName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // PDG Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.userRole,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Logout button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                              tooltip: 'Déconnexion',
                              onPressed: () async {
                                try {
                                  await FirebaseApi().unsubscribeFromAllTopics();
                                } catch (_) {}
                                await FirebaseAuth.instance.signOut();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Service Cards
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(_buildMobileCards()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMobileCards() {
    final cards = <Widget>[];

    if (RolePermissions.canSeeAdminCard(widget.userRole)) {
      cards.add(_mobileServiceCard(
        icon: Icons.shield_rounded,
        title: 'Administration',
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        shadowColor: const Color(0xFF667EEA),
        delay: 0,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdministrationDashboardPage(
              displayName: widget.displayName,
              userRole: widget.userRole,
            ),
          ),
        ),
      ));
      cards.add(const SizedBox(height: 16));
    }

    if (RolePermissions.canSeeTechServiceCard(widget.userRole)) {
      cards.add(_mobileServiceCard(
        icon: Icons.engineering_rounded,
        title: 'Service Technique',
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        shadowColor: const Color(0xFF10B981),
        delay: 100,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceTechniqueDashboardPage(
              displayName: widget.displayName,
              userRole: widget.userRole,
            ),
          ),
        ),
      ));
      cards.add(const SizedBox(height: 16));
    }

    if (RolePermissions.canSeeITServiceCard(widget.userRole)) {
      cards.add(_mobileServiceCard(
        icon: Icons.computer_rounded,
        title: 'Service IT',
        gradient: const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
        ),
        shadowColor: const Color(0xFF06B6D4),
        delay: 200,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceItDashboardPage(
              displayName: widget.displayName,
              userRole: widget.userRole,
            ),
          ),
        ),
      ));
    }

    return cards;
  }

  Widget _mobileServiceCard({
    required IconData icon,
    required String title,
    required Gradient gradient,
    required Color shadowColor,
    required int delay,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + delay),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 30 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: Offset(0, 20)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(32),
            child: Padding(
              padding: const EdgeInsets.all(28), // was 32
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16), // was 20
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: shadowColor.withOpacity(0.4), blurRadius: 20, offset: Offset(0, 10)),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 36), // was 40
                  ),

                  const SizedBox(width: 16), // was 24

                  // Title
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18, // was 22
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  // Arrow
                  Container(
                    padding: const EdgeInsets.all(10), // was 12
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.9), size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
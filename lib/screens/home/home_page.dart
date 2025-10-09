// lib/screens/home/home_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:boitex_info_app/screens/service_technique/service_technique_dashboard_page.dart';
import 'package:boitex_info_app/screens/administration/administration_dashboard_page.dart';
import 'package:boitex_info_app/screens/service_it/service_it_dashboard_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/api/firebase_api.dart';
import 'package:animated_gradient/animated_gradient.dart';
import 'package:boitex_info_app/screens/home/widgets/animated_service_card.dart';

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
    final firebaseApi = FirebaseApi();
    await firebaseApi.initNotifications();
    await firebaseApi.subscribeToTopics(widget.userRole);
    await firebaseApi.saveTokenForCurrentUser();
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

  Widget _buildPremiumWebLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // MODERN SIDEBAR WITH BIG TRANSPARENT LOGO
          Container(
            width: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1e3a8a),
                  const Color(0xFF3b82f6),
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
                // Logo Section - BIG AND TRANSPARENT
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // YOUR BIG LOGO WITHOUT BACKGROUND
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
                // User Card
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
                          widget.displayName.isNotEmpty ? widget.displayName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Color(0xFF1e3a8a), fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.displayName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                            Text(widget.userRole, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
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
                      final firebaseApi = FirebaseApi();
                      await firebaseApi.unsubscribeFromAllTopics();
                      await FirebaseAuth.instance.signOut();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Déconnexion'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // MAIN CONTENT
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Tableau de Bord', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('Vue d\'ensemble', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                      const Spacer(),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF3b82f6),
                        child: Text(
                          widget.displayName.isNotEmpty ? widget.displayName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bienvenue, ${widget.displayName} 👋', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Sélectionnez un service pour commencer', style: TextStyle(fontSize: 16, color: Colors.grey)),
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
      cards.add(_premiumCard(Icons.admin_panel_settings_rounded, 'Administration', 'Gestion', [const Color(0xFF6366f1), const Color(0xFF8b5cf6)], () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => AdministrationDashboardPage(displayName: widget.displayName, userRole: widget.userRole)));
      }));
    }
    if (RolePermissions.canSeeTechServiceCard(widget.userRole)) {
      cards.add(_premiumCard(Icons.engineering_rounded, 'Service Technique', 'Interventions', [const Color(0xFF10b981), const Color(0xFF059669)], () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => ServiceTechniqueDashboardPage(displayName: widget.displayName, userRole: widget.userRole)));
      }));
    }
    if (RolePermissions.canSeeITServiceCard(widget.userRole)) {
      cards.add(_premiumCard(Icons.computer_rounded, 'Service IT', 'Infrastructure', [const Color(0xFF06b6d4), const Color(0xFF0891b2)], () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => ServiceItDashboardPage(displayName: widget.displayName, userRole: widget.userRole)));
      }));
    }
    return cards;
  }

  Widget _premiumCard(IconData icon, String title, String subtitle, List<Color> colors, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: colors[0].withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      body: AnimatedGradient(
        colors: [Colors.grey.shade50, Colors.grey.shade200],
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bienvenue, ${widget.displayName}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text(widget.userRole, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.logout), onPressed: () async {
                      await FirebaseApi().unsubscribeFromAllTopics();
                      await FirebaseAuth.instance.signOut();
                    }),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: _buildMobileCards(),
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
      cards.add(AnimatedServiceCard(icon: Icons.admin_panel_settings_outlined, title: 'Administration', color: Colors.blue.shade700, onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => AdministrationDashboardPage(displayName: widget.displayName, userRole: widget.userRole)));
      }));
      cards.add(const SizedBox(height: 16));
    }
    if (RolePermissions.canSeeTechServiceCard(widget.userRole)) {
      cards.add(AnimatedServiceCard(icon: Icons.support_agent_outlined, title: 'Service Technique', color: Colors.green.shade700, onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => ServiceTechniqueDashboardPage(displayName: widget.displayName, userRole: widget.userRole)));
      }));
      cards.add(const SizedBox(height: 16));
    }
    if (RolePermissions.canSeeITServiceCard(widget.userRole)) {
      cards.add(AnimatedServiceCard(icon: Icons.computer_outlined, title: 'Service IT', color: Colors.cyan.shade700, onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => ServiceItDashboardPage(displayName: widget.displayName, userRole: widget.userRole)));
      }));
    }
    return cards;
  }
}

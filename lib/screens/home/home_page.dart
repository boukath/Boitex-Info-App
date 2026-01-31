// lib/screens/home/home_page.dart

import 'dart:async'; // ✅ Added for Timeout logic
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart'; // ✅ Added for Car Icon
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:boitex_info_app/screens/service_technique/service_technique_dashboard_page.dart';
import 'package:boitex_info_app/screens/administration/administration_dashboard_page.dart';
import 'package:boitex_info_app/screens/service_it/service_it_dashboard_page.dart';
import 'package:boitex_info_app/screens/commercial/commercial_dashboard_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/api/firebase_api.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/home/notifications_page.dart';
import 'package:boitex_info_app/screens/settings/global_settings_page.dart';
// ✅ IMPORT THE FLEET GARAGE
import 'package:boitex_info_app/screens/fleet/fleet_list_page.dart';
// ✅ IMPORT MORNING BRIEFING SUMMARY
import 'package:boitex_info_app/screens/dashboard/morning_briefing_summary_page.dart';

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

  // 🚪 LOGOUT LOGIC: Confirm -> Load -> Exit
  Future<void> _handleLogout(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent clicking outside to close while loading
      builder: (dialogContext) {
        bool isLoading = false;

        // StatefulBuilder allows us to update the dialog content (show spinner)
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: isLoading
                  ? const Center(child: Text("Déconnexion...", style: TextStyle(fontSize: 18)))
                  : const Text("Déconnexion", style: TextStyle(fontWeight: FontWeight.bold)),

              content: isLoading
                  ? const SizedBox(
                height: 80,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
                  : const Text("Voulez-vous vraiment vous déconnecter ?"),

              actions: isLoading
                  ? [] // Hide buttons while loading to prevent double-clicks
                  : [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(), // Cancel
                  child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // 1. Switch UI to Loading State
                    setState(() => isLoading = true);

                    // 2. Perform Network Cleanup (with Safety Timeout)
                    try {
                      // Give it max 3 seconds to unsubscribe, otherwise force logout
                      await FirebaseApi()
                          .unsubscribeFromAllTopics()
                          .timeout(const Duration(seconds: 3));
                    } catch (_) {
                      // If timeout or error, ignore and proceed to sign out
                    }

                    // 3. Close the Dialog
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }

                    // 4. Actual Sign Out (AuthGate will handle the redirect)
                    await FirebaseAuth.instance.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Se déconnecter"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .limit(10) // ✅ CHANGED: Limit increased to count up to 9+
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          unreadCount = snapshot.data!.docs.length;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
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
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: kIsWeb ? 20 : 18,
                ),
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationsPage(
                        userRole: widget.userRole,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: -5, // ✅ CHANGED: Adjusted position to hang off the corner
                right: -5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5), // Added white border for contrast
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount', // ✅ CHANGED: Show number
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
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

  // 🚗 THE GARAGE ICON WIDGET
  Widget _buildGarageIcon(BuildContext context) {
    // ✅ VISIBLE FOR EVERYONE (Restriction Removed)
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: IconButton(
        icon: Icon(
          CupertinoIcons.car_detailed, // Premium Car Icon
          color: Colors.white,
          size: kIsWeb ? 20 : 18,
        ),
        tooltip: 'Le Garage',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FleetListPage(),
            ),
          );
        },
      ),
    );
  }

  // ☀️ THE NEW MORNING BRIEFING ICON
  Widget _buildBriefingIcon(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: IconButton(
        icon: Icon(
          Icons.wb_sunny_rounded, // Sun Icon indicates "Morning/Day Start"
          color: Colors.white,
          size: kIsWeb ? 20 : 18,
        ),
        tooltip: 'Briefing Matinal',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MorningBriefingSummaryPage(),
            ),
          );
        },
      ),
    );
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
            Image.asset(
              'assets/images/logo.png',
              height: 80,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.business, size: 80, color: Colors.white);
              },
            ),
            const Spacer(),
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

            // ✅ BRIEFING ICON (WEB) - Placed before Garage
            _buildBriefingIcon(context),
            const SizedBox(width: 16),

            // ✅ CAR ICON (WEB)
            _buildGarageIcon(context),
            const SizedBox(width: 16),

            _buildNotificationBell(context),
            const SizedBox(width: 16),

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
                icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
                tooltip: 'Paramètres',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GlobalSettingsPage(userRole: widget.userRole),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),

            // ✅ UPDATED WEB LOGOUT BUTTON
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
                onPressed: () => _handleLogout(context), // Uses new Logic
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

    if (RolePermissions.canSeeCommercialCard(widget.userRole)) {
      if (cards.isNotEmpty) cards.add(const SizedBox(width: 20));
      cards.add(Expanded(
        child: _webServiceCard(
          context: context,
          title: 'Commercial',
          icon: Icons.business_center_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9966), Color(0xFFFF5E62)],
          ),
          delay: 50,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CommercialDashboardPage(),
              ),
            );
          },
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

  // 🎨 MOBILE LAYOUT (UPDATED FOR OPTION 1)
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. TOP ROW: Logo (Left) and Greeting/Identity (Right)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start, // Align to top
                        children: [
                          // Logo
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 70,
                              height: 70,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.business,
                                    size: 40, color: Colors.white);
                              },
                            ),
                          ),

                          // Greeting Text & Role Stack
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.displayName,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 8),

                                // ✅ MOVED ROLE BADGE HERE
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min, // Shrink to fit text
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
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24), // Increased spacing for cleaner look

                      // 2. SECOND ROW: Action Icons Only (Evenly Spaced)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // ✅ Clean Layout
                        children: [
                          // ✅ BRIEFING ICON (MOBILE) - First item for "Start of Day"
                          _buildBriefingIcon(context),

                          // ✅ CAR ICON (MOBILE)
                          _buildGarageIcon(context),

                          // Bell
                          _buildNotificationBell(context),

                          // Settings
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
                              icon: const Icon(Icons.settings_rounded,
                                  color: Colors.white, size: 18),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GlobalSettingsPage(
                                        userRole: widget.userRole),
                                  ),
                                );
                              },
                            ),
                          ),

                          // ✅ UPDATED MOBILE LOGOUT BUTTON
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
                              icon: const Icon(Icons.logout_rounded,
                                  color: Colors.white, size: 18),
                              tooltip: 'Déconnexion',
                              onPressed: () => _handleLogout(context), // Uses new Logic
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
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

    if (RolePermissions.canSeeCommercialCard(widget.userRole)) {
      cards.add(_mobileServiceCard(
        icon: Icons.business_center_rounded,
        title: 'Commercial',
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9966), Color(0xFFFF5E62)],
        ),
        shadowColor: const Color(0xFFFF9966),
        delay: 50,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CommercialDashboardPage(),
            ),
          );
        },
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
              padding: const EdgeInsets.all(28),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: shadowColor.withOpacity(0.4), blurRadius: 20, offset: Offset(0, 10)),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 36),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(10),
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
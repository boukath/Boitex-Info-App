// lib/screens/home/home_page.dart

import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:boitex_info_app/screens/fleet/fleet_list_page.dart';
import 'package:boitex_info_app/screens/dashboard/morning_briefing_summary_page.dart';
import 'package:flutter/services.dart';

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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late Timer _timeTimer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _setupNotifications();

    _currentTime = DateTime.now();
    _timeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() => _currentTime = DateTime.now());
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _timeTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<Color> _getTimeBasedGradientColors() {
    final hour = _currentTime.hour;
    if (hour >= 6 && hour < 12) {
      return const [Color(0xFF8CA6DB), Color(0xFFFFB347), Color(0xFFFF7B54)];
    } else if (hour >= 12 && hour < 18) {
      return const [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFFF093FB)];
    } else {
      return const [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2A0845)];
    }
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

  Future<void> _handleLogout(BuildContext context) async {
    SensoryEngine.playClick();
    await showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return CupertinoAlertDialog(
              title: isLoading ? const Text("Déconnexion...") : const Text("Déconnexion"),
              content: isLoading
                  ? const Padding(padding: EdgeInsets.all(20.0), child: CupertinoActivityIndicator(radius: 14))
                  : const Text("Voulez-vous vraiment vous déconnecter ?"),
              actions: isLoading ? [] : [
                CupertinoDialogAction(
                  onPressed: () {
                    SensoryEngine.playClick();
                    Navigator.of(context).pop();
                  },
                  child: const Text("Annuler"),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () async {
                    SensoryEngine.playHeavyClick();
                    setState(() => isLoading = true);
                    try {
                      await FirebaseApi().unsubscribeFromAllTopics().timeout(const Duration(seconds: 3));
                    } catch (_) {}
                    if (context.mounted) Navigator.of(context).pop();
                    await FirebaseAuth.instance.signOut();
                  },
                  child: const Text("Se déconnecter"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Route _premiumPageTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeTween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut));
        return FadeTransition(opacity: animation.drive(fadeTween), child: child);
      },
    );
  }

  Widget _buildGlassContainer({
    required Widget child,
    double borderRadius = 32,
    EdgeInsetsGeometry? padding,
    double blur = 30.0,
    double opacity = 0.15,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.2),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.05)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        Widget? badgeWidget;

        if (unreadCount > 0) {
          badgeWidget = Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: const Color(0xFFFF3B30).withOpacity(0.5), blurRadius: 8, spreadRadius: 1)]
            ),
            child: Text(
              unreadCount > 9 ? '9+' : '$unreadCount',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: '.SF Pro Text'),
            ),
          );
        }

        return _AnimatedGlassIconButton(
          icon: CupertinoIcons.bell,
          tooltip: 'Notifications',
          onPressed: () => Navigator.push(context, _premiumPageTransition(NotificationsPage(userRole: widget.userRole))),
          badge: badgeWidget,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width > 900) return _buildWebLayout(context, width);
      return _buildMobileLayout(context);
    });
  }

  Widget _buildWebLayout(BuildContext context, double width) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 4),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _getTimeBasedGradientColors(),
              stops: const [0.0, 0.5, 1.0]
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
                      padding: EdgeInsets.symmetric(horizontal: math.min((width - 1200) / 2, width * 0.05), vertical: 60),
                      child: _buildWebServiceCards(context),
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
        padding: const EdgeInsets.fromLTRB(40, 30, 40, 0),
        child: Row(
          children: [
            Image.asset('assets/images/BOITEXINFOBLANC.png', height: 85, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.building_2_fill, size: 60, color: Colors.white)),
            const Spacer(),
            _buildGlassContainer(
              borderRadius: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              blur: 40,
              child: Row(
                children: [
                  _AnimatedGlassIconButton(icon: CupertinoIcons.sun_max, tooltip: 'Briefing', onPressed: () => Navigator.push(context, _premiumPageTransition(const MorningBriefingSummaryPage()))),
                  const SizedBox(width: 8),
                  _AnimatedGlassIconButton(icon: CupertinoIcons.car_detailed, tooltip: 'Garage', onPressed: () => Navigator.push(context, _premiumPageTransition(const FleetListPage()))),
                  const SizedBox(width: 8),
                  _buildNotificationBell(context),
                  const SizedBox(width: 8),
                  _AnimatedGlassIconButton(icon: CupertinoIcons.settings, tooltip: 'Paramètres', onPressed: () => Navigator.push(context, _premiumPageTransition(GlobalSettingsPage(userRole: widget.userRole)))),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(width: 8),
                  _AnimatedGlassIconButton(icon: CupertinoIcons.power, tooltip: 'Déconnexion', onPressed: () => _handleLogout(context)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _HoverableProfileChip(displayName: widget.displayName, userRole: widget.userRole),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 4),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _getTimeBasedGradientColors(),
              stops: const [0.0, 0.5, 1.0]
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/BOITEXINFOBLANC.png', width: 85, height: 85, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.building_2_fill, size: 60, color: Colors.white)),
                              _HoverableProfileChip(displayName: widget.displayName, userRole: widget.userRole),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _buildGlassContainer(
                            borderRadius: 40,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            blur: 40,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _AnimatedGlassIconButton(icon: CupertinoIcons.sun_max, tooltip: 'Briefing', onPressed: () => Navigator.push(context, _premiumPageTransition(const MorningBriefingSummaryPage()))),
                                _AnimatedGlassIconButton(icon: CupertinoIcons.car_detailed, tooltip: 'Garage', onPressed: () => Navigator.push(context, _premiumPageTransition(const FleetListPage()))),
                                _buildNotificationBell(context),
                                _AnimatedGlassIconButton(icon: CupertinoIcons.settings, tooltip: 'Paramètres', onPressed: () => Navigator.push(context, _premiumPageTransition(GlobalSettingsPage(userRole: widget.userRole)))),
                                Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3)),
                                _AnimatedGlassIconButton(icon: CupertinoIcons.power, tooltip: 'Déconnexion', onPressed: () => _handleLogout(context)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                sliver: SliverList(delegate: SliverChildListDelegate(_buildMobileCards())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebServiceCards(BuildContext context) {
    final cards = <Widget>[];
    Widget buildExpandedCard(Widget card) => Expanded(child: card);

    if (RolePermissions.canSeeAdminCard(widget.userRole)) {
      cards.add(buildExpandedCard(
        _HoverableServiceCard(title: 'Administration', icon: CupertinoIcons.shield_fill, gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]), onTap: () => Navigator.push(context, _premiumPageTransition(AdministrationDashboardPage(displayName: widget.displayName, userRole: widget.userRole)))),
      ));
    }
    if (RolePermissions.canSeeCommercialCard(widget.userRole)) {
      if (cards.isNotEmpty) cards.add(const SizedBox(width: 24));
      cards.add(buildExpandedCard(
        _HoverableServiceCard(title: 'Commercial', icon: CupertinoIcons.briefcase_fill, gradient: const LinearGradient(colors: [Color(0xFFFF9966), Color(0xFFFF5E62)]), onTap: () => Navigator.push(context, _premiumPageTransition(const CommercialDashboardPage()))),
      ));
    }
    if (RolePermissions.canSeeTechServiceCard(widget.userRole)) {
      if (cards.isNotEmpty) cards.add(const SizedBox(width: 24));
      cards.add(buildExpandedCard(
        _HoverableServiceCard(title: 'Service Technique', icon: CupertinoIcons.wrench_fill, gradient: const LinearGradient(colors: [Color(0xFF34C759), Color(0xFF009624)]), onTap: () => Navigator.push(context, _premiumPageTransition(ServiceTechniqueDashboardPage(displayName: widget.displayName, userRole: widget.userRole)))),
      ));
    }
    if (RolePermissions.canSeeITServiceCard(widget.userRole)) {
      if (cards.isNotEmpty) cards.add(const SizedBox(width: 24));
      cards.add(buildExpandedCard(
        _HoverableServiceCard(title: 'Service IT', icon: CupertinoIcons.device_laptop, gradient: const LinearGradient(colors: [Color(0xFF32ADE6), Color(0xFF007AFF)]), onTap: () => Navigator.push(context, _premiumPageTransition(ServiceItDashboardPage(displayName: widget.displayName, userRole: widget.userRole)))),
      ));
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cards,
      ),
    );
  }

  List<Widget> _buildMobileCards() {
    final cards = <Widget>[];

    if (RolePermissions.canSeeAdminCard(widget.userRole)) {
      cards.add(_HoverableMobileServiceCard(title: 'Administration', icon: CupertinoIcons.shield_fill, gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]), shadowColor: const Color(0xFF667EEA), onTap: () => Navigator.push(context, _premiumPageTransition(AdministrationDashboardPage(displayName: widget.displayName, userRole: widget.userRole)))));
    }
    if (RolePermissions.canSeeCommercialCard(widget.userRole)) {
      cards.add(_HoverableMobileServiceCard(title: 'Commercial', icon: CupertinoIcons.briefcase_fill, gradient: const LinearGradient(colors: [Color(0xFFFF9966), Color(0xFFFF5E62)]), shadowColor: const Color(0xFFFF9966), onTap: () => Navigator.push(context, _premiumPageTransition(const CommercialDashboardPage()))));
    }
    if (RolePermissions.canSeeTechServiceCard(widget.userRole)) {
      cards.add(_HoverableMobileServiceCard(title: 'Service Technique', icon: CupertinoIcons.wrench_fill, gradient: const LinearGradient(colors: [Color(0xFF34C759), Color(0xFF009624)]), shadowColor: const Color(0xFF34C759), onTap: () => Navigator.push(context, _premiumPageTransition(ServiceTechniqueDashboardPage(displayName: widget.displayName, userRole: widget.userRole)))));
    }
    if (RolePermissions.canSeeITServiceCard(widget.userRole)) {
      cards.add(_HoverableMobileServiceCard(title: 'Service IT', icon: CupertinoIcons.device_laptop, gradient: const LinearGradient(colors: [Color(0xFF32ADE6), Color(0xFF007AFF)]), shadowColor: const Color(0xFF32ADE6), onTap: () => Navigator.push(context, _premiumPageTransition(ServiceItDashboardPage(displayName: widget.displayName, userRole: widget.userRole)))));
    }
    return cards;
  }
}

// ✅ Sounds removed. Haptic physical vibrations kept for premium feel.
class SensoryEngine {
  static void playHover() {
    HapticFeedback.selectionClick();
  }

  static void playClick() {
    HapticFeedback.lightImpact();
  }

  static void playHeavyClick() {
    HapticFeedback.heavyImpact();
  }
}

class _HoverableProfileChip extends StatefulWidget {
  final String displayName;
  final String userRole;

  const _HoverableProfileChip({required this.displayName, required this.userRole});

  @override
  State<_HoverableProfileChip> createState() => _HoverableProfileChipState();
}

class _HoverableProfileChipState extends State<_HoverableProfileChip> {
  bool _isHovered = false;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 12) return 'Bonjour,';
    if (hour >= 12 && hour < 18) return 'Bon après-midi,';
    return 'Bonsoir,';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final photoUrl = currentUser?.photoURL;

    return MouseRegion(
      onEnter: (_) {
        SensoryEngine.playHover();
        setState(() => _isHovered = true);
      },
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0)..translate(0.0, _isHovered ? -3.0 : 0.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withOpacity(_isHovered ? 0.6 : 0.3), width: 1.2),
                boxShadow: _isHovered ? [BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)] : [],
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.05)]),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_getGreeting(), style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7), fontFamily: '.SF Pro Text', letterSpacing: 0.2)),
                      Text(widget.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: '.SF Pro Display', letterSpacing: -0.3)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: Text(widget.userRole.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64D2FF), letterSpacing: 1.0, fontFamily: '.SF Pro Text')),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: photoUrl != null && photoUrl.isNotEmpty
                          ? CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover, placeholder: (context, url) => const CupertinoActivityIndicator(), errorWidget: (context, url, error) => const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 24))
                          : const Icon(CupertinoIcons.person_solid, color: Colors.white, size: 24),
                    ),
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

class _AnimatedGlassIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget? badge;

  const _AnimatedGlassIconButton({required this.icon, required this.tooltip, required this.onPressed, this.badge});

  @override
  State<_AnimatedGlassIconButton> createState() => _AnimatedGlassIconButtonState();
}

class _AnimatedGlassIconButtonState extends State<_AnimatedGlassIconButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final double scale = _isPressed ? 0.92 : (_isHovered ? 1.15 : 1.0);
    final double translateY = _isPressed ? 0.0 : (_isHovered ? -3.0 : 0.0);

    return MouseRegion(
      onEnter: (_) {
        SensoryEngine.playHover();
        setState(() => _isHovered = true);
      },
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) {
          SensoryEngine.playClick();
          setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Tooltip(
          message: widget.tooltip,
          verticalOffset: 30,
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: '.SF Pro Text', fontWeight: FontWeight.bold),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutQuart,
            transform: Matrix4.identity()..scale(scale)..translate(0.0, translateY),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(_isHovered ? 0.3 : 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(_isHovered ? 0.7 : 0.4), width: 1.2),
                    boxShadow: _isHovered ? [BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)] : [],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 22),
                ),
                if (widget.badge != null) Positioned(top: -2, right: -2, child: widget.badge!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverableServiceCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _HoverableServiceCard({required this.title, required this.icon, required this.gradient, required this.onTap});

  @override
  State<_HoverableServiceCard> createState() => _HoverableServiceCardState();
}

class _HoverableServiceCardState extends State<_HoverableServiceCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.98 : (_isHovered ? 1.04 : 1.0);
    final translateY = _isPressed ? 0.0 : (_isHovered ? -8.0 : 0.0);

    return MouseRegion(
      onEnter: (_) {
        SensoryEngine.playHover();
        setState(() => _isHovered = true);
      },
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) {
          SensoryEngine.playClick();
          setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Hero(
          tag: 'hero-${widget.title}',
          flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
            return DefaultTextStyle(
              style: DefaultTextStyle.of(toHeroContext).style,
              child: toHeroContext.widget,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuart,
            transform: Matrix4.identity()..scale(scale)..translate(0.0, translateY),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: widget.gradient.colors.last.withOpacity(_isHovered ? 0.5 : 0.3),
                  blurRadius: _isHovered ? 60 : 40,
                  offset: Offset(0, _isHovered ? 25 : 20),
                  spreadRadius: _isHovered ? 2 : 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(color: Colors.white.withOpacity(_isHovered ? 0.6 : 0.3), width: 1.2),
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.05)]),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: widget.gradient,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: widget.gradient.colors.first.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 15))],
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 56),
                      ),
                      const SizedBox(height: 32),
                      Text(widget.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5, fontFamily: '.SF Pro Display'), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverableMobileServiceCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Gradient gradient;
  final Color shadowColor;
  final VoidCallback onTap;

  const _HoverableMobileServiceCard({required this.title, required this.icon, required this.gradient, required this.shadowColor, required this.onTap});

  @override
  State<_HoverableMobileServiceCard> createState() => _HoverableMobileServiceCardState();
}

class _HoverableMobileServiceCardState extends State<_HoverableMobileServiceCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTapDown: (_) {
          SensoryEngine.playClick();
          setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Hero(
          tag: 'hero-${widget.title}',
          flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
            return DefaultTextStyle(
              style: DefaultTextStyle.of(toHeroContext).style,
              child: toHeroContext.widget,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutQuart,
            transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: widget.shadowColor.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 15))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.2),
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.05)]),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: widget.gradient,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: widget.shadowColor.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))],
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5, fontFamily: '.SF Pro Display'))),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                        child: const Icon(CupertinoIcons.chevron_right, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
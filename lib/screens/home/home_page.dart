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

// ✅ IMPORT THE STORY FILES FROM STEP 1
import 'package:boitex_info_app/models/story_item.dart';
import 'package:boitex_info_app/screens/home/widgets/premium_story_viewer.dart';

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

  // 🚀 REFRESH / MIGRATION SCRIPT: Triggered by pulling down!
  Future<void> _syncOldInterventionsToStories() async {
    SensoryEngine.playHeavyClick();
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('interventions')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterday))
          .get();

      if (snapshot.docs.isEmpty) return; // Exit early if nothing to sync

      // 1. Create a WriteBatch
      final batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        String? logoUrl;

        // Note: It's usually better to denormalize the logoUrl into the intervention
        // document at creation time to avoid this lookup, but this works for now!
        try {
          if (data['clientId'] != null && data['storeId'] != null) {
            final storeDoc = await FirebaseFirestore.instance
                .collection('clients').doc(data['clientId'])
                .collection('stores').doc(data['storeId']).get();
            logoUrl = storeDoc.data()?['logoUrl'];
          }
        } catch (_) {}

        final storeName = data['storeName']?.toString() ?? 'Magasin';
        final location = storeName.contains(' - ')
            ? storeName.split(' - ').last
            : 'Magasin';

        final storyData = {
          'userId': data['createdByUid'] ?? 'unknown',
          'userName': data['createdByName'] ?? 'Technicien',
          'storeName': storeName,
          'storeLogoUrl': logoUrl,
          'location': location,
          'description': data['requestDescription'] ?? 'Intervention',
          'badgeText': data['interventionCode'] ?? 'INFO',
          'mediaUrls': data['mediaUrls'] ?? [],
          'timestamp': data['createdAt'],
          'type': 'intervention',
        };

        // 2. Add to batch instead of saving immediately
        final storyRef = FirebaseFirestore.instance.collection('daily_stories').doc(doc.id);
        batch.set(storyRef, storyData);
        count++;
      }

      // 3. Commit all writes at once!
      await batch.commit();

      if (mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ $count interventions synchronisées.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Migration Error: $e");
    }
  }

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

              // 🚀 NEW: Added the Global Story Feed to the Web Layout!
              // We add some dynamic padding so it aligns nicely with the web cards.
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: 40, // Space below the top header
                        left: math.min((width - 1200) / 2, width * 0.05),
                        right: math.min((width - 1200) / 2, width * 0.05),
                      ),
                      child: const GlobalStoryFeed(),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      // Reduced the top vertical padding from 60 to 20 because the story feed is above it now
                      padding: EdgeInsets.symmetric(horizontal: math.min((width - 1200) / 2, width * 0.05), vertical: 20),
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
          // 🚀 HERE IS THE PULL-TO-REFRESH WRAPPER!
          child: RefreshIndicator(
            onRefresh: _syncOldInterventionsToStories,
            color: const Color(0xFF667EEA),
            backgroundColor: Colors.white,
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

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 24, bottom: 8),
                    child: GlobalStoryFeed(),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
                  sliver: SliverList(delegate: SliverChildListDelegate(_buildMobileCards())),
                ),
              ],
            ),
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

  String _getSmartRole(String role) {
    final normalizedRole = role.trim().toUpperCase();
    switch (normalizedRole) {
      case 'RESPONSABLE ADMINISTRATIF': return 'RESP. ADMIN';
      case 'RESPONSABLE COMMERCIAL': return 'RESP. COM';
      case 'RESPONSABLE TECHNIQUE': return 'RESP. TECH';
      case 'RESPONSABLE IT': return 'RESP. IT';
      case 'CHEF DE PROJET': return 'CHEF PROJET';
      case 'TECHNICIEN ST': return 'TECH ST';
      case 'TECHNICIEN IT': return 'TECH IT';
      case 'ADMIN': return 'ADMIN';
      case 'PDG': return 'PDG';
      default:
        if (role.length > 14) return '${role.substring(0, 12).toUpperCase()}...';
        return role.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(widget.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: '.SF Pro Display', letterSpacing: -0.3)),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 140),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: Text(_getSmartRole(widget.userRole), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64D2FF), letterSpacing: 1.0, fontFamily: '.SF Pro Text')),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  _AnimatedStoryAvatar(displayName: widget.displayName),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🌟 STEP 2: THE INSTAGRAM-STYLE STORY AVATAR RING (CURRENT USER)
// ============================================================================
class _AnimatedStoryAvatar extends StatefulWidget {
  final String displayName;
  const _AnimatedStoryAvatar({required this.displayName});

  @override
  State<_AnimatedStoryAvatar> createState() => _AnimatedStoryAvatarState();
}

class _AnimatedStoryAvatarState extends State<_AnimatedStoryAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _openStories(BuildContext context, List<StoryItem> stories) {
    SensoryEngine.playHeavyClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return PremiumStoryViewer(stories: stories);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final photoUrl = currentUser?.photoURL;
    if (currentUser == null) return _buildStaticAvatar(photoUrl);

    final yesterday = DateTime.now().subtract(const Duration(hours: 24));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('daily_stories')
          .where('userId', isEqualTo: currentUser.uid)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterday))
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildStaticAvatar(photoUrl);
        }

        final stories = snapshot.data!.docs.map((doc) => StoryItem.fromFirestore(doc)).toList();

        // 🚀 NEW: Check if the user themselves has unseen stories
        bool hasUnseen = false;
        if (currentUser != null) {
          hasUnseen = stories.any((s) => !s.viewedBy.contains(currentUser.uid));
        }

        return GestureDetector(
          onTap: () => _openStories(context, stories),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 🚀 Conditional Glow
              if (hasUnseen)
                RotationTransition(
                  turns: _spinController,
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFFFEDA75), Color(0xFFFA7E1E), Color(0xFFD62976),
                          Color(0xFF962FBF), Color(0xFF4F5BD5), Color(0xFFFEDA75),
                        ],
                      ),
                    ),
                  ),
                )
              else
              // 🚀 Static Grey Ring if all stories are viewed
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2.0),
                  ),
                ),
              // White spacing ring
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                    color: hasUnseen ? Colors.white : Colors.transparent,
                    shape: BoxShape.circle
                ),
              ),
              // Profile Picture
              Container(
                height: 38,
                width: 38,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1E1E1E)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover)
                      : Center(
                    child: Text(
                      widget.displayName.isNotEmpty ? widget.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStaticAvatar(String? photoUrl) {
    return Container(
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
            ? CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover)
            : Center(
          child: Text(
            widget.displayName.isNotEmpty ? widget.displayName[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      ),
    );
  }
}

class StoryPageViewer extends StatelessWidget {
  final List<StoryItem> stories;

  const StoryPageViewer({super.key, required this.stories});

  @override
  Widget build(BuildContext context) {
    final PageController pageController = PageController();

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: pageController,
        itemCount: stories.length,
        itemBuilder: (context, index) {

        },
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

// ============================================================================
// 🌟 THE INSTAGRAM-STYLE GLOBAL STORY FEED
// ============================================================================
class GlobalStoryFeed extends StatelessWidget {
  const GlobalStoryFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('daily_stories')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterday))
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent),
            ),
            child: Text("🚨 Erreur Firebase: ${snapshot.error}", style: const TextStyle(color: Colors.white, fontSize: 12)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final Map<String, List<StoryItem>> groupedStories = {};
        for (var doc in snapshot.data!.docs) {
          final story = StoryItem.fromFirestore(doc);
          if (!groupedStories.containsKey(story.userId)) {
            groupedStories[story.userId] = [];
          }
          groupedStories[story.userId]!.add(story);
        }

        List<String> uniqueUsers = groupedStories.keys.toList();

        if (currentUser != null && uniqueUsers.contains(currentUser.uid)) {
          uniqueUsers.remove(currentUser.uid);
          uniqueUsers.insert(0, currentUser.uid);
        }

        return SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: uniqueUsers.length,
            itemBuilder: (context, index) {
              final userId = uniqueUsers[index];
              final userStories = groupedStories[userId]!;
              final userName = userStories.first.userName;
              final bool isMe = currentUser != null && userId == currentUser.uid;

              // 🚀 NEW: Check if there are any unseen stories for this user
              bool hasUnseen = false;
              if (currentUser != null) {
                hasUnseen = userStories.any((s) => !s.viewedBy.contains(currentUser.uid));
              }

              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: _GlobalStoryAvatarRing(
                  userName: userName,
                  stories: userStories,
                  isMe: isMe,
                  photoUrl: isMe ? currentUser.photoURL : null,
                  hasUnseen: hasUnseen, // 🚀 Pass the variable down
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _GlobalStoryAvatarRing extends StatefulWidget {
  final String userName;
  final List<StoryItem> stories;
  final bool isMe;
  final String? photoUrl;
  final bool hasUnseen; // 🚀 NEW PROPERTY

  const _GlobalStoryAvatarRing({
    required this.userName,
    required this.stories,
    required this.isMe,
    this.photoUrl,
    this.hasUnseen = false, // 🚀 Default to false
  });

  @override
  State<_GlobalStoryAvatarRing> createState() => _GlobalStoryAvatarRingState();
}

class _GlobalStoryAvatarRingState extends State<_GlobalStoryAvatarRing> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _openUserStories() {
    SensoryEngine.playHeavyClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          // ✅ USE THE NEW PREMIUM VIEWER
          return PremiumStoryViewer(stories: widget.stories);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [Colors.blueAccent, Colors.purpleAccent, Colors.teal, Colors.orangeAccent, Colors.pinkAccent];
    return colors[name.length % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final String displayTitle = widget.isMe ? "Vous" : widget.userName.split(' ').first;

    return GestureDetector(
      onTap: _openUserStories,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // 🚀 Show the spin ONLY if there are unseen stories
              if (widget.hasUnseen)
                RotationTransition(
                  turns: _spinController,
                  child: Container(
                    height: 64,
                    width: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFFFEDA75), Color(0xFFFA7E1E), Color(0xFFD62976),
                          Color(0xFF962FBF), Color(0xFF4F5BD5), Color(0xFFFEDA75),
                        ],
                      ),
                    ),
                  ),
                )
              else
              // 🚀 If all viewed, show a clean, static grey ring
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2.5),
                  ),
                ),
              // White cutout ring
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                    color: widget.hasUnseen ? Colors.white : Colors.transparent, // Only solid white if glowing
                    shape: BoxShape.circle
                ),
              ),
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.photoUrl == null ? _getAvatarColor(widget.userName) : Colors.black,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: widget.photoUrl!, fit: BoxFit.cover)
                      : Center(
                    child: Text(
                      widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 70,
            child: Text(
              displayTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: widget.isMe ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: widget.isMe ? FontWeight.bold : FontWeight.w600,
                  fontFamily: '.SF Pro Text'
              ),
            ),
          )
        ],
      ),
    );
  }
}
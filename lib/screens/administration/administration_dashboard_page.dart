// lib/screens/administration/administration_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ✅ ADDED: For ImageFilter.blur (Glassmorphism)
import 'dart:ui';
// ✅ ADDED: For premium 4K fonts
import 'package:google_fonts/google_fonts.dart';
// ✅ ADDED: To detect Web platform easily if needed
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async'; // Needed for the Timer
// SCREEN IMPORTS
import 'package:boitex_info_app/screens/administration/manage_clients_page.dart';
import 'package:boitex_info_app/screens/administration/add_project_page.dart';
import 'package:boitex_info_app/screens/administration/manage_projects_page.dart';
import 'package:boitex_info_app/screens/administration/product_catalog_page.dart';
import 'package:boitex_info_app/screens/administration/stock_page.dart';
import 'package:boitex_info_app/screens/administration/manage_missions_page.dart';
import 'package:boitex_info_app/screens/administration/purchasing_hub_page.dart';
import 'package:boitex_info_app/screens/administration/billing_hub_page.dart';
import 'package:boitex_info_app/screens/administration/activity_log_page.dart';
import 'package:boitex_info_app/screens/administration/livraisons_hub_page.dart';
import 'package:boitex_info_app/screens/administration/rappel_page.dart';
import 'package:boitex_info_app/screens/announce/announce_hub_page.dart';
import 'package:boitex_info_app/screens/administration/analytics_dashboard_page.dart';
import 'package:boitex_info_app/screens/administration/universal_map_page.dart';
import 'package:boitex_info_app/screens/administration/portal_requests_list_page.dart';
import 'package:boitex_info_app/screens/administration/reporting_hub_page.dart';

class AdministrationDashboardPage extends StatefulWidget {
  final String displayName;
  final String userRole;

  const AdministrationDashboardPage({
    super.key,
    required this.displayName,
    required this.userRole,
  });

  @override
  State<AdministrationDashboardPage> createState() =>
      _AdministrationDashboardPageState();
}

class _AdministrationDashboardPageState
    extends State<AdministrationDashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ✅ STATE: For Adaptive Background
  late Timer _timeTimer;
  late DateTime _currentTime;

  // ✅ STATE: The Ordered List of Action IDs
  List<String> _orderedIds = [];
  bool _isLoadingPrefs = true;
  bool _isDragging = false; // To control UI during drag

  @override
  void initState() {
    super.initState();

    // Initialize Time Tracker
    _currentTime = DateTime.now();
    _timeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });

    // Animations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        );
    _controller.forward();

    // Load Data
    _loadUserLayout();
  }

  // ✅ ADAPTIVE COLOR LOGIC
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

  // 🔄 LOAD LAYOUT FROM FIRESTORE
  Future<void> _loadUserLayout() async {
    final user = FirebaseAuth.instance.currentUser;
    // Default Order (Fallback)
    final defaultOrder = _getAllActionsMap(context).keys.toList();

    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists &&
            doc.data() != null &&
            doc.data()!.containsKey('dashboard_layout')) {
          final savedList = List<String>.from(doc.data()!['dashboard_layout']);

          // Merge logic: Add new features that might not be in the saved list
          final Set<String> savedSet = savedList.toSet();
          final missingItems = defaultOrder.where((id) => !savedSet.contains(id));

          setState(() {
            _orderedIds = [...savedList, ...missingItems];
            _isLoadingPrefs = false;
          });
        } else {
          setState(() {
            _orderedIds = defaultOrder;
            _isLoadingPrefs = false;
          });
        }
      } catch (e) {
        debugPrint("⚠️ Error loading layout: $e");
        setState(() {
          _orderedIds = defaultOrder;
          _isLoadingPrefs = false;
        });
      }
    }
  }

  // 💾 SAVE LAYOUT TO FIRESTORE
  Future<void> _saveUserLayout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'dashboard_layout': _orderedIds
      }, SetOptions(merge: true));
    }
  }

  // 🔀 REORDER LOGIC (The Swap)
  void _onReorder(String draggedId, String targetId) {
    if (draggedId == targetId) return;

    final oldIndex = _orderedIds.indexOf(draggedId);
    final newIndex = _orderedIds.indexOf(targetId);

    if (oldIndex != -1 && newIndex != -1) {
      setState(() {
        final item = _orderedIds.removeAt(oldIndex);
        _orderedIds.insert(newIndex, item);
      });
      HapticFeedback.selectionClick(); // Tactile feel when items swap
    }
  }

  @override
  void dispose() {
    _timeTimer.cancel(); // Don't forget to cancel the timer!
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final isWeb = width > 900;

      return Scaffold(
        // ✅ CHANGED: Container is now AnimatedContainer
        body: AnimatedContainer(
          duration: const Duration(seconds: 4),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              // ✅ CHANGED: Now using our dynamic color function
              colors: _getTimeBasedGradientColors(),
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                isWeb ? _buildWebHeader() : _buildMobileHeader(),
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWeb ? (width > 1200 ? (width - 1200) / 2 : width * 0.05) : 0,
                        ),
                        child: isWeb
                            ? _buildWebLayout(context, width)
                            : _buildMobileLayout(context, width),
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
    });
  }

  // ================= LAYOUTS =================

  Widget _buildWebLayout(BuildContext context, double width) {
    // ✅ REMOVED: Row and Urgent Tasks column. Grid now takes full width gracefully.
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(),
          const SizedBox(height: 24),
          _buildDraggableGrid(context, width),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(),
              const SizedBox(height: 20),
              _buildDraggableGrid(context, width),
            ],
          ),
        ),
        // ✅ REMOVED: Tâches Urgentes padding and column
      ],
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Text(
          'APPS',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        // Edit Mode Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.touch_app_rounded,
                  color: Colors.white.withOpacity(0.8), size: 14),
              const SizedBox(width: 6),
              Text(
                "Maintenir pour ranger",
                style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9), fontSize: 12),
              ),
            ],
          ),
        )
      ],
    );
  }

  // ================= DRAG & DROP GRID ENGINE =================

  Widget _buildDraggableGrid(BuildContext context, double width) {
    if (_isLoadingPrefs) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final allActions = _getAllActionsMap(context);
    final displayList = _orderedIds
        .map((id) => allActions[id])
        .whereType<_ActionData>()
        .toList();

    // ✅ ADAPTIVE GRID SIZING (Updated to accommodate full width without urgent tasks)
    int crossAxisCount = 2;
    double childAspectRatio = 0.78; // Mobile Default

    if (width > 1200) {
      crossAxisCount = 5; // Takes full width perfectly
      childAspectRatio = 1.1;
    } else if (width > 900) {
      crossAxisCount = 4;
      childAspectRatio = 1.0;
    } else if (width > 600) {
      crossAxisCount = 3;
      childAspectRatio = 0.95; // Tablets
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final action = displayList[index];
        return _buildDraggableItem(action, width);
      },
    );
  }

  Widget _buildDraggableItem(_ActionData action, double width) {
    final bool isWide = width > 900;

    return LongPressDraggable<String>(
      data: action.id,
      feedback: Transform.scale(
        scale: 1.1,
        child: SizedBox(
          width: isWide ? 160 : 130, // Approximate width for feedback
          height: isWide ? 150 : 160,
          child: _ActionCard(action: action, isDragging: true, isWide: isWide),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _ActionCard(action: action, isWide: isWide),
      ),
      onDragStarted: () {
        HapticFeedback.lightImpact();
        setState(() => _isDragging = true);
      },
      onDragEnd: (details) {
        setState(() => _isDragging = false);
        _saveUserLayout(); // Save on drop
      },
      child: DragTarget<String>(
        onWillAccept: (incomingId) {
          if (incomingId != null && incomingId != action.id) {
            _onReorder(incomingId, action.id);
            return true;
          }
          return false;
        },
        onAccept: (data) {}, // Handled in onWillAccept for fluid feel
        builder: (context, candidateData, rejectedData) {
          return TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            tween: Tween(begin: 0, end: 1),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 1.0,
                child: child,
              );
            },
            child: _ActionCard(
              action: action,
              badgeStream: action.badgeStream,
              isWide: isWide,
            ),
          );
        },
      ),
    );
  }

  // ================= HEADERS =================

  Widget _buildMobileHeader() {
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
              child: _buildProfileChip(),
            ),
            const SizedBox(width: 12),
            _glassIconButton(
              icon: Icons.notifications_rounded,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RappelPage())),
            ),
            const SizedBox(width: 12),
            _glassIconButton(
              icon: Icons.campaign_rounded,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AnnounceHubPage())),
            ),
          ],
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _buildProfileChip(),
            ),
            const Spacer(),
            _glassIconButton(
              icon: Icons.notifications_rounded,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RappelPage())),
            ),
            const SizedBox(width: 12),
            _glassIconButton(
              icon: Icons.campaign_rounded,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AnnounceHubPage())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileChip() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.25),
              Colors.white.withOpacity(0.15)
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
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
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
            ),
            Flexible(
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassIconButton(
      {required IconData icon, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
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

  // ✅ ACTION MAP
  Map<String, _ActionData> _getAllActionsMap(BuildContext context) {
    return {
      'facturation': _ActionData(
        id: 'facturation',
        label: 'Facturation',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF0D9488), // Premium Teal color
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BillingHubPage()),
        ),
        badgeStream: FirebaseFirestore.instance
            .collection('interventions')
            .where('status', isEqualTo: "Terminé")
            .snapshots(),
      ),
      'achats': _ActionData(
        id: 'achats',
        label: 'Achats',
        icon: Icons.shopping_bag_rounded,
        color: const Color(0xFF8E24AA),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    PurchasingHubPage(userRole: widget.userRole))),
        badgeStream: FirebaseFirestore.instance
            .collection('requisitions')
            .where('status', isEqualTo: "En attente d'approbation")
            .snapshots(),
      ),
      'web_requests': _ActionData(
        id: 'web_requests',
        label: 'Demandes\nWeb',
        icon: Icons.public_rounded,
        color: const Color(0xFFFF5722),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PortalRequestsListPage())),
        badgeStream: FirebaseFirestore.instance
            .collection('interventions')
            .where('interventionCode', isEqualTo: 'PENDING')
            .snapshots(),
      ),
      'new_project': _ActionData(
        id: 'new_project',
        label: 'Nouveau\nProjet',
        icon: Icons.note_add_rounded,
        color: const Color(0xFF10B981),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddProjectPage())),
      ),
      'clients': _ActionData(
        id: 'clients',
        label: 'Clients',
        icon: Icons.store_rounded,
        color: const Color(0xFF3B82F6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ManageClientsPage(userRole: widget.userRole)),
        ),
      ),
      'projects': _ActionData(
        id: 'projects',
        label: 'Projets',
        icon: Icons.folder_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ManageProjectsPage(userRole: widget.userRole)),
        ),
      ),
      'products': _ActionData(
        id: 'products',
        label: 'Produits',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF14B8A6),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProductCatalogPage())),
      ),
      'stock': _ActionData(
        id: 'stock',
        label: 'Stock',
        icon: Icons.warehouse_rounded,
        color: const Color(0xFF6366F1),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const StockPage())),
      ),
      'missions': _ActionData(
        id: 'missions',
        label: 'Missions',
        icon: Icons.assignment_rounded,
        color: const Color(0xFFA855F7),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ManageMissionsPage())),
      ),
      'livraisons': _ActionData(
        id: 'livraisons',
        label: 'Livraisons',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFFF59E0B),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LivraisonsHubPage())),
      ),
      'reporting': _ActionData(
        id: 'reporting',
        label: "Centre\nd'Édition",
        icon: Icons.print_rounded,
        color: const Color(0xFF546E7A),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ReportingHubPage())),
      ),
      'history': _ActionData(
        id: 'history',
        label: 'Historique',
        icon: Icons.history_rounded,
        color: const Color(0xFF78716C),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ActivityLogPage(userRole: widget.userRole)),
        ),
      ),
      'analytics': _ActionData(
        id: 'analytics',
        label: 'Analytics',
        icon: Icons.analytics_rounded,
        color: const Color(0xFFEC4899),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AnalyticsDashboardPage())),
      ),
      'map': _ActionData(
        id: 'map',
        label: 'Carte',
        icon: Icons.map_rounded,
        color: const Color(0xFF0284C7),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UniversalMapPage()),
        ),
      ),
    };
  }
}

// ========================= ACTION CARD =========================

class _ActionData {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Stream<QuerySnapshot>? badgeStream;

  _ActionData({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeStream,
  });
}

// ✅ APPLE IOS 26 PREMIUM GLASS APP CARDS
class _ActionCard extends StatelessWidget {
  final _ActionData action;
  final Stream<QuerySnapshot>? badgeStream;
  final bool isDragging;
  final bool isWide;

  const _ActionCard({
    required this.action,
    this.badgeStream,
    this.isDragging = false,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: action.color.withOpacity(isDragging ? 0.3 : 0.15),
                blurRadius: isDragging ? 40 : 30,
                offset: Offset(0, isDragging ? 20 : 15),
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
                      Colors.white.withOpacity(isDragging ? 0.35 : 0.25),
                      Colors.white.withOpacity(isDragging ? 0.15 : 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isDragging
                        ? Colors.amber.withOpacity(0.8) // Highlight on drag
                        : Colors.white.withOpacity(0.4),
                    width: isDragging ? 2.0 : 1.2,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: action.onTap,
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
                                  action.color.withOpacity(0.9),
                                  action.color.withOpacity(0.6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: action.color.withOpacity(0.5),
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
                            child: Icon(action.icon,
                                color: Colors.white, size: isWide ? 38 : 28),
                          ),
                          SizedBox(height: isWide ? 14 : 8),
                          Container(
                            height: isWide ? 50.0 : 40.0,
                            alignment: Alignment.center,
                            child: Text(
                              action.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: isWide ? 15 : 12,
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
        if (badgeStream != null)
          StreamBuilder<QuerySnapshot>(
            stream: badgeStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox();
              }
              final count = snapshot.data!.docs.length;
              return Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      count > 99 ? '99+' : count.toString(),
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
              );
            },
          ),
      ],
    );
  }
}
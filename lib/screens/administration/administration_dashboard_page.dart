// lib/screens/administration/administration_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// SCREEN IMPORTS
import 'package:boitex_info_app/screens/administration/manage_clients_page.dart';
import 'package:boitex_info_app/screens/administration/add_project_page.dart';
import 'package:boitex_info_app/screens/administration/manage_projects_page.dart';
import 'package:boitex_info_app/screens/administration/product_catalog_page.dart';
import 'package:boitex_info_app/screens/administration/stock_page.dart';
import 'package:boitex_info_app/screens/administration/manage_missions_page.dart';
import 'package:boitex_info_app/screens/administration/replacement_requests_hub_page.dart';
import 'package:boitex_info_app/screens/administration/requisition_approval_page.dart';
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

import 'dart:math' as math;

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

  // ✅ STATE: The Ordered List of Action IDs
  List<String> _orderedIds = [];
  bool _isLoadingPrefs = true;
  bool _isDragging = false; // To control UI during drag

  @override
  void initState() {
    super.initState();
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final isWeb = width > 900;

      final canSeeMgmt = <String>{
        'PDG',
        'Admin',
        'Responsable Administratif',
        'Responsable Commercial',
        'Responsable Technique',
        'Responsable IT',
        'Chef de Projet',
      }.contains(widget.userRole);

      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFFF093FB)],
              stops: [0.0, 0.5, 1.0],
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
                          horizontal: isWeb ? math.min((width - 1400) / 2, width * 0.1) : 0,
                        ),
                        child: isWeb
                            ? _buildWebLayout(context, canSeeMgmt)
                            : _buildMobileLayout(context, canSeeMgmt),
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

  Widget _buildWebLayout(BuildContext context, bool canSeeMgmt) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Draggable Grid
        Expanded(
          flex: 3,
          child: _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(),
                const SizedBox(height: 24),
                _buildDraggableGrid(context, crossAxisCount: 4),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Right: Urgent Tasks
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tâches Urgentes',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              _buildUrgentTasksColumn(canSeeMgmt),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool canSeeMgmt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(),
              const SizedBox(height: 20),
              _buildDraggableGrid(context, crossAxisCount: 2),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Text(
            'Tâches Urgentes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildUrgentTasksColumn(canSeeMgmt),
      ],
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        const Text(
          'APPS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
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
                "Maintenez pour réorganiser",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9), fontSize: 12),
              ),
            ],
          ),
        )
      ],
    );
  }

  // ================= DRAG & DROP GRID ENGINE =================

  Widget _buildDraggableGrid(BuildContext context, {required int crossAxisCount}) {
    if (_isLoadingPrefs) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final allActions = _getAllActionsMap(context);
    final displayList = _orderedIds
        .map((id) => allActions[id])
        .whereType<_ActionData>()
        .toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: crossAxisCount == 4 ? 1.0 : 0.90,
      ),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final action = displayList[index];
        return _buildDraggableItem(action);
      },
    );
  }

  Widget _buildDraggableItem(_ActionData action) {
    return LongPressDraggable<String>(
      data: action.id,
      feedback: Transform.scale(
        scale: 1.1,
        child: SizedBox(
          width: 140, // Approximate width for feedback
          height: 140,
          child: _ActionCard(action: action, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _ActionCard(action: action),
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
                scale: 1.0, // Could animate scale on hover
                child: child,
              );
            },
            child: _ActionCard(
              action: action,
              badgeStream: action.badgeStream,
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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

  Widget _buildUrgentTasksColumn(bool canSeeMgmt) {
    final cards = <Widget>[
      const _ReplacementRequestsCard(),
      if (canSeeMgmt) const _PendingBillingCard(),
      if (canSeeMgmt) const _PendingReplacementsCard(),
      if (canSeeMgmt) const _LivraisonsCard(),
    ];

    return Column(
      children: cards.asMap().entries.map((entry) {
        final index = entry.key;
        final card = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: card,
        );
      }).toList(),
    );
  }

  // ✅ ACTION MAP
  Map<String, _ActionData> _getAllActionsMap(BuildContext context) {
    return {
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

class _ActionCard extends StatelessWidget {
  final _ActionData action;
  final Stream<QuerySnapshot>? badgeStream;
  final bool isDragging;

  const _ActionCard({
    required this.action,
    this.badgeStream,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(isDragging ? 0.35 : 0.25),
                Colors.white.withOpacity(isDragging ? 0.25 : 0.15)
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDragging
                  ? Colors.amber.withOpacity(0.8) // Highlight when dragging
                  : Colors.white.withOpacity(0.3),
              width: isDragging ? 2.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: isDragging ? 30 : 20,
                  offset: isDragging ? const Offset(0, 15) : const Offset(0, 10)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: action.onTap,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          action.color,
                          action.color.withOpacity(0.7)
                        ]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: action.color.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Icon(action.icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      action.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
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
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

// ======= STAT CARDS (same as before) =======

class _ReplacementRequestsCard extends StatelessWidget {
  const _ReplacementRequestsCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('replacementRequests')
          .where('requestStatus', isEqualTo: "En attente d'action")
          .snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildGlowingCard(
          context: context,
          title: 'Demandes de Remplacement',
          count: count.toString(),
          icon: Icons.sync_problem_rounded,
          gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ReplacementRequestsHubPage(
                pageTitle: 'Demandes en Attente',
                filterStatus: "En attente d'action",
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PendingBillingCard extends StatelessWidget {
  const _PendingBillingCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('interventions')
          .where('status', isEqualTo: "Terminé")
          .snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildGlowingCard(
          context: context,
          title: 'Facturation en Attente',
          count: count.toString(),
          icon: Icons.receipt_long_rounded,
          gradient: const LinearGradient(
              colors: [Color(0xFF14B8A6), Color(0xFF0D9488)]),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BillingHubPage())),
        );
      },
    );
  }
}

class _PendingReplacementsCard extends StatelessWidget {
  const _PendingReplacementsCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('replacementRequests')
          .where('requestStatus', isEqualTo: "Approuvé - Produit en stock")
          .snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildGlowingCard(
          context: context,
          title: 'Remplacements à Préparer',
          count: count.toString(),
          icon: Icons.inventory_rounded,
          gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ReplacementRequestsHubPage(
                pageTitle: 'Remplacements à Préparer',
                filterStatus: "Approuvé - Produit en stock",
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LivraisonsCard extends StatelessWidget {
  const _LivraisonsCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('livraisons')
          .where('status',
          whereIn: const ["À Préparer", "En Cours de Livraison"])
          .snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildGlowingCard(
          context: context,
          title: 'Livraisons Actives',
          count: count.toString(),
          icon: Icons.local_shipping_rounded,
          gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LivraisonsHubPage())),
        );
      },
    );
  }
}

// Shared glowing stat card
Widget _buildGlowingCard({
  required BuildContext context,
  required String title,
  required String count,
  required IconData icon,
  required Gradient gradient,
  VoidCallback? onTap,
  Widget? customBody,
}) {
  final isWeb = MediaQuery.of(context).size.width > 900;

  return Container(
    margin:
    isWeb ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ]),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15)),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: gradient.colors.first.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: Colors.white.withOpacity(0.9)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              customBody ??
                  ShaderMask(
                    shaderCallback: (bounds) => gradient.createShader(bounds),
                    child: Text(
                      count,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    ),
  );
}
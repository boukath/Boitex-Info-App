// lib/screens/administration/administration_dashboard_page.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

class _AdministrationDashboardPageState extends State<AdministrationDashboardPage>
    with TickerProviderStateMixin { // <-- Ensure TickerProviderStateMixin
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String? _currentUserId;
  TabController? _pendingActionsTabController; // <-- Added for tabs
  int _selectedPendingActionTab = 0; // <-- Added for tabs

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // --- Initialize TabController ---
    _pendingActionsTabController = TabController(length: 3, vsync: this);
    _pendingActionsTabController!.addListener(() {
      // Check if the controller index is actually changing to avoid unnecessary rebuilds
      if (!_pendingActionsTabController!.indexIsChanging &&
          _pendingActionsTabController!.index != _selectedPendingActionTab) {
        setState(() {
          _selectedPendingActionTab = _pendingActionsTabController!.index;
        });
      }
    });
    // --- END ---
  }

  @override
  void dispose() {
    _controller.dispose();
    _pendingActionsTabController?.dispose(); // <-- Dispose TabController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;

      final canSeeMgmt = <String>{
        'PDG',
        'Admin',
        'Responsable Administratif',
        'Responsable Commercial',
        'Responsable Technique',
        'Responsable IT',
        'Chef de Projet',
      }.contains(widget.userRole);

      if (width > 900) {
        return _buildWebDashboard(context, canSeeMgmt, width);
      } else {
        return _buildMobileDashboard(context, canSeeMgmt);
      }
    });
  }

  // ========================= WEB =========================

  Widget _buildWebDashboard(
      BuildContext context, bool canSeeMgmt, double width) {
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
              _buildWebHeader(),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: math.min((width - 1400) / 2, width * 0.1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT COLUMN - Actions Grid, Pending, Recent
                          Expanded(
                            flex: 3,
                            child: _buildGlassCard(
                                child: _buildWebActionsGrid(context)),
                          ),
                          const SizedBox(width: 24),
                          // RIGHT COLUMN - Urgent Tasks
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
                                _buildWebUrgentTasksColumn(canSeeMgmt),
                              ],
                            ),
                          ),
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
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
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
              icon: Icons.notifications_rounded,
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const RappelPage())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassIconButton({required IconData icon, required VoidCallback onTap}) {
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

  Widget _buildWebActionsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Actions Rapides Grid ---
        const Text(
          'Actions Rapides',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 1.0,
          children: _buildQuickActions(context),
        ),

        // --- Actions en Attente (Tabs) ---
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'Actions en Attente', // Updated Title
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildPendingActionsFeed(), // Contains Tabs

        // --- Activité Récente ---
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'Activité Récente',
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildRecentActivityFeed(),
      ],
    );
  }

  Widget _buildWebUrgentTasksColumn(bool canSeeMgmt) {
    final cards = <Widget>[
      const _ReplacementRequestsCard(),
      if (canSeeMgmt) _RequisitionPipelineCard(userRole: widget.userRole),
      if (canSeeMgmt) const _PendingBillingCard(),
      if (canSeeMgmt) const _PendingReplacementsCard(),
      if (canSeeMgmt) const _LivraisonsCard(),
    ];

    return Column(
      children: cards.asMap().entries.map((entry) {
        final index = entry.key;
        final card = entry.value;
        return Padding( // Add padding between urgent task cards
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 600 + (index * 100)),
            tween: Tween(begin: 0, end: 1),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: card,
          ),
        );
      }).toList(),
    );
  }

  // ========================= MOBILE =========================
  // (Mobile section remains largely the same, just ensure it includes the new sections if needed)

  Widget _buildMobileDashboard(BuildContext context, bool canSeeMgmt) {
    // Note: The new tabbed list might be too complex/wide for mobile.
    // Consider showing a simplified version or just the recent activity here.
    // For now, let's keep it structurally similar to web, but it might need refinement.
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
              _buildUltraCompactHeader(),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGlassCard(child: _buildActionsGrid(context)), // Quick Actions

                        // --- Mobile Pending Actions (Simplified - maybe just counts or first few items?) ---
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Text(
                            'Actions en Attente',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 20, // Mobile size
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildGlassCard(child: _buildPendingActionsFeed()), // Use the same tabbed view for now

                        // --- Mobile Recent Activity ---
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Text(
                            'Activité Récente',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 20, // Mobile size
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildGlassCard(child: _buildRecentActivityFeed()),


                        const SizedBox(height: 24),
                        _buildUrgentTasksSection(canSeeMgmt), // Urgent Tasks (Cards)
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
                        Expanded(
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
                ),
              ),
            ),
            const SizedBox(width: 12),
            _glassIconButton(
              icon: Icons.notifications_rounded,
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const RappelPage())),
            ),
          ],
        ),
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
          colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
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

  Widget _buildActionsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions Rapides',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.90,
          children: _buildQuickActions(context),
        ),
      ],
    );
  }

  List<Widget> _buildQuickActions(BuildContext context) {
    final items = <_ActionData>[
      _ActionData(
        'Nouveau\nProjet', Icons.note_add_rounded, const Color(0xFF10B981),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProjectPage())),
      ),
      _ActionData(
        'Clients', Icons.store_rounded, const Color(0xFF3B82F6),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageClientsPage(userRole: widget.userRole))),
      ),
      _ActionData(
        'Projets', Icons.folder_rounded, const Color(0xFF8B5CF6),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageProjectsPage(userRole: widget.userRole))),
      ),
      _ActionData(
        'Produits', Icons.inventory_2_rounded, const Color(0xFF14B8A6),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductCatalogPage())),
      ),
      _ActionData(
        'Stock', Icons.warehouse_rounded, const Color(0xFF6366F1),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockPage())),
      ),
      _ActionData(
        'Missions', Icons.assignment_rounded, const Color(0xFFA855F7),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageMissionsPage())),
      ),
      _ActionData(
        'Livraisons', Icons.local_shipping_rounded, const Color(0xFFF59E0B),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LivraisonsHubPage())),
      ),
      _ActionData(
        'Historique', Icons.history_rounded, const Color(0xFF78716C),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityLogPage(userRole: widget.userRole))),
      ),
    ];

    return items.asMap().entries.map((entry) {
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
        ),
      );
    }).toList();
  }

  Widget _buildUrgentTasksSection(bool canSeeMgmt) {
    final cards = <Widget>[
      const _ReplacementRequestsCard(),
      if (canSeeMgmt) _RequisitionPipelineCard(userRole: widget.userRole),
      if (canSeeMgmt) const _PendingBillingCard(),
      if (canSeeMgmt) const _PendingReplacementsCard(),
      if (canSeeMgmt) const _LivraisonsCard(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
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
        Column(
          children: cards.asMap().entries.map((entry) {
            final index = entry.key;
            final card = entry.value;
            return Padding( // Added padding for mobile urgent tasks
              padding: const EdgeInsets.only(bottom: 16),
              child: TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 600 + (index * 100)),
                tween: Tween(begin: 0, end: 1),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: card,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ========================================================
  // =============== NEW & UPDATED HELPER METHODS ===============
  // ========================================================

  // --- Pending Actions Feed (with Tabs) ---
  Widget _buildPendingActionsFeed() {
    return Column(
      children: [
        Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(25.0),
          ),
          child: TabBar(
            controller: _pendingActionsTabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(25.0),
              color: Colors.white.withOpacity(0.3),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
            tabs: const [
              Tab(text: 'Interventions'),
              Tab(text: 'SAV'),
              Tab(text: 'Missions'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Container(
            key: ValueKey<int>(_selectedPendingActionTab),
            child: _buildSelectedPendingList(),
          ),
        ),
      ],
    );
  }

  // --- Helper to build the correct list based on selected tab ---
  Widget _buildSelectedPendingList() {
    switch (_selectedPendingActionTab) {
      case 0: // Interventions
        return _buildGeneralTaskStream(
          key: const ValueKey('interventions'),
          collection: 'interventions',
          icon: Icons.handyman_rounded,
          statusField: 'status',
          pendingStatus: 'Nouveau',
          titleField: 'interventionCode',
          subtitleField: 'clientName',
        );
      case 1: // SAV
        return _buildGeneralTaskStream(
          key: const ValueKey('sav'),
          collection: 'sav_tickets',
          icon: Icons.support_agent_rounded,
          statusField: 'status',
          pendingStatus: 'Irréparable - Remplacement Demandé',
          titleField: 'savCode',
          subtitleField: 'clientName',
        );
      case 2: // Missions
        return _buildGeneralTaskStream(
          key: const ValueKey('missions'),
          collection: 'missions',
          icon: Icons.assignment_rounded,
          statusField: 'status',
          pendingStatus: 'En Cours',
          titleField: 'title',
          subtitleField: 'clientName',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // --- General Task Stream (No user filter) ---
  Widget _buildGeneralTaskStream({
    required Key key,
    required IconData icon,
    required String collection,
    required String statusField,
    required String pendingStatus,
    required String titleField,
    String? subtitleField,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(statusField, isEqualTo: pendingStatus)
          .orderBy('timestamp', descending: true) // Assuming timestamp exists
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))));
        }
        if (snapshot.hasError) {
          // ignore: avoid_print
          print('Error in GENERAL task stream ($collection): ${snapshot.error}');
          return const Center(child: Text('Erreur de chargement.', style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Padding( // Add padding to empty message
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text('Aucun élément "$pendingStatus".', style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
          ));
        }

        final tasks = snapshot.data!.docs;

        return ListView.builder(
          itemCount: tasks.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(0),
          itemBuilder: (context, index) {
            final task = tasks[index].data() as Map<String, dynamic>;

            final String taskTitle = task[titleField] ?? 'Tâche inconnue';
            String taskSubtitle = '';

            if (subtitleField != null && task.containsKey(subtitleField) && task[subtitleField] != null) {
              taskSubtitle = task[subtitleField];
            }

            // --- Display assigned technicians ---
            List<String> assignedNames = [];
            // Define expected field names based on collection
            String techNameField = '';
            if (collection == 'interventions' && task.containsKey('assignedTechniciansNames')) {
              techNameField = 'assignedTechniciansNames';
            } else if (collection == 'missions' && task.containsKey('assignedTechniciansNames')) {
              techNameField = 'assignedTechniciansNames';
            } else if (collection == 'sav_tickets' && task.containsKey('pickupTechnicianNames')) {
              techNameField = 'pickupTechnicianNames';
            }

            if (techNameField.isNotEmpty && task[techNameField] is List) {
              assignedNames = List<String>.from(task[techNameField] ?? []);
            }

            String assignedText = assignedNames.isNotEmpty ? 'Assigné à: ${assignedNames.join(', ')}' : 'Non assigné';
            // --- END ---

            String combinedSubtitle = taskSubtitle;
            if (taskSubtitle.isNotEmpty) {
              combinedSubtitle += '\n$assignedText';
            } else {
              combinedSubtitle = assignedText;
            }

            return ListTile(
              isThreeLine: taskSubtitle.isNotEmpty && assignedNames.isNotEmpty,
              leading: Icon(icon, color: Colors.white, size: 28),
              title: Text(
                taskTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                combinedSubtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.8), height: 1.3),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 16,
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Navigation vers $taskTitle non implémentée.'),
                    backgroundColor: Colors.indigo,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // --- Recent Activity Feed (Detailed View) ---
  Widget _buildRecentActivityFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('global_activity_log')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.white70),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding( // Add padding to empty message
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Aucune activité récente.',
                style: TextStyle(
                    color: Colors.white70, fontStyle: FontStyle.italic),
              ),
            ),
          );
        }

        final logs = snapshot.data!.docs;

        return ListView.separated(
          itemCount: logs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (context, index) => Divider(
            color: Colors.white.withOpacity(0.2),
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
          ),
          itemBuilder: (context, index) {
            final log = logs[index].data() as Map<String, dynamic>;

            final String message = log['message'] ?? 'Action inconnue';
            final String user = log['userName'] ?? 'Système';
            final String? category = log['category'] as String?;
            final Timestamp? timestamp = log['timestamp'];
            final String time = _formatRelativeTime(timestamp);
            final String? clientName = log['clientName'] as String?;
            final String? storeName = log['storeName'] as String?;
            final String? storeLocation = log['storeLocation'] as String?;

            List<String> contextParts = [];
            if (clientName != null && clientName.isNotEmpty) contextParts.add(clientName);
            if (storeName != null && storeName.isNotEmpty) contextParts.add(storeName);
            if (storeLocation != null && storeLocation.isNotEmpty) contextParts.add(storeLocation);
            String contextLine = contextParts.join(' • ');
            String actorLine = '$user • $time';
            String subtitleText = contextLine.isNotEmpty ? '$contextLine\n$actorLine' : actorLine;

            return ListTile(
              isThreeLine: contextLine.isNotEmpty,
              leading: Icon(_getIconForActivity(category), color: Colors.white),
              title: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                subtitleText,
                style: TextStyle(color: Colors.white.withOpacity(0.8), height: 1.4),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getIconForActivity(String? type) {
    switch (type) {
      case 'PROJECT': return Icons.folder_rounded;
      case 'CLIENT': return Icons.store_rounded;
      case 'STOCK': return Icons.warehouse_rounded;
      case 'MISSION': return Icons.assignment_rounded;
      case 'LIVRAISON': return Icons.local_shipping_rounded;
      case 'AUTH': return Icons.login_rounded;
    // Add specific icons for intervention, SAV etc. if needed
      case 'INTERVENTION': return Icons.handyman_rounded;
      case 'SAV_TICKET': return Icons.support_agent_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  String _formatRelativeTime(Timestamp? timestamp) {
    if (timestamp == null) return 'date inconnue';
    final dt = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inSeconds < 60) return 'à l\'instant';
    if (difference.inMinutes < 60) return 'il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'il y a ${difference.inHours} h';
    if (difference.inDays == 1) return 'hier';
    try {
      // Ensure locale is initialized (might need setup in main.dart)
      return DateFormat('d MMM', 'fr_FR').format(dt);
    } catch (e) {
      // Fallback if locale isn't ready
      return DateFormat('d MMM').format(dt);
    }
  }
} // End of _AdministrationDashboardPageState

// ========================= MODELS & CARDS =========================
// (ActionData, ActionCard, Stat Cards like _ReplacementRequestsCard, _buildGlowingCard etc. remain unchanged below)


class _ActionData {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _ActionData(this.label, this.icon, this.color, this.onTap);
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.25), Colors.white.withOpacity(0.15)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient:
                    LinearGradient(colors: [color, color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
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
    );
  }
}

// ======= STAT CARDS (streams) =======

class _ReplacementRequestsCard extends StatelessWidget {
  const _ReplacementRequestsCard({super.key});

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
          gradient:
          const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
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

class _RequisitionPipelineCard extends StatelessWidget {
  final String userRole;
  const _RequisitionPipelineCard({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    return _buildGlowingCard(
      context: context,
      title: 'Commandes',
      count: '', // Count is handled by mini stats
      icon: Icons.shopping_cart_rounded,
      gradient:
      const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
      customBody: Row(
        children: [
          Expanded(
            child: _buildMiniStat(
              context,
              'Approbation',
              FirebaseFirestore.instance
                  .collection('requisitions')
                  .where('status', isEqualTo: "En attente d'approbation")
                  .snapshots(),
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RequisitionApprovalPage(userRole: userRole)),
              ),
            ),
          ),
          Container(
            width: 2,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.0),
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.0)
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildMiniStat(
              context,
              'À Commander',
              FirebaseFirestore.instance
                  .collection('requisitions')
                  .where('status', isEqualTo: "Approuvée")
                  .snapshots(),
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PurchasingHubPage(userRole: userRole)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      BuildContext ctx,
      String title,
      Stream<QuerySnapshot> stream,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Placeholder replaced by actual StreamBuilder
            StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (c, s) {
                final cnt = s.hasData ? s.data!.docs.length : 0;
                // Use ShaderMask if you want the gradient effect on the number
                return Text(
                  cnt.toString(),
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingBillingCard extends StatelessWidget {
  const _PendingBillingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Check both interventions and potentially SAV tickets if they also need billing
      stream: FirebaseFirestore.instance
          .collection('interventions')
          .where('status', isEqualTo: "Terminé")
      // Add .where('billingStatus', isEqualTo: 'pending') if you have such a field
          .snapshots(),
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return _buildGlowingCard(
          context: context,
          title: 'Facturation en Attente',
          count: count.toString(),
          icon: Icons.receipt_long_rounded,
          gradient:
          const LinearGradient(colors: [Color(0xFF14B8A6), Color(0xFF0D9488)]),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const BillingHubPage())),
        );
      },
    );
  }
}

class _PendingReplacementsCard extends StatelessWidget {
  const _PendingReplacementsCard({super.key});

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
          gradient:
          const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
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
  const _LivraisonsCard({super.key});

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
          gradient:
          const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const LivraisonsHubPage())),
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
    margin: isWeb ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 20),
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
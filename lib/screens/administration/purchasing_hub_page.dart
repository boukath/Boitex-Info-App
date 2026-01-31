// lib/screens/administration/purchasing_hub_page.dart

import 'dart:ui'; // For ImageFilter (Glassmorphism)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

// PAGE IMPORTS
import 'package:boitex_info_app/screens/administration/add_requisition_page.dart';
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';
// ✅ NEW: Import Direct Import Page
import 'package:boitex_info_app/screens/administration/direct_import_page.dart';

class PurchasingHubPage extends StatefulWidget {
  final String userRole;
  const PurchasingHubPage({super.key, this.userRole = ''});

  @override
  State<PurchasingHubPage> createState() => _PurchasingHubPageState();
}

class _PurchasingHubPageState extends State<PurchasingHubPage>
    with SingleTickerProviderStateMixin {
  late String _currentUserRole;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _currentUserRole = widget.userRole;
    if (_currentUserRole.isEmpty) {
      _fetchUserRole();
    }
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.lightImpact(); // Haptic on tab switch
      }
    });
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted && doc.exists) {
        setState(() {
          _currentUserRole = doc.data()?['role'] ?? 'Employé';
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==========================================
  // ACTION SPLITTER (The Premium Sheet)
  // ==========================================
  void _showCreateActionSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95), // Frosted
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Nouvelle Opération",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Quel type d'achat souhaitez-vous enregistrer ?",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Option 1: Standard Requisition
              _buildActionTile(
                icon: Icons.post_add_rounded,
                color: Colors.blue.shade700,
                title: "Demande Standard",
                subtitle: "Workflow classique : Validation → Commande",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddRequisitionPage()),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Option 2: Direct Import
              _buildActionTile(
                icon: Icons.bolt_rounded,
                color: Colors.orange.shade800,
                title: "Entrée Directe / Import",
                subtitle: "Ajout immédiat au stock (ex: Retour Chine)",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DirectImportPage()),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // A. Animated Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF3E5F5), // Very light purple
                  Color(0xFFE3F2FD), // Very light blue
                  Color(0xFFFAFAFA), // Almost white
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),

          // B. Main Content
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                _buildPremiumAppBar(),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _RequisitionList(
                  statuses: const ["En attente d'approbation"],
                  userRole: _currentUserRole,
                  emptyMessage: 'Tout est validé.',
                  emptyIcon: Icons.check_circle_outline,
                ),
                _RequisitionList(
                  statuses: const ['Approuvée'],
                  userRole: _currentUserRole,
                  emptyMessage: 'Tout est commandé.',
                  emptyIcon: Icons.shopping_cart_outlined,
                ),
                _RequisitionList(
                  statuses: const ['Commandée', 'Partiellement Reçue'],
                  userRole: _currentUserRole,
                  emptyMessage: 'Aucune réception en attente.',
                  emptyIcon: Icons.local_shipping_outlined,
                ),
                _RequisitionList(
                  statuses: const [
                    'Reçue',
                    'Reçue avec Écarts',
                    'Refusée',
                    'Annulée'
                  ],
                  userRole: _currentUserRole,
                  isHistory: true,
                  emptyMessage: 'Aucun historique récent.',
                  emptyIcon: Icons.history,
                ),
              ],
            ),
          ),
        ],
      ),
      // FAB (Now triggers Action Sheet)
      floatingActionButton: Container(
        padding: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          elevation: 4,
          highlightElevation: 8,
          onPressed: _showCreateActionSheet, // ✅ Calls the new sheet
          label: const Text(
            'Nouvelle Demande',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          backgroundColor: Colors.transparent,
          extendedPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ).applyGradient(const LinearGradient(
          colors: [Color(0xFF8E24AA), Color(0xFF5E35B1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // APP BAR (Fixed Overflow)
  Widget _buildPremiumAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white.withOpacity(0.7),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      elevation: 0,
      title: const Text(
        'Bureau des Achats',
        style: TextStyle(
          color: Color(0xFF1A237E),
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, color: Colors.black54),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
      pinned: true,
      floating: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          height: 55,
          margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
          child: TabBar(
            controller: _tabController,
            isScrollable: true, // ✅ Prevents Overflow
            tabAlignment: TabAlignment.start, // ✅ Aligns correctly
            padding: const EdgeInsets.symmetric(horizontal: 16),
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            indicatorPadding: const EdgeInsets.symmetric(vertical: 6),
            labelColor: const Color(0xFF1A237E),
            unselectedLabelColor: Colors.grey.shade600,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            dividerColor: Colors.transparent,
            overlayColor: MaterialStateProperty.all(Colors.transparent),
            tabs: [
              _buildTab(label: 'Validations', query: ['En attente d\'approbation']),
              _buildTab(label: 'Commandes', query: ['Approuvée']),
              _buildTab(label: 'Suivi', query: ['Commandée', 'Partiellement Reçue']),
              const Tab(text: 'Historique'),
            ],
          ),
        ),
      ),
    );
  }

  // TAB BUILDER (Fixed Overflow)
  Widget _buildTab({required String label, required List<String> query}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('requisitions')
          .where('status', whereIn: query)
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }
        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)), // ✅ Prevents text overflow
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }
}

// ==============================================================================
// 4. THE CARD DESIGN & LIST (Same as before)
// ==============================================================================

class _RequisitionList extends StatelessWidget {
  final List<String> statuses;
  final String userRole;
  final String emptyMessage;
  final IconData emptyIcon;
  final bool isHistory;

  const _RequisitionList({
    required this.statuses,
    required this.userRole,
    required this.emptyMessage,
    required this.emptyIcon,
    this.isHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('requisitions')
        .where('status', whereIn: statuses)
        .orderBy('createdAt', descending: true);

    if (isHistory) {
      query = query.limit(50);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Erreur: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(emptyIcon, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: docs.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return _PremiumRequisitionCard(
              data: data,
              docId: doc.id,
              userRole: userRole,
            );
          },
        );
      },
    );
  }
}

class _PremiumRequisitionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String userRole;

  const _PremiumRequisitionCard({
    required this.data,
    required this.docId,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'Sans titre';
    final supplier = data['supplierName'] ?? 'Fournisseur inconnu';
    final code = data['requisitionCode'] ?? 'N/A';
    final status = data['status'] ?? 'Inconnu';
    final dateTs = data['createdAt'] as Timestamp?;
    final dateStr = dateTs != null
        ? DateFormat('dd MMM').format(dateTs.toDate())
        : '--';

    final supplierInitial = supplier.isNotEmpty ? supplier[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A1B9A).withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RequisitionDetailsPage(
                  requisitionId: docId,
                  userRole: userRole,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: _getHashColor(supplier).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        supplierInitial,
                        style: TextStyle(
                          color: _getHashColor(supplier),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2D3436),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.store_mall_directory_rounded,
                                  size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  supplier,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        code,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusCapsule(status: status),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getHashColor(String value) {
    final int hash = value.codeUnits.fold(0, (p, c) => p + c);
    final List<Color> colors = [
      Colors.blue.shade700,
      Colors.purple.shade700,
      Colors.orange.shade800,
      Colors.teal.shade700,
      Colors.pink.shade700,
      Colors.indigo.shade700,
    ];
    return colors[hash % colors.length];
  }
}

class _StatusCapsule extends StatelessWidget {
  final String status;
  const _StatusCapsule({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (status) {
      case 'Approuvée':
        color = const Color(0xFF00C853);
        icon = Icons.check_circle_rounded;
        break;
      case 'Reçue':
        color = const Color(0xFF2E7D32);
        icon = Icons.inventory_2_rounded;
        break;
      case "En attente d'approbation":
        color = const Color(0xFFFF9100);
        icon = Icons.hourglass_top_rounded;
        break;
      case 'Commandée':
        color = const Color(0xFF2962FF);
        icon = Icons.send_rounded;
        break;
      case 'Refusée':
      case 'Annulée':
        color = const Color(0xFFD50000);
        icon = Icons.cancel_rounded;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info_rounded;
    }

    String displayLabel = status;
    if (status == "En attente d'approbation") displayLabel = "En attente";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            displayLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

extension FloatingActionButtonGradient on FloatingActionButton {
  Widget applyGradient(Gradient gradient) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: this,
      ),
    );
  }
}
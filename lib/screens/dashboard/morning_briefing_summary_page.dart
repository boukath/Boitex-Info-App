import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ✅ Import the SAV Model
import 'package:boitex_info_app/models/sav_ticket.dart';

// Import your detail pages
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';

class MorningBriefingSummaryPage extends StatefulWidget {
  const MorningBriefingSummaryPage({super.key});

  @override
  State<MorningBriefingSummaryPage> createState() =>
      _MorningBriefingSummaryPageState();
}

class _MorningBriefingSummaryPageState
    extends State<MorningBriefingSummaryPage> {
  bool _isLoading = true;
  String? _userRole;
  Map<String, List<String>> _contentVisibility = {};

  // ✅ Strictly Typed Lists to avoid "Object?" errors
  List<DocumentSnapshot<Map<String, dynamic>>> _interventions = [];
  List<DocumentSnapshot<Map<String, dynamic>>> _savTickets = [];
  List<DocumentSnapshot<Map<String, dynamic>>> _livraisons = [];
  List<DocumentSnapshot<Map<String, dynamic>>> _billing = [];
  List<DocumentSnapshot<Map<String, dynamic>>> _requisitions = [];

  @override
  void initState() {
    super.initState();
    _loadBriefingData();
  }

  Future<void> _loadBriefingData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Get User Role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      _userRole = userDoc.data()?['role'];

      // 2. Get Briefing Settings (Permissions)
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('morning_briefing')
          .get();
      if (settingsDoc.exists) {
        final data = settingsDoc.data()!;
        if (data['content_visibility'] != null) {
          final Map<String, dynamic> rawMap = data['content_visibility'];
          _contentVisibility = rawMap
              .map((key, value) => MapEntry(key, List<String>.from(value)));
        }
      }

      // 3. Fetch Data in Parallel based on permissions
      if (_userRole != null) {
        await Future.wait([
          if (_canSee('pending_interventions')) _fetchInterventions(),
          if (_canSee('active_sav')) _fetchSav(),
          if (_canSee('todays_livraisons')) _fetchLivraisons(),
          if (_canSee('pending_billing')) _fetchBilling(),
          if (_canSee('pending_requisitions')) _fetchRequisitions(),
        ]);
      }
    } catch (e) {
      debugPrint("Error loading briefing: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper: Check if current role is allowed to see this section
  bool _canSee(String key) {
    final allowedRoles = _contentVisibility[key];
    if (allowedRoles == null) return false;
    return allowedRoles.contains(_userRole) || allowedRoles.contains('ALL');
  }

  // --- FETCHING LOGIC ---

  Future<void> _fetchInterventions() async {
    final snap = await FirebaseFirestore.instance
        .collection('interventions')
        .where('status', isEqualTo: 'Nouvelle Demande')
        .limit(20)
        .get();
    _interventions = snap.docs;
  }

  Future<void> _fetchSav() async {
    final snap = await FirebaseFirestore.instance
        .collection('sav_tickets')
        .where('status',
        whereIn: ['Nouveau', 'En cours', 'En attente de pièce', 'Diagnostiqué'])
        .limit(20)
        .get();
    _savTickets = snap.docs;
  }

  Future<void> _fetchLivraisons() async {
    final snap = await FirebaseFirestore.instance
        .collection('livraisons')
        .where('status', isEqualTo: 'À Préparer')
        .limit(20)
        .get();
    _livraisons = snap.docs;
  }

  Future<void> _fetchBilling() async {
    final snap = await FirebaseFirestore.instance
        .collection('interventions')
        .where('status', isEqualTo: 'Terminé')
        .limit(20)
        .get();
    _billing = snap.docs;
  }

  Future<void> _fetchRequisitions() async {
    final snap = await FirebaseFirestore.instance
        .collection('requisitions')
        .where('status', isEqualTo: "En attente d'approbation")
        .limit(20)
        .get();
    _requisitions = snap.docs;
  }

  @override
  Widget build(BuildContext context) {
    final totalTasks = _interventions.length +
        _savTickets.length +
        _livraisons.length +
        _billing.length +
        _requisitions.length;
    final dateStr = DateFormat('EEEE d MMMM', 'fr').format(DateTime.now());

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Premium 4K iOS 2026 Background (Mesh Gradient Feel)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Deep Slate
                  Color(0xFF1E1B4B), // Deep Indigo
                  Color(0xFF312E81), // Rich Purple
                  Color(0xFF0F172A),
                ],
                stops: [0.0, 0.4, 0.8, 1.0],
              ),
            ),
          ),
          // Subtle glowing orbs in background
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withOpacity(0.2),
              ),
            ),
          ),
          // Blur layer over the orbs to create the "mesh" effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),

          // 2. Main Content (Adaptable for Web & Mobile)
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800), // Web limit
                child: _isLoading
                    ? const Center(
                  child: CupertinoActivityIndicator(
                    color: Colors.white,
                    radius: 20,
                  ),
                )
                    : CustomScrollView(
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    // Dynamic Glass Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateStr.toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Briefing Matinal",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildProgressCard(totalTasks),
                          ],
                        ),
                      ),
                    ),

                    // Sections
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (totalTasks == 0) _buildEmptyState(),

                          if (_interventions.isNotEmpty)
                            _buildGlassSection(
                              title: "Interventions",
                              count: _interventions.length,
                              color: const Color(0xFFF59E0B), // Amber
                              icon: CupertinoIcons.wrench_fill,
                              items: _interventions,
                              itemBuilder: (doc) =>
                                  _buildInterventionCard(doc),
                            ),

                          if (_savTickets.isNotEmpty)
                            _buildGlassSection(
                              title: "Tickets SAV",
                              count: _savTickets.length,
                              color: const Color(0xFFEF4444), // Red
                              icon: CupertinoIcons.ticket_fill,
                              items: _savTickets,
                              itemBuilder: (doc) => _buildSavCard(doc),
                            ),

                          if (_livraisons.isNotEmpty)
                            _buildGlassSection(
                              title: "Livraisons",
                              count: _livraisons.length,
                              color: const Color(0xFF3B82F6), // Blue
                              icon: CupertinoIcons.cube_box_fill,
                              items: _livraisons,
                              itemBuilder: (doc) =>
                                  _buildLivraisonCard(doc),
                            ),

                          if (_requisitions.isNotEmpty)
                            _buildGlassSection(
                              title: "Achats (Réquisitions)",
                              count: _requisitions.length,
                              color: const Color(0xFF10B981), // Emerald
                              icon: CupertinoIcons.cart_fill,
                              items: _requisitions,
                              itemBuilder: (doc) => _buildSimpleCard(
                                  doc, "requisitionCode", "requestedBy"),
                            ),

                          if (_billing.isNotEmpty)
                            _buildGlassSection(
                              title: "Facturation (Terminé)",
                              count: _billing.length,
                              color: const Color(0xFF8B5CF6), // Purple
                              icon: CupertinoIcons.doc_text_fill,
                              items: _billing,
                              itemBuilder: (doc) =>
                                  _buildInterventionCard(doc),
                            ),

                          const SizedBox(height: 60),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- PREMIUM WIDGETS ---

  Widget _buildProgressCard(int totalTasks) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: Row(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: totalTasks == 0
                      ? const Color(0xFF10B981).withOpacity(0.2)
                      : const Color(0xFFF59E0B).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  totalTasks == 0
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.bolt_fill,
                  color: totalTasks == 0
                      ? const Color(0xFF34D399)
                      : const Color(0xFFFCD34D),
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      totalTasks == 0
                          ? "Journée terminée"
                          : "$totalTasks Tâches en attente",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: totalTasks == 0 ? 1.0 : 0.3,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(
                          totalTasks == 0
                              ? const Color(0xFF34D399)
                              : const Color(0xFF8B5CF6),
                        ),
                        minHeight: 6,
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3), width: 1),
            ),
            child: const Icon(CupertinoIcons.checkmark_seal_fill,
                size: 64, color: Color(0xFF34D399)),
          ),
          const SizedBox(height: 24),
          Text(
            "Tout est à jour !",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Aucune tâche en attente pour votre rôle.\nProfitez de votre journée.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.6),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSection({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required List<DocumentSnapshot<Map<String, dynamic>>> items,
    required Widget Function(DocumentSnapshot<Map<String, dynamic>>) itemBuilder,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: true,
                iconColor: Colors.white70,
                collapsedIconColor: Colors.white70,
                tilePadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                title: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    color: Colors.white,
                  ),
                ),
                trailing: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                children: [
                  Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.1),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        height: 1,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    itemBuilder: (ctx, i) => itemBuilder(items[i]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- GLASS LIST ITEMS ---

  Widget _buildInterventionCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      title: Text(
        data['clientName'] ?? 'Client Inconnu',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontSize: 15,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${data['storeName'] ?? ''} • ${data['serviceType'] ?? ''}",
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(CupertinoIcons.clock, size: 14, color: Colors.white54),
                const SizedBox(width: 4),
                Text(
                  data['createdAt'] != null
                      ? DateFormat('dd MMM HH:mm')
                      .format((data['createdAt'] as Timestamp).toDate())
                      : "Date inconnue",
                  style:
                  GoogleFonts.poppins(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
      ),
      trailing:
      const Icon(CupertinoIcons.right_chevron, color: Colors.white30, size: 18),
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => InterventionDetailsPage(interventionDoc: doc),
          ),
        );
      },
    );
  }

  Widget _buildSavCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(
        data['clientName'] ?? 'Client Inconnu',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontSize: 15,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          "${data['productName'] ?? 'Produit'} • ${data['status']}",
          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
        ),
      ),
      trailing:
      const Icon(CupertinoIcons.right_chevron, color: Colors.white30, size: 18),
      onTap: () {
        final ticket = SavTicket.fromFirestore(doc);
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => SavTicketDetailsPage(ticket: ticket),
          ),
        );
      },
    );
  }

  Widget _buildLivraisonCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(CupertinoIcons.cube_box, color: Colors.white70, size: 20),
      ),
      title: Text(
        data['clientName'] ?? 'Client Inconnu',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontSize: 15,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          "BL: ${data['bonLivraisonCode'] ?? 'N/A'}",
          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
        ),
      ),
      trailing:
      const Icon(CupertinoIcons.right_chevron, color: Colors.white30, size: 18),
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => LivraisonDetailsPage(livraisonId: doc.id),
          ),
        );
      },
    );
  }

  Widget _buildSimpleCard(
      DocumentSnapshot<Map<String, dynamic>> doc, String titleKey, String subKey) {
    final data = doc.data()!;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(
        data[titleKey] ?? 'Item',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontSize: 15,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          data[subKey] ?? '',
          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
        ),
      ),
      trailing:
      const Icon(CupertinoIcons.right_chevron, color: Colors.white30, size: 18),
      onTap: () {
        if (titleKey == 'requisitionCode') {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => RequisitionDetailsPage(
                requisitionId: doc.id,
                userRole: _userRole ?? '',
              ),
            ),
          );
        }
      },
    );
  }
}
import 'package:flutter/material.dart';
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
  State<MorningBriefingSummaryPage> createState() => _MorningBriefingSummaryPageState();
}

class _MorningBriefingSummaryPageState extends State<MorningBriefingSummaryPage> {
  bool _isLoading = true;
  String? _userRole;
  Map<String, List<String>> _contentVisibility = {};

  // ✅ FIXED: Strictly Typed Lists to avoid "Object?" errors
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
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      _userRole = userDoc.data()?['role'];

      // 2. Get Briefing Settings (Permissions)
      final settingsDoc = await FirebaseFirestore.instance.collection('settings').doc('morning_briefing').get();
      if (settingsDoc.exists) {
        final data = settingsDoc.data()!;
        if (data['content_visibility'] != null) {
          final Map<String, dynamic> rawMap = data['content_visibility'];
          _contentVisibility = rawMap.map((key, value) => MapEntry(key, List<String>.from(value)));
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
    _interventions = snap.docs; // Implicitly cast because we typed the list correctly
  }

  Future<void> _fetchSav() async {
    final snap = await FirebaseFirestore.instance
        .collection('sav_tickets')
        .where('status', whereIn: ['Nouveau', 'En cours', 'En attente de pièce', 'Diagnostiqué'])
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
    final totalTasks = _interventions.length + _savTickets.length + _livraisons.length + _billing.length + _requisitions.length;
    final dateStr = DateFormat('EEEE d MMMM', 'fr').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        slivers: [
          // 1. Pro Header
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: Colors.blue[900],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                "Briefing Matinal",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue[900]!, Colors.blue[700]!],
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    Text(
                      dateStr.toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "$totalTasks Tâches en attente",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalTasks == 0 ? 1 : 0.1,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation(
                          totalTasks == 0 ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Sections
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (totalTasks == 0) _buildEmptyState(),

                if (_interventions.isNotEmpty)
                  _buildSection(
                    title: "Interventions",
                    count: _interventions.length,
                    color: Colors.orange,
                    icon: Icons.build_circle_outlined,
                    items: _interventions,
                    itemBuilder: (doc) => _buildInterventionCard(doc),
                  ),

                if (_savTickets.isNotEmpty)
                  _buildSection(
                    title: "Tickets SAV",
                    count: _savTickets.length,
                    color: Colors.red,
                    icon: Icons.confirmation_number_outlined,
                    items: _savTickets,
                    itemBuilder: (doc) => _buildSavCard(doc),
                  ),

                if (_livraisons.isNotEmpty)
                  _buildSection(
                    title: "Livraisons",
                    count: _livraisons.length,
                    color: Colors.blue,
                    icon: Icons.local_shipping_outlined,
                    items: _livraisons,
                    itemBuilder: (doc) => _buildLivraisonCard(doc),
                  ),

                if (_requisitions.isNotEmpty)
                  _buildSection(
                    title: "Achats (Réquisitions)",
                    count: _requisitions.length,
                    color: Colors.teal,
                    icon: Icons.shopping_cart_outlined,
                    items: _requisitions,
                    itemBuilder: (doc) => _buildSimpleCard(doc, "requisitionCode", "requestedBy"),
                  ),

                if (_billing.isNotEmpty)
                  _buildSection(
                    title: "Facturation (Terminé)",
                    count: _billing.length,
                    color: Colors.purple,
                    icon: Icons.receipt_long,
                    items: _billing,
                    itemBuilder: (doc) => _buildInterventionCard(doc),
                  ),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
          const SizedBox(height: 16),
          Text(
            "Tout est à jour !",
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
          ),
          Text(
            "Aucune tâche en attente pour votre rôle.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // --- SECTION WIDGETS ---

  Widget _buildSection({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    // ✅ FIXED: Explicit type
    required List<DocumentSnapshot<Map<String, dynamic>>> items,
    required Widget Function(DocumentSnapshot<Map<String, dynamic>>) itemBuilder,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.grey[100]),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(0),
            itemCount: items.length,
            separatorBuilder: (ctx, i) => Divider(height: 1, color: Colors.grey[100]),
            itemBuilder: (ctx, i) => itemBuilder(items[i]),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // --- ITEM CARDS ---

  // ✅ FIXED: Argument type
  Widget _buildInterventionCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!; // Safe because of strict type
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        data['clientName'] ?? 'Client Inconnu',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${data['storeName'] ?? ''} • ${data['serviceType'] ?? ''}"),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                data['createdAt'] != null
                    ? DateFormat('dd MMM HH:mm').format((data['createdAt'] as Timestamp).toDate())
                    : "Date inconnue",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {
        // ✅ FIXED: Passes strictly typed document
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InterventionDetailsPage(interventionDoc: doc),
          ),
        );
      },
    );
  }

  // ✅ FIXED: Argument type
  Widget _buildSavCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        data['clientName'] ?? 'Client Inconnu',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text("${data['productName'] ?? 'Produit'} • ${data['status']}"),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {
        // ✅ FIXED: Use .fromFirestore() which is the correct factory
        final ticket = SavTicket.fromFirestore(doc);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SavTicketDetailsPage(ticket: ticket),
          ),
        );
      },
    );
  }

  // ✅ FIXED: Argument type
  Widget _buildLivraisonCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ListTile(
      leading: const Icon(Icons.local_shipping, color: Colors.blueGrey),
      title: Text(
        data['clientName'] ?? 'Client',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text("BL: ${data['bonLivraisonCode'] ?? 'N/A'}"),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LivraisonDetailsPage(livraisonId: doc.id),
          ),
        );
      },
    );
  }

  // ✅ FIXED: Argument type
  Widget _buildSimpleCard(DocumentSnapshot<Map<String, dynamic>> doc, String titleKey, String subKey) {
    final data = doc.data()!;
    return ListTile(
      title: Text(data[titleKey] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(data[subKey] ?? ''),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        if(titleKey == 'requisitionCode') {
          Navigator.push(
            context,
            MaterialPageRoute(
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
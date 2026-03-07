// lib/screens/service_technique/intervention_list_page.dart

import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:boitex_info_app/screens/service_technique/add_intervention_page.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_history_clients_page.dart';
import 'package:boitex_info_app/screens/administration/store_equipment_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:timeago/timeago.dart' as timeago;

class InterventionListPage extends StatefulWidget {
  final String userRole;
  final String serviceType;
  const InterventionListPage({
    super.key,
    required this.userRole,
    required this.serviceType,
  });

  @override
  State<InterventionListPage> createState() => _InterventionListPageState();
}

class _InterventionListPageState extends State<InterventionListPage> with SingleTickerProviderStateMixin {
  bool _canDelete = false;
  bool _canPrioritize = false;
  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _checkUserPermissions();
    // Ambient background animation
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkUserPermissions() async {
    final canDelete = await RolePermissions.canCurrentUserDeleteIntervention();
    final canPrioritize = widget.userRole.contains('Admin') ||
        widget.userRole.contains('Responsable') ||
        widget.userRole.contains('PDG');

    if (mounted) {
      setState(() {
        _canDelete = canDelete;
        _canPrioritize = canPrioritize;
      });
    }
  }

  // --- ⚡️ FLASH INFO DIALOG ---
  Future<void> _showQuickUpdateDialog(String docId, String? currentNote) async {
    final TextEditingController noteController = TextEditingController(text: currentNote);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 32,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.flash_on, color: Colors.amber, size: 20),
            ),
            const SizedBox(width: 12),
            Text("Flash Info", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Ajoutez une note rapide pour expliquer la situation actuelle.",
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: noteController,
              autofocus: true,
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "La situation actuelle...",
                hintStyle: const TextStyle(color: Colors.black38),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Annuler", style: GoogleFonts.plusJakartaSans(color: Colors.black54, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              if (noteController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('interventions').doc(docId).update({
                  'lastFollowUpNote': noteController.text.trim(),
                  'lastFollowUpDate': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text("Publier", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- 📌 ACTIONS LOGIC ---
  Future<void> _togglePin(String docId, bool currentPinStatus) async {
    await FirebaseFirestore.instance.collection('interventions').doc(docId).update({
      'isPinned': !currentPinStatus,
      if (!currentPinStatus) 'pinnedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updatePriority(String docId, int newPriorityLevel) async {
    await FirebaseFirestore.instance.collection('interventions').doc(docId).update({'priorityLevel': newPriorityLevel});
  }

  Future<void> _onReorderPinned(int oldIndex, int newIndex, List<QueryDocumentSnapshot> pinnedDocs) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = pinnedDocs.removeAt(oldIndex);
    pinnedDocs.insert(newIndex, item);

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < pinnedDocs.length; i++) {
      batch.update(pinnedDocs[i].reference, {'pinSortIndex': i});
    }
    await batch.commit();
  }

  Future<void> _deleteIntervention(String interventionId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          title: Text('Supprimer ?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer définitivement l\'intervention pour "$title"? Cette action est irréversible.',
              style: GoogleFonts.plusJakartaSans(fontSize: 14)),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade700),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('interventions').doc(interventionId).delete();
    }
  }

  // --- 🌌 BREATHTAKING AMBIENT BACKGROUND ---
  Widget _buildAmbientBackground() {
    return AnimatedBuilder(
      animation: _bgAnimationController,
      builder: (context, child) {
        final double animValue = _bgAnimationController.value;
        return Stack(
          children: [
            Container(color: const Color(0xFFF2F5FA)), // Crisp light base
            // Top Right Pink/Purple
            Positioned(
              top: -100 + (math.sin(animValue * math.pi * 2) * 50),
              right: -50 + (math.cos(animValue * math.pi * 2) * 50),
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFD1FF).withOpacity(0.6)),
              ),
            ),
            // Center Left Blue
            Positioned(
              top: MediaQuery.of(context).size.height * 0.3 + (math.cos(animValue * math.pi) * 80),
              left: -100 + (math.sin(animValue * math.pi) * 80),
              child: Container(
                width: 400, height: 400,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFD1E8FF).withOpacity(0.7)),
              ),
            ),
            // Bottom Right Mint/Teal
            Positioned(
              bottom: -50 + (math.sin(animValue * math.pi * 1.5) * 60),
              right: -100 + (math.cos(animValue * math.pi * 1.5) * 60),
              child: Container(
                width: 350, height: 350,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFD1FFED).withOpacity(0.5)),
              ),
            ),
            // The massive blur that creates the Mesh Gradient effect
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(color: Colors.transparent),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final serviceType = widget.serviceType;
    final userRole = widget.userRole;
    final double screenWidth = MediaQuery.of(context).size.width;

    // 🚀 Smart Web Adaptation: Keep max width to 850px for readability
    final double contentPadding = screenWidth > 850 ? (screenWidth - 850) / 2 : 16.0;

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('interventions')
        .where('serviceType', isEqualTo: serviceType)
        .where('status', whereIn: ['Nouvelle Demande', 'Nouveau', 'En cours', 'En attente'])
        .orderBy('createdAt', descending: true);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _buildAmbientBackground(), // 🌌 The magic background

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('Erreur serveur.'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_rounded, size: 80, color: Colors.black12),
                      const SizedBox(height: 16),
                      Text('Aucune intervention active', style: GoogleFonts.plusJakartaSans(fontSize: 20, color: Colors.black38, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }

              final allDocs = snapshot.data!.docs;
              List<QueryDocumentSnapshot<Map<String, dynamic>>> pinnedDocs = [];
              List<QueryDocumentSnapshot<Map<String, dynamic>>> unpinnedDocs = [];

              for (var doc in allDocs) {
                if (doc.data()['isPinned'] == true) pinnedDocs.add(doc);
                else unpinnedDocs.add(doc);
              }

              pinnedDocs.sort((a, b) => (a.data()['pinSortIndex'] ?? 999).compareTo(b.data()['pinSortIndex'] ?? 999));
              unpinnedDocs.sort((a, b) {
                final int priorityA = a.data()['priorityLevel'] ?? 1;
                final int priorityB = b.data()['priorityLevel'] ?? 1;
                if (priorityA != priorityB) return priorityB.compareTo(priorityA);
                final timeA = a.data()['createdAt'] as Timestamp?;
                final timeB = b.data()['createdAt'] as Timestamp?;
                if (timeA != null && timeB != null) return timeB.compareTo(timeA);
                return 0;
              });

              return CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  // --- 🍏 PREMIUM APP BAR ---
                  SliverAppBar(
                    backgroundColor: Colors.white.withOpacity(0.3),
                    expandedHeight: 120,
                    pinned: true,
                    elevation: 0,
                    flexibleSpace: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: FlexibleSpaceBar(
                          titlePadding: EdgeInsets.only(left: contentPadding, bottom: 16, right: contentPadding),
                          title: Text(
                            'Interventions',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.black87,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          background: Container(color: Colors.white.withOpacity(0.1)),
                        ),
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: EdgeInsets.only(right: contentPadding > 16 ? contentPadding - 16 : 0),
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), shape: BoxShape.circle),
                            child: const Icon(Icons.history_rounded, color: Colors.black87, size: 20),
                          ),
                          tooltip: "Historique Clients",
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InterventionHistoryClientsPage(serviceType: serviceType))),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // --- 📌 PINNED SECTION ---
                  if (pinnedDocs.isNotEmpty) ...[
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(contentPadding, 0, contentPadding, 12),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.push_pin_rounded, color: Colors.redAccent, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Text("Épinglées", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.3)),
                          ],
                        ),
                      ),
                    ),
                    SliverReorderableList(
                      itemCount: pinnedDocs.length,
                      onReorder: (oldIndex, newIndex) => _onReorderPinned(oldIndex, newIndex, pinnedDocs),
                      itemBuilder: (context, index) {
                        return Container(
                          key: ValueKey(pinnedDocs[index].id),
                          padding: EdgeInsets.symmetric(horizontal: contentPadding, vertical: 10),
                          child: _buildPremiumGlassCard(pinnedDocs[index]),
                        );
                      },
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 32, child: Divider(color: Colors.black.withOpacity(0.05), thickness: 2, indent: contentPadding, endIndent: contentPadding))),
                  ],

                  // --- 📁 UNPINNED SECTION ---
                  if (unpinnedDocs.isNotEmpty) ...[
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(contentPadding, pinnedDocs.isEmpty ? 0 : 12, contentPadding, 12),
                      sliver: SliverToBoxAdapter(
                        child: Text("Toutes les demandes", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.3)),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: contentPadding, vertical: 10),
                            child: _buildPremiumGlassCard(unpinnedDocs[index]),
                          );
                        },
                        childCount: unpinnedDocs.length,
                      ),
                    ),
                  ],

                  const SliverPadding(padding: EdgeInsets.only(bottom: 120)), // Space for FAB
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: RolePermissions.canAddIntervention(userRole)
          ? FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => AddInterventionPage(serviceType: serviceType))),
        elevation: 8,
        highlightElevation: 12,
        label: Text("Nouvelle", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Colors.white)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        backgroundColor: const Color(0xFF4A65E6), // Premium vibrant blue
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      )
          : null,
    );
  }

  Widget _buildPremiumGlassCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return PremiumGlassCard(
      doc: doc,
      canDelete: _canDelete,
      canPrioritize: _canPrioritize,
      onDelete: _deleteIntervention,
      onPrioritize: _updatePriority,
      onTogglePin: _togglePin,
      onFlashUpdate: _showQuickUpdateDialog,
    );
  }
}

// -----------------------------------------------------------------------------
// 🍎 iOS 2026 ULTRA-PREMIUM GLASSMORPHISM CARD (WITH NO OVERFLOWS)
// -----------------------------------------------------------------------------
class PremiumGlassCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool canDelete;
  final bool canPrioritize;
  final Function(String, String) onDelete;
  final Function(String, int) onPrioritize;
  final Function(String, bool) onTogglePin;
  final Function(String, String?) onFlashUpdate;

  const PremiumGlassCard({
    super.key,
    required this.doc,
    required this.canDelete,
    required this.canPrioritize,
    required this.onDelete,
    required this.onPrioritize,
    required this.onTogglePin,
    required this.onFlashUpdate,
  });

  @override
  State<PremiumGlassCard> createState() => _PremiumGlassCardState();
}

class _PremiumGlassCardState extends State<PremiumGlassCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isTapped = false;

  Map<String, dynamic> _getInterventionStyle(String? type, String? billingStatus) {
    if (type == 'Facturable' || type == 'Intervention Facturable' || billingStatus == 'FACTURABLE') {
      return {'color': const Color(0xFFE59400), 'icon': Icons.monetization_on_rounded, 'label': 'FACTURABLE'};
    }
    if (type == 'Corrective' || type == 'Maintenance Corrective') {
      return {'color': const Color(0xFFE04006), 'icon': Icons.build_circle_rounded, 'label': 'CORRECTIF'};
    }
    if (type == 'Garantie' || type == 'Sous Garantie' || billingStatus == 'GRATUIT') {
      return {'color': const Color(0xFF00B04A), 'icon': Icons.verified_user_rounded, 'label': 'GARANTIE'};
    }
    if (type == 'Preventive' || type == 'Maintenance Préventive') {
      return {'color': const Color(0xFF3F51B5), 'icon': Icons.calendar_month_rounded, 'label': 'PRÉVENTIF'};
    }
    return {'color': const Color(0xFF546E7A), 'icon': Icons.work_rounded, 'label': 'INTERVENTION'};
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'En cours': return const Color(0xFFF57C00);
      case 'Nouveau':
      case 'Nouvelle Demande': return const Color(0xFF1976D2);
      case 'Terminé': return const Color(0xFF388E3C);
      case 'En attente': return const Color(0xFF7B1FA2);
      default: return Colors.black54;
    }
  }

  Widget _buildPriorityBadge(int priorityLevel) {
    Color pColor; String pLabel; IconData pIcon;
    switch(priorityLevel) {
      case 3: pColor = const Color(0xFFD32F2F); pLabel = "URGENT"; pIcon = Icons.warning_rounded; break;
      case 2: pColor = const Color(0xFFF57C00); pLabel = "HAUT"; pIcon = Icons.priority_high_rounded; break;
      case 1: pColor = const Color(0xFF1976D2); pLabel = "NORMAL"; pIcon = Icons.drag_handle_rounded; break;
      default: pColor = const Color(0xFF616161); pLabel = "BAS"; pIcon = Icons.arrow_downward_rounded; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: pColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pIcon, size: 12, color: pColor),
          const SizedBox(width: 4),
          Text(pLabel, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: pColor)),
        ],
      ),
    );
  }

  // --- 🚀 PREMIUM LONG PRESS MENU ---
  void _showLongPressMenu(BuildContext context, String docId, String storeName, String? flashNote) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true, // 🚀 FIX 1: Allows sheet to adapt to its full content height
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              // 🚀 FIX 2: Wrapped in SingleChildScrollView to completely prevent Overflow crashes on small screens
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 48, height: 5, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                      Text(storeName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87)),
                      const SizedBox(height: 12),
                      const Divider(indent: 24, endIndent: 24),

                      ListTile(
                        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.amber.shade50, shape: BoxShape.circle), child: const Icon(Icons.flash_on_rounded, color: Colors.amber)),
                        title: Text("Mettre à jour le statut (Flash)", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onFlashUpdate(docId, flashNote);
                        },
                      ),

                      if (widget.canPrioritize) ...[
                        const Divider(indent: 24, endIndent: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Align(alignment: Alignment.centerLeft, child: Text("NIVEAU DE PRIORITÉ", style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0))),
                        ),
                        _buildMenuOption(context, "Urgence absolue", "🚨", () => widget.onPrioritize(docId, 3)),
                        _buildMenuOption(context, "Haute priorité", "⬆️", () => widget.onPrioritize(docId, 2)),
                        _buildMenuOption(context, "Priorité normale", "➖", () => widget.onPrioritize(docId, 1)),
                        _buildMenuOption(context, "Basse priorité", "⬇️", () => widget.onPrioritize(docId, 0)),
                      ],

                      if (widget.canDelete) ...[
                        const Divider(indent: 24, endIndent: 24),
                        ListTile(
                          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle), child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700)),
                          title: Text("Supprimer l'intervention", style: GoogleFonts.plusJakartaSans(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onDelete(docId, storeName);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }
    );
  }

  ListTile _buildMenuOption(BuildContext context, String title, String emoji, VoidCallback onTap) {
    return ListTile(
      leading: Padding(padding: const EdgeInsets.only(left: 8.0), child: Text(emoji, style: const TextStyle(fontSize: 22))),
      title: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.black87)),
      dense: true,
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final data = widget.doc.data();
    final String docId = widget.doc.id;

    final String storeName = data['storeName'] ?? 'Magasin Inconnu';
    final String clientName = data['clientName'] ?? 'Client Inconnu';
    final String interventionCode = data['interventionCode'] ?? 'INT-XX';
    final String status = data['status'] ?? 'Inconnu';
    final DateTime? createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final String formattedDate = createdAt != null ? DateFormat('dd MMM yyyy à HH:mm', 'fr').format(createdAt) : 'N/A';

    final String? clientId = data['clientId'];
    final String? storeId = data['storeId'];
    final DateTime? scheduledAt = (data['scheduledAt'] as Timestamp?)?.toDate();
    final String? type = data['interventionType'];
    final String? billingStatus = data['billingStatus'];
    final bool isPinned = data['isPinned'] ?? false;
    final int priorityLevel = data['priorityLevel'] ?? 1;

    final style = _getInterventionStyle(type, billingStatus);
    final Color themeColor = style['color'];
    final IconData themeIcon = style['icon'];

    final String? flashNote = data['lastFollowUpNote'];
    final DateTime? flashDate = (data['lastFollowUpDate'] as Timestamp?)?.toDate();
    final bool hasFlash = flashNote != null && flashNote.isNotEmpty;

    // Scale Logic for 2026 feel
    final scale = _isTapped ? 0.96 : (_isHovered ? 1.015 : 1.0);

    Widget glassCard = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isTapped = true),
        onTapUp: (_) => setState(() => _isTapped = false),
        onTapCancel: () => setState(() => _isTapped = false),
        onLongPress: () => _showLongPressMenu(context, docId, storeName, flashNote),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => InterventionDetailsPage(interventionDoc: widget.doc)));
        },
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutExpo,
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(color: themeColor.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 15)),
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.2)],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Watermark Ambient Icon
                      Positioned(
                        bottom: -40,
                        right: -40,
                        child: Transform.rotate(
                          angle: -0.2,
                          child: Icon(themeIcon, size: 220, color: themeColor.withOpacity(0.05)),
                        ),
                      ),

                      if (isPinned)
                        Positioned(
                          top: 24,
                          right: 24,
                          child: Icon(Icons.push_pin_rounded, color: Colors.redAccent.shade200, size: 22),
                        ),

                      // Left Glowing Indicator Bar
                      Positioned(
                        left: 0, top: 0, bottom: 0,
                        child: Container(
                          width: 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [themeColor.withOpacity(0.9), themeColor.withOpacity(0.4)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                          ),
                        ),
                      ),

                      // Main Content safely wrapped
                      Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- TOP ROW: Tags ---
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: themeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(themeIcon, size: 14, color: themeColor),
                                        const SizedBox(width: 6),
                                        Text(style['label'], style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: themeColor)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (priorityLevel != 1) _buildPriorityBadge(priorityLevel),
                                  const Spacer(),
                                  if (!isPinned)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                      child: Text(status.toUpperCase(), style: GoogleFonts.plusJakartaSans(color: _getStatusColor(status), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // --- MIDDLE ROW: Logos & Titles ---
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StoreLogoFetcher(
                                    clientId: clientId,
                                    storeId: storeId,
                                    fallback: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.7),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                                      ),
                                      child: Icon(Icons.storefront_rounded, size: 26, color: themeColor.withOpacity(0.8)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Link behavior
                                        InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: () {
                                            if (clientId != null && storeId != null && clientId.isNotEmpty && storeId.isNotEmpty) {
                                              Navigator.push(context, MaterialPageRoute(builder: (_) => StoreEquipmentPage(clientId: clientId, storeId: storeId, storeName: storeName)));
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    storeName,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: isMobile ? 18 : 22,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.black87,
                                                      letterSpacing: -0.5,
                                                      height: 1.2,
                                                    ),
                                                    maxLines: isMobile ? 3 : 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 6.0),
                                                  child: Icon(Icons.arrow_outward_rounded, size: 16, color: Colors.blue.shade600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "$clientName  •  $interventionCode",
                                          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600),
                                          maxLines: isMobile ? 2 : 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // --- BOTTOM ROW: Schedule & Flash Note ---
                              if (scheduledAt != null) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.event_rounded, size: 18, color: Colors.blue.shade700),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Prévu : ${DateFormat('dd MMM yyyy - HH:mm', 'fr').format(scheduledAt)}",
                                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.blue.shade900),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              if (hasFlash)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.tips_and_updates_rounded, size: 20, color: Color(0xFFE65100)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              flashNote,
                                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black87, fontWeight: FontWeight.w600),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (flashDate != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            "Mis à jour ${timeago.format(flashDate, locale: 'fr')}",
                                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Icon(Icons.schedule_rounded, size: 16, color: Colors.black38),
                                    const SizedBox(width: 8),
                                    Text(
                                      formattedDate,
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                            ],
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
    );

    if (widget.canPrioritize) {
      return Dismissible(
        key: Key('swipe_$docId'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          widget.onTogglePin(docId, isPinned);
          return false;
        },
        background: Container(
          decoration: BoxDecoration(
            color: isPinned ? Colors.black87 : const Color(0xFF4A65E6),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 32),
          child: Row(
            children: [
              Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(isPinned ? "Désépingler" : "Épingler", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        child: glassCard,
      );
    }
    return glassCard;
  }
}

// -----------------------------------------------------------------------------
// 🏢 LOGO FETCHER WIDGET
// -----------------------------------------------------------------------------
class StoreLogoFetcher extends StatelessWidget {
  final String? clientId;
  final String? storeId;
  final Widget fallback;

  const StoreLogoFetcher({
    super.key,
    required this.clientId,
    required this.storeId,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (clientId == null || storeId == null || clientId!.isEmpty || storeId!.isEmpty) return fallback;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('clients').doc(clientId).collection('stores').doc(storeId).get(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final String? logoUrl = data?['logoUrl'];

          if (logoUrl != null && logoUrl.isNotEmpty) {
            return CachedNetworkImage(
              imageUrl: logoUrl,
              imageBuilder: (context, imageProvider) => Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
                  image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                ),
              ),
              placeholder: (context, url) => fallback,
              errorWidget: (context, url, error) => fallback,
            );
          }
        }
        return fallback;
      },
    );
  }
}
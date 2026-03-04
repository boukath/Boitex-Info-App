// lib/screens/home/notifications_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/models/mission.dart';
import 'package:boitex_info_app/models/channel_model.dart';

import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_timeline_page.dart';

import 'package:boitex_info_app/screens/administration/project_details_page.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';
import 'package:boitex_info_app/screens/announce/announce_hub_page.dart';
import 'package:boitex_info_app/screens/announce/channel_chat_page.dart';
import 'package:boitex_info_app/screens/administration/rappel_page.dart';
import 'package:boitex_info_app/screens/administration/mission_details_page.dart';
import 'package:boitex_info_app/screens/administration/portal_request_details_page.dart';
import 'package:boitex_info_app/screens/fleet/fleet_list_page.dart';
import 'package:boitex_info_app/screens/dashboard/morning_briefing_summary_page.dart';

// ✅ HELPER CLASS FOR GROUPING
class NotificationGroup {
  final String docId;
  final String collection;
  final String type;
  final List<DocumentSnapshot> events;
  final DateTime latestTimestamp;
  final bool hasUnread;

  NotificationGroup({
    required this.docId,
    required this.collection,
    this.type = '',
    required this.events,
    required this.latestTimestamp,
    required this.hasUnread,
  });
}

// ✅ HELPER CLASS FOR STATUS STYLING
class _StatusAttributes {
  final Color color;
  final Color bgColor;
  final String label;
  final IconData badgeIcon;

  _StatusAttributes({
    required this.color,
    required this.bgColor,
    required this.label,
    required this.badgeIcon,
  });
}

class NotificationsPage extends StatefulWidget {
  final String userRole;

  const NotificationsPage({
    super.key,
    required this.userRole,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String? _userId;
  bool _isLoading = false;

  final Color _primaryBlue = const Color(0xFF007AFF); // iOS Blue
  final Color _textDark = const Color(0xFF1C1C1E);
  final Color _textGrey = const Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }

  List<NotificationGroup> _groupNotifications(List<QueryDocumentSnapshot> docs) {
    Map<String, List<DocumentSnapshot>> groups = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String key = data['relatedDocId'] ?? doc.id;

      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(doc);
    }

    List<NotificationGroup> groupList = [];
    groups.forEach((key, events) {
      events.sort((a, b) {
        final tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
        final tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
        return (tB?.toDate() ?? DateTime(0)).compareTo(tA?.toDate() ?? DateTime(0));
      });

      final latestDoc = events.first.data() as Map<String, dynamic>;
      final hasUnread = events.any((e) => (e.data() as Map<String, dynamic>)['isRead'] == false);

      groupList.add(NotificationGroup(
        docId: key,
        collection: latestDoc['relatedCollection'] ?? 'unknown',
        type: latestDoc['type'] ?? '',
        events: events,
        latestTimestamp: (latestDoc['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        hasUnread: hasUnread,
      ));
    });

    groupList.sort((a, b) => b.latestTimestamp.compareTo(a.latestTimestamp));
    return groupList;
  }

  String _formatSmartDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 24) {
      return timeago.format(date, locale: 'fr');
    } else {
      return DateFormat('d MMM à HH:mm', 'fr').format(date);
    }
  }

  Future<void> _deleteNotificationGroup(NotificationGroup group) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in group.events) {
      batch.delete(doc.reference);
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Notifications supprimées", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: _textDark.withOpacity(0.9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              duration: const Duration(seconds: 2),
            )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _cleanTitle(String title) {
    final prefixes = ["Mise à jour :", "Mise à jour", "Update:", "Notification:", "Rappel :"];
    String clean = title;
    for (var prefix in prefixes) {
      if (clean.toLowerCase().startsWith(prefix.toLowerCase())) {
        clean = clean.substring(prefix.length).trim();
      }
    }
    if (clean.isNotEmpty) clean = clean[0].toUpperCase() + clean.substring(1);
    return clean;
  }

  _StatusAttributes _getStatusAttributes(String body, String type) {
    final lowerBody = body.toLowerCase();

    if (type == 'morning_briefing') {
      return _StatusAttributes(
        color: Colors.amber.shade800,
        bgColor: Colors.amber.shade50,
        label: "BRIEFING",
        badgeIcon: Icons.wb_sunny_rounded,
      );
    }

    if (type == 'reminder') {
      if (lowerBody.contains("vidange") || lowerBody.contains("oil change")) {
        if (lowerBody.contains("🚨") || lowerBody.contains("critique") || lowerBody.contains("1000")) {
          return _StatusAttributes(color: const Color(0xFFD50000), bgColor: const Color(0xFFFFEBEE), label: "VIDANGE URGENTE", badgeIcon: Icons.water_drop_rounded);
        }
        return _StatusAttributes(color: const Color(0xFFFF6D00), bgColor: const Color(0xFFFFF3E0), label: "VIDANGE BIENTÔT", badgeIcon: Icons.water_drop_outlined);
      }
      return _StatusAttributes(color: const Color(0xFFFFD600), bgColor: const Color(0xFFFFF9C4), label: "RAPPEL KILOMÉTRAGE", badgeIcon: Icons.speed_rounded);
    }

    if (lowerBody.contains("terminé") || lowerBody.contains("clôturé") || lowerBody.contains("livré") || lowerBody.contains("validé")) {
      // YOUR CUSTOM GREEN
      return _StatusAttributes(color: const Color(0xFF1B5E20), bgColor: const Color(0xFFE8F5E9), label: "TERMINÉ", badgeIcon: Icons.check_circle_rounded);
    } else if (lowerBody.contains("en cours") || lowerBody.contains("démarré") || lowerBody.contains("traitement") || lowerBody.contains("update") || lowerBody.contains("mise à jour")) {
      // YOUR CUSTOM ORANGE
      return _StatusAttributes(color: const Color(0xFFE65100), bgColor: const Color(0xFFFFF3E0), label: "EN COURS", badgeIcon: Icons.schedule_rounded);
    } else if (lowerBody.contains("urgent") || lowerBody.contains("problème") || lowerBody.contains("panne")) {
      // YOUR CUSTOM RED
      return _StatusAttributes(color: const Color(0xFFB71C1C), bgColor: const Color(0xFFFFEBEE), label: "URGENT", badgeIcon: Icons.warning_rounded);
    } else {
      // YOUR CUSTOM BLUE
      return _StatusAttributes(color: const Color(0xFF2962FF), bgColor: const Color(0xFFE3F2FD), label: "NOUVEAU", badgeIcon: Icons.info_rounded);
    }
  }

  // ✅ BRING BACK YOUR GRADIENT FUNCTION
  LinearGradient _getGradientForStatus(_StatusAttributes status) {
    return LinearGradient(
      colors: [status.color.withOpacity(0.85), status.color],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Widget _buildStatusPill(_StatusAttributes status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: status.bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(
        status.label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: status.color, letterSpacing: 0.5),
      ),
    );
  }

  IconData _getIconForCollection(String? collection) {
    switch (collection) {
      case 'portal_requests': return Icons.lock_clock;
      case 'interventions': return Icons.handyman_rounded;
      case 'installations': return Icons.router_rounded;
      case 'sav_tickets': return Icons.assignment_return_rounded;
      case 'missions': return Icons.location_on_rounded;
      case 'livraisons': return Icons.local_shipping_rounded;
      case 'requisitions': return Icons.shopping_cart_rounded;
      case 'projects': return Icons.folder_shared_rounded;
      case 'channels': return Icons.forum_rounded;
      case 'reminders': return Icons.alarm_rounded;
      case 'vehicles': return Icons.directions_car_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Future<void> _navigateToDetails(String? collection, String? docId, String type, List<DocumentSnapshot> groupEvents) async {
    for (var doc in groupEvents) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isRead'] == false) {
        FirebaseFirestore.instance.collection('user_notifications').doc(doc.id).update({'isRead': true});
      }
    }

    if (type == 'morning_briefing') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MorningBriefingSummaryPage()));
      return;
    }

    if (type == 'reminder' && collection == 'vehicles') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FleetListPage()));
      return;
    }

    if (collection == null || docId == null) return;

    setState(() => _isLoading = true);

    // Modern iOS Loading overlay
    showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.2),
        builder: (ctx) => Center(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
                child: const CircularProgressIndicator(color: Colors.black87, strokeWidth: 3),
              ),
            )
        )
    );

    try {
      Widget? pageToNavigate;

      if (collection == 'portal_requests') {
        final doc = await FirebaseFirestore.instance.collection('interventions').doc(docId).get().timeout(const Duration(seconds: 10));
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? '';
          if (status == 'En Attente Validation') {
            pageToNavigate = PortalRequestDetailsPage(interventionId: docId);
          } else {
            pageToNavigate = InterventionDetailsPage(interventionDoc: doc);
          }
        }
      } else if (['interventions', 'sav_tickets', 'installations', 'projects', 'livraisons', 'requisitions', 'missions'].contains(collection)) {
        final doc = await FirebaseFirestore.instance.collection(collection!).doc(docId).get().timeout(const Duration(seconds: 10));
        if (!doc.exists) throw Exception("Ce document n'existe plus.");

        switch (collection) {
          case 'interventions': pageToNavigate = InterventionDetailsPage(interventionDoc: doc); break;
          case 'sav_tickets': pageToNavigate = SavTicketDetailsPage(ticket: SavTicket.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)); break;
          case 'installations':
            final data = doc.data() as Map<String, dynamic>;
            if (data['status'] == 'En Cours') {
              pageToNavigate = InstallationTimelinePage(installationId: docId, installationData: data);
            } else {
              pageToNavigate = InstallationDetailsPage(installationDoc: doc, userRole: widget.userRole);
            }
            break;
          case 'projects': pageToNavigate = ProjectDetailsPage(projectId: docId, userRole: widget.userRole); break;
          case 'livraisons': pageToNavigate = LivraisonDetailsPage(livraisonId: docId); break;
          case 'requisitions': pageToNavigate = RequisitionDetailsPage(requisitionId: docId, userRole: widget.userRole); break;
          case 'missions': pageToNavigate = MissionDetailsPage(mission: Mission.fromFirestore(doc)); break;
        }
      } else if (collection == 'channels') {
        final doc = await FirebaseFirestore.instance.collection('channels').doc(docId).get().timeout(const Duration(seconds: 10));
        pageToNavigate = doc.exists ? ChannelChatPage(channel: ChannelModel.fromFirestore(doc)) : const AnnounceHubPage();
      } else if (collection == 'reminders') pageToNavigate = const RappelPage();
      else if (collection == 'vehicles') pageToNavigate = const FleetListPage();

      if (mounted) {
        Navigator.of(context).pop();
        if (pageToNavigate != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => pageToNavigate!));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Page de détails introuvable.')));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =======================================================================
  // UI BUILDERS (Vibrant iOS 26 Aesthetic)
  // =======================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // Base iOS background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.5)),
        centerTitle: false,
        backgroundColor: Colors.white.withOpacity(0.5),
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.white.withOpacity(0.2)),
          ),
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 22), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          //  1. VIBRANT MESH BACKGROUND (Absolute positioning for performance)
          Positioned(
              top: -100, left: -100,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFF2D55).withOpacity(0.15))),
              )
          ),
          Positioned(
              bottom: -50, right: -50,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF007AFF).withOpacity(0.15))),
              )
          ),
          Positioned(
              top: 300, right: -150,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFAF52DE).withOpacity(0.15))),
              )
          ),
          // 📄 2. CONTENT LAYER
          SafeArea(
            child: _userId == null
                ? Center(child: Text("Erreur: Non connecté", style: GoogleFonts.inter(color: Colors.red)))
                : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('user_notifications').where('userId', isEqualTo: _userId).orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: _primaryBlue));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

                final groups = _groupNotifications(snapshot.data!.docs);

                // 🌐 Web Adaptability (MaxWidth 750)
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 750),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      itemCount: groups.length,
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return Dismissible(
                          key: Key(groups[index].docId),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 28),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFF3B30), Color(0xFFFF453A)]),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 32),
                          ),
                          onDismissed: (direction) => _deleteNotificationGroup(groups[index]),
                          child: _buildGlassCard(groups[index]),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(NotificationGroup group) {
    final latestData = group.events.first.data() as Map<String, dynamic>;
    final String rawTitle = latestData['title'] ?? 'Notification';
    final String rawBody = latestData['body'] ?? '';
    final String cleanTitle = _cleanTitle(rawTitle);
    final int count = group.events.length;
    final status = _getStatusAttributes(rawBody, group.type);

    String categoryName = group.collection.toUpperCase();
    if (group.collection == 'sav_tickets') categoryName = "SERVICE APRÈS-VENTE";
    if (group.collection == 'portal_requests') categoryName = "DEMANDE CLIENT";
    if (group.collection == 'vehicles') categoryName = "GESTION PARC";
    if (group.type == 'morning_briefing') categoryName = "QUOTIDIEN";
    if (group.type == 'reminder') categoryName = "MAINTENANCE FLOTTE";

    IconData mainIcon = _getIconForCollection(group.collection);
    if (group.type == 'reminder' && (rawBody.toLowerCase().contains('vidange') || rawBody.toLowerCase().contains('oil'))) {
      mainIcon = Icons.oil_barrel_outlined;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25), // Intense Glass Blur
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.65), // Frosted White Base
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _navigateToDetails(group.collection, group.docId, group.type, group.events),
                highlightColor: Colors.black.withOpacity(0.05),
                splashColor: Colors.black.withOpacity(0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ YOUR COLORED GRADIENT HEADER IS BACK!
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: _getGradientForStatus(status),
                      ),
                      child: Row(
                        children: [
                          Icon(mainIcon, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              categoryName,
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (group.hasUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                "NON LU",
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                              _formatSmartDate(group.latestTimestamp),
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600)
                          ),
                        ],
                      ),
                    ),

                    // MAIN CONTENT
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SMART AVATAR (Glass Styled)
                          _StoreLogoAvatar(
                            collection: group.collection,
                            type: group.type,
                            data: latestData,
                            status: status,
                            defaultIcon: mainIcon,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cleanTitle, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark, height: 1.2, letterSpacing: -0.3)),
                                const SizedBox(height: 8),
                                Text(rawBody, style: GoogleFonts.inter(fontSize: 14, color: _textGrey.withOpacity(0.9), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildStatusPill(status),
                                    if (count > 1) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                                        child: Text("+${count - 1} updates", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _textGrey)),
                                      )
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Icon(Icons.check_circle_outline_rounded, size: 60, color: Colors.black.withOpacity(0.2)),
          ),
          const SizedBox(height: 24),
          Text('All Caught Up', style: GoogleFonts.inter(fontSize: 22, color: _textDark, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('You have no new notifications.', style: GoogleFonts.inter(fontSize: 15, color: _textGrey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ============================================================================
// ✅ THE SMART STORE LOGO AVATAR (Redesigned for Glassmorphism)
// ============================================================================
class _StoreLogoAvatar extends StatefulWidget {
  final String collection;
  final String type;
  final Map<String, dynamic> data;
  final _StatusAttributes status;
  final IconData defaultIcon;

  const _StoreLogoAvatar({
    required this.collection,
    required this.type,
    required this.data,
    required this.status,
    required this.defaultIcon,
  });

  @override
  State<_StoreLogoAvatar> createState() => _StoreLogoAvatarState();
}

class _StoreLogoAvatarState extends State<_StoreLogoAvatar> {
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _fetchLogo();
  }

  Future<void> _fetchLogo() async {
    if (widget.type == 'morning_briefing') return;
    if (!['interventions', 'installations', 'sav_tickets', 'livraisons', 'portal_requests'].contains(widget.collection)) return;

    try {
      String? storeId = widget.data['storeId'];
      String? clientId = widget.data['clientId'];

      if (storeId == null && widget.data['relatedDocId'] != null) {
        final relatedDocRef = await FirebaseFirestore.instance
            .collection(widget.collection == 'portal_requests' ? 'interventions' : widget.collection)
            .doc(widget.data['relatedDocId'])
            .get();

        if (relatedDocRef.exists) {
          storeId = relatedDocRef.data()?['storeId'];
          clientId = relatedDocRef.data()?['clientId'];
        }
      }

      if (clientId != null && storeId != null) {
        final storeDoc = await FirebaseFirestore.instance.collection('clients').doc(clientId).collection('stores').doc(storeId).get();

        if (storeDoc.exists && storeDoc.data()?['logoUrl'] != null) {
          final fetchedUrl = storeDoc.data()!['logoUrl'] as String;
          if (fetchedUrl.isNotEmpty && mounted) {
            setState(() {
              _logoUrl = fetchedUrl;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching store logo for notification: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == 'morning_briefing') {
      return Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFFF9500).withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
        ),
        child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFFFF9500), size: 30),
      );
    }

    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: widget.status.bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 2), // Thick white rim
        boxShadow: [BoxShadow(color: widget.status.color.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: _logoUrl != null
          ? ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: _logoUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: widget.status.color.withOpacity(0.5))),
          errorWidget: (context, url, error) => Icon(widget.defaultIcon, color: widget.status.color.withOpacity(0.85), size: 28),
        ),
      )
          : Icon(widget.defaultIcon, color: widget.status.color.withOpacity(0.85), size: 28),
    );
  }
}
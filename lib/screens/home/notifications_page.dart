// lib/screens/home/notifications_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // ✅ REQUIRED FOR DATE FORMATTING

// ✅ IMPORTS
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/models/mission.dart'; // Mission Model
import 'package:boitex_info_app/models/channel_model.dart'; // Channel Model

import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
// ✅ NEW IMPORT: For Smart Navigation to Timeline
import 'package:boitex_info_app/screens/service_technique/installation_timeline_page.dart';

import 'package:boitex_info_app/screens/administration/project_details_page.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';
import 'package:boitex_info_app/screens/announce/announce_hub_page.dart';
import 'package:boitex_info_app/screens/announce/channel_chat_page.dart'; // Chat Page
import 'package:boitex_info_app/screens/administration/rappel_page.dart';
import 'package:boitex_info_app/screens/administration/mission_details_page.dart'; // Mission Details

// ✅ NEW IMPORT: For Portal Request Validation
import 'package:boitex_info_app/screens/administration/portal_request_details_page.dart';

// ✅ NEW IMPORT: For Fleet Navigation
import 'package:boitex_info_app/screens/fleet/fleet_list_page.dart';

// ✅ HELPER CLASS FOR GROUPING
class NotificationGroup {
  final String docId;
  final String collection;
  final List<DocumentSnapshot> events;
  final DateTime latestTimestamp;
  final bool hasUnread;

  NotificationGroup({
    required this.docId,
    required this.collection,
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
  // ignore: unused_field
  bool _isLoading = false;

  // 🎨 Theme Colors (Premium Palette)
  final Color _bgLight = const Color(0xFFF0F2F5);
  final Color _cardWhite = Colors.white;
  final Color _primaryBlue = const Color(0xFF2962FF);
  final Color _textDark = const Color(0xFF111111);
  final Color _textGrey = const Color(0xFF616161);

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }

  /// ✅ GROUPING LOGIC
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
        events: events,
        latestTimestamp: (latestDoc['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        hasUnread: hasUnread,
      ));
    });

    groupList.sort((a, b) => b.latestTimestamp.compareTo(a.latestTimestamp));
    return groupList;
  }

  /// ✅ SMART DATE FORMATTING LOGIC
  /// Returns "TimeAgo" if < 24h, otherwise explicit Date/Time
  String _formatSmartDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 24) {
      return timeago.format(date, locale: 'fr');
    } else {
      // Example: "24 janv. à 14:30"
      return DateFormat('d MMM à HH:mm', 'fr').format(date);
    }
  }

  /// ✅ BATCH DELETE LOGIC (SWIPE ACTION)
  Future<void> _deleteNotificationGroup(NotificationGroup group) async {
    final batch = FirebaseFirestore.instance.batch();

    // Delete all individual notifications in this group
    for (var doc in group.events) {
      batch.delete(doc.reference);
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Notifications supprimées"),
              behavior: SnackBarBehavior.floating,
              backgroundColor: _textDark,
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

  /// ✅ PARSING LOGIC: Cleans up title
  String _cleanTitle(String title) {
    final prefixes = [
      "Mise à jour :", "Mise à jour", "Update:", "Notification:", "Rappel :"
    ];

    String clean = title;
    for (var prefix in prefixes) {
      if (clean.toLowerCase().startsWith(prefix.toLowerCase())) {
        clean = clean.substring(prefix.length).trim();
      }
    }
    if (clean.isNotEmpty) {
      clean = clean[0].toUpperCase() + clean.substring(1);
    }
    return clean;
  }

  /// ✅ CENTRALIZED STATUS LOGIC
  _StatusAttributes _getStatusAttributes(String body) {
    final lowerBody = body.toLowerCase();

    if (lowerBody.contains("terminé") || lowerBody.contains("clôturé") || lowerBody.contains("livré") || lowerBody.contains("validé")) {
      return _StatusAttributes(
        color: const Color(0xFF1B5E20), // Green
        bgColor: const Color(0xFFE8F5E9),
        label: "TERMINÉ",
        badgeIcon: Icons.check_circle_rounded,
      );
    } else if (lowerBody.contains("en cours") || lowerBody.contains("démarré") || lowerBody.contains("traitement") || lowerBody.contains("update") || lowerBody.contains("mise à jour")) {
      return _StatusAttributes(
        color: const Color(0xFFE65100), // Orange
        bgColor: const Color(0xFFFFF3E0),
        label: "EN COURS",
        badgeIcon: Icons.schedule_rounded,
      );
    } else if (lowerBody.contains("urgent") || lowerBody.contains("problème") || lowerBody.contains("panne")) {
      return _StatusAttributes(
        color: const Color(0xFFB71C1C), // Red
        bgColor: const Color(0xFFFFEBEE),
        label: "URGENT",
        badgeIcon: Icons.warning_rounded,
      );
    } else {
      return _StatusAttributes(
        color: const Color(0xFF2962FF), // Blue
        bgColor: const Color(0xFFE3F2FD),
        label: "NOUVEAU",
        badgeIcon: Icons.info_rounded,
      );
    }
  }

  /// ✅ HELPER: Generate Gradient based on Status Color
  LinearGradient _getGradientForStatus(_StatusAttributes status) {
    return LinearGradient(
      colors: [
        status.color.withOpacity(0.85), // Slightly lighter start
        status.color,                   // Solid color end
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// ✅ DYNAMIC STORYTELLER ICON
  Widget _buildDynamicStoryIcon(String collection, String body) {
    final status = _getStatusAttributes(body);
    final IconData mainIcon = _getIconForCollection(collection);

    return Stack(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: status.bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: status.color.withOpacity(0.15), width: 1.5),
          ),
          child: Icon(
            mainIcon,
            color: status.color.withOpacity(0.85),
            size: 24,
          ),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            padding: const EdgeInsets.all(2), // White border effect
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: status.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: status.color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Icon(
                status.badgeIcon,
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ✅ STATUS PILL
  Widget _buildStatusPill(_StatusAttributes status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: status.color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  IconData _getIconForCollection(String? collection) {
    switch (collection) {
      case 'portal_requests': return Icons.lock_clock; // Special Icon for Requests
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

  // ✅ NAVIGATION LOGIC (UPDATED WITH SMART REDIRECT)
  Future<void> _navigateToDetails(String? collection, String? docId, List<DocumentSnapshot> groupEvents) async {
    for (var doc in groupEvents) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isRead'] == false) {
        FirebaseFirestore.instance.collection('user_notifications').doc(doc.id).update({'isRead': true});
      }
    }

    if (collection == null || docId == null) return;

    setState(() => _isLoading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      Widget? pageToNavigate;

      // ----------------------------------------------------------------------
      // 🚀 1. SPECIAL LOGIC: PORTAL REQUESTS
      // ----------------------------------------------------------------------
      if (collection == 'portal_requests') {
        final doc = await FirebaseFirestore.instance.collection('interventions').doc(docId).get()
            .timeout(const Duration(seconds: 10));

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? '';

          if (status == 'En Attente Validation') {
            pageToNavigate = PortalRequestDetailsPage(interventionId: docId);
          } else {
            pageToNavigate = InterventionDetailsPage(interventionDoc: doc);
          }
        } else {
          throw Exception("Cette demande n'existe plus.");
        }
      }

      // ----------------------------------------------------------------------
      // 2. STANDARD LOGIC
      // ----------------------------------------------------------------------
      else if (['interventions', 'sav_tickets', 'installations', 'projects', 'livraisons', 'requisitions', 'missions'].contains(collection)) {
        final doc = await FirebaseFirestore.instance.collection(collection!).doc(docId).get()
            .timeout(const Duration(seconds: 10));

        if (!doc.exists) throw Exception("Ce document n'existe plus.");

        switch (collection) {
          case 'interventions': pageToNavigate = InterventionDetailsPage(interventionDoc: doc); break;
          case 'sav_tickets':
            final ticket = SavTicket.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
            pageToNavigate = SavTicketDetailsPage(ticket: ticket);
            break;

        // ✅ SMART NAV: Installation Timeline vs Details
          case 'installations':
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'];
            // If "En Cours", we assume it's an active job needing the Timeline
            if (status == 'En Cours') {
              pageToNavigate = InstallationTimelinePage(
                installationId: docId,
                installationData: data,
              );
            } else {
              // Otherwise (Terminée, À Planifier, etc.), go to Details
              pageToNavigate = InstallationDetailsPage(installationDoc: doc, userRole: widget.userRole);
            }
            break;

          case 'projects': pageToNavigate = ProjectDetailsPage(projectId: docId, userRole: widget.userRole); break;
          case 'livraisons': pageToNavigate = LivraisonDetailsPage(livraisonId: docId); break;
          case 'requisitions': pageToNavigate = RequisitionDetailsPage(requisitionId: docId, userRole: widget.userRole); break;
          case 'missions':
            final mission = Mission.fromFirestore(doc);
            pageToNavigate = MissionDetailsPage(mission: mission);
            break;
        }
      }
      // ----------------------------------------------------------------------
      // 3. CHANNEL LOGIC (Direct Navigation to Chat)
      // ----------------------------------------------------------------------
      else if (collection == 'channels') {
        final doc = await FirebaseFirestore.instance.collection('channels').doc(docId).get()
            .timeout(const Duration(seconds: 10));

        if (doc.exists) {
          final channel = ChannelModel.fromFirestore(doc);
          pageToNavigate = ChannelChatPage(channel: channel);
        } else {
          // Fallback to Hub if the specific channel is gone
          pageToNavigate = const AnnounceHubPage();
        }
      }
      else if (collection == 'reminders') pageToNavigate = const RappelPage();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: false,
        backgroundColor: _bgLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _userId == null
          ? Center(child: Text("Erreur: Non connecté", style: GoogleFonts.poppins(color: Colors.red)))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_notifications')
            .where('userId', isEqualTo: _userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _primaryBlue));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final groups = _groupNotifications(snapshot.data!.docs);

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: groups.length,
            physics: const BouncingScrollPhysics(),
            separatorBuilder: (ctx, i) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              // ⚡⚡⚡ WRAP IN DISMISSIBLE FOR SWIPE-TO-DELETE
              return Dismissible(
                key: Key(groups[index].docId), // Unique Key for the Group
                direction: DismissDirection.endToStart, // Swipe Right to Left
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "Supprimer",
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                    ],
                  ),
                ),
                onDismissed: (direction) {
                  _deleteNotificationGroup(groups[index]);
                },
                child: _buildBigCard(groups[index]),
              );
            },
          );
        },
      ),
    );
  }

  // 🔥 "COMMAND CENTER" CARD LAYOUT
  Widget _buildBigCard(NotificationGroup group) {
    final latestData = group.events.first.data() as Map<String, dynamic>;
    final String rawTitle = latestData['title'] ?? 'Notification';
    final String rawBody = latestData['body'] ?? '';
    final String cleanTitle = _cleanTitle(rawTitle);
    final int count = group.events.length;
    final status = _getStatusAttributes(rawBody); // Get status info

    // Determine category name from collection
    String categoryName = group.collection.toUpperCase();
    if (group.collection == 'sav_tickets') categoryName = "SERVICE APRÈS-VENTE";
    if (group.collection == 'portal_requests') categoryName = "DEMANDE CLIENT";
    if (group.collection == 'vehicles') categoryName = "GESTION PARC";

    return Container(
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => _navigateToDetails(group.collection, group.docId, group.events),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP HEADER BANNER (Updated Logic: Color by Status)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  // ⚡ CHANGED: Uses status color instead of collection color
                  gradient: _getGradientForStatus(status),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        categoryName,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (group.hasUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "NON LU", // ⚡ UPDATED: Changed from "NOUVEAU" to "NON LU"
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 2. HERO CONTENT
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic Icon (Matches Status Color)
                    _buildDynamicStoryIcon(group.collection, rawBody),

                    const SizedBox(width: 16),

                    // TEXT CONTENT
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cleanTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildStatusPill(status),
                              if (count > 1) ...[
                                const SizedBox(width: 8),
                                Text(
                                  "+${count - 1} maj",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _textGrey,
                                  ),
                                ),
                              ]
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            rawBody,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _textGrey,
                              height: 1.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 0),
              Divider(color: Colors.grey.shade100, thickness: 1.5, height: 1),

              // 3. ACTION FOOTER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: _textGrey.withOpacity(0.6)),
                    const SizedBox(width: 6),
                    // ⚡⚡⚡ UPDATED: Uses Smart Date Logic
                    Text(
                      _formatSmartDate(group.latestTimestamp),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _textGrey.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "VOIR",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _primaryBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: _primaryBlue),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Icon(Icons.mark_email_read_outlined, size: 50, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          Text(
            'Boîte de réception vide',
            style: GoogleFonts.poppins(fontSize: 18, color: _textDark, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tout est calme pour le moment.',
            style: GoogleFonts.poppins(fontSize: 14, color: _textGrey),
          ),
        ],
      ),
    );
  }
}
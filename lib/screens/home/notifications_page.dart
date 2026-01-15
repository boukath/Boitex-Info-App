// lib/screens/home/notifications_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';

// ✅ IMPORTS
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:boitex_info_app/screens/administration/project_details_page.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';
import 'package:boitex_info_app/screens/announce/announce_hub_page.dart';
import 'package:boitex_info_app/screens/administration/rappel_page.dart';

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
  final Color _bgLight = const Color(0xFFF0F2F5); // Slightly darker for contrast
  final Color _cardWhite = Colors.white;
  final Color _primaryBlue = const Color(0xFF2962FF);
  final Color _textDark = const Color(0xFF111111); // Darker black
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

  /// ✅ STATUS PILL LOGIC (Updated Style)
  Widget _buildStatusPill(String body) {
    Color pillColor = Colors.grey.shade100;
    Color textColor = Colors.grey.shade700;
    String statusText = "INFO";

    final lowerBody = body.toLowerCase();

    if (lowerBody.contains("terminé") || lowerBody.contains("clôturé") || lowerBody.contains("livré") || lowerBody.contains("validé")) {
      pillColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF1B5E20);
      statusText = "TERMINÉ";
    } else if (lowerBody.contains("en cours") || lowerBody.contains("démarré") || lowerBody.contains("traitement")) {
      pillColor = const Color(0xFFFFF3E0);
      textColor = const Color(0xFFE65100);
      statusText = "EN COURS";
    } else if (lowerBody.contains("nouveau") || lowerBody.contains("assigné") || lowerBody.contains("créé")) {
      pillColor = const Color(0xFFE3F2FD);
      textColor = const Color(0xFF0D47A1);
      statusText = "NOUVEAU";
    } else if (lowerBody.contains("urgent") || lowerBody.contains("problème") || lowerBody.contains("panne")) {
      pillColor = const Color(0xFFFFEBEE);
      textColor = const Color(0xFFB71C1C);
      statusText = "URGENT";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: pillColor,
        borderRadius: BorderRadius.circular(8), // Less rounded, more "tag" like
        border: Border.all(color: textColor.withOpacity(0.1)),
      ),
      child: Text(
        statusText,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  IconData _getIconForCollection(String? collection) {
    switch (collection) {
      case 'interventions': return Icons.handyman_rounded;
      case 'installations': return Icons.router_rounded;
      case 'sav_tickets': return Icons.assignment_return_rounded;
      case 'missions': return Icons.location_on_rounded;
      case 'livraisons': return Icons.local_shipping_rounded;
      case 'requisitions': return Icons.shopping_cart_rounded;
      case 'projects': return Icons.folder_shared_rounded;
      case 'channels': return Icons.forum_rounded;
      case 'reminders': return Icons.alarm_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  LinearGradient _getGradientForType(String? collection) {
    switch (collection) {
      case 'interventions': return const LinearGradient(colors: [Color(0xFFFF9966), Color(0xFFFF5E62)]);
      case 'missions': return const LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]);
      case 'installations': return const LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)]);
      case 'livraisons': return const LinearGradient(colors: [Color(0xFF00B09B), Color(0xFF96C93D)]);
      case 'sav_tickets': return const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]);
      case 'requisitions': return const LinearGradient(colors: [Color(0xFFB24592), Color(0xFFF15F79)]);
      case 'projects': return const LinearGradient(colors: [Color(0xFF0575E6), Color(0xFF021B79)]);
      case 'reminders': return const LinearGradient(colors: [Color(0xFFF2994A), Color(0xFFF2C94C)]);
      default: return const LinearGradient(colors: [Color(0xFF4B6CB7), Color(0xFF182848)]);
    }
  }

  // ✅ NAVIGATION LOGIC
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

      if (['interventions', 'sav_tickets', 'installations', 'projects', 'livraisons', 'requisitions'].contains(collection)) {
        final doc = await FirebaseFirestore.instance.collection(collection!).doc(docId).get()
            .timeout(const Duration(seconds: 10));

        if (!doc.exists) throw Exception("Ce document n'existe plus.");

        switch (collection) {
          case 'interventions': pageToNavigate = InterventionDetailsPage(interventionDoc: doc); break;
          case 'sav_tickets':
            final ticket = SavTicket.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
            pageToNavigate = SavTicketDetailsPage(ticket: ticket);
            break;
          case 'installations': pageToNavigate = InstallationDetailsPage(installationDoc: doc, userRole: widget.userRole); break;
          case 'projects': pageToNavigate = ProjectDetailsPage(projectId: docId, userRole: widget.userRole); break;
          case 'livraisons': pageToNavigate = LivraisonDetailsPage(livraisonId: docId); break;
          case 'requisitions': pageToNavigate = RequisitionDetailsPage(requisitionId: docId, userRole: widget.userRole); break;
        }
      }
      else if (collection == 'channels') pageToNavigate = const AnnounceHubPage();
      else if (collection == 'reminders') pageToNavigate = const RappelPage();

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
              return _buildBigCard(groups[index]);
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

    // Determine category name from collection
    String categoryName = group.collection.toUpperCase();
    if (group.collection == 'sav_tickets') categoryName = "SERVICE APRÈS-VENTE";

    return Container(
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(24), // Big rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // Deep soft shadow
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
              // 1. TOP HEADER BANNER (Gradient)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: _getGradientForType(group.collection),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getIconForCollection(group.collection),
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        categoryName,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (group.hasUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "NOUVEAU",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 2. HERO CONTENT
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleanTitle, // Big Store Name
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatusPill(rawBody),
                        if (count > 1) ...[
                          const SizedBox(width: 8),
                          Text(
                            "+${count - 1} maj",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _textGrey,
                            ),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      rawBody,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _textGrey,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              Divider(color: Colors.grey.shade100, thickness: 1.5),

              // 3. ACTION FOOTER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: _textGrey.withOpacity(0.6)),
                    const SizedBox(width: 6),
                    Text(
                      timeago.format(group.latestTimestamp, locale: 'fr'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _textGrey.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "VOIR LES DÉTAILS",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
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
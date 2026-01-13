// lib/screens/home/notifications_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart'; // ✅ Added for Premium Fonts

// ✅ IMPORTS (Kept Original)
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:boitex_info_app/screens/administration/project_details_page.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';
import 'package:boitex_info_app/screens/announce/announce_hub_page.dart';
import 'package:boitex_info_app/screens/administration/rappel_page.dart';

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
  final Color _bgLight = const Color(0xFFFAFAFA); // Ultra Clean White
  final Color _cardWhite = Colors.white;
  final Color _primaryBlue = const Color(0xFF2962FF); // Electric Blue
  final Color _textDark = const Color(0xFF1A1A1A);
  final Color _textGrey = const Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    if (_userId != null) {
      _markAllAsRead(_userId!);
    }
  }

  Future<void> _markAllAsRead(String uid) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('user_notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ Error marking read: $e');
    }
  }

  IconData _getIconForCollection(String? collection) {
    switch (collection) {
      case 'interventions': return Icons.build_circle_outlined;
      case 'sav_tickets': return Icons.support_agent_rounded;
      case 'installations': return Icons.settings_input_component_rounded;
      case 'projects': return Icons.folder_shared_rounded;
      case 'livraisons': return Icons.local_shipping_rounded;
      case 'requisitions': return Icons.shopping_bag_outlined;
      case 'channels': return Icons.campaign_rounded;
      case 'reminders': return Icons.notifications_active_rounded;
      default: return Icons.notifications_none_rounded;
    }
  }

  // Helper to get gradient color based on type
  LinearGradient _getGradientForType(String? collection) {
    switch (collection) {
      case 'reminders':
        return const LinearGradient(colors: [Color(0xFFFF9966), Color(0xFFFF5E62)]); // Orange
      case 'livraisons':
        return const LinearGradient(colors: [Color(0xFF00B09B), Color(0xFF96C93D)]); // Green
      case 'sav_tickets':
        return const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]); // Purple
      default:
        return const LinearGradient(colors: [Color(0xFF2962FF), Color(0xFF536DFE)]); // Blue
    }
  }

  // ✅ LOGIC (Kept exactly as requested)
  Future<void> _navigateToDetails(String? collection, String? docId) async {
    print("👉 START NAVIGATION: Collection: $collection, ID: $docId");

    if (collection == null || docId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Données de notification incomplètes.')),
        );
      }
      return;
    }

    // 1. Show Loading Dialog using State Context
    setState(() => _isLoading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      Widget? pageToNavigate;

      // 2. Fetch Data with TIMEOUT
      if (['interventions', 'sav_tickets', 'installations', 'projects', 'livraisons', 'requisitions'].contains(collection)) {

        print("⏳ Fetching document from Firestore...");

        final doc = await FirebaseFirestore.instance
            .collection(collection!)
            .doc(docId)
            .get()
            .timeout(const Duration(seconds: 10), onTimeout: () {
          throw Exception("Délai d'attente dépassé (Timeout). Vérifiez votre connexion.");
        });

        if (!doc.exists) {
          throw Exception("Ce document n'existe plus.");
        }

        print("✅ Document found! Type: $collection");

        switch (collection) {
          case 'interventions':
            pageToNavigate = InterventionDetailsPage(interventionDoc: doc);
            break;
          case 'sav_tickets':
            final ticket = SavTicket.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
            pageToNavigate = SavTicketDetailsPage(ticket: ticket);
            break;
          case 'installations':
            pageToNavigate = InstallationDetailsPage(installationDoc: doc, userRole: widget.userRole);
            break;
          case 'projects':
            pageToNavigate = ProjectDetailsPage(projectId: docId, userRole: widget.userRole);
            break;
          case 'livraisons':
            pageToNavigate = LivraisonDetailsPage(livraisonId: docId);
            break;
          case 'requisitions':
            pageToNavigate = RequisitionDetailsPage(requisitionId: docId, userRole: widget.userRole);
            break;
        }
      }
      else if (collection == 'channels') {
        pageToNavigate = const AnnounceHubPage();
      } else if (collection == 'reminders') {
        pageToNavigate = const RappelPage();
      }

      // 3. Navigation
      if (mounted) {
        Navigator.of(context).pop(); // 🛑 Close Spinner using State context

        if (pageToNavigate != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => pageToNavigate!));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Page de détails introuvable.')),
          );
        }
      }

    } catch (e) {
      print("❌ Error during navigation: $e");
      if (mounted) {
        Navigator.of(context).pop(); // 🛑 Close Spinner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceAll("Exception:", "")}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
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
          style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: false,
        backgroundColor: _bgLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
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

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: docs.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final isRead = data['isRead'] ?? false;
              final timestamp = data['timestamp'] as Timestamp?;

              return _buildNotificationCard(data, isRead, timestamp);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> data, bool isRead, Timestamp? timestamp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isRead ? 0.02 : 0.08), // Subtle shadow for read, stronger for unread
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: !isRead ? Border.all(color: _primaryBlue.withOpacity(0.1), width: 1.5) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _navigateToDetails(
            data['relatedCollection'],
            data['relatedDocId'],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Icon Container
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: _getGradientForType(data['relatedCollection']),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _getGradientForType(data['relatedCollection']).colors.first.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getIconForCollection(data['relatedCollection']),
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // 2. Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['title'] ?? 'Notification',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.bold, // Bolder for unread
                                color: isRead ? _textDark.withOpacity(0.8) : _textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(color: _primaryBlue, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data['body'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: _textGrey,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: _textGrey.withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(
                            timestamp != null ? timeago.format(timestamp.toDate(), locale: 'fr') : '',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: _textGrey.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Icon(Icons.notifications_off_outlined, size: 50, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucune notification',
            style: GoogleFonts.poppins(fontSize: 18, color: _textDark, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous êtes à jour !',
            style: GoogleFonts.poppins(fontSize: 14, color: _textGrey),
          ),
        ],
      ),
    );
  }
}
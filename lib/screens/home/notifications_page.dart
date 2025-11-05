// lib/screens/home/notifications_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

// ✅ ADDED: Imports for all your detail pages and models
import 'package:boitex_info_app/models/sav_ticket.dart'; // ✅ We need this model
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:boitex_info_app/screens/administration/project_details_page.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';
import 'package:boitex_info_app/screens/announce/announce_hub_page.dart';
import 'package:boitex_info_app/screens/administration/rappel_page.dart';
// Note: No detail pages were found for support_tickets or maintenance_it,
// so we will show a default message for those.

class NotificationsPage extends StatefulWidget {
  // ✅ ADDED: Accept the userRole
  final String userRole;

  const NotificationsPage({
    super.key,
    required this.userRole, // ✅ Make it required
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String? _userId;
  bool _isLoading = false; // ✅ ADDED: To show loading indicator during navigation

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    if (_userId != null) {
      _markAllAsRead(_userId!);
    }
  }

  /// Finds all unread notifications for the user and marks them as read
  Future<void> _markAllAsRead(String uid) async {
    // ... (This function remains unchanged)
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('user_notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return; // Nothing to mark
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      print('✅ Marked ${querySnapshot.docs.length} notifications as read.');
    } catch (e) {
      print('❌ Error marking notifications as read: $e');
    }
  }

  /// Returns a specific icon based on the notification type
  IconData _getIconForCollection(String? collection) {
    // ... (This function remains unchanged)
    switch (collection) {
      case 'interventions':
        return Icons.build_rounded;
      case 'sav_tickets':
        return Icons.support_agent_rounded;
      case 'installations':
        return Icons.construction_rounded;
      case 'projects':
        return Icons.assignment_rounded;
      case 'livraisons':
        return Icons.local_shipping_rounded;
      case 'requisitions':
        return Icons.shopping_cart_rounded;
      case 'channels':
        return Icons.campaign_rounded;
      case 'reminders':
        return Icons.alarm_rounded;
      case 'support_tickets':
        return Icons.headset_mic_rounded;
      case 'maintenance_it':
        return Icons.computer_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  // ✅ --- START: FULLY REVISED NAVIGATION LOGIC ---
  Future<void> _navigateToDetails(
      BuildContext context, String? collection, String? docId) async {
    if (collection == null || docId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Impossible de naviguer: Données manquantes.'),
        duration: Duration(seconds: 2),
      ));
      return;
    }

    // Show loading dialog
    setState(() => _isLoading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      Widget? pageToNavigate;

      switch (collection) {
        case 'interventions':
          final doc = await FirebaseFirestore.instance
              .collection('interventions')
              .doc(docId)
              .get();
          if (doc.exists) {
            // ✅ FIX: Pass the DocumentSnapshot to 'interventionDoc'
            pageToNavigate = InterventionDetailsPage(interventionDoc: doc);
          }
          break;

        case 'sav_tickets':
          final doc = await FirebaseFirestore.instance
              .collection('sav_tickets')
              .doc(docId)
              .get();
          if (doc.exists) {
            // ✅ FIX: Pass the entire doc to the factory constructor
            final ticket =
            SavTicket.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
            // ✅ FIX: Pass the 'ticket' object
            pageToNavigate = SavTicketDetailsPage(ticket: ticket);
          }
          break;

        case 'installations':
          final doc = await FirebaseFirestore.instance
              .collection('installations')
              .doc(docId)
              .get();
          if (doc.exists) {
            // ✅ FIX: Pass 'installationDoc' and 'userRole'
            pageToNavigate = InstallationDetailsPage(
              installationDoc: doc,
              userRole: widget.userRole,
            );
          }
          break;

        case 'projects':
        // ✅ FIX: Pass 'projectId' and 'userRole'
          pageToNavigate = ProjectDetailsPage(
            projectId: docId,
            userRole: widget.userRole,
          );
          break;

        case 'livraisons':
        // Assuming this page also only needs the ID.
        // If it fails, we'll need to fetch the doc like for interventions.
          pageToNavigate = LivraisonDetailsPage(livraisonId: docId);
          break;

        case 'requisitions':
        // ✅ FIX: Pass 'requisitionId' and 'userRole'
          pageToNavigate = RequisitionDetailsPage(
            requisitionId: docId,
            userRole: widget.userRole,
          );
          break;

        case 'channels':
          pageToNavigate = const AnnounceHubPage();
          break;

        case 'reminders':
          pageToNavigate = const RappelPage();
          break;

        default:
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Navigation non implémentée for "$collection"'),
            duration: const Duration(seconds: 2),
          ));
      }

      // Hide loading dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close the loading dialog
      }

      // Perform the navigation if a page was successfully built
      if (pageToNavigate != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => pageToNavigate!),
        );
      } else if (collection != 'reminders' && collection != 'channels') {
        // Show error if the doc wasn't found (but ignore for reminders/channels)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur: Document non trouvé.'),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      // Hide loading dialog on error
      if (mounted) {
        Navigator.of(context).pop();
      }
      print('❌ Error navigating to details: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: $e'),
        duration: const Duration(seconds: 2),
      ));
    } finally {
      setState(() => _isLoading = false);
    }
  }
  // ✅ --- END OF REVISED NAVIGATION LOGIC ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _userId == null
          ? const Center(
        child: Text("Erreur: Utilisateur non connecté."),
      )
          : StreamBuilder<QuerySnapshot>(
        // Query for all notifications for this user, newest first
        stream: FirebaseFirestore.instance
            .collection('user_notifications')
            .where('userId', isEqualTo: _userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return const Center(
              child: Text("Une erreur est survenue."),
            );
          }

          // Empty state
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // Data loaded state
          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final bool isRead = data['isRead'] ?? false;
              final String title = data['title'] ?? 'Sans Titre';
              final String body = data['body'] ?? '...';
              final Timestamp timestamp =
                  data['timestamp'] ?? Timestamp.now();
              final String? relatedCollection =
              data['relatedCollection'];
              final String? relatedDocId = data['relatedDocId'];

              return Column(
                children: [
                  ListTile(
                    isThreeLine: true,
                    leading: _buildLeadingIcon(isRead, relatedCollection),
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                        isRead ? FontWeight.normal : FontWeight.bold,
                        color: isRead ? Colors.grey[700] : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      '$body\n${timeago.format(timestamp.toDate(), locale: 'fr')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isRead ? Colors.grey[600] : Colors.black87,
                      ),
                    ),
                    // Disable tap while loading
                    onTap: _isLoading
                        ? null
                        : () => _navigateToDetails(
                      context,
                      relatedCollection,
                      relatedDocId,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// The icon on the left of the ListTile.
  Widget _buildLeadingIcon(bool isRead, String? collection) {
    // ... (This function remains unchanged)
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor:
          isRead ? Colors.grey[200] : Colors.blue.withOpacity(0.1),
          child: Icon(
            _getIconForCollection(collection),
            size: 20,
            color: isRead ? Colors.grey[600] : Colors.blue,
          ),
        ),
        if (!isRead)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  /// The widget to show when the list is empty.
  Widget _buildEmptyState() {
    // ... (This function remains unchanged)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 60,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'Votre boîte de réception est vide',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les nouvelles notifications apparaîtront ici.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
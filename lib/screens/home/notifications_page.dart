// lib/screens/home/notifications_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

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
      case 'interventions': return Icons.build_rounded;
      case 'sav_tickets': return Icons.support_agent_rounded;
      case 'installations': return Icons.construction_rounded;
      case 'projects': return Icons.assignment_rounded;
      case 'livraisons': return Icons.local_shipping_rounded;
      case 'requisitions': return Icons.shopping_cart_rounded;
      case 'channels': return Icons.campaign_rounded;
      case 'reminders': return Icons.alarm_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  // ✅ FIXED: Removed 'BuildContext context' param.
  // We use 'this.context' (the State's context) which is stable.
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
      appBar: AppBar(title: const Text('Notifications')),
      body: _userId == null
          ? const Center(child: Text("Erreur: Non connecté"))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_notifications')
            .where('userId', isEqualTo: _userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = snapshot.data!.docs;
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final isRead = data['isRead'] ?? false;
              final timestamp = data['timestamp'] as Timestamp?;

              return ListTile(
                leading: _buildLeadingIcon(isRead, data['relatedCollection']),
                title: Text(
                  data['title'] ?? 'Notification',
                  style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                ),
                subtitle: Text(
                  "${data['body'] ?? ''}\n${timestamp != null ? timeago.format(timestamp.toDate(), locale: 'fr') : ''}",
                  maxLines: 2,
                ),
                isThreeLine: true,
                // ✅ FIXED: Removed 'context' argument
                onTap: () => _navigateToDetails(
                  data['relatedCollection'],
                  data['relatedDocId'],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLeadingIcon(bool isRead, String? collection) {
    return CircleAvatar(
      backgroundColor: isRead ? Colors.grey[200] : Colors.blue.withOpacity(0.1),
      child: Icon(_getIconForCollection(collection), color: isRead ? Colors.grey : Colors.blue),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey),
          Text('Aucune notification', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}
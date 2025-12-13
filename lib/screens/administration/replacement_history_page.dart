// lib/screens/administration/replacement_history_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/replacement_request_details_page.dart';

class ReplacementHistoryPage extends StatelessWidget {
  const ReplacementHistoryPage({super.key});

  // NEW: Helper function to show a dialog with the signature
  void _showSignatureDialog(BuildContext context, String? signatureUrl) {
    if (signatureUrl == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Signature du Responsable'),
        content: Image.network(signatureUrl,
          loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
        ),
        actions: [TextButton(child: const Text('Fermer'), onPressed: () => Navigator.of(ctx).pop())],
      ),
    );
  }

  // NEW: Helper function to show a dialog with photos
  void _showPhotosDialog(BuildContext context, List<dynamic>? photoUrls) {
    if (photoUrls == null || photoUrls.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Photos de Remplacement'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: photoUrls.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Image.network(photoUrls[index],
                loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ),
        actions: [TextButton(child: const Text('Fermer'), onPressed: () => Navigator.of(ctx).pop())],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique des Remplacements"),
        backgroundColor: const Color(0xFFF8F8FA),
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      backgroundColor: const Color(0xFFF8F8FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('global_activity_log')
            .where('category', isEqualTo: 'Remplacements')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Erreur de chargement de l'historique."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("Aucune activité de remplacement enregistrée.", style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }

          final logs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index].data() as Map<String, dynamic>;

              final formattedDate = (log['timestamp'] as Timestamp?) != null
                  ? DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format((log['timestamp'] as Timestamp).toDate())
                  : 'Date inconnue';

              final clientName = log['clientName'] ?? 'N/A';
              final userName = log['userName'] ?? 'Utilisateur inconnu';
              final replacementId = log['replacementRequestId'] as String?;
              final photoUrls = log['completionPhotoUrls'] as List<dynamic>?;
              final signatureUrl = log['completionSignatureUrl'] as String?;

              return Card(
                elevation: 1.0,
                margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    onTap: () {
                      if (replacementId != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => ReplacementRequestDetailsPage(requestId: replacementId)),
                        );
                      }
                    },
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      child: const Icon(Icons.sync_problem_outlined, color: Colors.red),
                    ),
                    title: Text(log['message'] ?? 'Action non définie', style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Client: $clientName\nPar: $userName\n$formattedDate", style: TextStyle(color: Colors.grey.shade600)),
                        // MODIFIED: Add buttons if proof exists
                        if(photoUrls != null || signatureUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                if (photoUrls != null && photoUrls.isNotEmpty)
                                  TextButton.icon(
                                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                                    label: const Text('Photos'),
                                    onPressed: () => _showPhotosDialog(context, photoUrls),
                                  ),
                                if (signatureUrl != null)
                                  TextButton.icon(
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    label: const Text('Signature'),
                                    onPressed: () => _showSignatureDialog(context, signatureUrl),
                                  ),
                              ],
                            ),
                          )
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
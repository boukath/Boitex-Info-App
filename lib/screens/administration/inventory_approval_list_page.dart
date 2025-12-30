// lib/screens/administration/inventory_approval_list_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/models/inventory_session.dart';
import 'package:boitex_info_app/services/inventory_service.dart';
import 'package:boitex_info_app/screens/administration/inventory_review_details_page.dart';

class InventoryApprovalListPage extends StatelessWidget {
  const InventoryApprovalListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Validations en attente", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<InventorySession>>(
        stream: InventoryService().getPendingSessions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade200),
                  const SizedBox(height: 16),
                  const Text("Tout est à jour !", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text("Aucun inventaire en attente de validation.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final sessions = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.indigo.shade50,
                    child: const Icon(Icons.assignment_ind, color: Colors.indigo),
                  ),
                  title: Text(
                    "Inventaire: ${session.scope}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text("Fait par: ${session.createdByName}"),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(DateFormat('dd/MM/yyyy HH:mm').format(session.createdAt)),
                        ],
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InventoryReviewDetailsPage(session: session),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
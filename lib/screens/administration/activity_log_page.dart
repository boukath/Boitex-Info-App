// lib/screens/administration/activity_log_page.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/screens/administration/billing_history_page.dart';
import 'package:boitex_info_app/screens/administration/replacement_history_page.dart';
import 'package:boitex_info_app/screens/administration/requisition_history_page.dart';

// ✅ MODIFIED: Added userRole parameter
class ActivityLogPage extends StatelessWidget {
  final String userRole;

  const ActivityLogPage({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique des Activités"),
        backgroundColor: const Color(0xFFF8F8FA),
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      backgroundColor: const Color(0xFFF8F8FA),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHistoryCategoryCard(
            context: context,
            title: 'Historique de Facturation',
            subtitle: 'Consulter toutes les décisions de facturation',
            icon: Icons.receipt_long,
            color: Colors.teal,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BillingHistoryPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildHistoryCategoryCard(
            context: context,
            title: 'Historique des Remplacements',
            subtitle: 'Consulter les approbations de remplacement',
            icon: Icons.sync_problem_outlined,
            color: Colors.red,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ReplacementHistoryPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildHistoryCategoryCard(
            context: context,
            title: 'Historique des Achats',
            subtitle: 'Consulter les commandes reçues',
            icon: Icons.shopping_bag_rounded,
            color: Colors.blue,
            onTap: () {
              // ✅ FIXED: Pass userRole to RequisitionHistoryPage
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RequisitionHistoryPage(userRole: userRole),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCategoryCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16.0),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}

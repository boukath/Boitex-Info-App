// lib/screens/settings/global_settings_page.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/screens/settings/notification_manager_page.dart'; // ✅ ADDED

class GlobalSettingsPage extends StatelessWidget {
  final String userRole;

  const GlobalSettingsPage({
    super.key,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres & Configuration'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // "Gestion des Notifications" Card
          _buildSettingsCard(
            context,
            title: 'Gestion des Notifications',
            subtitle: 'Activer/Désactiver les alertes par utilisateur',
            icon: Icons.notifications_active_rounded,
            color: Colors.blue,
            onTap: () {
              // ✅ MODIFIED: Navigate to the Manager Page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationManagerPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
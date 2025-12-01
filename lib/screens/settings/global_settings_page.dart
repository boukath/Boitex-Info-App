// lib/screens/settings/global_settings_page.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/screens/settings/notification_manager_page.dart';
import 'package:boitex_info_app/screens/settings/user_role_manager_page.dart'; // ✅ ADDED IMPORT
import 'package:boitex_info_app/screens/settings/morning_briefing_page.dart'; // ✅ NEW IMPORT

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
          // ✅ FIXED: Only Admin sees these controls
          if (userRole == UserRoles.admin) ...[
            // 1. Role Manager (Existing)
            _buildSettingsCard(
              context,
              title: 'Gestion des Rôles',
              subtitle: 'Modifier les rôles et permissions des utilisateurs',
              icon: Icons.security_rounded,
              color: Colors.redAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserRoleManagerPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 10), // Spacing between Admin cards

            // ---------------------------------------------------------
            // ✅ 2. MORNING BRIEFING (NEW)
            // ---------------------------------------------------------
            _buildSettingsCard(
              context,
              title: 'Morning Briefing',
              subtitle: 'Planifier les jours, l\'heure et les destinataires',
              icon: Icons.wb_sunny_rounded, // Sun icon for morning
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MorningBriefingPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 10), // Spacing between Admin cards

            // 3. Notification Manager (Existing)
            _buildSettingsCard(
              context,
              title: 'Gestion des Notifications',
              subtitle: 'Activer/Désactiver les alertes par utilisateur',
              icon: Icons.notifications_active_rounded,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationManagerPage(),
                  ),
                );
              },
            ),
          ],
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
// lib/screens/settings/global_settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/screens/settings/notification_manager_page.dart';
import 'package:boitex_info_app/screens/settings/user_role_manager_page.dart';
import 'package:boitex_info_app/screens/settings/morning_briefing_page.dart';
import 'package:boitex_info_app/services/update_service.dart';

// ✅ IMPORT THE NEW PROFILE HEADER
import 'package:boitex_info_app/screens/settings/widgets/profile_header.dart';

// ✅ IMPORT MIGRATION SERVICES
import 'package:boitex_info_app/services/migration_service.dart';
import 'package:boitex_info_app/services/client_search_migration_service.dart'; // 👈 Added this

class GlobalSettingsPage extends StatelessWidget {
  final String userRole;

  const GlobalSettingsPage({
    super.key,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    // 2026 Theme: Pure White Background
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // Transparent / Minimalist AppBar
        title: const Text(
          'Configuration',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: -0.5, // Tighter tracking for modern feel
            color: Colors.black,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0, // Prevents color change on scroll
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ✅ 1. THE HERO PROFILE HEADER
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ProfileHeader(),
            ),

            const SizedBox(height: 20),

            // ---------------------------------------------------------
            // 🌍 SECTION GÉNÉRALE
            // ---------------------------------------------------------
            _buildSectionTitle("APPLICATION"),

            _buildSettingsGroup(
              children: [
                _buildSettingsTile(
                  context,
                  title: 'Mise à jour',
                  subtitle: 'Version actuelle 1.6.4+6',
                  icon: Icons.system_update_rounded,
                  iconColor: Colors.black, // Monochrome for "General"
                  isLast: true,
                  onTap: () {
                    HapticFeedback.lightImpact(); // Premium feel
                    UpdateService().checkForUpdate(context, showNoUpdateMessage: true);
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ---------------------------------------------------------
            // 🛡️ SECTION ADMIN
            // ---------------------------------------------------------
            if (userRole == UserRoles.admin) ...[
              _buildSectionTitle("ADMINISTRATION"),

              _buildSettingsGroup(
                children: [
                  // 1. Role Manager
                  _buildSettingsTile(
                    context,
                    title: 'Gestion des Rôles',
                    subtitle: 'Permissions et accès utilisateurs',
                    icon: Icons.shield_rounded,
                    iconColor: const Color(0xFFFF3B30), // iOS System Red
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const UserRoleManagerPage()));
                    },
                  ),

                  _buildDivider(),

                  // 2. Morning Briefing
                  _buildSettingsTile(
                    context,
                    title: 'Morning Briefing',
                    subtitle: 'Planification des rapports quotidiens',
                    icon: Icons.wb_sunny_rounded,
                    iconColor: const Color(0xFFFF9500), // iOS System Orange
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MorningBriefingPage()));
                    },
                  ),

                  _buildDivider(),

                  // 3. Notification Manager
                  _buildSettingsTile(
                    context,
                    title: 'Notifications',
                    subtitle: 'Centre de contrôle des alertes',
                    icon: Icons.notifications_active_rounded,
                    iconColor: const Color(0xFF007AFF), // iOS System Blue
                    isLast: false,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationManagerPage()));
                    },
                  ),

                  _buildDivider(),

                  // 4. DATABASE MIGRATION (Slugs)
                  _buildSettingsTile(
                    context,
                    title: 'Maintenance Données',
                    subtitle: 'Migrer les slugs (Anti-doublons)',
                    icon: Icons.engineering_rounded, // Construction icon
                    iconColor: Colors.amber.shade700, // Warning/Amber color
                    isLast: false, // 👈 Changed to false to add the next item
                    onTap: () async {
                      HapticFeedback.heavyImpact();

                      // Confirmation Dialog
                      bool confirm = await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("⚠️ Attention"),
                            content: const Text(
                              "Cette action va scanner tous les clients et magasins pour générer les 'Slugs' manquants.\n\nCela ne modifie pas les IDs existants.",
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Lancer")),
                            ],
                          )
                      ) ?? false;

                      if (!confirm) return;

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Migration en cours... Patientez...")),
                        );
                      }

                      // Run Logic
                      String result = await MigrationService().runSlugMigration();

                      if(context.mounted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Rapport de Migration"),
                            content: Text(result),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
                            ],
                          ),
                        );
                      }
                    },
                  ),

                  _buildDivider(),

                  // ✅ 5. AUTO-DISCOVERY (Brands) - The New Button
                  _buildSettingsTile(
                    context,
                    title: 'Auto-Discovery (Marques)',
                    subtitle: 'Scanner et lier les marques aux clients',
                    icon: Icons.auto_fix_high, // Magic wand icon
                    iconColor: Colors.teal, // Distinct color
                    isLast: true, // This is the last item
                    onTap: () async {
                      HapticFeedback.heavyImpact();

                      bool confirm = await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("⚠️ Lancer l'Auto-Discovery ?"),
                            content: const Text(
                              "Cette action va scanner tous les magasins existants pour détecter les marques (ex: Zara) et les ajouter aux mots-clés de recherche des clients (ex: Azadea).\n\nPermet de trouver le client en tapant ses enseignes.",
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Lancer le Scan")),
                            ],
                          )
                      ) ?? false;

                      if (!confirm) return;

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Analyse des magasins en cours... Patientez...")),
                        );
                      }

                      try {
                        // Pass userRole for security check inside the service
                        final stats = await ClientSearchMigrationService().runAutoDiscoveryMigration(userRole);

                        if(context.mounted) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("✅ Terminé"),
                              content: Text(
                                "Mise à jour réussie !\n\n"
                                    "• Clients mis à jour : ${stats['clients']}\n"
                                    "• Marques détectées : ${stats['brands']}",
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
                              ],
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ],

            // Footer / Version Info
            const SizedBox(height: 50),
            Center(
              child: Text(
                "Boitex Info • 2026 Design System",
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 🎨 WIDGETS: THE PREMIUM DESIGN SYSTEM
  // ---------------------------------------------------------

  /// 1. The "Micro-Cap" Section Title
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 1.5, // Wide spacing for "Tech" feel
        ),
      ),
    );
  }

  /// 2. The "Surface" Container (Replaces Card)
  Widget _buildSettingsGroup({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // Large "Squircle" radius
        border: Border.all(color: Colors.grey.shade100), // Very subtle border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // 4% Opacity Shadow
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  /// 3. The Minimalist Divider
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade50, // Almost invisible divider
      indent: 70, // Start after the icon
    );
  }

  /// 4. The Premium Tile
  Widget _buildSettingsTile(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color iconColor,
        required VoidCallback onTap,
        bool isLast = false,
      }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(24))
            : (isLast == false && subtitle == 'Version actuelle 1.6.4+6' ? // First item only
        const BorderRadius.vertical(top: Radius.circular(24)) : BorderRadius.zero),

        highlightColor: Colors.grey.shade50,
        splashColor: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Icon Container
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.08), // Very subtle tint
                  borderRadius: BorderRadius.circular(14), // Squircle
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),

              const SizedBox(width: 16),

              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600, // Semi-bold for legibility
                        color: Colors.black87,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Modern Chevron
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey.shade300, // Very subtle arrow
              ),
            ],
          ),
        ),
      ),
    );
  }
}
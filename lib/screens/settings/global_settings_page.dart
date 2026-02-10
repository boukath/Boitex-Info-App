// lib/screens/settings/global_settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:package_info_plus/package_info_plus.dart'; // For dynamic version check

import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/screens/settings/notification_manager_page.dart';
import 'package:boitex_info_app/screens/settings/user_role_manager_page.dart';
import 'package:boitex_info_app/screens/settings/morning_briefing_page.dart';
import 'package:boitex_info_app/services/update_service.dart';

// IMPORT THE NEW EMAIL SETTINGS PAGE
import 'package:boitex_info_app/screens/settings/email_settings_page.dart';

// IMPORT THE NEW PROFILE HEADER
import 'package:boitex_info_app/screens/settings/widgets/profile_header.dart';

// IMPORT MIGRATION SERVICES
import 'package:boitex_info_app/services/migration_service.dart';
import 'package:boitex_info_app/services/client_search_migration_service.dart';
// IMPORT DATABASE TRANSFER SERVICES
import 'package:boitex_info_app/services/database_transfer_service.dart';
import 'package:boitex_info_app/services/sub_collection_transfer_service.dart'; // ✅ ADDED

// IMPORT REPAIR TOOL
import 'package:boitex_info_app/screens/administration/stock_repair_page.dart';

class GlobalSettingsPage extends StatefulWidget {
  final String userRole;

  const GlobalSettingsPage({
    super.key,
    required this.userRole,
  });

  @override
  State<GlobalSettingsPage> createState() => _GlobalSettingsPageState();
}

class _GlobalSettingsPageState extends State<GlobalSettingsPage> {
  String _appVersion = "Chargement..."; // Default text while loading

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  /// Fetches the real version from pubspec.yaml (via the native layer)
  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = "Version actuelle ${info.version}";
      });
    }
  }

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
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 1. THE HERO PROFILE HEADER
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
                  subtitle: _appVersion, // Uses dynamic variable
                  icon: Icons.system_update_rounded,
                  iconColor: Colors.black, // Monochrome for "General"
                  isFirst: true, // It is the first item
                  isLast: true,  // It is also the last item (Single item group)
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
            if (widget.userRole == UserRoles.admin) ...[
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
                    isFirst: true,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const UserRoleManagerPage()));
                    },
                  ),

                  _buildDivider(),

                  // 2. Email CC Manager
                  _buildSettingsTile(
                    context,
                    title: 'Destinataires Emails (CC)',
                    subtitle: 'Gérer les copies cachées (Tech, IT, SAV)',
                    icon: Icons.alternate_email,
                    iconColor: Colors.teal,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const EmailSettingsPage()));
                    },
                  ),

                  _buildDivider(),

                  // 3. Morning Briefing
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

                  // 4. Notification Manager
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

                  // 5. DATABASE MIGRATION (Slugs)
                  _buildSettingsTile(
                    context,
                    title: 'Maintenance Données',
                    subtitle: 'Migrer les slugs (Anti-doublons)',
                    icon: Icons.engineering_rounded, // Construction icon
                    iconColor: Colors.amber.shade700, // Warning/Amber color
                    isLast: false,
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

                  // 6. AUTO-DISCOVERY (Brands)
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
                        final stats = await ClientSearchMigrationService().runAutoDiscoveryMigration(widget.userRole);

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

              const SizedBox(height: 32),

              // ---------------------------------------------------------
              // 🚨 SECTION MAINTENANCE AVANCÉE
              // ---------------------------------------------------------
              _buildSectionTitle("MAINTENANCE AVANCÉE"),

              _buildSettingsGroup(
                  children: [
                    _buildSettingsTile(
                      context,
                      title: 'Réparation Historique Stock',
                      subtitle: 'Recalculer les quantités (Reverse Replay)',
                      icon: Icons.healing_rounded,
                      iconColor: Colors.orange.shade800,
                      isFirst: true,
                      isLast: true,
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const StockRepairPage()));
                      },
                    ),
                  ]
              ),

              const SizedBox(height: 32),

              // ---------------------------------------------------------
              // ☢️ ZONE DE DANGER (MIGRATION DE COMPTE)
              // ---------------------------------------------------------
              Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      "ZONE DE DANGER (MIGRATION)",
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              _buildSettingsGroup(
                children: [
                  // ÉTAPE 1 : TRANSFERT PRINCIPAL
                  _buildSettingsTile(
                    context,
                    title: 'Transférer la Base de Données',
                    subtitle: 'Étape 1 : Collections Principales',
                    icon: Icons.cloud_upload_rounded,
                    iconColor: Colors.red,
                    isFirst: true,
                    isLast: false, // Not last anymore
                    onTap: () async {
                      HapticFeedback.heavyImpact();

                      // 1. WARNING DIALOG
                      bool? confirm = await showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (c) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red),
                              SizedBox(width: 8),
                              Text("ALERTE CRITIQUE"),
                            ],
                          ),
                          content: const SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Vous êtes sur le point de copier l'intégralité de la base de données vers le nouveau projet.",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 12),
                                Text("• Source : boitexinfo-63060 (Actuel)"),
                                Text("• Cible : boitexinfo-63060 (Nouveau)"),
                                SizedBox(height: 12),
                                Text(
                                  "⚠️ PRÉ-REQUIS OBLIGATOIRES :",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                                Text("1. Ne fermez pas l'application."),
                                Text("2. Gardez l'écran allumé."),
                                Text("3. Assurez-vous d'avoir une connexion stable."),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text("ANNULER"),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.bolt),
                              label: const Text("LANCER LE TRANSFERT"),
                              onPressed: () => Navigator.pop(c, true),
                            ),
                          ],
                        ),
                      );

                      // 2. EXECUTE TRANSFER
                      if (confirm == true) {
                        if(context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("🚀 Transfert en cours... Consultez la console (Debug)"),
                              backgroundColor: Colors.blue,
                              duration: Duration(seconds: 5),
                            ),
                          );
                        }

                        // Run the service
                        await DatabaseTransferService().startTransfer();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text("✅ Transfert Terminé avec Succès !"),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 8),
                            ),
                          );
                        }
                      }
                    },
                  ),

                  _buildDivider(),

                  // ✅ ÉTAPE 2 : SOUS-COLLECTIONS (ADDED HERE)
                  _buildSettingsTile(
                    context,
                    title: 'Transfert Sous-Collections (Étape 2)',
                    subtitle: 'Copier les données imbriquées (Stores, Logs, etc.)',
                    icon: Icons.layers_rounded,
                    iconColor: Colors.orange,
                    isLast: true,
                    onTap: () async {
                      HapticFeedback.heavyImpact();

                      // Confirmation Dialog
                      bool? confirm = await showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (c) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange),
                              SizedBox(width: 8),
                              Text("PHASE 2 : SOUS-COLLECTIONS"),
                            ],
                          ),
                          content: const Text(
                            "Cette action va copier les données imbriquées (Stores, Logs, Items d'inventaire, etc.) qui n'ont pas été copiées lors de l'étape 1.\n\n"
                                "Assurez-vous que l'étape 1 est terminée.",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text("ANNULER"),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.layers),
                              label: const Text("LANCER L'ÉTAPE 2"),
                              onPressed: () => Navigator.pop(c, true),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("🚀 Démarrage Phase 2... Consultez la console !"),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        }

                        // Run the new service
                        await SubCollectionTransferService().startSubCollectionTransfer();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("✅ Transfert Sous-Collections Terminé !"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ], // End if UserRoles.admin

            // Footer / Version Info
            const SizedBox(height: 50),
            Center(
              child: Column(
                children: [
                  Text(
                    "Boitex Info • 2026 Design System",
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Développé par le Service IT",
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.3),
                      fontSize: 10,
                    ),
                  ),
                ],
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
        bool isFirst = false,
        bool isLast = false,
      }) {

    // Determine the border radius based on position
    BorderRadius radius = BorderRadius.zero;
    if (isFirst && isLast) {
      radius = BorderRadius.circular(24); // Single item
    } else if (isFirst) {
      radius = const BorderRadius.vertical(top: Radius.circular(24));
    } else if (isLast) {
      radius = const BorderRadius.vertical(bottom: Radius.circular(24));
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius, // Matches the container
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
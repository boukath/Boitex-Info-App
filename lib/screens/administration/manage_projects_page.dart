// lib/screens/administration/manage_projects_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ PREMIUM UI ADDITION
import 'package:boitex_info_app/screens/administration/project_list_page.dart';
import 'package:boitex_info_app/screens/administration/project_history_page.dart';

class ManageProjectsPage extends StatefulWidget {
  final String userRole;

  const ManageProjectsPage({super.key, required this.userRole});

  @override
  State<ManageProjectsPage> createState() => _ManageProjectsPageState();
}

class _ManageProjectsPageState extends State<ManageProjectsPage> with SingleTickerProviderStateMixin {
  // ✅ PREMIUM COLOR PALETTE
  static const Color bgColor = Color(0xFFF5F7FA);
  static const Color surfaceColor = Colors.white;
  static const Color textDark = Color(0xFF1E293B);
  static const Color textLight = Color(0xFF64748B);

  // Service specific colors
  static const Color techColor = Color(0xFF4F46E5); // Indigo
  static const Color itColor = Color(0xFF0EA5E9);   // Sky Blue

  // State for the modern toggle
  String _activeService = 'Service Technique';

  // Helper to get current active color
  Color get _activeColor => _activeService == 'Service Technique' ? techColor : itColor;

  // ✅ PREMIUM CUSTOM TOGGLE (Apple/Tesla Style Segmented Control)
  Widget _buildServiceToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.02)),
      ),
      child: Row(
        children: [
          _buildTogglePill('Service Technique', Icons.engineering_rounded, techColor),
          _buildTogglePill('Service IT', Icons.router_rounded, itColor),
        ],
      ),
    );
  }

  Widget _buildTogglePill(String title, IconData icon, Color themeColor) {
    final bool isActive = _activeService == title;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeService = title),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? surfaceColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive ? [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))
            ] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: isActive ? themeColor : textLight),
              const SizedBox(width: 8),
              Text(
                title.replaceAll('Service ', ''), // Shorter text for clean look
                style: GoogleFonts.inter(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  fontSize: 15,
                  color: isActive ? textDark : textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ PREMIUM HERO CARD (Gradient & Glassmorphism)
  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          highlightColor: gradientColors.first.withOpacity(0.05),
          splashColor: gradientColors.first.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: gradientColors.last.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))
                      ]
                  ),
                  child: Icon(icon, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: textDark),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(fontSize: 14, color: textLight, fontWeight: FontWeight.w500, height: 1.4),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.03), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: textDark, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Gestion des Projets', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textDark, fontSize: 18)),
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black.withOpacity(0.05), height: 1),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elegant Toggle Switch
          _buildServiceToggle(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Text(
                "ESPACE DE TRAVAIL",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: textLight, letterSpacing: 1.2)
            ),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                );
              },
              // The key forces the animation to play when the service changes
              child: ListView(
                key: ValueKey<String>(_activeService),
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(top: 12, bottom: 40),
                children: [
                  // --- Card 1: Pipeline Actif ---
                  _buildActionCard(
                    title: 'Projets Actifs',
                    subtitle: 'Gérer les nouvelles demandes, les évaluations en cours et les planifications.',
                    icon: Icons.rocket_launch_rounded,
                    gradientColors: _activeService == 'Service Technique'
                        ? [const Color(0xFF6366F1), const Color(0xFF4F46E5)] // Indigo gradient
                        : [const Color(0xFF38BDF8), const Color(0xFF0284C7)], // Sky gradient
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ProjectListPage(
                            userRole: widget.userRole,
                            serviceType: _activeService,
                          ),
                        ),
                      );
                    },
                  ),

                  // --- Card 2: Historique ---
                  _buildActionCard(
                    title: 'Historique',
                    subtitle: 'Consulter les archives et les projets finalisés ou annulés.',
                    icon: Icons.history_rounded,
                    gradientColors: [const Color(0xFF94A3B8), const Color(0xFF475569)], // Slate grey gradient
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ProjectHistoryPage(
                            userRole: widget.userRole,
                            serviceType: _activeService,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
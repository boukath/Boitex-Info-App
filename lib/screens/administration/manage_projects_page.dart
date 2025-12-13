// lib/screens/administration/manage_projects_page.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/screens/administration/project_list_page.dart';
// ✅ ADDED: Import for the new history page
import 'package:boitex_info_app/screens/administration/project_history_page.dart';

class ManageProjectsPage extends StatelessWidget {
  final String userRole;

  const ManageProjectsPage({super.key, required this.userRole});

  Widget _buildServiceCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ NEW: Helper to show the Service Type choice (Technique or IT)
  void _showServiceChoice(BuildContext context,
      {required String pageTitle,
        required Widget Function(String serviceType) targetPageBuilder}) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.engineering, color: Colors.blue.shade700),
                title: const Text('Service Technique'),
                onTap: () {
                  Navigator.pop(context); // Dismiss bottom sheet
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          targetPageBuilder('Service Technique'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.computer, color: Colors.green.shade700),
                title: const Text('Service IT'),
                onTap: () {
                  Navigator.pop(context); // Dismiss bottom sheet
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => targetPageBuilder('Service IT'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer les Projets'),
      ),
      // ✅ MODIFIED: Body now has two clear options
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- Card 1: Projets Actifs (The Pipeline) ---
            _buildServiceCard(
              context: context,
              title: 'Projets Actifs (Pipeline)',
              icon: Icons.folder_open_outlined,
              color: Colors.blue.shade700,
              onTap: () {
                // Shows the service choice popup first
                _showServiceChoice(
                  context,
                  pageTitle: 'Projets Actifs',
                  // This now points to our new 5-tab pipeline page
                  targetPageBuilder: (serviceType) => ProjectListPage(
                    userRole: userRole,
                    serviceType: serviceType,
                  ),
                );
              },
            ),

            // --- Card 2: Historique des Projets (The Archive) ---
            _buildServiceCard(
              context: context,
              title: 'Historique des Projets',
              icon: Icons.history_outlined,
              color: Colors.grey.shade700,
              onTap: () {
                // Also shows the service choice popup
                _showServiceChoice(
                  context,
                  pageTitle: 'Historique des Projets',
                  // This points to our new archive page
                  targetPageBuilder: (serviceType) => ProjectHistoryPage(
                    userRole: userRole,
                    serviceType: serviceType,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
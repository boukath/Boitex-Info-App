// lib/screens/administration/manage_projects_page.dart

import 'package:flutter/material.dart';
// ✅ ADDED: Import for the new list page
import 'package:boitex_info_app/screens/administration/project_list_page.dart';

class ManageProjectsPage extends StatelessWidget {
  final String userRole;

  const ManageProjectsPage({super.key, required this.userRole});

  // ✅ NEW: Helper widget to create a consistent navigation card
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer les Projets'),
      ),
      // ✅ MODIFIED: The body is now a simple column with two buttons
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildServiceCard(
              context: context,
              title: 'Service Technique',
              icon: Icons.engineering,
              color: Colors.blue.shade700,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProjectListPage(
                      userRole: userRole,
                      serviceType: 'Service Technique',
                    ),
                  ),
                );
              },
            ),
            _buildServiceCard(
              context: context,
              title: 'Service IT',
              icon: Icons.computer,
              color: Colors.green.shade700,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProjectListPage(
                      userRole: userRole,
                      serviceType: 'Service IT',
                    ),
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
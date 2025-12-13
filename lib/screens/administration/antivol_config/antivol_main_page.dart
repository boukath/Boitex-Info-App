// lib/screens/administration/antivol_config/antivol_main_page.dart

import 'package:flutter/material.dart';
// ✅ 1. ADD IMPORT for the new page
import 'package:boitex_info_app/screens/administration/antivol_config/supplier_list_page.dart';

class AntivolMainPage extends StatelessWidget {
  const AntivolMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration Antivol'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          // ✅ 2. CORRECTION: Typo 'crossAxisAlignmentAxisAlignment' corrigée
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sélectionner une technologie',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildTechButton(
              context: context,
              label: 'AM',
              icon: Icons.waves_rounded,
              color: Colors.blue.shade700,
              onPressed: () {
                // ✅ UPDATE Navigation
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SupplierListPage(technology: 'AM'),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildTechButton(
              context: context,
              label: 'RF',
              icon: Icons.wifi_tethering_rounded,
              color: Colors.green.shade700,
              onPressed: () {
                // ✅ UPDATE Navigation
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SupplierListPage(technology: 'RF'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 5,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
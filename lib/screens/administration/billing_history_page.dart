// lib/screens/administration/billing_history_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// ✅ ADDED: Import for the next page in the flow
import 'package:boitex_info_app/screens/administration/billing_category_page.dart';

// ✅ CHANGED: Converted to a StatelessWidget
class BillingHistoryPage extends StatelessWidget {
  const BillingHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ✅ CHANGED: Removed search bar and set a simple title
        title: Text(
          'Historique de Facturation',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      // ✅ CHANGED: Body is now a simple ListView for navigation
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                child: Icon(Icons.construction_outlined),
              ),
              title: Text(
                'Interventions',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                "Voir l'historique des interventions",
                style: GoogleFonts.poppins(),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Navigate to Page 2, passing 'intervention' as the type
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BillingCategoryPage(
                      type: 'intervention',
                      title: 'Historique Interventions',
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                child: Icon(Icons.support_agent_outlined),
              ),
              title: Text(
                'SAV',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                "Voir l'historique des tickets SAV",
                style: GoogleFonts.poppins(),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Navigate to Page 2, passing 'sav' as the type
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BillingCategoryPage(
                      type: 'sav',
                      title: 'Historique SAV',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
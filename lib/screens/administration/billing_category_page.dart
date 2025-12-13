// lib/screens/administration/billing_category_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// ✅ ADDED: Import for the final page in the flow
import 'package:boitex_info_app/screens/administration/billing_filtered_list_page.dart';
// ✅ ADDED: Import for the NEW service type selection page
import 'package:boitex_info_app/screens/administration/billing_service_type_page.dart';


class BillingCategoryPage extends StatelessWidget {
  final String type; // 'intervention' or 'sav'
  final String title;

  const BillingCategoryPage({
    super.key,
    required this.type,
    required this.title,
  });

  // Helper to determine icon and color based on type
  IconData _getIcon() {
    return type == 'intervention'
        ? Icons.construction_outlined
        : Icons.support_agent_outlined;
  }

  Color _getColor() {
    return type == 'intervention' ? Colors.deepPurple : Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getColor().withOpacity(0.1),
                foregroundColor: _getColor(),
                child: const Icon(Icons.receipt_long_outlined),
              ),
              title: Text(
                'Facturé',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Voir les dossiers facturés',
                style: GoogleFonts.poppins(),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // ✅ CHANGED: Conditional navigation
                if (type == 'intervention') {
                  // Navigate to the NEW service type page first
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => BillingServiceTypePage(
                        billingStatus: 'Facturé',
                        // Pass the title or construct a new one
                        title: '$title: Facturé',
                      ),
                    ),
                  );
                } else {
                  // SAV goes directly to the final list
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => BillingFilteredListPage(
                        type: type, // 'sav'
                        billingStatus: 'Facturé',
                        title: '$title: Facturé',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.grey.shade700,
                child: const Icon(Icons.do_not_disturb_alt_outlined),
              ),
              title: Text(
                'Sans Facturation',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                "Voir les dossiers clôturés sans facture",
                style: GoogleFonts.poppins(),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // ✅ CHANGED: Conditional navigation
                if (type == 'intervention') {
                  // Navigate to the NEW service type page first
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => BillingServiceTypePage(
                        billingStatus: 'Sans Facture',
                        // Pass the title or construct a new one
                        title: '$title: Sans Facture',
                      ),
                    ),
                  );
                } else {
                  // SAV goes directly to the final list
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => BillingFilteredListPage(
                        type: type, // 'sav'
                        billingStatus: 'Sans Facture',
                        title: '$title: Sans Facture',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
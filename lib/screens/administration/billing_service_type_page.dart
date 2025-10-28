// lib/screens/administration/billing_service_type_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// ✅ ADDED: Import for the final page in the flow
import 'package:boitex_info_app/screens/administration/billing_filtered_list_page.dart';

class BillingServiceTypePage extends StatelessWidget {
  final String billingStatus; // 'Facturé' or 'Sans Facture'
  final String title;

  const BillingServiceTypePage({
    super.key,
    required this.billingStatus,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title, // e.g., "Historique Interventions: Facturé"
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
                backgroundColor: Colors.blue.withOpacity(0.1),
                foregroundColor: Colors.blue,
                child: const Icon(Icons.engineering_outlined), // Icon for Technical Service
              ),
              title: Text(
                'Service Technique',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Voir les dossiers du service technique',
                style: GoogleFonts.poppins(),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Navigate to the final list page (Page 4)
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BillingFilteredListPage(
                      type: 'intervention', // Hardcoded as this page is only for interventions
                      billingStatus: billingStatus,
                      serviceType: 'Service Technique', // Pass the selected service type
                      title: '$title - Tech', // Construct a final title
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
              leading: CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.1),
                foregroundColor: Colors.green,
                child: const Icon(Icons.computer_outlined), // Icon for IT Service
              ),
              title: Text(
                'Service IT', // Or "Service Informatique" if that's the value in Firestore
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                "Voir les dossiers du service IT", // Adjust if needed
                style: GoogleFonts.poppins(),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Navigate to the final list page (Page 4)
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BillingFilteredListPage(
                      type: 'intervention', // Hardcoded
                      billingStatus: billingStatus,
                      serviceType: 'Service IT', // Pass the selected service type
                      title: '$title - IT', // Construct a final title
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
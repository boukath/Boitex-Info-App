// lib/screens/service_technique/intervention_history_clients_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_history_stores_page.dart';
import 'package:boitex_info_app/screens/service_technique/universal_intervention_search_page.dart';

class InterventionHistoryClientsPage extends StatefulWidget {
  final String serviceType;

  const InterventionHistoryClientsPage({super.key, required this.serviceType});

  @override
  State<InterventionHistoryClientsPage> createState() =>
      _InterventionHistoryClientsPageState();
}

class _InterventionHistoryClientsPageState
    extends State<InterventionHistoryClientsPage> {
  // ✅ STATE: Default to current year (e.g., 2026)
  int _selectedYear = DateTime.now().year;

  // Generate a list of years (Current year back 4 years)
  List<int> get _availableYears {
    final currentYear = DateTime.now().year;
    return List.generate(4, (index) => currentYear - index);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ LOGIC: Define the Date Range for the query
    final startOfYear = DateTime(_selectedYear, 1, 1);
    final endOfYear = DateTime(_selectedYear, 12, 31, 23, 59, 59);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Historique des Interventions',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 4.0,
        shadowColor: Colors.black.withOpacity(0.1),
        actions: [
          // ✅ UI: Year Selector Dropdown
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down,
                    color: Colors.blue, size: 24),
                style: GoogleFonts.poppins(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                items: _availableYears.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text("Année $year"),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedYear = val);
                  }
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UniversalInterventionSearchPage(
                    serviceType: widget.serviceType,
                  ),
                ),
              );
            },
            tooltip: 'Recherche Globale',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('serviceType', isEqualTo: widget.serviceType)
            .where('status', whereIn: ['Terminé', 'Clôturé'])
        // ✅ QUERY: Filter by Year Range
            .where('createdAt', isGreaterThanOrEqualTo: startOfYear)
            .where('createdAt', isLessThanOrEqualTo: endOfYear)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune intervention en $_selectedYear.',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Group unique client names
          final clientNames = snapshot.data!.docs
              .map((doc) =>
          (doc.data() as Map<String, dynamic>)['clientName']
          as String? ??
              'Client non spécifié')
              .toSet()
              .toList();

          clientNames.sort();

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: clientNames.length,
            itemBuilder: (context, index) {
              final clientName = clientNames[index];
              return _buildElegantCard(
                context: context,
                clientName: clientName,
                onTap: () {
                  // ✅ NAV: Pass the selectedYear to the next screen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InterventionHistoryStoresPage(
                        serviceType: widget.serviceType,
                        clientName: clientName,
                        selectedYear: _selectedYear, // 👈 PASS IT DOWN
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildElegantCard({
    required BuildContext context,
    required String clientName,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 12),
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1e3a8a).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.business_center,
                  color: Color(0xFF1e3a8a),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  clientName,
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
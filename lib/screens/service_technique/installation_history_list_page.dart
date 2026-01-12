// lib/screens/service_technique/installation_history_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Typography
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/universal_installation_search_page.dart';

class InstallationHistoryListPage extends StatefulWidget {
  final String serviceType;
  final String userRole;

  const InstallationHistoryListPage({
    super.key,
    required this.serviceType,
    required this.userRole,
  });

  @override
  State<InstallationHistoryListPage> createState() =>
      _InstallationHistoryListPageState();
}

class _InstallationHistoryListPageState
    extends State<InstallationHistoryListPage> {
  // ✅ STATE: Default to current year
  int _selectedYear = DateTime.now().year;

  // Generate a list of years (Current year back 4 years)
  List<int> get _availableYears {
    final currentYear = DateTime.now().year;
    return List.generate(4, (index) => currentYear - index);
  }

  // 🎨 THEME COLORS
  final Color _primaryBlue = const Color(0xFF2962FF);
  final Color _bgLight = const Color(0xFFF4F6F9);
  final Color _cardWhite = Colors.white;
  final Color _textDark = const Color(0xFF2D3436);

  @override
  Widget build(BuildContext context) {
    // ✅ LOGIC: Define the Date Range for the selected year
    final startOfYear = DateTime(_selectedYear, 1, 1);
    final endOfYear = DateTime(_selectedYear, 12, 31, 23, 59, 59);

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'ARCHIVES',
          style: GoogleFonts.poppins(
            color: _textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UniversalInstallationSearchPage(
                    serviceType: widget.serviceType,
                    userRole: widget.userRole,
                  ),
                ),
              );
            },
            tooltip: 'Rechercher',
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ UI: Styled Year Selector (Logic Untouched)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Année sélectionnée:",
                  style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _primaryBlue.withOpacity(0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      dropdownColor: Colors.white,
                      icon: Icon(Icons.arrow_drop_down, color: _primaryBlue),
                      style: GoogleFonts.poppins(
                        color: _primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      items: _availableYears.map((year) {
                        return DropdownMenuItem(
                          value: year,
                          child: Text("$year"),
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
              ],
            ),
          ),

          // ✅ LIST STREAM
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('installations')
                  .where('serviceType', isEqualTo: widget.serviceType)
                  .where('status', isEqualTo: 'Terminée')
              // ✅ QUERY: Filter by Date Range (Time Machine Logic)
                  .where('createdAt', isGreaterThanOrEqualTo: startOfYear)
                  .where('createdAt', isLessThanOrEqualTo: endOfYear)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: _primaryBlue));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Une erreur est survenue.', style: GoogleFonts.poppins(color: Colors.red)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text(
                          'Aucune installation en $_selectedYear.',
                          style: GoogleFonts.poppins(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                final installationDocs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: installationDocs.length,
                  itemBuilder: (context, index) {
                    final doc = installationDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    // ✅ EXTRACTED DATA (Safe Parsing for UI)
                    final installationCode = data['installationCode'] ?? 'N/A';
                    final clientName = data['clientName'] ?? 'N/A';
                    final storeName = data['storeName'] ?? 'N/A';
                    final storeLocation = data['storeLocation'] ?? '';

                    // Defensive Date Parsing to prevent crashes on old data
                    DateTime? createdDate;
                    if (data['createdAt'] is Timestamp) {
                      createdDate = (data['createdAt'] as Timestamp).toDate();
                    }

                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => InstallationDetailsPage(
                            installationDoc: doc,
                            userRole: widget.userRole,
                          ),
                        ));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _cardWhite,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              // Icon Box (Completed)
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                              ),
                              const SizedBox(width: 16),

                              // Info Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      installationCode,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: _textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$storeName ${storeLocation.isNotEmpty ? '- $storeLocation' : ''}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      clientName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Date Column
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (createdDate != null)
                                    Text(
                                      DateFormat('dd MMM').format(createdDate),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  if (createdDate != null)
                                    Text(
                                      DateFormat('yyyy').format(createdDate),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  if (createdDate == null)
                                    Text("--/--", style: GoogleFonts.poppins(color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade300),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
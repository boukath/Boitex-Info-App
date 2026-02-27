// lib/screens/service_technique/installation_history_list_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // ✅ Apple-style icons
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Typography
import 'package:cached_network_image/cached_network_image.dart'; // ✅ High-performance image loading
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

class _InstallationHistoryListPageState extends State<InstallationHistoryListPage> {
  // ✅ STATE: Default to current year
  int _selectedYear = DateTime.now().year;

  // Generate a list of years (Current year back 4 years)
  List<int> get _availableYears {
    final currentYear = DateTime.now().year;
    return List.generate(4, (index) => currentYear - index);
  }

  // 🎨 PREMIUM THEME COLORS
  final Color _primaryBlue = const Color(0xFF007AFF); // iOS Blue
  final Color _bgLight = const Color(0xFFF2F2F7); // iOS System Grouped Background
  final Color _cardWhite = Colors.white;
  final Color _textDark = const Color(0xFF1C1C1E); // iOS Label Color
  final Color _textMuted = const Color(0xFF8E8E93); // iOS Secondary Label

  // Fetch Store Logo dynamically
  Future<String?> _fetchStoreLogo(String clientId, String storeId) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .doc(storeId)
          .get();

      if (docSnapshot.exists && docSnapshot.data()!.containsKey('logoUrl')) {
        return docSnapshot.data()!['logoUrl'] as String?;
      }
    } catch (e) {
      debugPrint("Error fetching logo: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ LOGIC: Define the Date Range for the selected year
    final startOfYear = DateTime(_selectedYear, 1, 1);
    final endOfYear = DateTime(_selectedYear, 12, 31, 23, 59, 59);

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent, // Clean iOS look
        elevation: 0,
        iconTheme: IconThemeData(color: _textDark),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, size: 28), // Apple-style back button
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'ARCHIVES',
          style: GoogleFonts.poppins(
            color: _textDark,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: IconButton(
              icon: const Icon(CupertinoIcons.search, color: Colors.black87),
              tooltip: 'Rechercher',
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
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ UI: Premium Styled Year Selector
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Année sélectionnée",
                  style: GoogleFonts.poppins(
                      color: _textMuted, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: _bgLight,
                    borderRadius: BorderRadius.circular(20), // Pill shape
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      dropdownColor: Colors.white,
                      icon: const Icon(CupertinoIcons.chevron_down, color: Colors.black87, size: 16),
                      style: GoogleFonts.poppins(
                        color: _textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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

          const SizedBox(height: 10),

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
                  return Center(
                      child: Text('Une erreur est survenue.',
                          style: GoogleFonts.poppins(color: Colors.red)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.time, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune installation en $_selectedYear.',
                          style: GoogleFonts.poppins(
                              color: _textMuted, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                final installationDocs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  physics: const BouncingScrollPhysics(), // Apple-like bounce
                  itemCount: installationDocs.length,
                  itemBuilder: (context, index) {
                    final doc = installationDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    // ✅ EXTRACTED DATA (Safe Parsing for UI)
                    final installationCode = data['installationCode'] ?? 'N/A';
                    final clientName = data['clientName'] ?? 'Client Inconnu';
                    final storeName = data['storeName'] ?? 'Magasin Inconnu';
                    final storeLocation = data['storeLocation'] ?? '';

                    // IDs needed to fetch the logo
                    final clientId = data['clientId'];
                    final storeId = data['storeId'];
                    final directLogoUrl = data['logoUrl'];

                    // Defensive Date Parsing
                    DateTime? createdDate;
                    if (data['createdAt'] is Timestamp) {
                      createdDate = (data['createdAt'] as Timestamp).toDate();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _cardWhite,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => InstallationDetailsPage(
                                  installationDoc: doc,
                                  userRole: widget.userRole,
                                ),
                              ));
                            },
                            borderRadius: BorderRadius.circular(20),
                            highlightColor: Colors.black.withOpacity(0.02),
                            splashColor: const Color(0xFF34C759).withOpacity(0.05), // Greenish splash for finished
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [

                                  // 🖼️ DYNAMIC LOGO CONTAINER (with Completion Badge)
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.grey.shade100, width: 1),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(15),
                                          child: directLogoUrl != null
                                              ? CachedNetworkImage(
                                            imageUrl: directLogoUrl,
                                            fit: BoxFit.contain,
                                            placeholder: (context, url) => const CupertinoActivityIndicator(),
                                            errorWidget: (context, url, error) => _fallbackIcon(),
                                          )
                                              : (clientId != null && storeId != null)
                                              ? FutureBuilder<String?>(
                                            future: _fetchStoreLogo(clientId, storeId),
                                            builder: (context, logoSnapshot) {
                                              if (logoSnapshot.connectionState == ConnectionState.waiting) {
                                                return const CupertinoActivityIndicator();
                                              }
                                              if (logoSnapshot.hasData && logoSnapshot.data != null) {
                                                return CachedNetworkImage(
                                                  imageUrl: logoSnapshot.data!,
                                                  fit: BoxFit.contain,
                                                  errorWidget: (context, url, error) => _fallbackIcon(),
                                                );
                                              }
                                              return _fallbackIcon();
                                            },
                                          )
                                              : _fallbackIcon(),
                                        ),
                                      ),
                                      // Premium Completed Checkmark Badge
                                      Positioned(
                                        bottom: -4,
                                        right: -4,
                                        child: Container(
                                          decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.1),
                                                  blurRadius: 4,
                                                )
                                              ]
                                          ),
                                          child: const Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFF34C759), size: 20),
                                        ),
                                      )
                                    ],
                                  ),

                                  const SizedBox(width: 16),

                                  // 📄 INFO SECTION
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          installationCode,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 17,
                                            color: _textDark,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$storeName ${storeLocation.isNotEmpty ? '— $storeLocation' : ''}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: _textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          clientName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: _textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 📅 DATE & CHEVRON
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (createdDate != null)
                                        Text(
                                          DateFormat('dd MMM').format(createdDate),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: _textDark,
                                          ),
                                        ),
                                      if (createdDate != null)
                                        Text(
                                          DateFormat('yyyy').format(createdDate),
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: _textMuted,
                                          ),
                                        ),
                                      if (createdDate == null)
                                        Text("--/--", style: GoogleFonts.poppins(color: _textMuted)),

                                      const SizedBox(height: 8),
                                      Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey.shade400),
                                    ],
                                  )
                                ],
                              ),
                            ),
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

  // Fallback Icon if Logo URL fails or is empty
  Widget _fallbackIcon() {
    return Container(
      color: _bgLight,
      child: Center(
        child: Icon(CupertinoIcons.photo, color: Colors.grey.shade400, size: 24),
      ),
    );
  }
}
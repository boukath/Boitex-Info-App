import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';

class UniversalInterventionSearchPage extends StatefulWidget {
  final String serviceType;

  const UniversalInterventionSearchPage({
    super.key,
    required this.serviceType,
  });

  @override
  State<UniversalInterventionSearchPage> createState() =>
      _UniversalInterventionSearchPageState();
}

class _UniversalInterventionSearchPageState extends State<UniversalInterventionSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // 🎨 PREMIUM THEME COLORS
  final Color _primaryBlue = const Color(0xFF007AFF);
  final Color _bgLight = const Color(0xFFF2F2F7);
  final Color _cardWhite = Colors.white;
  final Color _textDark = const Color(0xFF1C1C1E);
  final Color _textMuted = const Color(0xFF8E8E93);

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
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _textDark),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'RECHERCHE',
          style: GoogleFonts.poppins(
            color: _textDark,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          // 🔍 PREMIUM SEARCH BAR
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: _bgLight,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                  });
                },
                style: GoogleFonts.poppins(color: _textDark),
                decoration: InputDecoration(
                  hintText: 'Rechercher un client, magasin ou code...',
                  hintStyle: GoogleFonts.poppins(color: _textMuted),
                  prefixIcon: Icon(CupertinoIcons.search, color: _textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(CupertinoIcons.clear_thick_circled, color: Colors.grey.shade400),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = "";
                      });
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
          ),

          // 📄 LIVE STREAM OF ALL INTERVENTIONS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('interventions')
                  .where('serviceType', isEqualTo: widget.serviceType)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: _primaryBlue));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erreur de chargement.', style: GoogleFonts.poppins(color: Colors.red)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.search, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune intervention trouvée.',
                          style: GoogleFonts.poppins(color: _textMuted, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final clientName = (data['clientName'] ?? '').toString().toLowerCase();
                    final storeName = (data['storeName'] ?? '').toString().toLowerCase();
                    final code = (data['interventionCode'] ?? '').toString().toLowerCase();

                    return clientName.contains(_searchQuery) ||
                        storeName.contains(_searchQuery) ||
                        code.contains(_searchQuery);
                  }).toList();
                }

                docs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;

                  Timestamp? timeA = dataA['updatedAt'] ?? dataA['createdAt'];
                  Timestamp? timeB = dataB['updatedAt'] ?? dataB['createdAt'];

                  if (timeA == null && timeB == null) return 0;
                  if (timeA == null) return 1;
                  if (timeB == null) return -1;

                  return timeB.compareTo(timeA);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun résultat pour "$_searchQuery"',
                      style: GoogleFonts.poppins(color: _textMuted),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final clientName = data['clientName'] ?? 'Client Inconnu';
                    final storeName = data['storeName'] ?? 'Magasin Inconnu';
                    final storeLocation = data['storeLocation'] ?? '';
                    final status = data['status'] ?? 'En Cours';

                    // ✅ NEW LOGIC: Determine if closed and format the status string
                    final bool isClosed = (status == 'Terminée' || status == 'Terminé' || status == 'Clôturée');

                    // Add the checkmark if the status is Terminé(e)
                    final String displayStatus = (status == 'Terminée' || status == 'Terminé')
                        ? '✅ $status'
                        : status;

                    final clientId = data['clientId'];
                    final storeId = data['storeId'];
                    final directLogoUrl = data['logoUrl'];

                    Timestamp? displayTimestamp = data['updatedAt'] ?? data['createdAt'];
                    DateTime? displayDate = displayTimestamp?.toDate();

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
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => InterventionDetailsPage(
                                    interventionDoc: doc as DocumentSnapshot<Map<String, dynamic>>,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            highlightColor: Colors.black.withOpacity(0.02),
                            splashColor: isClosed
                                ? const Color(0xFF34C759).withOpacity(0.05)
                                : const Color(0xFFFF9500).withOpacity(0.05),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 🖼️ DYNAMIC LOGO & STATUS BADGE
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

                                      Positioned(
                                        bottom: -4,
                                        right: -4,
                                        child: Container(
                                          decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)
                                              ]
                                          ),
                                          child: Icon(
                                              isClosed ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.time_solid,
                                              color: isClosed ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                                              size: 20
                                          ),
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
                                          storeName,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: _textDark,
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$clientName ${storeLocation.isNotEmpty ? '— $storeLocation' : ''}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: _textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        // ✅ TEXT UPDATED HERE: Uses displayStatus
                                        Text(
                                          displayStatus,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: isClosed ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                                            fontWeight: FontWeight.w600,
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
                                      if (displayDate != null)
                                        Text(
                                          DateFormat('dd MMM').format(displayDate),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: _textDark,
                                          ),
                                        ),
                                      if (displayDate != null)
                                        Text(
                                          DateFormat('yyyy').format(displayDate),
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: _textMuted,
                                          ),
                                        ),
                                      if (displayDate == null)
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

  Widget _fallbackIcon() {
    return Container(
      color: _bgLight,
      child: Center(
        child: Icon(CupertinoIcons.photo, color: Colors.grey.shade400, size: 24),
      ),
    );
  }
}
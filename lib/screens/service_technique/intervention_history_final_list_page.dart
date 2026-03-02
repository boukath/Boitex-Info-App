// lib/screens/service_technique/intervention_history_final_list_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/administration/store_equipment_page.dart';

class InterventionHistoryFinalListPage extends StatefulWidget {
  final String serviceType;
  final String clientName;
  final String storeName;
  final int selectedYear;

  const InterventionHistoryFinalListPage({
    super.key,
    required this.serviceType,
    required this.clientName,
    required this.storeName,
    required this.selectedYear,
  });

  @override
  State<InterventionHistoryFinalListPage> createState() =>
      _InterventionHistoryFinalListPageState();
}

class _InterventionHistoryFinalListPageState
    extends State<InterventionHistoryFinalListPage> {
  String? _clientLogoUrl;
  String? _storeLogoUrl; // ✅ NEW: Variable for the specific store logo
  bool _isLoadingLogo = true;

  // Variables to store the actual IDs extracted from the interventions
  String? _clientId;
  String? _storeId;
  String? _storeLocation;

  // 🎨 Premium Color Palette
  final Color _bgLight = const Color(0xFFF4F6F9);
  final Color _textDark = const Color(0xFF111827);
  final Color _textMuted = const Color(0xFF6B7280);
  final Color _cardWhite = Colors.white;
  final Color _primaryBlue = const Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _extractIdsAndFetchDetails();
  }

  /// Extract clientId and storeId directly from an intervention!
  Future<void> _extractIdsAndFetchDetails() async {
    try {
      // 1. Get just ONE intervention belonging to this list to extract the real IDs
      final interventionSnap = await FirebaseFirestore.instance
          .collection('interventions')
          .where('clientName', isEqualTo: widget.clientName)
          .where('storeName', isEqualTo: widget.storeName)
          .limit(1)
          .get();

      if (interventionSnap.docs.isNotEmpty) {
        final interventionData = interventionSnap.docs.first.data();

        // Extract the exact IDs!
        final exactClientId = interventionData['clientId'] as String?;
        final exactStoreId = interventionData['storeId'] as String?;

        if (exactClientId != null && exactStoreId != null) {
          // 2. Fetch Logo using the exact clientId
          final clientDoc = await FirebaseFirestore.instance.collection('clients').doc(exactClientId).get();
          final clientData = clientDoc.data();

          // 3. Fetch exact location AND Store Logo using the exact storeId
          final storeDoc = await FirebaseFirestore.instance
              .collection('clients')
              .doc(exactClientId)
              .collection('stores')
              .doc(exactStoreId)
              .get();
          final storeData = storeDoc.data();

          if (mounted) {
            setState(() {
              _clientId = exactClientId;
              _storeId = exactStoreId;
              _clientLogoUrl = clientData?['logoUrl'] as String?;
              // ✅ Fetch the Store's logoUrl
              _storeLogoUrl = storeData?['logoUrl'] as String?;
              _storeLocation = storeData?['adresse'] ?? storeData?['address'] ?? storeData?['location'] ?? '';
              _isLoadingLogo = false;
            });
          }
          return; // Success!
        }
      }

      // Fallback if no intervention had IDs
      if (mounted) setState(() => _isLoadingLogo = false);

    } catch (e) {
      debugPrint("Error fetching client/store details: $e");
      if (mounted) setState(() => _isLoadingLogo = false);
    }
  }

  // Navigation function
  void _navigateToStorePage() {
    if (_clientId != null && _storeId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoreEquipmentPage(
            clientId: _clientId!,
            storeId: _storeId!,
            storeName: widget.storeName,
            // Pass the best logo we have to the Store Equipment page
            logoUrl: _storeLogoUrl?.isNotEmpty == true ? _storeLogoUrl : _clientLogoUrl,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Données du magasin introuvables ou en cours de chargement."),
          backgroundColor: Colors.orange.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final startOfYear = DateTime(widget.selectedYear, 1, 1);
    final endOfYear = DateTime(widget.selectedYear, 12, 31, 23, 59, 59);

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _cardWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: _textDark),
        centerTitle: false,
        toolbarHeight: 90,
        title: GestureDetector(
          onTap: _navigateToStorePage,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: _bgLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                _buildStoreLogo(), // ✅ Uses the updated logo function
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.storeName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                          fontSize: 14,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (_storeLocation != null && _storeLocation!.isNotEmpty) ...[
                            Icon(CupertinoIcons.location_solid, size: 12, color: _primaryBlue),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _storeLocation!,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: _textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            "•  ${widget.selectedYear}",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(CupertinoIcons.arrow_right_circle_fill, color: _primaryBlue, size: 28),
              ],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('serviceType', isEqualTo: widget.serviceType)
            .where('clientName', isEqualTo: widget.clientName)
            .where('storeName', isEqualTo: widget.storeName)
            .where('createdAt', isGreaterThanOrEqualTo: startOfYear)
            .where('createdAt', isLessThanOrEqualTo: endOfYear)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text("Erreur: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // FILTER LOCALLY: Only keep Terminé and Clôturé
          final docs = snapshot.data!.docs.where((doc) {
            final status = doc.data()['status'] as String?;
            return status == 'Terminé' || status == 'Clôturé';
          }).toList();

          if (docs.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: docs.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final interventionDoc = docs[index];
              final data = interventionDoc.data();
              return _buildPerfectCard(context, interventionDoc, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Icon(CupertinoIcons.doc_text_search, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucune intervention trouvée',
            style: GoogleFonts.poppins(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Il n\'y a pas d\'interventions terminées\npour ${widget.selectedYear}.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: _textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// ✅ Logic to prefer Store Logo, fallback to Client Logo
  Widget _buildStoreLogo() {
    if (_isLoadingLogo) {
      return const SizedBox(
          width: 42,
          height: 42,
          child: CupertinoActivityIndicator()
      );
    }

    // Determine which logo to use (Store > Client > Null)
    final String? finalLogoUrl = (_storeLogoUrl != null && _storeLogoUrl!.isNotEmpty)
        ? _storeLogoUrl
        : _clientLogoUrl;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: finalLogoUrl != null && finalLogoUrl.isNotEmpty
            ? CachedNetworkImage(
          imageUrl: finalLogoUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Center(child: CupertinoActivityIndicator()),
          errorWidget: (context, url, error) => Icon(Icons.storefront, color: Colors.grey.shade400, size: 20),
        )
            : Icon(Icons.storefront, color: Colors.grey.shade400, size: 20),
      ),
    );
  }

  Widget _buildPerfectCard(BuildContext context, DocumentSnapshot interventionDoc, Map<String, dynamic> data) {
    final bool isCloture = data['status'] == 'Clôturé';
    final String status = data['status'] ?? 'Inconnu';

    final String code = data['interventionCode'] ?? data['code'] ?? 'Sans code';
    final String type = data['interventionType'] ?? 'Intervention';
    final String systemName = data['systemName'] ?? 'Système non spécifié';
    final String priority = data['priority'] ?? 'Normale';
    final String billingStatus = data['billingStatus'] ?? 'N/A';

    final List<dynamic> techsDyn = data['assignedTechnicians'] ?? [];
    final String technicians = techsDyn.isNotEmpty ? techsDyn.join(', ') : 'Non assigné';

    final Timestamp? scheduledTs = data['scheduledAt'] as Timestamp?;
    final Timestamp? createdTs = data['createdAt'] as Timestamp?;
    final DateTime? actionDate = scheduledTs?.toDate() ?? createdTs?.toDate();

    final String formattedDate = actionDate != null
        ? DateFormat('dd MMM yyyy • HH:mm', 'fr_FR').format(actionDate)
        : 'Date inconnue';

    Color priorityColor = Colors.grey.shade600;
    Color priorityBg = Colors.grey.shade100;
    if (priority.toLowerCase() == 'haute') {
      priorityColor = const Color(0xFFDC2626);
      priorityBg = const Color(0xFFFEF2F2);
    } else if (priority.toLowerCase() == 'moyenne') {
      priorityColor = const Color(0xFFD97706);
      priorityBg = const Color(0xFFFFFBEB);
    }

    final Color statusColor = isCloture ? const Color(0xFF059669) : const Color(0xFFEA580C);
    final Color statusBg = isCloture ? const Color(0xFFD1FAE5) : const Color(0xFFFFEDD5);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => InterventionDetailsPage(
                  interventionDoc: interventionDoc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      code,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        priority.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: priorityColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  "$type - $systemName",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Icon(CupertinoIcons.calendar, size: 16, color: _textMuted),
                    const SizedBox(width: 8),
                    Text(
                      formattedDate,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(CupertinoIcons.person_2_fill, size: 16, color: _textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        technicians,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              isCloture ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.time_solid,
                              color: statusColor,
                              size: 14
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Row(
                      children: [
                        Icon(
                          billingStatus == 'FACTURABLE' ? CupertinoIcons.money_dollar_circle_fill : CupertinoIcons.doc_text,
                          size: 16,
                          color: billingStatus == 'FACTURABLE' ? Colors.red.shade600 : _textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          billingStatus,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: billingStatus == 'FACTURABLE' ? Colors.red.shade700 : _textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
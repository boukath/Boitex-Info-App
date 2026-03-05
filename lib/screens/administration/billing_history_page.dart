// lib/screens/administration/billing_history_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// IMPORTANT IMPORTS FOR VIEWING DETAILS
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';

class BillingHistoryPage extends StatefulWidget {
  const BillingHistoryPage({super.key});

  @override
  State<BillingHistoryPage> createState() => _BillingHistoryPageState();
}

class _BillingHistoryPageState extends State<BillingHistoryPage> {
  // --- FILTER STATES ---
  String _selectedType = 'intervention'; // 'intervention' or 'sav'
  String _selectedStatus = 'Tous'; // 'Tous', 'Facturé', 'Sans Facture'
  String _selectedService = 'Tous'; // 'Tous', 'Service IT', 'Service Technique'
  String _searchQuery = '';

  // --- DATA STATES ---
  late Future<List<DocumentSnapshot>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Fetch from Firestore only when changing the primary type (Intervention vs SAV)
  void _fetchData() {
    final collection = _selectedType == 'intervention' ? 'interventions' : 'sav_tickets';
    _dataFuture = FirebaseFirestore.instance
        .collection(collection)
        .where('status', isEqualTo: 'Clôturé')
        .get()
        .then((snap) => snap.docs);
  }

  Future<void> _launchURL(BuildContext context, String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir: $urlString')));
      }
    }
  }

  // --- 💎 iOS 2026 UI HELPERS 💎 ---

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          _buildSegment('Interventions', 'intervention', Icons.construction_rounded),
          _buildSegment('Tickets SAV', 'sav', Icons.support_agent_rounded),
        ],
      ),
    );
  }

  Widget _buildSegment(String title, String value, IconData icon) {
    final isSelected = _selectedType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            setState(() {
              _selectedType = value;
              // Reset sub-filters to prevent empty lists on switch
              _selectedStatus = 'Tous';
              _selectedService = 'Tous';
              _fetchData();
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastOutSlowIn,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? const Color(0xFF007AFF) : const Color(0xFF86868B)),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? const Color(0xFF1D1D1F) : const Color(0xFF86868B),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPills(List<String> options, String currentValue, Function(String) onSelect) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: options.map((option) {
          final isSelected = currentValue == option;
          return GestureDetector(
            onTap: () => setState(() => onSelect(option)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1D1D1F) : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? const Color(0xFF1D1D1F) : Colors.white.withOpacity(0.8)),
              ),
              child: Text(
                option,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF86868B),
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.3),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(color: Colors.transparent),
          ),
        ),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1D1D1F)),
        title: Text(
          "Historique de Facturation",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1D1D1F), fontSize: 20),
        ),
      ),
      body: Stack(
        children: [
          // 🌈 iOS 2026 Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE0EAFC), Color(0xFFF9E0FA), Color(0xFFE5F0FF)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100, right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFD1FF).withOpacity(0.7))),
            ),
          ),
          Positioned(
            bottom: -50, left: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFB5DEFF).withOpacity(0.6))),
            ),
          ),

          // 📱 MAIN CONTENT
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 750),
                child: Column(
                  children: [
                    // --- STATIC HEADER SECTION ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: Column(
                        children: [
                          // Search Bar
                          _buildGlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: "Rechercher un dossier...",
                                hintStyle: GoogleFonts.outfit(color: const Color(0xFF86868B)),
                                border: InputBorder.none,
                                icon: const Icon(Icons.search_rounded, color: Color(0xFF007AFF)),
                              ),
                              style: GoogleFonts.outfit(color: const Color(0xFF1D1D1F)),
                              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                            ),
                          ),

                          // Main Type Toggle
                          _buildGlassSegmentedControl(),
                          const SizedBox(height: 16),

                          // Status Filters
                          _buildFilterPills(['Tous', 'Facturé', 'Sans Facture'], _selectedStatus, (val) => _selectedStatus = val),

                          // Service Filters (Animated to disappear if SAV is selected)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _selectedType == 'intervention'
                                ? Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: _buildFilterPills(['Tous', 'Service IT', 'Service Technique'], _selectedService, (val) => _selectedService = val),
                            )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),

                    // --- DYNAMIC LIST SECTION ---
                    Expanded(
                      child: FutureBuilder<List<DocumentSnapshot>>(
                        future: _dataFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF007AFF)));
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text("Erreur de chargement", style: GoogleFonts.outfit(color: const Color(0xFFFF3B30))));
                          }

                          // LOCAL FILTERING (Extremely fast, no extra Firestore reads)
                          final allDocs = snapshot.data ?? [];
                          final filteredDocs = allDocs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>?;
                            if (data == null) return false;

                            // 1. Status Filter
                            if (_selectedStatus != 'Tous') {
                              final status = data['billingStatus'] as String? ?? '';
                              if (status != _selectedStatus) return false;
                            }

                            // 2. Service Filter (Interventions Only)
                            if (_selectedType == 'intervention' && _selectedService != 'Tous') {
                              final service = data['serviceType'] as String? ?? '';
                              if (service != _selectedService) return false;
                            }

                            // 3. Search Query Filter
                            if (_searchQuery.isNotEmpty) {
                              final title = (data['storeName'] ?? data['clientName'] ?? data['ticketId'] ?? '').toString().toLowerCase();
                              if (!title.contains(_searchQuery)) return false;
                            }

                            return true;
                          }).toList();

                          // Sort locally by date descending
                          filteredDocs.sort((a, b) {
                            final aData = a.data() as Map<String, dynamic>?;
                            final bData = b.data() as Map<String, dynamic>?;
                            final aDate = (aData?['interventionDate'] ?? aData?['createdAt']) as Timestamp?;
                            final bDate = (bData?['interventionDate'] ?? bData?['createdAt']) as Timestamp?;
                            return (bDate?.toDate() ?? DateTime(0)).compareTo(aDate?.toDate() ?? DateTime(0));
                          });

                          if (filteredDocs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.history_rounded, size: 64, color: Color(0xFF86868B)),
                                  const SizedBox(height: 16),
                                  Text("Aucun historique trouvé", style: GoogleFonts.outfit(fontSize: 18, color: const Color(0xFF86868B))),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 40),
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final data = doc.data() as Map<String, dynamic>;

                              return _buildHistoryTile(context, doc, data);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- BUILDER FOR INDIVIDUAL LIST ITEMS ---
  Widget _buildHistoryTile(BuildContext context, DocumentSnapshot doc, Map<String, dynamic> data) {
    final isFacture = data['billingStatus'] == 'Facturé';
    final invoiceUrl = data['invoiceUrl'] as String?;

    // Determine title based on type
    final storeName = data['storeName'] as String? ?? data['clientName'] as String? ?? 'Inconnu';
    final location = data['storeLocation'] as String? ?? '';
    final title = location.isNotEmpty ? '$storeName - $location' : storeName;

    // Subtitle
    final subTitle = _selectedType == 'intervention'
        ? (data['serviceType'] as String? ?? 'Service N/A')
        : 'Ticket #${data['ticketId'] ?? 'N/A'}';

    // Date
    final dateRaw = (data['interventionDate'] ?? data['createdAt']) as Timestamp?;
    final dateStr = dateRaw != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(dateRaw.toDate()) : 'N/A';

    return GestureDetector(
      onTap: () {
        if (_selectedType == 'intervention') {
          // ✅ FIXED: Added 'as DocumentSnapshot<Map<String, dynamic>>'
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => InterventionDetailsPage(
                  interventionDoc: doc as DocumentSnapshot<Map<String, dynamic>>
              ))
          );
        } else {
          final ticket = SavTicket.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SavTicketDetailsPage(ticket: ticket))
          );
        }
      },
      child: _buildGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Status Icon Indicator
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isFacture ? const Color(0xFF34C759).withOpacity(0.1) : const Color(0xFFFF9500).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isFacture ? Icons.receipt_long_rounded : Icons.money_off_csred_rounded,
                color: isFacture ? const Color(0xFF34C759) : const Color(0xFFFF9500),
              ),
            ),
            const SizedBox(width: 16),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1D1D1F)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // ✅ FIXED: Wrapped in Flexible and added overflow handling
                      Flexible(
                        child: Text(
                          subTitle,
                          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF86868B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4, height: 4,
                        decoration: const BoxDecoration(color: Color(0xFF86868B), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      // The date can stay rigid, as we want to always see it
                      Text(dateStr, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF86868B))),
                    ],
                  )
                ],
              ),
            ),

            // Action / Trailing
            if (isFacture && invoiceUrl != null && invoiceUrl.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFFF3B30)),
                tooltip: 'Ouvrir Facture PDF',
                onPressed: () => _launchURL(context, invoiceUrl),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFC7C7CC)),
          ],
        ),
      ),
    );
  }
}
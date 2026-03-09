// lib/screens/service_technique/sav_ticket_history_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Added for Date Formatting
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';

class SavTicketHistoryPage extends StatefulWidget {
  final String serviceType;

  const SavTicketHistoryPage({super.key, required this.serviceType});

  @override
  State<SavTicketHistoryPage> createState() => _SavTicketHistoryPageState();
}

class _SavTicketHistoryPageState extends State<SavTicketHistoryPage> {
  // ✅ STATE: Search Query
  String _searchQuery = '';

  // ✅ STATE: Year Selection (Default to current year)
  int _selectedYear = DateTime.now().year;

  // Generate a list of years (Current year back 4 years)
  List<int> get _availableYears {
    final currentYear = DateTime.now().year;
    return List.generate(4, (index) => currentYear - index);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ LOGIC: Define the Date Range for the selected year
    final startOfYear = DateTime(_selectedYear, 1, 1);
    final endOfYear = DateTime(_selectedYear, 12, 31, 23, 59, 59);

    // Responsive width constraint for Web/Desktop
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final double contentWidth = isDesktop ? 600 : double.infinity;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF8FAFC), // Fallback light color
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Historique SAV',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          _buildYearSelectorGlass(),
        ],
      ),
      body: Stack(
        children: [
          // 🌅 Background Gradient 2026 Light Style
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8FAFC), // Slate 50 (Very light grey/white)
                    Color(0xFFE0E7FF), // Indigo 100 (Soft blueish)
                    Color(0xFFF3E8FF), // Purple 100 (Soft pastel purple)
                    Color(0xFFFFF7ED), // Orange 50 (Warm touch)
                  ],
                  stops: [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // ✨ Ambient Glowing Orbs (Softened for light mode)
          Positioned(
            top: -50,
            left: -50,
            child: _buildGlowingOrb(Colors.orange.shade200, 200),
          ),
          Positioned(
            bottom: 100,
            right: -100,
            child: _buildGlowingOrb(Colors.blue.shade200, 250),
          ),

          // 📱 Main Content Area
          SafeArea(
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    // 🔍 Glassmorphic Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: _buildGlassSearchBar(),
                    ),

                    // 📜 Expanded List with Glass Cards
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('sav_tickets')
                            .where('serviceType', isEqualTo: widget.serviceType)
                            .where('status', whereIn: ['Retourné', 'Dépose'])
                            .where('createdAt', isGreaterThanOrEqualTo: startOfYear)
                            .where('createdAt', isLessThanOrEqualTo: endOfYear)
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text(
                                'Une erreur est survenue.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            );
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.black26,
                                strokeWidth: 2,
                              ),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return _buildEmptyState();
                          }

                          // Filtering logic (Search) applied to the Year's data
                          final allTickets = snapshot.data!.docs.map((doc) {
                            return SavTicket.fromFirestore(
                                doc as DocumentSnapshot<Map<String, dynamic>>);
                          }).toList();

                          final filteredTickets = allTickets.where((ticket) {
                            final query = _searchQuery.toLowerCase();
                            return ticket.savCode.toLowerCase().contains(query) ||
                                ticket.clientName.toLowerCase().contains(query) ||
                                ticket.productName.toLowerCase().contains(query) ||
                                ticket.serialNumber.toLowerCase().contains(query) ||
                                (ticket.storeName ?? '').toLowerCase().contains(query);
                          }).toList();

                          if (filteredTickets.isEmpty) {
                            return _buildEmptyState(isSearch: true);
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.only(
                                left: 16.0, right: 16.0, bottom: 40.0),
                            physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics()),
                            itemCount: filteredTickets.length,
                            itemBuilder: (context, index) {
                              final ticket = filteredTickets[index];
                              return _buildGlassCard(context, ticket);
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

  // --- UI COMPONENTS ---

  /// Year Selector (Glass Pill)
  Widget _buildYearSelectorGlass() {
    return Container(
      margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                dropdownColor: Colors.white.withOpacity(0.95),
                icon: const Icon(CupertinoIcons.chevron_down, color: Colors.black87, size: 14),
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }

  /// Glassmorphic Search Bar
  Widget _buildGlassSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
          ),
          child: TextField(
            style: const TextStyle(color: Colors.black87, fontSize: 16),
            cursorColor: Colors.black87,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: const InputDecoration(
              hintText: 'Rechercher (Boutique, Client, SAV...)',
              hintStyle: TextStyle(color: Colors.black54),
              prefixIcon: Icon(CupertinoIcons.search, color: Colors.black54),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ NEW: Fetches the Store Logo dynamically or falls back to Status Icon
  Widget _buildStoreLogoOrIcon(SavTicket ticket, Color statusColor, Color statusBgColor, IconData statusIcon) {
    // If we are missing IDs, just show the fallback icon immediately.
    if (ticket.clientId.toString().isEmpty || ticket.storeId.toString().isEmpty) {
      return _buildFallbackIcon(statusColor, statusBgColor, statusIcon);
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('clients')
          .doc(ticket.clientId)
          .collection('stores')
          .doc(ticket.storeId)
          .get(),
      builder: (context, snapshot) {
        // While Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildFallbackIcon(statusColor, statusBgColor, statusIcon, isLoading: true);
        }

        // If data is received and logoUrl exists
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final logoUrl = data?['logoUrl'] as String?;

          if (logoUrl != null && logoUrl.isNotEmpty) {
            return Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2), // Premium white ring around logo
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  logoUrl,
                  fit: BoxFit.cover,
                  // If the image fails to load, gracefully fall back to the icon
                  errorBuilder: (context, error, stackTrace) =>
                      _buildFallbackIcon(statusColor, statusBgColor, statusIcon),
                ),
              ),
            );
          }
        }

        // Final fallback if document didn't contain a URL
        return _buildFallbackIcon(statusColor, statusBgColor, statusIcon);
      },
    );
  }

  /// Fallback UI for when a logo doesn't exist or is loading
  Widget _buildFallbackIcon(Color statusColor, Color statusBgColor, IconData statusIcon, {bool isLoading = false}) {
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        color: statusBgColor.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: statusBgColor, width: 1),
      ),
      child: isLoading
          ? const CupertinoActivityIndicator()
          : Icon(statusIcon, color: statusColor, size: 24),
    );
  }

  /// Modern Glass Card Item
  Widget _buildGlassCard(BuildContext context, SavTicket ticket) {
    final isDepose = ticket.status == 'Dépose';

    // Dynamic styling based on status
    final statusColor = isDepose ? Colors.orange.shade700 : Colors.teal.shade600;
    final statusBgColor = isDepose ? Colors.orange.shade100 : Colors.teal.shade100;
    final statusIcon = isDepose ? CupertinoIcons.arrow_down_circle_fill : CupertinoIcons.checkmark_circle_fill;

    // Formatting the date.
    final formattedDate = DateFormat('dd MMM yyyy').format(ticket.createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                splashColor: Colors.black.withOpacity(0.05),
                highlightColor: Colors.black.withOpacity(0.02),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => SavTicketDetailsPage(ticket: ticket),
                  ));
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ✅ Replaced static container with dynamic Store Logo Widget
                      _buildStoreLogoOrIcon(ticket, statusColor, statusBgColor, statusIcon),

                      const SizedBox(width: 12),

                      // Card Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ROW 1: Store Name & Status Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    ticket.storeName ?? 'Boutique non spécifiée',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      height: 1.2,
                                      letterSpacing: -0.5,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    ticket.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: statusColor,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // ROW 2: Client Name
                            Text(
                              ticket.clientName,
                              style: TextStyle(
                                color: Colors.black87.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            // ROW 3: SAV Code & Date
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  ticket.savCode,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(CupertinoIcons.calendar, size: 14, color: Colors.black45),
                                    const SizedBox(width: 4),
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.chevron_right, color: Colors.black26, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Empty State Widget
  Widget _buildEmptyState({bool isSearch = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearch ? CupertinoIcons.search : CupertinoIcons.doc_text_search,
            size: 60,
            color: Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            isSearch
                ? 'Aucun résultat trouvé.'
                : 'Aucun ticket en $_selectedYear.',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Ambient Glowing Orb builder for Background
  Widget _buildGlowingOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.5),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
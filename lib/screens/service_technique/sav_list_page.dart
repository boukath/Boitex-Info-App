// lib/screens/service_technique/sav_list_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/screens/service_technique/add_sav_ticket_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_history_page.dart';

class SavListPage extends StatefulWidget {
  final String serviceType;
  const SavListPage({super.key, required this.serviceType});

  @override
  State<SavListPage> createState() => _SavListPageState();
}

class _SavListPageState extends State<SavListPage> {
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();
  }

  Future<void> _fetchCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _currentUserRole = doc.data()?['role'];
          });
        }
      } catch (e) {
        debugPrint('Error fetching role: $e');
      }
    }
  }

  bool get _isManager {
    return _currentUserRole == 'Admin' ||
        _currentUserRole == 'PDG' ||
        _currentUserRole == 'Responsable Technique' ||
        _currentUserRole == 'Responsable Administratif';
  }

  // ✅ ENHANCED Apple-Style Colorful Gradients for the Ambient Glow
  (List<Color> gradient, Color textColor) _getStatusTheme(String status) {
    switch (status) {
      case 'Nouveau': // Vivid iOS Blue
        return ([const Color(0xFF3B82F6), const Color(0xFF60A5FA), const Color(0xFF93C5FD)], const Color(0xFF1E3A8A));
      case 'En Diagnostic':
      case 'En Réparation': // Warm Sunset Amber
        return ([const Color(0xFFF59E0B), const Color(0xFFFBBF24), const Color(0xFFFDE68A)], const Color(0xFF78350F));
      case 'Terminé':
      case 'Approuvé - Prêt pour retour': // Vibrant Emerald
        return ([const Color(0xFF10B981), const Color(0xFF34D399), const Color(0xFFA7F3D0)], const Color(0xFF064E3B));
      case 'Irréparable - Remplacement Demandé': // Intense Rose/Red
        return ([const Color(0xFFEF4444), const Color(0xFFF87171), const Color(0xFFFECACA)], const Color(0xFF7F1D1D));
      case 'Retourné':
      case 'Dépose': // Sleek Graphite/Silver
        return ([const Color(0xFF6B7280), const Color(0xFF9CA3AF), const Color(0xFFE5E7EB)], const Color(0xFF1F2937));
      default:
        return ([const Color(0xFF6B7280), const Color(0xFF9CA3AF), const Color(0xFFE5E7EB)], const Color(0xFF1F2937));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive width constraint for Web/Desktop
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final double contentWidth = isDesktop ? 650 : double.infinity;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF8FAFC),
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
                    Color(0xFFF8FAFC), // Slate 50
                    Color(0xFFE0E7FF), // Soft Indigo
                    Color(0xFFF3E8FF), // Pastel Purple
                    Color(0xFFFFF7ED), // Warm Orange touch
                  ],
                  stops: [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // ✨ Ambient Glowing Orbs (Fixed in background so cards slide over them)
          Positioned(
            top: 100,
            left: -50,
            child: _buildGlowingOrb(Colors.blue.shade200, 250),
          ),
          Positioned(
            bottom: 200,
            right: -100,
            child: _buildGlowingOrb(Colors.orange.shade200, 300),
          ),

          // 📱 Main Custom Scroll View
          Center(
            child: SizedBox(
              width: contentWidth,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverAppBar(
                    expandedHeight: 120.0,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    iconTheme: const IconThemeData(color: Colors.black87),
                    flexibleSpace: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: FlexibleSpaceBar(
                          titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
                          title: Text(
                            'SAV Actifs',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF111827),
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                            ),
                          ),
                          background: Container(color: Colors.white.withOpacity(0.4)),
                        ),
                      ),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.8), width: 1),
                        ),
                        child: IconButton(
                          tooltip: 'Historique',
                          icon: const Icon(CupertinoIcons.time, color: Color(0xFF4B5563), size: 22),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => SavTicketHistoryPage(serviceType: widget.serviceType)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('sav_tickets')
                        .where('serviceType', isEqualTo: widget.serviceType)
                        .where('status', whereIn: [
                      'Nouveau',
                      'En Diagnostic',
                      'En Réparation',
                      'Terminé',
                      'Approuvé - Prêt pour retour',
                      'Irréparable - Remplacement Demandé',
                    ])
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(color: Colors.black26, strokeWidth: 3),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'Une erreur est survenue.',
                              style: GoogleFonts.inter(color: Colors.red.shade400),
                            ),
                          ),
                        );
                      }

                      final tickets = snapshot.data?.docs ?? [];

                      if (tickets.isEmpty) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.tray_fill, size: 64, color: Colors.black.withOpacity(0.1)),
                                const SizedBox(height: 16),
                                Text(
                                  "Aucun ticket SAV actif.",
                                  style: GoogleFonts.inter(
                                    color: Colors.black54,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final doc = tickets[index];
                              final ticket = SavTicket.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
                              return _buildIOS26GlassCard(context, ticket);
                            },
                            childCount: tickets.length,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // 🍎 iOS Style Floating Action Button
      // 🍎 iOS Style Floating Action Button
      floatingActionButton: FloatingActionButton.extended(
        elevation: 8,
        highlightElevation: 16,
        backgroundColor: Colors.white.withOpacity(0.9),
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white, width: 2), // ✅ FIXED HERE
        ),
        icon: const Icon(CupertinoIcons.add, size: 22),
        label: Text(
          'Nouveau Ticket',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddSavTicketPage(serviceType: widget.serviceType),
            ),
          );
        },
      ),
    );
  }

  // --- UI COMPONENTS ---

  /// Ambient Glowing Orb builder for Background
  Widget _buildGlowingOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.4),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  /// Fetches the Store Logo dynamically or falls back to Status Icon
  Widget _buildStoreLogoOrIcon(SavTicket ticket, Color statusColor, Color statusBgColor) {
    if (ticket.clientId.toString().isEmpty || ticket.storeId.toString().isEmpty) {
      return _buildFallbackIcon(statusColor, statusBgColor);
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('clients')
          .doc(ticket.clientId)
          .collection('stores')
          .doc(ticket.storeId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildFallbackIcon(statusColor, statusBgColor, isLoading: true);
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final logoUrl = data?['logoUrl'] as String?;

          if (logoUrl != null && logoUrl.isNotEmpty) {
            return Container(
              height: 56, // Massive Hero Logo Size
              width: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  logoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildFallbackIcon(statusColor, statusBgColor),
                ),
              ),
            );
          }
        }

        return _buildFallbackIcon(statusColor, statusBgColor);
      },
    );
  }

  /// Fallback UI for when a logo doesn't exist
  Widget _buildFallbackIcon(Color statusColor, Color statusBgColor, {bool isLoading = false}) {
    return Container(
      height: 56,
      width: 56,
      decoration: BoxDecoration(
        color: statusBgColor.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: statusBgColor, width: 1.5),
      ),
      child: isLoading
          ? const CupertinoActivityIndicator()
          : Icon(CupertinoIcons.building_2_fill, color: statusColor, size: 28),
    );
  }

  // ✅ 2026 iOS GLASS ANIMATION CARD WITH HUGE STORE NAME
  Widget _buildIOS26GlassCard(BuildContext context, SavTicket ticket) {
    final theme = _getStatusTheme(ticket.status);

    // Fallback date formatter if locale not initialized, robust against errors
    String formattedDate;
    try {
      formattedDate = DateFormat('dd MMM yyyy • HH:mm', 'fr_FR').format(ticket.createdAt);
    } catch (_) {
      formattedDate = DateFormat('dd MMM yyyy • HH:mm').format(ticket.createdAt);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      // THE AMBIENT GLOW BACKDROP
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: theme.$1[0].withOpacity(0.12),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      // THE FROSTED GLASS LAYER
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                highlightColor: Colors.black.withOpacity(0.03),
                splashColor: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(32),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SavTicketDetailsPage(ticket: ticket)),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- ROW 1: SAV CODE & STATUS PILL ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          ticket.savCode,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.$1[0].withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.$1[0].withOpacity(0.3), width: 1),
                          ),
                          child: Text(
                            ticket.status.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: theme.$2,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // --- ROW 2 (HERO): HUGE LOGO & STORE NAME ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildStoreLogoOrIcon(ticket, theme.$2, theme.$1[0].withOpacity(0.2)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            ticket.storeName ?? 'Boutique non spécifiée',
                            style: GoogleFonts.inter(
                              fontSize: 22, // Massive Hero Title
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -1.0,
                              height: 1.1,
                            ),
                            maxLines: 2, // Wraps cleanly on mobile
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // --- ROW 3: PRODUCT & CLIENT SUBTITLES ---
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.productName,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(CupertinoIcons.person_solid, size: 14, color: Colors.black.withOpacity(0.4)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  ticket.clientName,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black54,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --- INSET BOX: PROBLEM DESCRIPTION ---
                    if (ticket.problemDescription.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.8)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(CupertinoIcons.exclamationmark_circle, size: 16, color: theme.$2.withOpacity(0.7)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                ticket.problemDescription,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF4B5563),
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // --- BOTTOM ROW: DATE & ACTIONS ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Date Info
                        Row(
                          children: [
                            const Icon(CupertinoIcons.calendar, size: 14, color: Colors.black45),
                            const SizedBox(width: 6),
                            Text(
                              formattedDate,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),

                        // Actions (Delete & Forward Arrow)
                        Row(
                          children: [
                            if (_isManager && ticket.id != null) ...[
                              GestureDetector(
                                onTap: () => _confirmDelete(context, ticket.id!),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(CupertinoIcons.trash, size: 16, color: Colors.red.shade400),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],

                            // Apple-style circular action button
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.$1[0],
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.$1[0].withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                              ),
                              child: const Icon(CupertinoIcons.arrow_right, size: 16, color: Colors.white),
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
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String ticketId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        surfaceTintColor: Colors.transparent,
        title: Text('Supprimer ?', style: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        content: Text('Voulez-vous vraiment supprimer ce ticket ? Cette action est irréversible.', style: GoogleFonts.inter(height: 1.4, color: Colors.black87)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            child: Text('Annuler', style: GoogleFonts.inter(color: Colors.black54, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              FirebaseFirestore.instance.collection('sav_tickets').doc(ticketId).delete();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ticket supprimé', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  backgroundColor: Colors.black87,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: Text('Supprimer', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
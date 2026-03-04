// lib/screens/service_technique/sav_list_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
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
    return Scaffold(
      // Clean, slightly off-white background to make the glass pop
      backgroundColor: const Color(0xFFF4F5F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white.withOpacity(0.7),
            iconTheme: const IconThemeData(color: Colors.black87),
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
                  title: Text(
                    '   SAV',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF111827),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                    ),
                  ),
                  background: Container(color: Colors.transparent),
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Historique',
                icon: const Icon(Icons.history_rounded, color: Color(0xFF4B5563)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SavTicketHistoryPage(serviceType: widget.serviceType)),
                  );
                },
              ),
              const SizedBox(width: 8),
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
                    child: CircularProgressIndicator(color: Color(0xFF111827), strokeWidth: 3),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Une erreur est survenue ou un index est manquant.',
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
                        Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          "Aucun ticket SAV actif.",
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
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

      floatingActionButton: FloatingActionButton.extended(
        elevation: 8,
        highlightElevation: 16,
        backgroundColor: const Color(0xFF000000), // Pure black iOS style
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.add_rounded, size: 24),
        label: Text(
          'Nouveau Ticket',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.3),
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

  // ✅ NEW 2026 iOS GLASS ANIMATION CARD
  Widget _buildIOS26GlassCard(BuildContext context, SavTicket ticket) {
    final theme = _getStatusTheme(ticket.status);
    final isWeb = MediaQuery.of(context).size.width > 600;

    // Helper for default logo
    Widget buildDefaultLogo() {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.$1[1].withOpacity(0.2), theme.$1[2].withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.5)),
        ),
        child: Icon(Icons.storefront_rounded, size: 18, color: theme.$2),
      );
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        constraints: isWeb ? const BoxConstraints(maxWidth: 800) : null,
        // ✅ 1. THE AMBIENT GLOW BACKDROP
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          // Deep, colorful soft shadow matching the status
          boxShadow: [
            BoxShadow(
              color: theme.$1[0].withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: -5,
              offset: const Offset(0, 15),
            ),
          ],
          // Colorful under-gradient that will bleed through the glass
          gradient: LinearGradient(
            colors: [
              theme.$1[0].withOpacity(0.15),
              theme.$1[1].withOpacity(0.05),
              Colors.transparent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        // ✅ 2. THE FROSTED GLASS LAYER
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6), // Slightly milky glass
                borderRadius: BorderRadius.circular(32),
                // Ultra-thin, crisp highly reflective edge
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
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
                      // --- TOP ROW: LOGO, STORE NAME & STATUS PILL ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // B2 Logo Fetcher
                          if (ticket.clientId.isNotEmpty && ticket.storeId != null && ticket.storeId!.isNotEmpty)
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('clients')
                                  .doc(ticket.clientId)
                                  .collection('stores')
                                  .doc(ticket.storeId)
                                  .get(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 14.0),
                                    child: SizedBox(
                                      width: 36, height: 36,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.$2.withOpacity(0.5)),
                                    ),
                                  );
                                }
                                if (snapshot.hasData && snapshot.data!.exists) {
                                  final storeData = snapshot.data!.data() as Map<String, dynamic>?;
                                  final logoUrl = storeData?['logoUrl'] as String?;
                                  if (logoUrl != null && logoUrl.isNotEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 14.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(9),
                                          child: Image.network(
                                            logoUrl,
                                            width: 36, height: 36, fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) => buildDefaultLogo(),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(right: 14.0),
                                  child: buildDefaultLogo(),
                                );
                              },
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(right: 14.0),
                              child: buildDefaultLogo(),
                            ),

                          // Store Name & SAV Code
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ticket.storeName ?? 'Inconnu',
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ticket.savCode,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.$2.withOpacity(0.7),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Glowing Status Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [theme.$1[0].withOpacity(0.2), theme.$1[1].withOpacity(0.1)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.$1[0].withOpacity(0.3), width: 1),
                            ),
                            child: Text(
                              ticket.status.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: theme.$2,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // --- HERO SECTION: HUGE PRODUCT NAME ---
                      Text(
                        ticket.productName,
                        style: GoogleFonts.inter(
                          fontSize: 24, // Massive 4K iOS typography
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF030712),
                          letterSpacing: -1.0,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 16),

                      // --- INSET BOX: PROBLEM DESCRIPTION ---
                      if (ticket.problemDescription.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4), // Inner frosted glass
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.6)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded, size: 18, color: theme.$2.withOpacity(0.6)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ticket.problemDescription,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF374151),
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      // --- BOTTOM ROW: AVATAR, DATE & ACTIONS ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Client info
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: theme.$1[0].withOpacity(0.2),
                                    child: Icon(Icons.person_rounded, size: 12, color: theme.$2),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    ticket.clientName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1F2937),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DateFormat('dd MMM yyyy • HH:mm', 'fr_FR').format(ticket.createdAt),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B7280),
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
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],

                              // Apple-style circular action button
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [theme.$1[0], theme.$1[1]],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.$1[0].withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
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
      ),
    );
  }

  void _confirmDelete(BuildContext context, String ticketId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title: Text('Confirmer la suppression', style: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        content: Text('Voulez-vous vraiment supprimer ce ticket ? Cette action est irréversible.', style: GoogleFonts.inter(height: 1.4, color: Colors.black87)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            child: Text('Annuler', style: GoogleFonts.inter(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              FirebaseFirestore.instance.collection('sav_tickets').doc(ticketId).delete();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ticket supprimé'), backgroundColor: Colors.red),
              );
            },
            child: Text('Supprimer', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
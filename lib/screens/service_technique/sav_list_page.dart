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

  // ✅ Extract color logic so we can use it for the badge AND the card accents
  (Color bgColor, Color textColor) _getStatusColors(String status) {
    switch (status) {
      case 'Nouveau':
        return (const Color(0xFFE0F2FE), const Color(0xFF0369A1)); // Light Blue
      case 'En Diagnostic':
      case 'En Réparation':
        return (const Color(0xFFFEF3C7), const Color(0xFFB45309)); // Amber
      case 'Terminé':
      case 'Approuvé - Prêt pour retour':
        return (const Color(0xFFDCFCE7), const Color(0xFF15803D)); // Emerald
      case 'Irréparable - Remplacement Demandé':
        return (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)); // Red
      case 'Retourné':
      case 'Dépose':
        return (const Color(0xFFF3F4F6), const Color(0xFF374151)); // Gray
      default:
        return (const Color(0xFFF3F4F6), const Color(0xFF374151));
    }
  }

  Widget _buildPremiumStatusBadge(String status) {
    final colors = _getStatusColors(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: colors.$2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white.withOpacity(0.85),
            iconTheme: const IconThemeData(color: Colors.black87),
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
                  title: Text(
                    '   SAV',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF111827),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
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
            // ✅ CRITICAL FIX: We now filter by IT vs Technique!
                .where('serviceType', isEqualTo: widget.serviceType)
                .where('status', whereIn: [
              'Nouveau',
              'En Diagnostic',
              'En Réparation',
              'Terminé',
              'Approuvé - Prêt pour retour',
              'Irréparable - Remplacement Demandé',
              // 'Dépose' is removed to keep it in History only
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
                padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final doc = tickets[index];
                      final ticket = SavTicket.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
                      return _buildPremiumTicketCard(context, ticket);
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
        elevation: 4,
        highlightElevation: 12,
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          'Nouveau Ticket',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: -0.2),
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

  Widget _buildPremiumTicketCard(BuildContext context, SavTicket ticket) {
    // Fetch the colors based on the current status
    final colors = _getStatusColors(ticket.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
        boxShadow: [
          BoxShadow(
            // ✅ TOUCH OF COLOR: The shadow subtly glows with the status color
            color: colors.$2.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          highlightColor: colors.$1.withOpacity(0.3),
          splashColor: colors.$1.withOpacity(0.5),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SavTicketDetailsPage(ticket: ticket)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        // ✅ TOUCH OF COLOR: Icon matches the status badge
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.$1,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.confirmation_number_rounded, size: 16, color: colors.$2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          ticket.savCode,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    _buildPremiumStatusBadge(ticket.status),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: Color(0xFFF3F4F6)),
                ),

                Text(
                  ticket.productName,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                // Client Row
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF6B7280)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ticket.clientName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // ✅ Store Name Row (only shown if it exists)
                if (ticket.storeName != null && ticket.storeName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF6B7280)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ticket.storeName!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ticket.problemDescription.isNotEmpty ? ticket.problemDescription : 'Aucune description fournie.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
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

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(ticket.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        if (_isManager)
                          GestureDetector(
                            onTap: () {
                              if (ticket.id != null) {
                                _confirmDelete(context, ticket.id!);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade700),
                            ),
                          ),
                        if (_isManager) const SizedBox(width: 12),

                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.$1, // Touch of color!
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_forward_rounded, size: 14, color: colors.$2),
                        ),
                      ],
                    )
                  ],
                ),
              ],
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
        title: Text('Confirmer la suppression', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer ce ticket ? Cette action est irréversible.', style: GoogleFonts.inter(height: 1.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
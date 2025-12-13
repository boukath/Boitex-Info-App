// lib/screens/service_it/pending_it_evaluations_list.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/administration/project_details_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class PendingItEvaluationsListPage extends StatelessWidget {
  final String userRole;

  const PendingItEvaluationsListPage({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    const List<Color> pageGradientColors = [
      Color(0xFF06B6D4),
      Color(0xFF0891B2),
      Color(0xFF0E7490),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Évaluations IT à Faire',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: pageGradientColors,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .where('status', isEqualTo: 'Nouvelle Demande')
            // ***** START FIXED CODE *****
            // Add this line to filter by service type
                .where('serviceType', isEqualTo: 'Service IT')
            // ***** END FIXED CODE *****
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white70));
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text(
                      "Une erreur s'est produite.",
                      style: GoogleFonts.lato(color: Colors.white70, fontSize: 16),
                    ));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                // Using the _buildEmptyState method from the previous design
                return _buildEmptyState();
              }

              final projects = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final projectDoc = projects[index];
                  // Using the _EvaluationListItem widget from the previous design
                  return _EvaluationListItem(
                    projectDoc: projectDoc,
                    userRole: userRole,
                    index: index,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Widget for the beautiful empty state (IT Version - copied from previous design)
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: Colors.white.withOpacity(0.8),
              size: 100,
            ),
            const SizedBox(height: 24),
            Text(
              'Réseau Calme...',
              style: GoogleFonts.lato(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Aucune évaluation IT n'est en attente. Le système est stable !",
              style: GoogleFonts.lato(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Widget for each list item with animation (copied from previous design)
class _EvaluationListItem extends StatefulWidget {
  final DocumentSnapshot projectDoc;
  final String userRole;
  final int index;

  const _EvaluationListItem({
    required this.projectDoc,
    required this.userRole,
    required this.index,
  });

  @override
  State<_EvaluationListItem> createState() => _EvaluationListItemState();
}

class _EvaluationListItemState extends State<_EvaluationListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 0,
    );

    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) {
        _controller.forward();
      }
    });


    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.projectDoc.data() as Map<String, dynamic>;
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    final clientName = data['clientName'] ?? 'Client inconnu';
    final storeName = data['storeName'] ?? 'Magasin inconnu';
    final initialRequest = data['initialRequest'] ?? 'Pas de description';

    final cardGradient = LinearGradient(
      transform: GradientRotation(math.pi / 4 + (widget.index * 0.1)),
      colors: [
        Colors.white.withOpacity(0.25),
        Colors.white.withOpacity(0.10),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: cardGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailsPage(
                      projectId: widget.projectDoc.id,
                      userRole: widget.userRole,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName,
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(icon: Icons.storefront_outlined, text: storeName),
                          const SizedBox(height: 6),
                          _InfoRow(icon: Icons.description_outlined, text: initialRequest, maxLines: 2),
                          const SizedBox(height: 10),
                          _InfoRow(
                            icon: Icons.calendar_today_outlined,
                            text: 'Demandé le: ${DateFormat('dd MMM yyyy', 'fr_FR').format(createdAt)}',
                            iconSize: 14,
                            fontSize: 12,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withOpacity(0.7),
                      size: 18,
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
}

// Helper widget for icon + text rows (copied from previous design)
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final int maxLines;
  final double iconSize;
  final double fontSize;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.maxLines = 1,
    this.iconSize = 16,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: iconSize,
          color: Colors.white.withOpacity(0.8),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.lato(
              fontSize: fontSize,
              color: Colors.white.withOpacity(0.9),
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
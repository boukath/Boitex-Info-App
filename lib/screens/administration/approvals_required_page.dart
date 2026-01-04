// lib/screens/administration/approvals_required_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:ui'; // Required for ImageFilter

class ApprovalsRequiredPage extends StatefulWidget {
  const ApprovalsRequiredPage({super.key});

  @override
  State<ApprovalsRequiredPage> createState() => _ApprovalsRequiredPageState();
}

class _ApprovalsRequiredPageState extends State<ApprovalsRequiredPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Key for glass effect
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Approbations Requises',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2C3E50), // Midnight Blue
              Color(0xFF4CA1AF), // Ocean Mist
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernSearchBar(),
              Expanded(
                child: _buildApprovalList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher demandeur...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                border: InputBorder.none,
                icon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
                    : null,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim().toLowerCase());
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalList() {
    return StreamBuilder<QuerySnapshot>(
      // Note: Kept your specific query filters
      stream: FirebaseFirestore.instance
          .collection('requisitions')
          .where('status', isEqualTo: 'en attente d\'approbation') // Ensure this matches your DB casing exactly
          .orderBy('requestedAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(child: Text('Erreur: ${snap.error}', style: const TextStyle(color: Colors.white70)));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        }

        final docs = snap.data?.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final requestedBy = (data['requestedBy'] ?? '').toString().toLowerCase();
          return requestedBy.contains(_searchQuery);
        }).toList() ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.white.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  'Aucune demande en attente',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final requestedBy = data['requestedBy'] ?? '—';
            final items = (data['requestedItems'] as List<dynamic>? ?? []);
            final ts = (data['requestedAt'] as Timestamp?)?.toDate();
            final dateStr = ts != null ? DateFormat('dd/MM/yy').format(ts) : '—';

            // Staggered Animation
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + (i * 100)),
              curve: Curves.easeOutQuart,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: _buildGlassCard(context, id, requestedBy, items.length, dateStr),
            );
          },
        );
      },
    );
  }

  Widget _buildGlassCard(BuildContext context, String id, String requestedBy, int itemCount, String date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/requisitionDetails',
                  arguments: {'id': id},
                );
              },
              highlightColor: Colors.white.withOpacity(0.1),
              splashColor: Colors.white.withOpacity(0.2),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    // Icon Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
                      ),
                      child: const Icon(Icons.priority_high_rounded, color: Colors.amberAccent, size: 24),
                    ),
                    const SizedBox(width: 16),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            requestedBy,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$itemCount article(s) à valider',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Date & Arrow
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          date,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.5), size: 16),
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
}
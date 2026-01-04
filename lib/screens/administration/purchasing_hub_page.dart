// lib/screens/administration/purchasing_hub_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:ui'; // Required for ImageFilter (Blur)
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';

class PurchasingHubPage extends StatefulWidget {
  final String userRole;
  const PurchasingHubPage({super.key, required this.userRole});

  @override
  State<PurchasingHubPage> createState() => _PurchasingHubPageState();
}

class _PurchasingHubPageState extends State<PurchasingHubPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _canAccessPOReference() {
    return widget.userRole == 'PDG' ||
        widget.userRole == 'Admin' ||
        widget.userRole == 'Responsable Administratif';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Purchasing Hub',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
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
              Color(0xFF0F2027), // Deep Space Blue
              Color(0xFF203A43), // Cyber Teal
              Color(0xFF2C5364), // Future Grey
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernSearchBar(),
              Expanded(
                child: _buildOrderList(),
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
                hintText: 'Rechercher une commande...',
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

  Widget _buildOrderList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('requisitions')
          .where('status', whereIn: ['Approuvée', 'Commandée', 'Partiellement Reçue'])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur de chargement',
              style: TextStyle(color: Colors.red.shade300),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final code = (data['requisitionCode'] ?? '').toString().toLowerCase();
          final requester = (data['requestedBy'] ?? '').toString().toLowerCase();
          final poRef = (data['purchaseOrderReference'] ?? '').toString().toLowerCase();
          return code.contains(_searchQuery) ||
              requester.contains(_searchQuery) ||
              poRef.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.white.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  'Aucune commande en attente',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            // Staggered Animation for smooth entry
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + (index * 100)),
              curve: Curves.easeOutQuart,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: _buildGlassCard(context, doc, data),
            );
          },
        );
      },
    );
  }

  Widget _buildGlassCard(BuildContext context, DocumentSnapshot doc, Map<String, dynamic> data) {
    final status = data['status'] ?? 'Inconnu';
    final requestedBy = data['requestedBy'] ?? 'Inconnu';
    final createdAt = data['createdAt'] as Timestamp?;
    final poRef = data['purchaseOrderReference'];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RequisitionDetailsPage(
                      requisitionId: doc.id,
                      userRole: widget.userRole,
                    ),
                  ),
                );
              },
              highlightColor: Colors.white.withOpacity(0.1),
              splashColor: Colors.white.withOpacity(0.2),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNeonStatusChip(status),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.5), size: 16),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data['requisitionCode'] ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (poRef != null && _canAccessPOReference())
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'BC: $poRef',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              child: Text(
                                requestedBy.isNotEmpty ? requestedBy[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              requestedBy,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        if (createdAt != null)
                          Text(
                            DateFormat('dd MMM yyyy').format(createdAt.toDate()),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
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

  Widget _buildNeonStatusChip(String status) {
    Color color;
    Color glowColor;
    switch (status) {
      case 'Approuvée':
        color = const Color(0xFFF2994A); // Orange
        glowColor = const Color(0xFFF2C94C);
        break;
      case 'Commandée':
        color = const Color(0xFF2F80ED); // Blue
        glowColor = const Color(0xFF56CCF2);
        break;
      case 'Partiellement Reçue':
        color = const Color(0xFFBB6BD9); // Purple
        glowColor = const Color(0xFFD383F6);
        break;
      default:
        color = Colors.grey;
        glowColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: glowColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: glowColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
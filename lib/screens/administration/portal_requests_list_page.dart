// lib/screens/administration/portal_requests_list_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ✅ Import the Details Page
import 'package:boitex_info_app/screens/administration/portal_request_details_page.dart';

// --- 🎨 PREMIUM 2026 APPLE DESIGN TOKENS ---
const Color kAppleDeepPurple = Color(0xFF2E0A5E);
const Color kAppleVibrantBlue = Color(0xFF0A84FF);
const Color kAppleMagenta = Color(0xFFFF2D55);
const Color kAppleBlue = Color(0xFF007AFF);
const Color kApplePurple = Color(0xFFAF52DE);
const Color kTextDark = Color(0xFF1D1D1F);
const Color kTextSecondary = Color(0xFF86868B);

class PortalRequestsListPage extends StatefulWidget {
  const PortalRequestsListPage({super.key});

  @override
  State<PortalRequestsListPage> createState() => _PortalRequestsListPageState();
}

class _PortalRequestsListPageState extends State<PortalRequestsListPage> with SingleTickerProviderStateMixin {
  late AnimationController _bgAnimationController;

  // 🚀 PERFORMANCE OPTIMIZATION: Cache logos to prevent infinite Firestore reads during scrolling
  final Map<String, String?> _logoCache = {};

  @override
  void initState() {
    super.initState();
    // Ambient background animation
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    super.dispose();
  }

  /// --------------------------------------------------------------------------
  /// 🔍 FETCH STORE LOGO LOGIC
  /// --------------------------------------------------------------------------
  Future<String?> _fetchStoreLogo(String? clientId, String? storeId) async {
    if (clientId == null || storeId == null) return null;

    // Create a unique key for the cache
    final cacheKey = "${clientId}_$storeId";

    // Return cached URL if it exists
    if (_logoCache.containsKey(cacheKey)) {
      return _logoCache[cacheKey];
    }

    try {
      // Fetch from Firestore: /clients/{clientId}/stores/{storeId}
      final storeDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .doc(storeId)
          .get();

      if (storeDoc.exists && storeDoc.data()!.containsKey('logoUrl')) {
        final logoUrl = storeDoc.data()!['logoUrl'] as String?;
        _logoCache[cacheKey] = logoUrl; // Save to cache
        return logoUrl;
      }
    } catch (e) {
      debugPrint("Error fetching logo: $e");
    }

    _logoCache[cacheKey] = null; // Cache the null result to prevent re-fetching
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF2F2F7), // Apple Light Gray Base
      appBar: AppBar(
        title: Text(
          "Demandes Web",
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: kTextDark, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white.withOpacity(0.4),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: kTextDark),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.white.withOpacity(0.3)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // --- 🌌 ANIMATED MESH GRADIENT BACKGROUND ---
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -100 + (60 * _bgAnimationController.value),
                    left: -50,
                    child: _buildBlurBlob(kAppleVibrantBlue.withOpacity(0.25), 350),
                  ),
                  Positioned(
                    bottom: -50 - (60 * _bgAnimationController.value),
                    right: -100,
                    child: _buildBlurBlob(kApplePurple.withOpacity(0.2), 400),
                  ),
                  Positioned(
                    top: 300,
                    right: -50 + (40 * _bgAnimationController.value),
                    child: _buildBlurBlob(Colors.orange.withOpacity(0.15), 300),
                  ),
                ],
              );
            },
          ),

          // --- 📜 MAIN LIST CONTENT ---
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850), // 🌐 Web optimization
                child: StreamBuilder<QuerySnapshot>(
                  // ⚠️ NOTE: Adjust this query if you need specific status filters
                  stream: FirebaseFirestore.instance
                      .collection('interventions')
                      .where('status', isEqualTo: 'En Attente Validation')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text("Erreur: ${snapshot.error}", style: GoogleFonts.inter()));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kAppleBlue));

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(
                        child: Text("Aucune demande en attente.", style: GoogleFonts.inter(fontSize: 16, color: kTextSecondary, fontWeight: FontWeight.w500)),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildGlassCard(doc.id, data);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 🛠 WIDGET HELPERS ---

  Widget _buildBlurBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildGlassCard(String docId, Map<String, dynamic> data) {
    final date = (data['createdAt'] as Timestamp?)?.toDate();
    final formattedDate = date != null ? DateFormat('dd MMM yyyy • HH:mm').format(date) : '-';

    final String type = data['interventionType'] ?? 'Standard';
    final String clientId = data['clientId'] ?? '';
    final String storeId = data['storeId'] ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PortalRequestDetailsPage(interventionId: docId)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ BEAUTIFUL STORE LOGO WITH FUTURE BUILDER
                        _buildStoreLogo(clientId, storeId),

                        const SizedBox(width: 16),

                        // TEXT INFO
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['storeName'] ?? 'Magasin Inconnu',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: kTextDark, letterSpacing: -0.3),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['clientName'] ?? 'Client Inconnu',
                                style: GoogleFonts.inter(color: kTextSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 14, color: kTextSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    formattedDate,
                                    style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Colors.black12, height: 1),
                    ),

                    // BOTTOM ROW (Tags & Action)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildMiniTag(icon: Icons.label_important_rounded, label: type, color: kAppleBlue),
                              _buildMiniTag(icon: Icons.pending_rounded, label: "En attente", color: Colors.orange.shade700),
                            ],
                          ),
                        ),

                        // ACTION ARROW
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: kAppleBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Ouvrir", style: GoogleFonts.inter(color: kAppleBlue, fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 16, color: kAppleBlue),
                            ],
                          ),
                        )
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

  // ✅ THE LOGO FETCHER WIDGET
  Widget _buildStoreLogo(String clientId, String storeId) {
    return FutureBuilder<String?>(
      future: _fetchStoreLogo(clientId, storeId),
      builder: (context, snapshot) {
        final bool isLoading = snapshot.connectionState == ConnectionState.waiting;
        final String? logoUrl = snapshot.data;

        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: isLoading
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kAppleBlue)))
                : (logoUrl != null && logoUrl.isNotEmpty)
                ? Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, color: kTextSecondary, size: 28),
            )
                : const Icon(Icons.storefront_rounded, color: kTextSecondary, size: 28), // Fallback Icon
          ),
        );
      },
    );
  }

  Widget _buildMiniTag({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
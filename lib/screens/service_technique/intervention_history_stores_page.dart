// lib/screens/service_technique/intervention_history_stores_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_history_final_list_page.dart';

// ✅ NEW HELPER CLASS: Pairs the Store Name with its Logo URL
class StoreItemInfo {
  final String storeName;
  final String? clientId;
  final String? storeId;
  String? logoUrl;

  StoreItemInfo({
    required this.storeName,
    this.clientId,
    this.storeId,
    this.logoUrl,
  });
}

// ✅ CHANGED: Converted to StatefulWidget to hold the Future efficiently
class InterventionHistoryStoresPage extends StatefulWidget {
  final String serviceType;
  final String clientName;
  final int selectedYear;

  const InterventionHistoryStoresPage({
    super.key,
    required this.serviceType,
    required this.clientName,
    required this.selectedYear,
  });

  @override
  State<InterventionHistoryStoresPage> createState() => _InterventionHistoryStoresPageState();
}

class _InterventionHistoryStoresPageState extends State<InterventionHistoryStoresPage> {
  late Future<List<StoreItemInfo>> _storesFuture;

  @override
  void initState() {
    super.initState();
    _storesFuture = _fetchStoresWithLogos();
  }

  // 🚀 NEW: Fetches unique stores from interventions, then fetches their logos in parallel
  Future<List<StoreItemInfo>> _fetchStoresWithLogos() async {
    final startOfYear = DateTime(widget.selectedYear, 1, 1);
    final endOfYear = DateTime(widget.selectedYear, 12, 31, 23, 59, 59);

    final snapshot = await FirebaseFirestore.instance
        .collection('interventions')
        .where('serviceType', isEqualTo: widget.serviceType)
        .where('clientName', isEqualTo: widget.clientName)
        .where('status', isEqualTo: 'Clôturé')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear))
        .get();

    // Map to ensure uniqueness by storeName
    final Map<String, StoreItemInfo> uniqueStores = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final storeName = data['storeName'] as String?;

      // If it's a valid store and we haven't tracked it yet
      if (storeName != null && storeName.isNotEmpty && !uniqueStores.containsKey(storeName)) {
        uniqueStores[storeName] = StoreItemInfo(
          storeName: storeName,
          clientId: data['clientId'] as String?,
          storeId: data['storeId'] as String?,
        );
      }
    }

    final storesList = uniqueStores.values.toList();

    // 🚀 Fetch logos in parallel for maximum performance
    await Future.wait(storesList.map((store) async {
      if (store.clientId != null && store.storeId != null) {
        try {
          final storeDoc = await FirebaseFirestore.instance
              .collection('clients')
              .doc(store.clientId)
              .collection('stores')
              .doc(store.storeId)
              .get();

          if (storeDoc.exists) {
            store.logoUrl = storeDoc.data()?['logoUrl'] as String?;
          }
        } catch (e) {
          debugPrint("⚠️ Erreur récupération logo pour le store ${store.storeId}: $e");
        }
      }
    }));

    // Sort alphabetically by store name
    storesList.sort((a, b) => a.storeName.compareTo(b.storeName));

    return storesList;
  }

  // --- 💎 iOS 2026 UI HELPERS 💎 ---

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6), // Translucent white
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  // Fallback icon if no logo exists or it fails to load
  Widget _buildFallbackIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C7BE), Color(0xFF007AFF)], // Cyan to Blue
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: const Icon(
        Icons.storefront_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.clientName,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1D1D1F),
                fontSize: 18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "Année ${widget.selectedYear}",
              style: GoogleFonts.outfit(
                color: const Color(0xFF007AFF),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 🌈 iOS 2026 Animated Mesh Gradient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE0EAFC), // Light Soft Blue
                    Color(0xFFF9E0FA), // Soft Pink
                    Color(0xFFE5F0FF), // Soft Cyan
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100, right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFD1FF).withOpacity(0.7)),
              ),
            ),
          ),
          Positioned(
            bottom: -50, left: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 400, height: 400,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFB5DEFF).withOpacity(0.6)),
              ),
            ),
          ),

          // 📱 MAIN CONTENT
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 750),
                child: FutureBuilder<List<StoreItemInfo>>(
                  future: _storesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF007AFF),
                          strokeWidth: 3,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: _buildGlassCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFFF3B30), size: 48),
                              const SizedBox(height: 16),
                              Text(
                                "Erreur de chargement",
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error.toString(),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(color: const Color(0xFF86868B)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: _buildGlassCard(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF86868B).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.store_outlined, color: Color(0xFF86868B), size: 64),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  "Aucun Magasin",
                                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1D1D1F)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Aucune intervention clôturée trouvée pour ce client en ${widget.selectedYear}.",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(fontSize: 16, color: const Color(0xFF86868B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final storesList = snapshot.data!;

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 40),
                      itemCount: storesList.length,
                      itemBuilder: (context, index) {
                        final store = storesList[index];

                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => InterventionHistoryFinalListPage(
                                  serviceType: widget.serviceType,
                                  clientName: widget.clientName,
                                  storeName: store.storeName,
                                  selectedYear: widget.selectedYear,
                                ),
                              ),
                            );
                          },
                          child: _buildGlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                // ✅ LEFT ICON - EITHER LOGO OR GRADIENT SQUIRCLE
                                if (store.logoUrl != null && store.logoUrl!.isNotEmpty)
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Image.network(
                                          store.logoUrl!,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  _buildFallbackIcon(),

                                const SizedBox(width: 16),

                                // Text Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        store.storeName,
                                        style: GoogleFonts.outfit(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1D1D1F),
                                          height: 1.2,
                                        ),
                                        maxLines: isMobile ? 3 : 1, // Adaptive line breaks
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Voir les dossiers",
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: const Color(0xFF86868B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Right Chevron
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF007AFF),
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
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
}
// lib/screens/administration/billing_hub_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boitex_info_app/screens/administration/billing_decision_page.dart';

// Helper class to pair the Firestore document with its fetched Store Logo
class InterventionItem {
  final DocumentSnapshot doc;
  final String? logoUrl;

  InterventionItem({required this.doc, this.logoUrl});
}

class BillingHubPage extends StatefulWidget {
  const BillingHubPage({super.key});

  @override
  State<BillingHubPage> createState() => _BillingHubPageState();
}

class _BillingHubPageState extends State<BillingHubPage> {

  // Fetches Store Logos in parallel for maximum performance.
  Future<List<InterventionItem>> _fetchPendingItems() async {
    final interventionsSnapshot = await FirebaseFirestore.instance
        .collection('interventions')
        .where('status', isEqualTo: 'Terminé')
        .get();

    final allDocs = interventionsSnapshot.docs;

    // Sort by date. Handle potential nulls.
    allDocs.sort((a, b) {
      final aData = a.data();
      final bData = b.data();

      DateTime? getDate(Map<String, dynamic>? data) {
        if (data == null) return null;
        final ts = (data['interventionDate'] ?? data['createdAt'] ?? data['updatedAt']) as Timestamp?;
        return ts?.toDate();
      }

      final aDate = getDate(aData) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = getDate(bData) ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate); // Sort descending (newest first)
    });

    // Fetch all logos efficiently in parallel
    final enrichedItems = await Future.wait(allDocs.map((doc) async {
      final data = doc.data();
      String? logoUrl;

      if (data != null) {
        final clientId = data['clientId'] as String?;
        final storeId = data['storeId'] as String?;

        // If we have both IDs, fetch the store document to get the logoUrl
        if (clientId != null && clientId.isNotEmpty && storeId != null && storeId.isNotEmpty) {
          try {
            final storeDoc = await FirebaseFirestore.instance
                .collection('clients')
                .doc(clientId)
                .collection('stores')
                .doc(storeId)
                .get();

            if (storeDoc.exists) {
              logoUrl = storeDoc.data()?['logoUrl'] as String?;
            }
          } catch (e) {
            debugPrint("⚠️ Erreur récupération logo pour le store $storeId: $e");
          }
        }
      }

      return InterventionItem(doc: doc, logoUrl: logoUrl);
    }));

    return enrichedItems;
  }

  // --- 💎 iOS 2026 UI HELPERS 💎 ---

  Widget _buildGlassCard({required Widget child}) {
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
            padding: const EdgeInsets.all(16),
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
          "Dossiers à Facturer",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1D1D1F),
            fontSize: 20,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF007AFF)),
              onPressed: () {
                setState(() {});
              },
              splashRadius: 24,
            ),
          ),
        ],
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
                child: FutureBuilder<List<InterventionItem>>(
                  future: _fetchPendingItems(),
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
                                    color: const Color(0xFF34C759).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF34C759), size: 64),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  "Tout est à jour !",
                                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1D1D1F)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Aucun dossier en attente de facturation.",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(fontSize: 16, color: const Color(0xFF86868B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final items = snapshot.data!;

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 40),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final doc = item.doc;
                        final data = doc.data() as Map<String, dynamic>?;

                        if (data == null) {
                          return _buildGlassCard(
                            child: Row(
                              children: [
                                const Icon(Icons.warning_rounded, color: Color(0xFFFF3B30), size: 32),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Erreur de données", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFFFF3B30))),
                                      Text("ID: ${doc.id}", style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF86868B))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (data.containsKey('serviceType')) {
                          return _buildInterventionTile(context, item, data);
                        }

                        return _buildGlassCard(
                          child: Row(
                            children: [
                              const Icon(Icons.help_outline_rounded, color: Color(0xFF86868B), size: 32),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text("Document inconnu: ${doc.id}", style: GoogleFonts.outfit()),
                              ),
                            ],
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

  // --- 💡 HELPER TO BUILD FALLBACK AVATAR ---
  Widget _buildFallbackAvatar(bool isIT) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isIT
              ? [const Color(0xFF34C759), const Color(0xFF30D158)] // Vibrant Green for IT
              : [const Color(0xFF00C7BE), const Color(0xFF007AFF)], // Cyan to Blue for Tech
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (isIT ? const Color(0xFF34C759) : const Color(0xFF007AFF)).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Icon(
        isIT ? Icons.computer_rounded : Icons.construction_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildInterventionTile(BuildContext context, InterventionItem item, Map<String, dynamic> data) {
    // ✅ NEW: Detect if the user is on a phone (width < 600)
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    final doc = item.doc;
    final storeName = data['storeName'] as String? ?? 'Magasin inconnu';
    final storeLocation = data['storeLocation'] as String? ?? '';
    final serviceType = data['serviceType'] as String? ?? 'Service N/A';

    String displayTitle = storeName;
    if (storeLocation.isNotEmpty) {
      displayTitle += ' - $storeLocation';
    }

    final dateRaw = (data['interventionDate'] ?? data['createdAt']) as Timestamp?;
    final String dateFormatted;
    if (dateRaw != null) {
      dateFormatted = DateFormat('dd MMM yyyy', 'fr_FR').format(dateRaw.toDate());
    } else {
      dateFormatted = 'Date N/A';
    }

    final bool isIT = serviceType == 'Service IT';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BillingDecisionPage(interventionDoc: doc),
          ),
        ).then((_) => setState(() {}));
      },
      child: _buildGlassCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Icon - Logo or Gradient Squircle
            if (item.logoUrl != null && item.logoUrl!.isNotEmpty)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.network(
                      item.logoUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(isIT),
                    ),
                  ),
                ),
              )
            else
              _buildFallbackAvatar(isIT),

            const SizedBox(width: 16),

            // Middle Content - Titles
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1D1D1F),
                      height: 1.3, // Added slight line height to make wrapped text look cleaner
                    ),
                    // ✅ CRUCIAL FIX: Allows up to 3 lines on mobile, forces 1 line on Web
                    maxLines: isMobile ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          serviceType,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5856D6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Right Content - Date & Chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dateFormatted,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF86868B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF007AFF),
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
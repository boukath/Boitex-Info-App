// lib/screens/administration/manage_stores_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:boitex_info_app/screens/administration/add_store_page.dart';
import 'package:boitex_info_app/screens/administration/store_equipment_page.dart';
import 'package:boitex_info_app/services/store_qr_pdf_service.dart';

// 🎨 --- 2026 PREMIUM APPLE COLORS & CONSTANTS --- 🎨
const kTextDark = Color(0xFF1D1D1F);
const kTextSecondary = Color(0xFF86868B);
const kAppleBlue = Color(0xFF007AFF);
const kAppleRed = Color(0xFFFF3B30);
const double kRadius = 24.0;

class ManageStoresPage extends StatefulWidget {
  final String clientId;
  final String clientName;

  const ManageStoresPage({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<ManageStoresPage> createState() => _ManageStoresPageState();
}

class _ManageStoresPageState extends State<ManageStoresPage> {

  // ---------------------------------------------------------------------------
  // ⚙️ LOGIC METHODS
  // ---------------------------------------------------------------------------

  /// Logic to handle QR printing & Token Generation
  Future<void> _handlePrintQr(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    String storeId = doc.id;
    String storeName = data['name'] ?? 'Magasin';

    // Extract and Format Location
    dynamic rawLocation = data['location'];
    String? formattedLocation;

    if (rawLocation is GeoPoint) {
      formattedLocation = "${rawLocation.latitude.toStringAsFixed(4)}, ${rawLocation.longitude.toStringAsFixed(4)}";
    } else if (rawLocation is String) {
      formattedLocation = rawLocation;
    }

    String? token = data['qrToken'];

    if (token == null || token.isEmpty) {
      token = const Uuid().v4();
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('stores')
          .doc(storeId)
          .update({'qrToken': token});
    }

    if (context.mounted) {
      // ✅ FIXED: Using the exact method signature from your StoreQrPdfService
      await StoreQrPdfService.generateStoreQr(
        storeName,
        widget.clientName,
        storeId,
        token,
        formattedLocation,
      );
    }
  }

  Future<void> _deleteStore(String storeId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: Text('Supprimer ce magasin ?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextDark)),
        content: Text('Voulez-vous vraiment supprimer ce magasin ? Cette action est irréversible.', style: GoogleFonts.inter(color: kTextDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler', style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAppleRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Supprimer', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('stores')
            .doc(storeId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Magasin supprimé avec succès', style: GoogleFonts.inter()),
            backgroundColor: kTextDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur lors de la suppression: $e', style: GoogleFonts.inter()),
            backgroundColor: kAppleRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ));
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🎨 COLORFUL MESH BACKGROUND & GLASSMORPHIC UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text('Magasins', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: kTextDark, fontSize: 18, letterSpacing: -0.5)),
            Text(widget.clientName, style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: kTextSecondary, fontSize: 12)),
          ],
        ),
        iconTheme: const IconThemeData(color: kTextDark),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.white.withOpacity(0.4)),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => AddStorePage(clientId: widget.clientId)));
        },
        backgroundColor: kTextDark,
        elevation: 10,
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: Text('Nouveau Magasin', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.2)),
      ),
      body: Stack(
        children: [
          // 1. Colourful Mesh Gradient Background (Warmer tones for Stores)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  stops: [0.0, 0.3, 0.7, 1.0],
                  colors: [
                    Color(0xFFFFD194), // Sunset Peach
                    Color(0xFF70E1F5), // Mint Green
                    Color(0xFFE8F1F5), // White-ish Blue
                    Color(0xFFFFE259), // Soft Yellow
                  ],
                ),
              ),
            ),
          ),

          // 2. Extra Blur layer for the "frosted" global effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.white.withOpacity(0.2)),
            ),
          ),

          // 3. Main Content (StreamBuilder)
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clients')
                  .doc(widget.clientId)
                  .collection('stores')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}', style: GoogleFonts.inter()));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());

                final stores = snapshot.data!.docs;
                if (stores.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 20, bottom: 120), // Padding for FAB
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    final doc = stores[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildGlassStoreCard(doc, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 💎 THE 2026 PREMIUM GLASS CARD
  Widget _buildGlassStoreCard(DocumentSnapshot doc, Map<String, dynamic> data) {
    String storeId = doc.id;
    String storeName = data['name'] ?? 'Magasin Inconnu';

    dynamic rawLocation = data['location'];
    String displayLocation = 'Localisation inconnue';
    if (rawLocation is GeoPoint) {
      displayLocation = "Coordonnées GPS: ${rawLocation.latitude.toStringAsFixed(2)}, ${rawLocation.longitude.toStringAsFixed(2)}";
    } else if (rawLocation is String) {
      displayLocation = rawLocation;
    }

    // Hash-based vibrant color for the store icon
    final int hash = storeName.hashCode;
    final Color color1 = HSLColor.fromAHSL(1.0, (hash % 360).toDouble(), 0.75, 0.55).toColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 20, right: 20),
      child: Slidable(
        key: ValueKey(storeId),
        endActionPane: ActionPane(
          motion: const StretchMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (context) => _deleteStore(storeId),
              backgroundColor: kAppleRed.withOpacity(0.9),
              foregroundColor: Colors.white,
              icon: Icons.delete_outline_rounded,
              label: 'Supprimer',
              borderRadius: BorderRadius.circular(kRadius),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP ROW: Icon + Name + Location
                    Row(
                      children: [
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            color: color1.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.storefront_rounded, color: color1, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(storeName, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -0.3)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 12, color: kTextSecondary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(displayLocation, style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // MIDDLE ROW: Quota Badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildCreditBadge('Interventions', data['interventionsUsed'] ?? 0, data['interventionsQuota'] ?? 0, const Color(0xFF007AFF)), // Apple Blue
                        _buildCreditBadge('Installations', data['installationsUsed'] ?? 0, data['installationsQuota'] ?? 0, const Color(0xFFAF52DE)), // Apple Purple
                        _buildCreditBadge('Livraisons', data['livraisonsUsed'] ?? 0, data['livraisonsQuota'] ?? 0, const Color(0xFF34C759)), // Apple Green
                      ],
                    ),

                    const SizedBox(height: 20),
                    Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                    const SizedBox(height: 16),

                    // BOTTOM ROW: Action Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            // ✅ FIXED: Removed clientName to match StoreEquipmentPage signature
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => StoreEquipmentPage(
                                  storeId: storeId,
                                  storeName: storeName,
                                  clientId: widget.clientId,
                                ),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.inventory_2_rounded, size: 18, color: kTextDark),
                                  const SizedBox(width: 8),
                                  Text("Équipements", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextDark, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: InkWell(
                            onTap: () => _handlePrintQr(context, doc),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: kTextDark.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.qr_code_2_rounded, size: 20, color: kTextDark),
                            ),
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

  Widget _buildCreditBadge(String label, int used, int quota, Color baseColor) {
    int remaining = quota - used;
    bool isLow = remaining <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isLow ? kAppleRed.withOpacity(0.1) : baseColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLow ? kAppleRed.withOpacity(0.2) : baseColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: isLow ? kAppleRed : baseColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            "$label: $used/$quota",
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isLow ? kAppleRed : baseColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
            ),
            child: const Icon(Icons.store_mall_directory_rounded, size: 64, color: kTextSecondary),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun magasin associé\nà ce client.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: kTextSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
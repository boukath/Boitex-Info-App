// lib/screens/administration/client_details_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// ✅ ADDED `hide` to prevent naming collisions for our premium design constants
import 'package:boitex_info_app/screens/administration/add_client_page.dart' hide kBgColor, kSurfaceColor, kTextDark, kTextSecondary, kAppleBlue, kAppleRed, kAppleGreen, kRadius;
import 'package:boitex_info_app/screens/administration/manage_stores_page.dart' hide kTextDark, kTextSecondary, kAppleBlue, kAppleRed, kRadius;
import 'package:boitex_info_app/screens/administration/store_equipment_page.dart';

// 🎨 --- 2026 PREMIUM APPLE COLORS & CONSTANTS --- 🎨
const kTextDark = Color(0xFF1D1D1F);
const kTextSecondary = Color(0xFF86868B);
const kAppleBlue = Color(0xFF007AFF);
const kAppleGreen = Color(0xFF34C759);
const kAppleRed = Color(0xFFFF3B30); // ✅ Added missing local Apple Red
const kTechIndigo = Color(0xFF4F46E5); // Technique Service
const kItSkyBlue = Color(0xFF0EA5E9); // IT Service
const double kRadius = 24.0;

class ClientDetailsPage extends StatelessWidget {
  final String clientId;

  const ClientDetailsPage({super.key, required this.clientId});

  Future<void> _launchUrl(String scheme, String value) async {
    final Uri uri = Uri(scheme: scheme, path: value);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ✅ FIXED: String interpolation & Proper Google Maps universal links
  Future<void> _openMaps(dynamic locationData) async {
    String mapUrl = '';
    if (locationData is GeoPoint) {
      mapUrl = 'https://maps.google.com/?q=${locationData.latitude},${locationData.longitude}';
    } else if (locationData is String && locationData.isNotEmpty) {
      // Prioritize direct URL if it's already a Maps link
      if (locationData.startsWith('http')) {
        mapUrl = locationData;
      } else {
        mapUrl = 'https://maps.google.com/?q=${Uri.encodeComponent(locationData)}';
      }
    } else {
      return;
    }

    final Uri uri = Uri.parse(mapUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Colourful Mesh Gradient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.4, 0.8, 1.0],
                  colors: [
                    Color(0xFFE0C3FC), // Soft Lilac
                    Color(0xFFE8F1F5), // White-ish Blue
                    Color(0xFF8EC5FC), // Sky Blue
                    Color(0xFFFEE1E8), // Soft Pink
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

          // 3. Main Scrollable Content
          StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('clients').doc(clientId).snapshots(),
              builder: (context, clientSnapshot) {
                if (clientSnapshot.hasError) return const Center(child: Text("Erreur de chargement."));
                if (clientSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());
                if (!clientSnapshot.hasData || !clientSnapshot.data!.exists) return const Center(child: Text("Client introuvable."));

                final clientData = clientSnapshot.data!.data() as Map<String, dynamic>;

                // Base Info
                final String clientName = clientData['name'] ?? 'Client Inconnu';
                final List<dynamic> contacts = clientData['contacts'] ?? [];

                // Legal Info
                final String rc = clientData['rc'] ?? clientData['registreCommerce'] ?? 'Non renseigné';
                final String art = clientData['art'] ?? clientData['articleImposition'] ?? 'Non renseigné';
                final String nif = clientData['nif'] ?? 'Non renseigné';

                // HQ Location
                final String? mapsLink = clientData['mapsLink'];
                final dynamic headquarters = (mapsLink != null && mapsLink.isNotEmpty)
                    ? mapsLink
                    : (clientData['headquartersLocation'] ?? clientData['address'] ?? clientData['location']);

                // Services Auth (Checks both arrays and strings to be ultra-compatible with old data)
                final dynamic serviceData = clientData['serviceType'] ?? clientData['services'];
                bool isTech = false;
                bool isIt = false;
                if (serviceData is String) {
                  isTech = serviceData.contains('Technique') || serviceData.contains('Both');
                  isIt = serviceData.contains('IT') || serviceData.contains('Both');
                } else if (serviceData is List) {
                  isTech = serviceData.contains('Service Technique');
                  isIt = serviceData.contains('Service IT');
                }
                // If none selected, default to both just so badges appear, or keep false
                if (!isTech && !isIt) { isTech = true; isIt = true; }

                final int hash = clientName.hashCode;
                final Color color1 = HSLColor.fromAHSL(1.0, (hash % 360).toDouble(), 0.7, 0.6).toColor();
                final Color color2 = HSLColor.fromAHSL(1.0, ((hash + 40) % 360).toDouble(), 0.8, 0.5).toColor();

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    // --- iOS Premium Sliver App Bar ---
                    SliverAppBar(
                      expandedHeight: 220.0,
                      floating: false,
                      pinned: true,
                      backgroundColor: Colors.transparent,
                      iconTheme: const IconThemeData(color: kTextDark),
                      flexibleSpace: ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: FlexibleSpaceBar(
                            centerTitle: true,
                            titlePadding: const EdgeInsets.only(bottom: 16),
                            title: Text(
                              clientName,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: kTextDark, fontSize: 20, letterSpacing: -0.5),
                            ),
                            background: Container(
                              color: Colors.white.withOpacity(0.3),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 30),
                                  Container(
                                    width: 90, height: 90,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(colors: [color1, color2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                      boxShadow: [BoxShadow(color: color2.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 6))],
                                    ),
                                    child: Center(
                                      child: Text(
                                        clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // --- Actions Row (Edit) ---
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildActionButton(
                                icon: Icons.edit_rounded,
                                label: "Modifier le Profil",
                                color: kTextDark,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddClientPage(clientId: clientId)))
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Services Associés ---
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("SERVICES PARTENAIRES", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (isTech) Expanded(child: _buildServiceBadge("Service Technique", kTechIndigo, Icons.engineering_rounded)),
                                if (isTech && isIt) const SizedBox(width: 12),
                                if (isIt) Expanded(child: _buildServiceBadge("Service IT", kItSkyBlue, Icons.router_rounded)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Informations Légales (RC, ART, NIF) ---
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("INFORMATIONS LÉGALES", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                            const SizedBox(height: 10),
                            _buildGlassContainer(
                              child: Column(
                                children: [
                                  _buildLegalRow("Registre de Commerce (RC)", rc),
                                  Divider(height: 1, color: Colors.black.withOpacity(0.05), indent: 20),
                                  _buildLegalRow("Article d'Imposition (ART)", art),
                                  Divider(height: 1, color: Colors.black.withOpacity(0.05), indent: 20),
                                  _buildLegalRow("Numéro Fiscale (NIF)", nif),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Siège Social (Headquarters Map) ---
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("SIÈGE SOCIAL", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                            const SizedBox(height: 10),
                            _buildGlassContainer(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: kAppleRed.withOpacity(0.1), shape: BoxShape.circle),
                                      child: const Icon(Icons.location_on_rounded, color: kAppleRed, size: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Localisation Principale", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
                                          const SizedBox(height: 4),
                                          Text(
                                            mapsLink != null && mapsLink.isNotEmpty ? "Lien Google Maps enregistré" : _formatLocation(headquarters),
                                            style: GoogleFonts.inter(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (headquarters != null && headquarters.toString().isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.map_rounded, color: kAppleBlue),
                                        onPressed: () => _openMaps(headquarters),
                                        style: IconButton.styleFrom(backgroundColor: kAppleBlue.withOpacity(0.1)),
                                      )
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Contacts Section ---
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Text("CONTACTS", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: contacts.isEmpty
                          ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text("Aucun contact enregistré.", style: GoogleFonts.inter(color: kTextSecondary, fontStyle: FontStyle.italic)),
                      )
                          : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: contacts.map((c) => _buildContactCard(c as Map<String, dynamic>)).toList(),
                        ),
                      ),
                    ),

                    // --- Stores Section ---
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("MAGASINS & SITES", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                            GestureBinding(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageStoresPage(clientId: clientId, clientName: clientName))),
                              child: Text("Gérer", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: kAppleBlue)),
                            )
                          ],
                        ),
                      ),
                    ),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('clients').doc(clientId).collection('stores').orderBy('name').snapshots(),
                      builder: (context, storeSnapshot) {
                        if (!storeSnapshot.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator.adaptive()));
                        final stores = storeSnapshot.data!.docs;

                        if (stores.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildGlassContainer(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Center(child: Text("Aucun magasin associé.", style: GoogleFonts.inter(color: kTextSecondary))),
                                ),
                              ),
                            ),
                          );
                        }

                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final storeDoc = stores[index];
                              final storeData = storeDoc.data() as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
                                child: _buildStoreCard(context, storeDoc.id, storeData, clientName),
                              );
                            },
                            childCount: stores.length,
                          ),
                        );
                      },
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 80)), // Bottom padding
                  ],
                );
              }
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  String _formatLocation(dynamic location) {
    if (location == null || location.toString().trim().isEmpty) return "Non définie";
    if (location is GeoPoint) {
      return "GPS: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}";
    }
    return location.toString();
  }

  Widget _buildServiceBadge(String label, Color color, IconData icon) {
    return _buildGlassContainer(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          borderRadius: BorderRadius.circular(kRadius),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.w500, fontSize: 14))),
          Text(value, style: GoogleFonts.inter(color: kTextDark, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
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
          child: child,
        ),
      ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    final name = contact['name'] ?? 'Inconnu';
    final role = contact['role'] ?? '';
    final phone = contact['phone'] ?? '';
    final email = contact['email'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildGlassContainer(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: kTextDark.withOpacity(0.05), shape: BoxShape.circle),
                    child: const Icon(Icons.person_rounded, color: kTextDark, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
                        if (role.isNotEmpty) Text(role, style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              if (phone.isNotEmpty || email.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (phone.isNotEmpty)
                      Expanded(
                        child: InkWell(
                          onTap: () => _launchUrl('tel', phone),
                          child: Row(
                            children: [
                              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: kAppleGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.phone_rounded, color: kAppleGreen, size: 14)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(phone, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: kTextDark), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                    if (email.isNotEmpty)
                      Expanded(
                        child: InkWell(
                          onTap: () => _launchUrl('mailto', email),
                          child: Row(
                            children: [
                              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: kAppleBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.email_rounded, color: kAppleBlue, size: 14)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(email, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: kTextDark), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreCard(BuildContext context, String storeId, Map<String, dynamic> storeData, String clientName) {
    String storeName = storeData['name'] ?? 'Magasin Inconnu';
    String displayLocation = _formatLocation(storeData['location']);

    return _buildGlassContainer(
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreEquipmentPage(clientId: clientId, storeId: storeId, storeName: storeName))),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.storefront_rounded, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(storeName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: kTextSecondary),
                        const SizedBox(width: 4),
                        Expanded(child: Text(displayLocation, style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: kTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// Ignore class mapping for GestureDetector to fix compilation
class GestureBinding extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const GestureBinding({super.key, required this.onTap, required this.child});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: child);
}
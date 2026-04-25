// lib/screens/administration/manage_stores_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // ✅ Added for date formatting

// ✅ Core App Imports
import 'package:boitex_info_app/screens/administration/add_store_page.dart';
import 'package:boitex_info_app/screens/administration/store_equipment_page.dart';
import 'package:boitex_info_app/services/store_qr_pdf_service.dart';
import 'package:boitex_info_app/services/store_transfer_service.dart';

// ✅ History Page Imports
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';

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

  Future<void> _handlePrintQr(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    String storeId = doc.id;
    String storeName = data['name'] ?? 'Magasin';

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

  Future<void> _showTransferDialog(String storeId, String storeName) async {
    final clientsSnapshot = await FirebaseFirestore.instance.collection('clients').get();
    final otherClients = clientsSnapshot.docs.where((doc) => doc.id != widget.clientId).toList();

    if (!mounted) return;

    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {

        final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutQuart);
        final scale = Tween<double>(begin: 0.85, end: 1.0).animate(curvedAnimation);
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15 * animation.value, sigmaY: 15 * animation.value),
          child: ScaleTransition(
            scale: scale,
            child: FadeTransition(
              opacity: fade,
              child: Center(
                child: _PremiumTransferDialogUI(
                  storeName: storeName,
                  clients: otherClients,
                ),
              ),
            ),
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      _triggerStoreTransfer(widget.clientId, storeId, result);
    }
  }

  Future<void> _triggerStoreTransfer(String currentClientId, String storeId, String newClientId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator.adaptive()),
    );

    try {
      final transferService = StoreTransferService();
      await transferService.transferStore(
        oldClientId: currentClientId,
        newClientId: newClientId,
        storeId: storeId,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Magasin transféré avec succès !", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors du transfert : $e", style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: kAppleRed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 📊 LIVE HISTORY LOGIC (NEW)
  // ---------------------------------------------------------------------------

  Timestamp? _getDate(Map<String, dynamic> data, String type) {
    if (type == 'Interventions') return data['scheduledAt'] ?? data['createdAt'];
    if (type == 'Installations') return data['installationDate'] ?? data['createdAt'];
    if (type == 'Livraisons') return data['completedAt'] ?? data['createdAt'];
    return data['createdAt'];
  }

  void _showHistoryBottomSheet(BuildContext context, String storeId, String storeName, String type) {
    String collection = '';
    Color themeColor = kAppleBlue;
    IconData icon = Icons.list;

    if (type == 'Interventions') { collection = 'interventions'; themeColor = kAppleBlue; icon = Icons.build_circle_rounded; }
    else if (type == 'Installations') { collection = 'installations'; themeColor = const Color(0xFFAF52DE); icon = Icons.handyman_rounded; }
    else if (type == 'Livraisons') { collection = 'livraisons'; themeColor = const Color(0xFF34C759); icon = Icons.local_shipping_rounded; }

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
                        ),
                        child: Column(
                            children: [
                              // Handle
                              const SizedBox(height: 12),
                              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
                              const SizedBox(height: 16),
                              // Header
                              Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle),
                                          child: Icon(icon, color: themeColor, size: 24),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("Historique des $type", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
                                                  Text(storeName, style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary)),
                                                ]
                                            )
                                        )
                                      ]
                                  )
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1, color: Colors.black12),
                              // Live List
                              Expanded(
                                  child: StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance.collection(collection).where('storeId', isEqualTo: storeId).snapshots(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());
                                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                          return Center(child: Text("Aucun(e) $type trouvé(e).", style: GoogleFonts.inter(color: kTextSecondary)));
                                        }

                                        final docs = snapshot.data!.docs.toList();
                                        // Sort descending by date
                                        docs.sort((a,b) {
                                          final dateA = _getDate(a.data() as Map<String, dynamic>, type);
                                          final dateB = _getDate(b.data() as Map<String, dynamic>, type);
                                          if (dateA == null) return 1;
                                          if (dateB == null) return -1;
                                          return dateB.compareTo(dateA);
                                        });

                                        return ListView.separated(
                                            controller: scrollController,
                                            padding: const EdgeInsets.all(20),
                                            itemCount: docs.length,
                                            separatorBuilder: (_,__) => const SizedBox(height: 12),
                                            itemBuilder: (context, index) {
                                              final doc = docs[index];
                                              final data = doc.data() as Map<String, dynamic>;

                                              String title = '';
                                              String subtitle = '';

                                              if (type == 'Interventions') {
                                                title = data['interventionCode'] ?? 'Intervention';
                                                subtitle = data['diagnostic'] ?? 'Aucun diagnostic';
                                              } else if (type == 'Installations') {
                                                title = data['installationCode'] ?? 'Installation';
                                                subtitle = "${(data['orderedProducts'] as List?)?.length ?? 0} produits installés";
                                              } else if (type == 'Livraisons') {
                                                title = data['bonLivraisonCode'] ?? 'Livraison';
                                                subtitle = "Livraison de ${(data['products'] as List?)?.length ?? 0} produit(s)";
                                              }

                                              final dateTs = _getDate(data, type);
                                              final dateStr = dateTs != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(dateTs.toDate()) : 'Date inconnue';
                                              final status = data['status'] ?? 'En attente';

                                              return InkWell(
                                                  onTap: () {
                                                    if (type == 'Interventions') {
                                                      Navigator.push(context, MaterialPageRoute(builder: (_) => InterventionDetailsPage(
                                                          interventionDoc: doc as DocumentSnapshot<Map<String, dynamic>>
                                                      )));
                                                    } else if (type == 'Installations') {
                                                      Navigator.push(context, MaterialPageRoute(builder: (_) => InstallationDetailsPage(
                                                          installationDoc: doc as DocumentSnapshot<Map<String, dynamic>>,
                                                          userRole: UserRoles.admin
                                                      )));
                                                    } else if (type == 'Livraisons') {
                                                      Navigator.push(context, MaterialPageRoute(builder: (_) => LivraisonDetailsPage(
                                                          livraisonId: doc.id
                                                      )));
                                                    }
                                                  },
                                                  borderRadius: BorderRadius.circular(16),
                                                  child: Container(
                                                      padding: const EdgeInsets.all(16),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(16),
                                                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                                                      ),
                                                      child: Row(
                                                          children: [
                                                            Container(
                                                              padding: const EdgeInsets.all(10),
                                                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
                                                              child: const Icon(Icons.calendar_today_rounded, size: 20, color: kTextSecondary),
                                                            ),
                                                            const SizedBox(width: 16),
                                                            Expanded(
                                                                child: Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                      Row(
                                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                          children: [
                                                                            Expanded(child: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextDark))),
                                                                            Text(dateStr, style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary)),
                                                                          ]
                                                                      ),
                                                                      const SizedBox(height: 4),
                                                                      Row(
                                                                          children: [
                                                                            Expanded(child: Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                                                            Container(
                                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                              decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                                                              child: Text(status, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: themeColor)),
                                                                            )
                                                                          ]
                                                                      )
                                                                    ]
                                                                )
                                                            )
                                                          ]
                                                      )
                                                  )
                                              );
                                            }
                                        );
                                      }
                                  )
                              )
                            ]
                        )
                    )
                );
              }
          );
        }
    );
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
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.white.withOpacity(0.2)),
            ),
          ),
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
                  padding: const EdgeInsets.only(top: 20, bottom: 120),
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

                    // ✅ LIVE DYNAMIC BADGES
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildLiveBadge(storeId, storeName, 'Interventions', 'interventions', const Color(0xFF007AFF)),
                        _buildLiveBadge(storeId, storeName, 'Installations', 'installations', const Color(0xFFAF52DE)),
                        _buildLiveBadge(storeId, storeName, 'Livraisons', 'livraisons', const Color(0xFF34C759)),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: InkWell(
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
                        // TRANSFER BUTTON
                        Expanded(
                          flex: 1,
                          child: InkWell(
                            onTap: () => _showTransferDialog(storeId, storeName),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: kAppleBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.swap_horiz_rounded, size: 20, color: kAppleBlue),
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

  // ✅ NEW LIVE BADGE BUILDER
  Widget _buildLiveBadge(String storeId, String storeName, String title, String collection, Color color) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(collection).where('storeId', isEqualTo: storeId).snapshots(),
        builder: (context, snapshot) {
          int count = snapshot.hasData ? snapshot.data!.docs.length : 0;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showHistoryBottomSheet(context, storeId, storeName, title),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$title: $count",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
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

// ==============================================================================
// 💎 PREMIUM GLASS DIALOG WIDGET (VISION OS / iOS 18 STYLE) - KEYBOARD FIXED
// ==============================================================================
class _PremiumTransferDialogUI extends StatefulWidget {
  final String storeName;
  final List<DocumentSnapshot> clients;

  const _PremiumTransferDialogUI({
    required this.storeName,
    required this.clients,
  });

  @override
  State<_PremiumTransferDialogUI> createState() => _PremiumTransferDialogUIState();
}

class _PremiumTransferDialogUIState extends State<_PremiumTransferDialogUI> {
  String? _selectedClientId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<DocumentSnapshot> filteredClients = widget.clients.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    filteredClients.sort((a, b) {
      final nameA = ((a.data() as Map<String, dynamic>)['name'] ?? '').toString().toLowerCase();
      final nameB = ((b.data() as Map<String, dynamic>)['name'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });

    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double dialogWidth = screenWidth > 600 ? 450 : screenWidth * 0.9;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final double maxDialogHeight = screenHeight - bottomInset - 40;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: dialogWidth,
          constraints: BoxConstraints(
            maxHeight: maxDialogHeight > 0 ? maxDialogHeight : screenHeight * 0.8,
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            children: [
              Positioned(
                top: -50, left: -50,
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(color: const Color(0xFF007AFF).withOpacity(0.35), shape: BoxShape.circle),
                ),
              ),
              Positioned(
                bottom: -50, right: -50,
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(color: const Color(0xFFAF52DE).withOpacity(0.35), shape: BoxShape.circle),
                ),
              ),

              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF007AFF).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF007AFF), size: 24),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Transférer ${widget.storeName}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1D1D1F), letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Sélectionnez le nouveau client pour ce magasin.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF86868B), height: 1.4),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: (val) => setState(() => _searchQuery = val),
                              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1D1D1F), fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                hintText: "Rechercher un client...",
                                hintStyle: GoogleFonts.inter(color: const Color(0xFF86868B)),
                                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF86868B), size: 18),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                    _searchFocusNode.unfocus();
                                  },
                                  child: const Icon(Icons.cancel_rounded, color: Color(0xFF86868B), size: 18),
                                )
                                    : null,
                              ),
                            ),
                          ),
                        ),

                        Flexible(
                          child: GestureDetector(
                            onPanDown: (_) => _searchFocusNode.unfocus(),
                            child: filteredClients.isEmpty
                                ? Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                "Aucun client trouvé.",
                                style: GoogleFonts.inter(color: const Color(0xFF86868B), fontSize: 14),
                              ),
                            )
                                : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredClients.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final doc = filteredClients[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final String name = data['name'] ?? 'Client Inconnu';
                                final bool isSelected = _selectedClientId == doc.id;

                                return GestureDetector(
                                  onTap: () {
                                    _searchFocusNode.unfocus();
                                    setState(() => _selectedClientId = doc.id);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutQuart,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF007AFF).withOpacity(0.08) : Colors.white.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF007AFF) : Colors.white.withOpacity(0.5),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36, height: 36,
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFF007AFF).withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                                              style: GoogleFonts.inter(
                                                color: isSelected ? const Color(0xFF007AFF) : const Color(0xFF1D1D1F),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                              color: const Color(0xFF1D1D1F),
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF), size: 22)
                                        else
                                          Icon(Icons.circle_outlined, color: Colors.grey.withOpacity(0.3), size: 22),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: Text('Annuler', style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF86868B), fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: _selectedClientId == null ? 0.5 : 1.0,
                                  child: ElevatedButton(
                                    onPressed: _selectedClientId == null ? null : () => Navigator.pop(context, _selectedClientId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF007AFF),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: Text('Confirmer', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
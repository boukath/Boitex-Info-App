// lib/screens/service_technique/installation_list_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // ✅ For Apple-style icons
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ High-performance image loading

import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/add_installation_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_history_list_page.dart';

class InstallationListPage extends StatelessWidget {
  final String userRole;
  final String serviceType;

  const InstallationListPage({
    super.key,
    required this.userRole,
    required this.serviceType,
  });

  // 🎨 PREMIUM THEME COLORS
  final Color _primaryBlue = const Color(0xFF007AFF); // iOS Blue
  final Color _bgLight = const Color(0xFFF2F2F7); // iOS System Grouped Background
  final Color _cardWhite = Colors.white;
  final Color _textDark = const Color(0xFF1C1C1E); // iOS Label Color
  final Color _textMuted = const Color(0xFF8E8E93); // iOS Secondary Label

  // Premium Status Colors (Soft background, bold text)
  Color _getStatusTextColor(String? status) {
    switch (status) {
      case 'En Cours':
        return const Color(0xFFE67E22); // Vibrant Orange
      case 'À Planifier':
        return const Color(0xFF007AFF); // Classic Blue
      case 'Planifiée':
        return const Color(0xFFAF52DE); // Apple Purple
      default:
        return const Color(0xFF8E8E93); // Muted Grey
    }
  }

  Color _getStatusBgColor(String? status) {
    return _getStatusTextColor(status).withOpacity(0.12);
  }

  // Fetch Store Logo dynamically
  Future<String?> _fetchStoreLogo(String clientId, String storeId) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .doc(storeId)
          .get();

      if (docSnapshot.exists && docSnapshot.data()!.containsKey('logoUrl')) {
        return docSnapshot.data()!['logoUrl'] as String?;
      }
    } catch (e) {
      debugPrint("Error fetching logo: $e");
    }
    return null;
  }

  void _navigateToDetails(BuildContext context, DocumentSnapshot doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstallationDetailsPage(
          installationDoc: doc,
          userRole: userRole,
        ),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, DocumentSnapshot doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddInstallationPage(
          userRole: userRole,
          serviceType: serviceType,
          installationToEdit: doc,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String docId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Supprimer ?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _textDark)),
        content: Text('Voulez-vous vraiment supprimer cette installation ?',
            style: GoogleFonts.poppins(color: _textDark)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Annuler', style: GoogleFonts.poppins(color: _textMuted, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30), // iOS Red
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Supprimer',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('installations').doc(docId).delete();
      } catch (e) {
        debugPrint("Error deleting: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = RolePermissions.canScheduleInstallation(userRole);

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent, // Clean iOS look
        elevation: 0,
        iconTheme: IconThemeData(color: _textDark),
        title: Text(
          'Installations ${serviceType.toUpperCase()}',
          style: GoogleFonts.poppins(
            color: _textDark,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: IconButton(
              icon: const Icon(CupertinoIcons.clock, color: Colors.black87),
              tooltip: "Historique",
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => InstallationHistoryListPage(
                      serviceType: serviceType,
                      userRole: userRole,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('installations')
            .where('serviceType', isEqualTo: serviceType)
            .where('status', whereIn: ['À Planifier', 'Planifiée', 'En Cours'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _primaryBlue));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Une erreur est survenue.', style: GoogleFonts.poppins(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.square_stack_3d_up_slash, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune installation active',
                    style: GoogleFonts.poppins(
                        fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          final installations = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(), // Apple-like bounce effect
            itemCount: installations.length,
            itemBuilder: (context, index) {
              final doc = installations[index];
              final data = doc.data() as Map<String, dynamic>;

              final installationCode = data['installationCode'] ?? 'N/A';
              final clientName = data['clientName'] ?? 'Client inconnu';
              final storeName = data['storeName'] ?? 'Magasin inconnu';
              final status = data['status'] ?? 'À Planifier';

              // IDs needed to fetch the logo
              final clientId = data['clientId'];
              final storeId = data['storeId'];
              // Direct logo fallback just in case it's saved on the installation doc
              final directLogoUrl = data['logoUrl'];

              final DateTime? installationDate = (data['installationDate'] as Timestamp?)?.toDate();
              final String dateDisplay = installationDate != null
                  ? DateFormat('dd MMM yyyy', 'fr_FR').format(installationDate)
                  : 'Date non définie';

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Slidable(
                  key: ValueKey(doc.id),
                  endActionPane: canEdit
                      ? ActionPane(
                    motion: const StretchMotion(),
                    extentRatio: 0.5,
                    children: [
                      SlidableAction(
                        onPressed: (ctx) => _navigateToEdit(context, doc),
                        backgroundColor: const Color(0xFF34C759), // iOS Green
                        foregroundColor: Colors.white,
                        icon: CupertinoIcons.pencil,
                        label: 'Éditer',
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                      ),
                      SlidableAction(
                        onPressed: (ctx) => _confirmDelete(context, doc.id),
                        backgroundColor: const Color(0xFFFF3B30), // iOS Red
                        foregroundColor: Colors.white,
                        icon: CupertinoIcons.trash,
                        label: 'Supprimer',
                        borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                      ),
                    ],
                  )
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardWhite,
                      borderRadius: BorderRadius.circular(20), // Apple-style rounded corners
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => _navigateToDetails(context, doc),
                        borderRadius: BorderRadius.circular(20),
                        highlightColor: Colors.black.withOpacity(0.02),
                        splashColor: _primaryBlue.withOpacity(0.05),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0), // Generous padding
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 🖼️ DYNAMIC LOGO CONTAINER
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey.shade100, width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: directLogoUrl != null
                                          ? CachedNetworkImage(
                                        imageUrl: directLogoUrl,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) => const CupertinoActivityIndicator(),
                                        errorWidget: (context, url, error) => _fallbackIcon(),
                                      )
                                          : (clientId != null && storeId != null)
                                          ? FutureBuilder<String?>(
                                        future: _fetchStoreLogo(clientId, storeId),
                                        builder: (context, logoSnapshot) {
                                          if (logoSnapshot.connectionState == ConnectionState.waiting) {
                                            return const CupertinoActivityIndicator();
                                          }
                                          if (logoSnapshot.hasData && logoSnapshot.data != null) {
                                            return CachedNetworkImage(
                                              imageUrl: logoSnapshot.data!,
                                              fit: BoxFit.contain,
                                              errorWidget: (context, url, error) => _fallbackIcon(),
                                            );
                                          }
                                          return _fallbackIcon();
                                        },
                                      )
                                          : _fallbackIcon(),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // 📄 INFO SECTION
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          installationCode,
                                          style: GoogleFonts.poppins(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: _textDark,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(CupertinoIcons.calendar, size: 14, color: _textMuted),
                                            const SizedBox(width: 6),
                                            Text(
                                              dateDisplay,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: installationDate != null ? _textMuted : const Color(0xFFFF3B30),
                                                fontWeight: installationDate != null ? FontWeight.w500 : FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 🚦 STATUS BADGE
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getStatusBgColor(status),
                                      borderRadius: BorderRadius.circular(20), // Pill shape
                                    ),
                                    child: Text(
                                      status,
                                      style: GoogleFonts.poppins(
                                        color: _getStatusTextColor(status),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),
                              Divider(height: 1, color: Colors.grey.shade200),
                              const SizedBox(height: 16),

                              // 📍 LOCATION & CLIENT DETAILS
                              Row(
                                children: [
                                  Icon(CupertinoIcons.building_2_fill, size: 18, color: Colors.grey.shade400),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      clientName,
                                      style: GoogleFonts.poppins(
                                          fontSize: 14, color: _textDark, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(CupertinoIcons.location_solid, size: 18, color: Colors.grey.shade400),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '$storeName ${data['storeLocation'] != null ? "— ${data['storeLocation']}" : ""}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 13, color: _textMuted, fontWeight: FontWeight.w400),
                                      overflow: TextOverflow.ellipsis,
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
            },
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddInstallationPage(
                userRole: userRole,
                serviceType: serviceType,
              ),
            ),
          );
        },
        backgroundColor: _textDark, // Black premium button
        elevation: 8, // ✅ Elevation alone handles the shadow
        // ❌ REMOVED: shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        icon: const Icon(CupertinoIcons.add, color: Colors.white),
        label: Text('NOUVELLE',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
      )
          : null,
    );
  }

  // Fallback Icon if Logo URL fails or is empty
  Widget _fallbackIcon() {
    return Container(
      color: _bgLight,
      child: Center(
        child: Icon(CupertinoIcons.photo, color: Colors.grey.shade400, size: 24),
      ),
    );
  }
}
// lib/screens/administration/portal_request_details_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;

// ✅ Import the Media Widgets
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';

// --- 🎨 PREMIUM 2026 APPLE DESIGN TOKENS ---
const Color kAppleDeepPurple = Color(0xFF2E0A5E);
const Color kAppleVibrantBlue = Color(0xFF0A84FF);
const Color kAppleMagenta = Color(0xFFFF2D55);
const Color kTextDark = Color(0xFF1D1D1F);
const Color kTextSecondary = Color(0xFF86868B);
const Color kAppleBlue = Color(0xFF007AFF);
const Color kApplePurple = Color(0xFFAF52DE);

class PortalRequestDetailsPage extends StatefulWidget {
  final String interventionId;

  const PortalRequestDetailsPage({super.key, required this.interventionId});

  @override
  State<PortalRequestDetailsPage> createState() => _PortalRequestDetailsPageState();
}

class _PortalRequestDetailsPageState extends State<PortalRequestDetailsPage> with SingleTickerProviderStateMixin {
  // --- STATE ---
  bool _isProcessing = false;
  String _selectedServiceType = 'Service Technique'; // Default
  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    // Subtle background animation controller
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    super.dispose();
  }

  /// --------------------------------------------------------------------------
  /// 1. APPROVAL LOGIC (THE TRANSACTION) - UNCHANGED
  /// --------------------------------------------------------------------------
  Future<void> _approveRequest(DocumentSnapshot doc) async {
    setState(() => _isProcessing = true);

    try {
      final currentYear = DateFormat('yyyy').format(DateTime.now());
      final counterRef = FirebaseFirestore.instance.collection('counters').doc('intervention_counter_$currentYear');
      final interventionRef = doc.reference;
      final docData = doc.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterDoc = await transaction.get(counterRef);
        int newCount = 1;
        if (counterDoc.exists) {
          final data = counterDoc.data() as Map<String, dynamic>;
          if (data['lastReset'] == currentYear) {
            newCount = (data['count'] as int? ?? 0) + 1;
          }
        }

        final newInterventionCode = 'INT-$newCount/$currentYear';
        final String? type = docData['interventionType'];
        final String? contractId = docData['contractId'];

        if ((type == 'Corrective' || type == 'Maintenance Corrective') && contractId != null) {
          final storeRef = FirebaseFirestore.instance
              .collection('clients')
              .doc(docData['clientId'])
              .collection('stores')
              .doc(docData['storeId']);
          final storeSnap = await transaction.get(storeRef);

          if (storeSnap.exists) {
            final sData = storeSnap.data() as Map<String, dynamic>;
            if (sData.containsKey('maintenance_contract') && sData['maintenance_contract'] != null) {
              Map<String, dynamic> contractMap = Map<String, dynamic>.from(sData['maintenance_contract']);
              if (contractMap['id'] == contractId) {
                contractMap['usedCorrective'] = (contractMap['usedCorrective'] ?? 0) + 1;
                transaction.update(storeRef, {'maintenance_contract': contractMap});
              }
            }
          }
        }

        transaction.set(counterRef, {'count': newCount, 'lastReset': currentYear});
        transaction.update(interventionRef, {
          'interventionCode': newInterventionCode,
          'status': 'Nouvelle Demande',
          'serviceType': _selectedServiceType,
          'approvedBy': 'Admin',
          'approvedAt': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Demande validée et transférée !"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    }
  }

  /// --------------------------------------------------------------------------
  /// 2. REJECTION LOGIC - UNCHANGED
  /// --------------------------------------------------------------------------
  Future<void> _rejectRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Refuser la demande ?"),
        content: const Text("Cette action est irréversible. La demande sera marquée comme 'Rejetée'."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("REFUSER")),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance.collection('interventions').doc(widget.interventionId).update({
        'status': 'Rejetée',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }

  /// --------------------------------------------------------------------------
  /// 3. MODERN APPLE 2026 UI BUILDER
  /// --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Détails de la Demande", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextDark)),
        backgroundColor: Colors.white.withOpacity(0.4),
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextDark),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.white.withOpacity(0.2)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // --- ANIMATED MESH GRADIENT BACKGROUND ---
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Stack(
                children: [
                  Container(color: const Color(0xFFF2F2F7)), // Apple Light Gray Base
                  Positioned(
                    top: -100 + (50 * _bgAnimationController.value),
                    left: -50,
                    child: _buildBlurBlob(kAppleVibrantBlue.withOpacity(0.3), 300),
                  ),
                  Positioned(
                    bottom: -100 - (50 * _bgAnimationController.value),
                    right: -50,
                    child: _buildBlurBlob(kApplePurple.withOpacity(0.2), 400),
                  ),
                  Positioned(
                    top: 200,
                    right: -100 + (50 * _bgAnimationController.value),
                    child: _buildBlurBlob(kAppleMagenta.withOpacity(0.15), 350),
                  ),
                ],
              );
            },
          ),

          // --- MAIN CONTENT (ADAPTABLE FOR WEB & MOBILE) ---
          SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('interventions').doc(widget.interventionId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Erreur: ${snapshot.error}"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kAppleBlue));

                final doc = snapshot.data!;
                final data = doc.data() as Map<String, dynamic>? ?? {};

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850), // 🌐 Web optimization
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(data),
                          const SizedBox(height: 24),

                          _buildGlassCard(
                            child: _buildInfoContent(data),
                          ),

                          const SizedBox(height: 24),

                          if (data['mediaUrls'] != null && (data['mediaUrls'] as List).isNotEmpty) ...[
                            Text("PIÈCES JOINTES", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.2)),
                            const SizedBox(height: 12),
                            _buildMediaGallery(context, data['mediaUrls']),
                            const SizedBox(height: 32),
                          ],

                          // --- ACTION ZONE ---
                          Text("ROUTAGE & VALIDATION", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.2)),
                          const SizedBox(height: 12),

                          _buildGlassCard(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Assignation du service", style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: kTextDark, fontSize: 16)),
                                const SizedBox(height: 6),
                                Text("Choisissez le département chargé de traiter cette demande.", style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: kTextSecondary, fontSize: 13)),
                                const SizedBox(height: 20),

                                // ✨ THE NEW PREMIUM ANIMATED SWITCHER
                                _buildPremiumServiceSwitcher(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // --- MODERN ACTION BUTTONS ---
                          Row(
                            children: [
                              Expanded(
                                child: _buildPremiumButton(
                                  label: "REFUSER",
                                  icon: Icons.close,
                                  color: kAppleMagenta,
                                  isOutlined: true,
                                  isLoading: false,
                                  onTap: _isProcessing ? null : _rejectRequest,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildPremiumButton(
                                  label: "ACCEPTER",
                                  icon: Icons.check,
                                  color: Colors.green.shade600,
                                  isOutlined: false,
                                  isLoading: _isProcessing,
                                  onTap: _isProcessing ? null : () => _approveRequest(doc),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(24)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> data) {
    final date = (data['createdAt'] as Timestamp?)?.toDate();
    final formattedDate = date != null ? DateFormat('dd MMM yyyy à HH:mm').format(date) : '-';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange.shade400]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.pending_actions_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Demande en Attente", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: kTextDark, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text("Reçue le $formattedDate", style: GoogleFonts.inter(color: kTextSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoContent(Map<String, dynamic> data) {
    final String type = data['interventionType'] ?? 'Standard';
    final bool isCorrective = (type == 'Corrective' || type == 'Maintenance Corrective');
    final bool isFacturable = (type == 'Facturable' || type == 'Intervention Facturable');

    Color typeColor = kTextSecondary;
    IconData typeIcon = Icons.info_outline;

    if (isCorrective) { typeColor = Colors.green.shade600; typeIcon = Icons.verified_rounded; }
    else if (isFacturable) { typeColor = Colors.orange.shade600; typeIcon = Icons.attach_money_rounded; }

    String storeName = data['storeName'] ?? 'Magasin Inconnu';
    dynamic rawLocation = data['storeLocation'];
    String locationSuffix = (rawLocation is String && rawLocation.isNotEmpty) ? " - $rawLocation" : "";
    String finalStoreDisplay = "$storeName$locationSuffix";

    final String phone = data['clientPhone'] ?? "Non renseigné";
    final String email = data['email'] ?? data['clientEmail'] ?? "Non renseigné";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TYPE BADGE
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: typeColor.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(typeIcon, color: typeColor, size: 16),
              const SizedBox(width: 8),
              Text(type.toUpperCase(), style: GoogleFonts.inter(color: typeColor, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // STORE & CLIENT
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kAppleBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.storefront_rounded, color: kAppleBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(finalStoreDisplay, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: kTextDark)),
                  const SizedBox(height: 2),
                  Text(data['clientName'] ?? 'Client Inconnu', style: GoogleFonts.inter(color: kTextSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),

        const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(color: Colors.black12, height: 1)),

        // DESCRIPTION
        Text("Description du problème", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextSecondary, fontSize: 13, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
          child: Text(
            data['requestDescription'] ?? "Aucune description fournie.",
            style: GoogleFonts.inter(fontSize: 15, height: 1.5, color: kTextDark),
          ),
        ),

        const SizedBox(height: 24),

        // 📞 CLICKABLE CONTACT INFO 📞
        _buildActionableContactRow(
            icon: Icons.person_rounded,
            text: data['managerName'] ?? "Nom inconnu",
            isLink: false
        ),
        const SizedBox(height: 12),
        _buildActionableContactRow(
          icon: Icons.phone_rounded,
          text: phone,
          isLink: phone != "Non renseigné",
          onTap: () => _launchPhone(phone),
        ),
        const SizedBox(height: 12),
        _buildActionableContactRow(
          icon: Icons.email_rounded,
          text: email,
          isLink: email != "Non renseigné",
          onTap: () => _launchEmail(email),
        ),
      ],
    );
  }

  // ✅ NEW: ACTIONABLE CONTACT ROW (CLICKABLE)
  Widget _buildActionableContactRow({required IconData icon, required String text, required bool isLink, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLink ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isLink ? kAppleBlue.withOpacity(0.1) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: isLink ? kAppleBlue : kTextSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    text,
                    style: GoogleFonts.inter(
                        color: isLink ? kAppleBlue : kTextDark,
                        fontSize: 15,
                        fontWeight: isLink ? FontWeight.w600 : FontWeight.w500,
                        decoration: isLink ? TextDecoration.underline : TextDecoration.none,
                        decorationColor: kAppleBlue.withOpacity(0.4)
                    ),
                    overflow: TextOverflow.ellipsis
                ),
              ),
              if (isLink)
                const Icon(Icons.arrow_outward_rounded, size: 14, color: kAppleBlue),
            ],
          ),
        ),
      ),
    );
  }

  // --- 📧 URL LAUNCHER METHODS ---
  Future<void> _launchPhone(String phone) async {
    // Strip everything except numbers and plus sign
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // --- MEDIA GALLERY ---
  Widget _buildMediaGallery(BuildContext context, dynamic mediaUrls) {
    final List<String> urls = (mediaUrls as List).map((e) => e.toString()).toList();
    final List<String> imagesOnly = urls.where((url) => ['.jpg', '.jpeg', '.png', '.webp'].contains(path.extension(url).toLowerCase())).toList();

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final url = urls[index];
          final ext = path.extension(url).toLowerCase();
          final isImage = ['.jpg', '.jpeg', '.png', '.webp'].contains(ext);
          final isVideo = ['.mp4', '.mov', '.avi'].contains(ext);

          if (isImage) {
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImageGalleryPage(imageUrls: imagesOnly, initialIndex: imagesOnly.indexOf(url)))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(url, width: 110, height: 110, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallbackTile(Icons.broken_image)),
              ),
            );
          } else if (isVideo) {
            // ✅ NEW: Uses our premium Video Thumbnail Tile!
            return _VideoThumbnailTile(
              videoUrl: url,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerPage(videoUrl: url))),
            );
          } else {
            return GestureDetector(
              onTap: () => _launchUrl(url),
              child: _buildFallbackTile(Icons.insert_drive_file_rounded, label: ext.replaceAll('.', '').toUpperCase()),
            );
          }
        },
      ),
    );
  }

  Widget _buildFallbackTile(IconData icon, {Color bgColor = Colors.white, Color iconColor = kAppleBlue, String? label}) {
    return Container(
      width: 110, height: 110,
      decoration: BoxDecoration(color: bgColor.withOpacity(0.7), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 36),
          if (label != null) ...[const SizedBox(height: 8), Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary))],
        ],
      ),
    );
  }

  // ✨ --- PREMIUM GLOWING ANIMATED SERVICE SWITCHER --- ✨
  Widget _buildPremiumServiceSwitcher() {
    final bool isTechnique = _selectedServiceType == "Service Technique";

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04), // Recessed track color
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
      ),
      child: Stack(
        children: [
          // 🚀 THE ANIMATED GLOWING PILL BACKGROUND
          AnimatedAlign(
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn, // Smooth Apple-style spring curve
            alignment: isTechnique ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5, // Pill takes exactly half the width
              child: Container(
                margin: const EdgeInsets.all(4), // Inner padding for the pill
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isTechnique
                          ? [kAppleVibrantBlue, kAppleBlue]
                          : [kApplePurple, kAppleDeepPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isTechnique ? kAppleBlue : kApplePurple).withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ]
                ),
              ),
            ),
          ),

          // 🔘 THE CLICKABLE OVERLAYS WITH ICONS
          Row(
            children: [
              Expanded(child: _buildSwitcherOption("Service Technique", Icons.build_circle_rounded, isTechnique)),
              Expanded(child: _buildSwitcherOption("Service IT", Icons.computer_rounded, !isTechnique)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitcherOption(String label, IconData icon, bool isSelected) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // Ensures the whole invisible half is clickable
      onTap: () => setState(() => _selectedServiceType = label),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0), // Adds a tiny buffer
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: GoogleFonts.inter(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : kTextSecondary,
              fontSize: 13, // 📉 Slightly reduced to fit mobile
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: isSelected ? Colors.white : kTextSecondary.withOpacity(0.6), size: 16), // 📉 Slightly reduced
                const SizedBox(width: 6),
                // ✅ WRAPPED IN FLEXIBLE TO PREVENT OVERFLOW
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- MODERN BUTTONS ---
  Widget _buildPremiumButton({required String label, required IconData icon, required Color color, required bool isOutlined, required bool isLoading, required VoidCallback? onTap}) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: isOutlined || onTap == null ? [] : [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: isOutlined ? Colors.transparent : (onTap == null ? Colors.grey.shade400 : color),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isOutlined ? BorderSide(color: onTap == null ? Colors.grey : color, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Center(
            child: isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: isOutlined ? (onTap == null ? Colors.grey : color) : Colors.white, size: 20),
                  const SizedBox(width: 6),
                  // ✅ WRAPPED IN FLEXIBLE TO PREVENT OVERFLOW
                  Flexible(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                          color: isOutlined ? (onTap == null ? Colors.grey : color) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14, // 📉 Slightly adjusted
                          letterSpacing: 0.5
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
// ✨ NEW: PREMIUM VIDEO THUMBNAIL WIDGET ✨
class _VideoThumbnailTile extends StatefulWidget {
  final String videoUrl;
  final VoidCallback onTap;

  const _VideoThumbnailTile({required this.videoUrl, required this.onTap});

  @override
  State<_VideoThumbnailTile> createState() => _VideoThumbnailTileState();
}

class _VideoThumbnailTileState extends State<_VideoThumbnailTile> {
  Uint8List? _thumbnailBytes;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 150, // Optimizes memory while keeping it crisp
        quality: 60,
      );

      if (mounted) {
        setState(() {
          _thumbnailBytes = uint8list;
        });
      }
    } catch (e) {
      debugPrint("Error generating video thumbnail: $e");
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. The Real Thumbnail Image
              if (_thumbnailBytes != null)
                Image.memory(_thumbnailBytes!, fit: BoxFit.cover)
              else if (!_hasError)
                const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))
              else
                const Center(child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 32)),

              // 2. The Premium Glass Play Button Overlay
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
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
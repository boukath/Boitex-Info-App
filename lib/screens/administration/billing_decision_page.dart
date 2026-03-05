// lib/screens/administration/billing_decision_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui'; // REQUIRED FOR GLASSMORPHISM (ImageFilter)
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// MEDIA VIEWERS
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class BillingDecisionPage extends StatefulWidget {
  final DocumentSnapshot interventionDoc;

  const BillingDecisionPage({super.key, required this.interventionDoc});

  @override
  State<BillingDecisionPage> createState() => _BillingDecisionPageState();
}

class _BillingDecisionPageState extends State<BillingDecisionPage> {
  bool _isActionInProgress = false;
  PlatformFile? _selectedPdf;

  // --- 🔒 CORE LOGIC PRESERVED EXACTLY AS BEFORE 🔒 ---

  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response = await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _uploadFileToB2(PlatformFile file, Map<String, dynamic> b2Creds) async {
    try {
      final String safeOriginalName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9\.\-]'), '_');
      final fileName = 'factures/${widget.interventionDoc.id}_${DateTime.now().millisecondsSinceEpoch}_$safeOriginalName';
      final int length = file.size;

      final Uint8List bytes;
      if (kIsWeb) {
        bytes = file.bytes!;
      } else {
        bytes = await File(file.path!).readAsBytes();
      }

      final sha1Hash = sha1.convert(bytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);

      var request = http.StreamedRequest('POST', uploadUri);
      request.headers.addAll({
        'Authorization': b2Creds['authorizationToken'] as String,
        'X-Bz-File-Name': Uri.encodeComponent(fileName),
        'Content-Type': 'application/pdf',
        'X-Bz-Content-Sha1': sha1Hash,
        'Content-Length': length.toString(),
      });

      request.sink.add(bytes);
      request.sink.close();

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final body = json.decode(respStr) as Map<String, dynamic>;
        final encodedPath = (body['fileName'] as String).split('/').map(Uri.encodeComponent).join('/');
        return (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
      } else {
        debugPrint("❌ B2 Upload Failed: ${response.statusCode} - $respStr");
        return null;
      }
    } catch (e) {
      debugPrint("❌ B2 Upload Error: $e");
      return null;
    }
  }

  Future<void> _closeWithoutBilling() async {
    setState(() => _isActionInProgress = true);
    try {
      final data = widget.interventionDoc.data() as Map<String, dynamic>?;
      if (data == null) throw Exception("Les données du document sont introuvables.");

      await FirebaseFirestore.instance.collection('interventions').doc(widget.interventionDoc.id).update({
        'status': 'Clôturé',
        'billingStatus': 'Sans Facture',
        'closedAt': Timestamp.now(),
      });

      await ActivityLogger.logActivity(
        message: "Intervention clôturée sans facture.",
        category: "Facturation",
        interventionId: widget.interventionDoc.id,
        clientName: data['clientName'] ?? '',
        storeName: data['storeName'] ?? '',
        storeLocation: data['storeLocation'] ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intervention clôturée sans facture.')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb,
    );
    if (result != null) setState(() => _selectedPdf = result.files.single);
  }

  void _removeSelectedPdf() => setState(() => _selectedPdf = null);

  Future<void> _confirmAndClose() async {
    if (_selectedPdf == null) return;
    setState(() => _isActionInProgress = true);
    try {
      final b2Credentials = await _getB2UploadCredentials();
      if (b2Credentials == null) throw Exception("Impossible d'obtenir les identifiants B2.");

      String? downloadUrl = await _uploadFileToB2(_selectedPdf!, b2Credentials);
      if (downloadUrl == null) throw Exception("Échec du téléversement sur B2.");

      final data = widget.interventionDoc.data() as Map<String, dynamic>?;
      if (data == null) throw Exception("Les données du document sont introuvables.");

      await FirebaseFirestore.instance.collection('interventions').doc(widget.interventionDoc.id).update({
        'status': 'Clôturé',
        'billingStatus': 'Facturé',
        'closedAt': Timestamp.now(),
        'invoiceUrl': downloadUrl,
      });

      await ActivityLogger.logActivity(
        message: "Intervention facturée et clôturée.",
        category: "Facturation",
        interventionId: widget.interventionDoc.id,
        clientName: data['clientName'] ?? '',
        storeName: data['storeName'] ?? '',
        storeLocation: data['storeLocation'] ?? '',
        invoiceUrl: downloadUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intervention facturée et clôturée avec succès.'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  // --- 💎 NEW IOS 2026 PREMIUM UI HELPERS 💎 ---

  bool _isVideoPath(String path) => path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov') || path.toLowerCase().endsWith('.avi') || path.toLowerCase().endsWith('.mkv');
  bool _isPdfPath(String path) => path.toLowerCase().endsWith('.pdf');

  Future<void> _launchURL(BuildContext context, String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    if (!await launchUrl(Uri.parse(urlString), mode: LaunchMode.externalApplication)) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir: $urlString')));
    }
  }

  Future<void> _openMedia(BuildContext context, String mediaUrl, List<dynamic>? allMediaUrls, {String? signatureUrl}) async {
    if (_isPdfPath(mediaUrl)) return _launchURL(context, mediaUrl);
    if (_isVideoPath(mediaUrl)) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoPlayerPage(videoUrl: mediaUrl)));
      return;
    }
    final List<String> imageUrls = (allMediaUrls ?? []).whereType<String>().where((url) => !_isVideoPath(url) && !_isPdfPath(url)).toList();
    if (signatureUrl != null && signatureUrl.isNotEmpty && !imageUrls.contains(signatureUrl)) imageUrls.add(signatureUrl);
    if (imageUrls.isEmpty) return;
    final int initialIndex = imageUrls.indexOf(mediaUrl);
    if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImageGalleryPage(imageUrls: imageUrls, initialIndex: initialIndex != -1 ? initialIndex : 0)));
  }

  // Glassmorphism Card Builder
  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6), // Translucent white
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, spreadRadius: -5)
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassInfoRow(String label, String? value, {IconData? icon, Color? iconColor, bool isLink = false, VoidCallback? onTap}) {
    Widget valueWidget = Text(
      value?.isNotEmpty ?? false ? value! : 'Non défini',
      style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: (isLink && value != null) ? const Color(0xFF007AFF) : const Color(0xFF1D1D1F)
      ),
    );

    if (isLink && value != null && onTap != null) {
      valueWidget = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: valueWidget,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor?.withOpacity(0.1) ?? const Color(0xFF007AFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor ?? const Color(0xFF007AFF)),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 130,
            child: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                label,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w500, color: const Color(0xFF86868B), fontSize: 14),
              ),
            ),
          ),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: valueWidget,
          )),
        ],
      ),
    );
  }

  Widget _buildGlassDetailSection(String label, String? value, {IconData? icon, Color? iconColor}) {
    final bool isEmpty = value == null || value.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor ?? const Color(0xFF1D1D1F)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1D1D1F)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.8))
            ),
            child: Text(
              isEmpty ? 'Aucune information fournie.' : value,
              style: GoogleFonts.outfit(
                  color: isEmpty ? const Color(0xFF86868B) : const Color(0xFF1D1D1F),
                  height: 1.5,
                  fontSize: 15,
                  fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumThumbnail(String url, List<dynamic> allMediaUrls, {String? signatureUrl}) {
    final bool isVideo = _isVideoPath(url);
    final bool isPdf = _isPdfPath(url);

    Widget content;
    if (isPdf) {
      content = const Center(child: Icon(Icons.picture_as_pdf, size: 36, color: Color(0xFFFF3B30)));
    } else if (isVideo) {
      content = FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(video: url, imageFormat: ImageFormat.JPEG, maxWidth: 100, quality: 30),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          if (snapshot.hasData && snapshot.data != null) return Image.memory(snapshot.data!, fit: BoxFit.cover);
          return const Center(child: Icon(Icons.videocam, size: 36, color: Color(0xFF86868B)));
        },
      );
    } else {
      content = Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (c, child, prog) => prog == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey),
      );
    }

    return GestureDetector(
      onTap: () => _openMedia(context, url, allMediaUrls, signatureUrl: signatureUrl),
      child: Container(
        width: 85,
        height: 85,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.white.withOpacity(0.8), child: content),
              if (isVideo && !isPdf)
                Container(
                  color: Colors.black26,
                  child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.interventionDoc.data() as Map<String, dynamic>?;

    if (data == null) {
      return Scaffold(
        body: Center(child: Text('Erreur de données', style: GoogleFonts.outfit())),
      );
    }

    final String? clientName = data['clientName'] as String?;
    final String? storeName = data['storeName'] as String?;
    final String? storeLocation = data['storeLocation'] as String?;
    final String? serviceType = data['serviceType'] as String?;
    final String? managerName = data['managerName'] as String?;
    final String? managerPhone = data['managerPhone'] as String?;
    final List<dynamic>? assignedTechniciansList = data['assignedTechnicians'] as List<dynamic>?;
    final String assignedTechniciansFormatted = assignedTechniciansList?.join(', ') ?? 'Non défini';
    final String? description = data['requestDescription'] as String?;
    final String? diagnostic = data['diagnostic'] as String?;
    final String? workDone = data['workDone'] as String?;
    final Timestamp? updatedAtRaw = data['updatedAt'] as Timestamp?;
    final String interventionDate = updatedAtRaw != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(updatedAtRaw.toDate()) : 'N/A';
    final String? signatureUrl = data['signatureUrl'] as String?;
    final List<dynamic>? mediaUrlsList = data['mediaUrls'] as List<dynamic>?;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.4),
        flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: Container(color: Colors.transparent))),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1D1D1F)),
        title: Text('Décision Facturation', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1D1D1F))),
      ),
      body: Stack(
        children: [
          // 🌈 IOS 2026 Animated Mesh Gradient Background
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
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFD1FF).withOpacity(0.6)),
            ).applyBlur(sigma: 80),
          ),
          Positioned(
            bottom: -50, left: -100,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFB5DEFF).withOpacity(0.5)),
            ).applyBlur(sigma: 80),
          ),

          // 📱 MAIN CONTENT (Adaptive for Web & Mobile)
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 750),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- 🏢 INTERVENTION DETAILS CARD ---
                      _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Détails de la mission', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1D1D1F))),
                            const SizedBox(height: 16),
                            _buildGlassInfoRow('Client', clientName, icon: Icons.business, iconColor: const Color(0xFF5856D6)),
                            _buildGlassInfoRow('Magasin', '$storeName ($storeLocation)', icon: Icons.storefront, iconColor: const Color(0xFFFF9500)),
                            _buildGlassInfoRow('Date', interventionDate, icon: Icons.calendar_today_rounded, iconColor: const Color(0xFFFF2D55)),
                            _buildGlassInfoRow('Type Service', serviceType, icon: Icons.design_services_rounded, iconColor: const Color(0xFF00C7BE)),
                            _buildGlassInfoRow('Manager', managerName, icon: Icons.person_rounded, iconColor: const Color(0xFF32ADE6)),
                            _buildGlassInfoRow('Téléphone', managerPhone, icon: Icons.phone_rounded, iconColor: const Color(0xFF34C759)),
                            _buildGlassInfoRow('Équipe', assignedTechniciansFormatted, icon: Icons.engineering_rounded, iconColor: const Color(0xFFAF52DE)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- 🛠️ TECHNICIAN REPORT CARD ---
                      _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rapport Technicien', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1D1D1F))),
                            const SizedBox(height: 16),
                            _buildGlassDetailSection('Description Initiale', description, icon: Icons.description_rounded, iconColor: const Color(0xFF5856D6)),
                            _buildGlassDetailSection('Diagnostic', diagnostic, icon: Icons.troubleshoot_rounded, iconColor: const Color(0xFFFF9500)),
                            _buildGlassDetailSection('Travaux Réalisés', workDone, icon: Icons.build_circle_rounded, iconColor: const Color(0xFF34C759)),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Divider(color: Colors.black12, thickness: 1),
                            ),

                            // Signature
                            if (signatureUrl != null && signatureUrl.isNotEmpty)
                              _buildGlassInfoRow('Signature Client', 'Ouvrir la signature', icon: Icons.draw_rounded, iconColor: const Color(0xFF1D1D1F), isLink: true, onTap: () => _openMedia(context, signatureUrl, mediaUrlsList, signatureUrl: signatureUrl)),

                            // Medias
                            if (mediaUrlsList != null && mediaUrlsList.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.perm_media_rounded, size: 18, color: Color(0xFF1D1D1F)),
                                  const SizedBox(width: 8),
                                  Text('Médias joints', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1D1D1F))),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: mediaUrlsList.whereType<String>().where((url) => url.isNotEmpty).map((url) => _buildPremiumThumbnail(url, mediaUrlsList, signatureUrl: signatureUrl)).toList(),
                              ),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // --- 🚀 ACTION AREA (SMART DYNAMIC CARD) ---
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.fastOutSlowIn,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: const Color(0xFF007AFF).withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 10))],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text('Décision Finale', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1D1D1F))),
                            const SizedBox(height: 20),

                            if (_isActionInProgress)
                              const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: CircularProgressIndicator(color: Color(0xFF007AFF), strokeWidth: 3),
                              )
                            else
                              Column(
                                children: [
                                  // Selected PDF Preview Bubble
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: _selectedPdf != null
                                        ? Container(
                                      key: const ValueKey('pdf_preview'),
                                      margin: const EdgeInsets.only(bottom: 20),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF007AFF).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFFF3B30), size: 32),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(_selectedPdf!.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: const Color(0xFF1D1D1F)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.cancel_rounded, color: Color(0xFF86868B)),
                                            onPressed: _removeSelectedPdf,
                                            splashRadius: 20,
                                          )
                                        ],
                                      ),
                                    )
                                        : const SizedBox.shrink(key: ValueKey('empty')),
                                  ),

                                  // Dual Action Buttons
                                  Row(
                                    children: [
                                      // Secondary Button (Non Facturable)
                                      Expanded(
                                        child: InkWell(
                                          onTap: _selectedPdf != null ? null : _closeWithoutBilling,
                                          borderRadius: BorderRadius.circular(24),
                                          child: Opacity(
                                            opacity: _selectedPdf != null ? 0.4 : 1.0,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 18),
                                              decoration: BoxDecoration(
                                                color: Colors.transparent,
                                                borderRadius: BorderRadius.circular(24),
                                                border: Border.all(color: const Color(0xFF86868B).withOpacity(0.3), width: 1.5),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text('Non Facturable', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1D1D1F))),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Primary Gradient Button (Facturable / Confirm)
                                      Expanded(
                                        child: InkWell(
                                          onTap: _selectedPdf == null ? _pickPdf : _confirmAndClose,
                                          borderRadius: BorderRadius.circular(24),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            padding: const EdgeInsets.symmetric(vertical: 18),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: _selectedPdf == null
                                                    ? [const Color(0xFF00C7BE), const Color(0xFF007AFF)] // Blue/Cyan
                                                    : [const Color(0xFF34C759), const Color(0xFF30D158)], // Green success
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(24),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (_selectedPdf == null ? const Color(0xFF007AFF) : const Color(0xFF34C759)).withOpacity(0.4),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 8),
                                                )
                                              ],
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(_selectedPdf == null ? Icons.upload_file_rounded : Icons.check_circle_rounded, color: Colors.white, size: 22),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _selectedPdf == null ? 'Facturer (PDF)' : 'Confirmer',
                                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🪄 Helper extension to easily apply blur to background elements
extension BlurExtension on Widget {
  Widget applyBlur({double sigma = 10.0}) {
    return ImageFilterWidget(sigma: sigma, child: this);
  }
}

class ImageFilterWidget extends StatelessWidget {
  final double sigma;
  final Widget child;
  const ImageFilterWidget({super.key, required this.sigma, required this.child});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}
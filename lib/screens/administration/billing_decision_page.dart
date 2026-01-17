// lib/screens/administration/billing_decision_page.dart

import 'dart:io';
import 'dart:typed_data'; // ADDED for thumbnails
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
// Keep for potential navigation
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// ✅ 1. ADD IMPORTS FOR IN-APP MEDIA VIEWERS
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';

// ✅ 2. ADD IMPORT FOR VIDEO THUMBNAILS
import 'package:video_thumbnail/video_thumbnail.dart';

class BillingDecisionPage extends StatefulWidget {
  final DocumentSnapshot interventionDoc;

  const BillingDecisionPage({super.key, required this.interventionDoc});

  @override
  State<BillingDecisionPage> createState() => _BillingDecisionPageState();
}

class _BillingDecisionPageState extends State<BillingDecisionPage> {
  bool _isActionInProgress = false;

  // --- Functions for billing/closing (Keep existing logic) ---
  Future<void> _closeWithoutBilling() async {
    setState(() => _isActionInProgress = true);
    try {
      final data = widget.interventionDoc.data() as Map<String, dynamic>?;

      if (data == null) {
        throw Exception("Les données du document sont introuvables.");
      }

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intervention clôturée sans facture.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }


  Future<void> _billAndClose() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);

    if (result != null) {
      File file = File(result.files.single.path!);
      setState(() => _isActionInProgress = true);
      try {
        String fileName = 'factures/${widget.interventionDoc.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        UploadTask task = FirebaseStorage.instance.ref(fileName).putFile(file);
        TaskSnapshot snapshot = await task;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        final data = widget.interventionDoc.data() as Map<String, dynamic>?;

        if (data == null) {
          throw Exception("Les données du document sont introuvables.");
        }

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Intervention facturée et clôturée.')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors du téléversement: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isActionInProgress = false);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun fichier sélectionné.')),
        );
      }
    }
  }

  // --- Helper widget for displaying info rows ---
  Widget _buildInfoRow(String label, String? value, {IconData? icon, Color? iconColor, bool isLink = false, VoidCallback? onTap}) {
    Widget valueWidget = Text(
      value?.isNotEmpty ?? false ? value! : 'N/A',
      style: GoogleFonts.poppins(color: (isLink && value != null) ? Colors.blue : null),
    );

    if (isLink && value != null && onTap != null) {
      valueWidget = InkWell(
        onTap: onTap,
        child: valueWidget,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) Icon(icon, size: 18, color: iconColor ?? Colors.grey.shade600),
          if (icon != null) const SizedBox(width: 8),
          SizedBox(
            width: 120, // Adjusted width
            child: Text(
              label,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }

  // --- Helper widget for multi-line details ---
  Widget _buildDetailSection(String label, String? value, {IconData? icon, Color? iconColor}) {
    if (value == null || value.isEmpty) {
      return Padding( // Still show label even if value is N/A for consistency
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) Icon(icon, size: 18, color: iconColor ?? Colors.grey.shade600),
                if (icon != null) const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300)
              ),
              child: Text(
                'Non spécifié',
                style: GoogleFonts.poppins(color: Colors.black54, height: 1.4, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      );
    }
    // Only build the full section if the value is not null or empty
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, size: 18, color: iconColor ?? Colors.grey.shade600),
              if (icon != null) const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300)
            ),
            child: Text(
              value, // Value is guaranteed non-empty here
              style: GoogleFonts.poppins(color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper to launch URLs ---
  Future<void> _launchURL(BuildContext context, String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL invalide ou manquante.')),
      );
      return;
    }
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir le lien: $urlString')),
        );
      }
    }
  }

  // ✅ 3. ADD HELPER FUNCTIONS FOR MEDIA TYPES
  // Helper function for checking video type
  bool _isVideoPath(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv');
  }

  // Helper function for checking PDF type
  bool _isPdfPath(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.pdf');
  }

  // ✅ 4. MODIFIED HELPER FUNCTION to open the correct viewer
  Future<void> _openMedia(BuildContext context, String mediaUrl, List<dynamic>? allMediaUrls, {String? signatureUrl}) async {
    // 1. Check for PDF
    if (_isPdfPath(mediaUrl)) {
      _launchURL(context, mediaUrl); // Use existing launcher for PDFs
      return;
    }

    // 2. Check for Video
    if (_isVideoPath(mediaUrl)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerPage(videoUrl: mediaUrl),
        ),
      );
      return;
    }

    // 3. Assume Image and open gallery
    // Filter for images only from the media list
    final List<String> imageUrls = (allMediaUrls ?? [])
        .whereType<String>() // Ensure all are strings
        .where((url) =>
    !_isVideoPath(url) &&
        !_isPdfPath(url))
        .toList();

    // If a signatureUrl is provided and not already in the list, add it
    if (signatureUrl != null && signatureUrl.isNotEmpty && !imageUrls.contains(signatureUrl)) {
      imageUrls.add(signatureUrl);
    }

    if (imageUrls.isEmpty) return; // No images to show

    // Find the index of the clicked image (which could be the signature)
    final int initialIndex = imageUrls.indexOf(mediaUrl);

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImageGalleryPage(
            imageUrls: imageUrls,
            initialIndex: initialIndex != -1 ? initialIndex : 0,
          ),
        ),
      );
    }
  }


  // ✅ 5. ADD THUMBNAIL WIDGET
  Widget _buildMediaThumbnail(BuildContext context, String url, List<dynamic> allMediaUrls, {String? signatureUrl}) {
    final bool isVideo = _isVideoPath(url);
    final bool isPdf = _isPdfPath(url);

    Widget content;
    if (isPdf) {
      content = const Center(
          child: Icon(Icons.picture_as_pdf, size: 40, color: Colors.red));
    } else if (isVideo) {
      content = FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(
          video: url,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 100,
          quality: 30,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData && snapshot.data != null) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                snapshot.data!,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            );
          }
          return const Center(
              child: Icon(Icons.videocam, size: 40, color: Colors.black54));
        },
      );
    } else {
      // Network Image
      content = Hero(
        tag: url, // Use URL as hero tag
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            loadingBuilder: (c, child, prog) => prog == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (c, e, s) =>
            const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openMedia(context, url, allMediaUrls, signatureUrl: signatureUrl),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          color: const Color(0xFFF1F5F9),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: content),
            if (isVideo && !isPdf)
              const Center(
                child:
                Icon(Icons.play_circle_fill, color: Colors.white, size: 30),
              ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final data = widget.interventionDoc.data() as Map<String, dynamic>?;

    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: const Center(child: Text('Impossible de lire les données de l\'intervention.')),
      );
    }

    // --- Extract ALL fields based on the user's provided list ---
    final String? clientName = data['clientName'] as String?;
    final String? storeName = data['storeName'] as String?;
    final String? storeLocation = data['storeLocation'] as String?;
    final String? serviceType = data['serviceType'] as String?;

    final String? managerName = data['managerName'] as String?;
    final String? managerPhone = data['managerPhone'] as String?;
    final List<dynamic>? assignedTechniciansList = data['assignedTechnicians'] as List<dynamic>?;
    final String assignedTechniciansFormatted = assignedTechniciansList?.join(', ') ?? 'N/A';

    final String? description = data['requestDescription'] as String?;

    final String? diagnostic = data['diagnostic'] as String?;
    final String? workDone = data['workDone'] as String?;
    final Timestamp? updatedAtRaw = data['updatedAt'] as Timestamp?;

    final String interventionDateFromUpdatedAt = updatedAtRaw != null ? DateFormat('dd/MM/yyyy', 'fr_FR').format(updatedAtRaw.toDate()) : 'N/A';

    final String updatedAtFormatted = updatedAtRaw != null ? DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(updatedAtRaw.toDate()) : 'N/A';

    final String? signatureUrl = data['signatureUrl'] as String?;
    final List<dynamic>? mediaUrlsList = data['mediaUrls'] as List<dynamic>?;
    // --- End Extraction ---

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Décision Facturation', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Intervention Details Card ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Détails Intervention',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),
                    const Divider(height: 20, thickness: 1),
                    _buildInfoRow('Client:', clientName, icon: Icons.person_outline),
                    _buildInfoRow('Magasin:', storeName, icon: Icons.storefront_outlined),
                    _buildInfoRow('Date Intervention:', interventionDateFromUpdatedAt, icon: Icons.calendar_today_outlined),
                    _buildInfoRow('Type Service:', serviceType, icon: Icons.build_outlined),
                    _buildInfoRow('Manager:', managerName, icon: Icons.manage_accounts_outlined),
                    _buildInfoRow('Téléphone Man.:', managerPhone, icon: Icons.phone_outlined),
                    _buildInfoRow('Techniciens:', assignedTechniciansFormatted, icon: Icons.engineering_outlined),
                    _buildInfoRow('Dern. MàJ:', updatedAtFormatted, icon: Icons.update_outlined),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Technician Report Card ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rapport Technicien',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),
                    const Divider(height: 20, thickness: 1),

                    _buildDetailSection('Description:', description, icon: Icons.description_outlined),
                    _buildDetailSection('Diagnostic:', diagnostic, icon: Icons.medical_information_outlined),
                    _buildDetailSection('Travaux Réalisés:', workDone, icon: Icons.handyman_outlined),

                    // ✅ 6. UPDATE SIGNATURE ONTAP
                    // Display Signature if available
                    if (signatureUrl != null && signatureUrl.isNotEmpty)
                      _buildInfoRow(
                        'Signature:',
                        'Voir Signature', // Display text instead of URL
                        icon: Icons.draw_outlined,
                        isLink: true,
                        onTap: () => _openMedia(context, signatureUrl, mediaUrlsList, signatureUrl: signatureUrl),
                      ),
                    if (signatureUrl == null || signatureUrl.isEmpty)
                      _buildInfoRow(
                        'Signature:',
                        'N/A', // Display N/A if no signature
                        icon: Icons.draw_outlined,
                      ),


                    // UPDATE MEDIA SECTION TO USE THUMBNAILS
                    if (mediaUrlsList != null && mediaUrlsList.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.perm_media_outlined, size: 18, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Text(
                                  'Médias:',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12), // Added space
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: mediaUrlsList.map((mediaUrl) {
                                if (mediaUrl is String && mediaUrl.isNotEmpty) {
                                  // Pass signatureUrl so it can be included in the gallery
                                  return _buildMediaThumbnail(context, mediaUrl, mediaUrlsList, signatureUrl: signatureUrl);
                                }
                                return const SizedBox.shrink();
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    if (mediaUrlsList == null || mediaUrlsList.isEmpty)
                      _buildInfoRow('Médias:', 'Aucun', icon: Icons.perm_media_outlined),


                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Action Buttons
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Action Requise',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (_isActionInProgress)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.do_not_disturb_alt),
                              onPressed: _closeWithoutBilling,
                              label: const Text('Non Facturable'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade800,
                                side: BorderSide(color: Colors.grey.shade400),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _billAndClose,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Facturable'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
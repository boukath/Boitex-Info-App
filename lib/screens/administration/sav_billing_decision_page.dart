// lib/screens/administration/sav_billing_decision_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart'; // No longer needed for invoice
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'package:http/http.dart' as http; // ✅ ADDED for B2
import 'package:crypto/crypto.dart';      // ✅ ADDED for B2
import 'dart:convert';                   // ✅ ADDED for B2
import 'package:path/path.dart' as path; // ✅ ADDED for B2 path.basename


class SavBillingDecisionPage extends StatefulWidget {
  final SavTicket ticket;
  const SavBillingDecisionPage({super.key, required this.ticket});

  @override
  State<SavBillingDecisionPage> createState() => _SavBillingDecisionPageState();
}

class _SavBillingDecisionPageState extends State<SavBillingDecisionPage> {
  bool _isActionInProgress = false;

  // ✅ ADDED B2 Cloud Function URL constant
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';


  Future<void> _approveAndReturn({String? invoiceUrl}) async {
    setState(() => _isActionInProgress = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final billingStatus = invoiceUrl != null ? 'Facturé' : 'Sans Facture';

      await FirebaseFirestore.instance
          .collection('sav_tickets')
          .doc(widget.ticket.id)
          .update({
        'status': 'Approuvé - Prêt pour retour',
        'billingStatus': billingStatus,
        'invoiceUrl': invoiceUrl, // This will now store the B2 URL
      });

      await ActivityLogger.logActivity(
        message:
        "Le ticket SAV ${widget.ticket.savCode} a été approuvé pour retour ($billingStatus).",
        interventionId: widget.ticket.id,
        category: 'SAV',
        // ✅ ADDED invoiceUrl to logger if available
        invoiceUrl: invoiceUrl,
      );

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            content: Text('Ticket SAV approuvé pour retour.'),
            backgroundColor: Colors.green),
      );
      navigator.pop();

    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
      // Ensure loading state is reset on error
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
    // No finally needed as state is reset on success (via pop) or error
  }


  // ✅ --- START: ADDED B2 HELPER FUNCTIONS ---
  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response =
      await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('Failed to get B2 credentials: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error calling Cloud Function for B2 credentials: $e');
      return null;
    }
  }

  Future<String?> _uploadFileToB2(
      File file, Map<String, dynamic> b2Creds, String desiredFileName) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);

      // Determine mime type for PDF
      const mimeType = 'application/pdf';

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          // Use the desired filename, ensure it's properly encoded
          'X-Bz-File-Name': Uri.encodeComponent(desiredFileName),
          'Content-Type': mimeType,
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        // Use the filename returned by B2 for the download URL construction
        final b2FileName = body['fileName'] as String;
        final encodedPath = b2FileName.split('/').map(Uri.encodeComponent).join('/');
        return (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
      } else {
        debugPrint('Failed to upload invoice to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading invoice file to B2: $e');
      return null;
    }
  }
  // ✅ --- END: ADDED B2 HELPER FUNCTIONS ---


  // ✅ MODIFIED to upload invoice to B2
  Future<void> _pickAndUploadInvoice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isActionInProgress = true);
      final file = File(result.files.single.path!);
      // Define a structured B2 filename/path
      final b2FileName =
          'invoices/sav/${widget.ticket.savCode}-${DateTime.now().millisecondsSinceEpoch}.pdf';
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      try {
        // --- B2 Upload ---
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) {
          throw Exception('Impossible de récupérer les accès B2 pour la facture.');
        }

        final downloadUrl = await _uploadFileToB2(file, b2Credentials, b2FileName);

        if (downloadUrl == null) {
          throw Exception('Échec de l\'upload de la facture vers B2.');
        }
        // --- End B2 Upload ---

        // Pass the B2 URL to the approve function
        await _approveAndReturn(invoiceUrl: downloadUrl);

      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text('Erreur lors de l\'upload: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
        // Reset loading state on error
        if (mounted) {
          setState(() => _isActionInProgress = false);
        }
      }
      // No finally needed here, _approveAndReturn handles success state, catch handles error state.
    }
  }

  bool _isVideoUrl(String url) {
    final lowercaseUrl = url.toLowerCase();
    return lowercaseUrl.endsWith('.mp4') ||
        lowercaseUrl.endsWith('.mov') ||
        lowercaseUrl.endsWith('.avi') ||
        lowercaseUrl.endsWith('.mkv');
  }

  void _openMedia(String url) {
    if (_isVideoUrl(url)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(videoUrl: url),
        ),
      );
    } else {
      final List<String> imageLinks = widget.ticket.itemPhotoUrls
          .where((link) => !_isVideoUrl(link))
          .toList();
      if (imageLinks.isEmpty) return;

      final int initialIndex = imageLinks.indexOf(url);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImageGalleryPage(
            imageUrls: imageLinks,
            initialIndex: (initialIndex != -1) ? initialIndex : 0,
          ),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Décision SAV: ${widget.ticket.savCode}'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildTechnicianReportCard(),
            const SizedBox(height: 16),
            if (widget.ticket.itemPhotoUrls.isNotEmpty) ...[
              _buildMediaSection(),
              const SizedBox(height: 24),
            ],
            if (_isActionInProgress)
              const Center(child: CircularProgressIndicator())
            else
              _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Détails du Ticket',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.teal)),
            const Divider(height: 20),
            _buildInfoRow('Code SAV:', widget.ticket.savCode),
            _buildInfoRow('Client:', widget.ticket.clientName),
            _buildInfoRow('Produit:', widget.ticket.productName),
            _buildInfoRow('N° de Série:', widget.ticket.serialNumber),
            _buildInfoRow(
                'Date de création:',
                DateFormat('dd MMM yyyy', 'fr_FR')
                    .format(widget.ticket.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicianReportCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rapport du Technicien',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.teal)),
            const Divider(height: 20),
            Text(
              widget.ticket.technicianReport?.isNotEmpty ?? false
                  ? widget.ticket.technicianReport!
                  : 'Aucun rapport fourni.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: widget.ticket.technicianReport?.isNotEmpty ?? false
                    ? Colors.black87
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photos/Vidéos Jointes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.teal)),
            const Divider(height: 20),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: widget.ticket.itemPhotoUrls
                  .map((url) => _buildMediaThumbnail(url))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaThumbnail(String url) {
    bool isVideo = _isVideoUrl(url);

    return GestureDetector(
      onTap: () => _openMedia(url),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade200,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isVideo
              ? FutureBuilder<Uint8List?>(
            future: VideoThumbnail.thumbnailData(
              video: url, imageFormat: ImageFormat.JPEG, maxWidth: 80, quality: 25,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              if (snapshot.hasData && snapshot.data != null) {
                return Stack( fit: StackFit.expand, children: [
                  Image.memory(snapshot.data!, fit: BoxFit.cover),
                  const Center( child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30), ),
                ],
                );
              }
              return const Center(child: Icon(Icons.videocam, color: Colors.black54));
            },
          )
              : Image.network(
            url, fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      ),
    );
  }


  Widget _buildActionButtons() {
    return Column(
      children: [
        Text(
          'Approuver le ticket pour retour au client',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.thumb_up_alt_outlined),
                onPressed: _isActionInProgress ? null : () => _approveAndReturn(),
                label: const Text('Sans Facture'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade800,
                  side: BorderSide(color: Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isActionInProgress ? null : _pickAndUploadInvoice,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Avec Facture'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
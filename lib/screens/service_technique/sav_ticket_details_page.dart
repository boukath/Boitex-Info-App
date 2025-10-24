// lib/screens/service_technique/sav_ticket_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/sav_ticket.dart'; // Ensure this path is correct
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:intl/intl.dart';
// import 'package:multi_select_flutter/multi_select_flutter.dart'; // Removed if _AddPartsDialog is separate
import 'package:boitex_info_app/screens/service_technique/finalize_sav_return_page.dart';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';

class SavTicketDetailsPage extends StatefulWidget {
  final SavTicket ticket;
  const SavTicketDetailsPage({super.key, required this.ticket});

  @override
  State<SavTicketDetailsPage> createState() => _SavTicketDetailsPageState();
}

class _SavTicketDetailsPageState extends State<SavTicketDetailsPage> {
  late SavTicket _currentTicket;
  late final TextEditingController _reportController;
  bool _isUpdating = false;
  Map<String, int> _stockStatus = {};

  List<File> _technicianMediaToUpload = [];

  final List<String> _statusOptions = [
    'Nouveau',
    'En Diagnostic',
    'En Réparation',
    'Terminé',
    'Irréparable - Remplacement Demandé',
    'Approuvé - Prêt pour retour',
    'Retourné',
  ];

  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';


  @override
  void initState() {
    super.initState();
    _currentTicket = widget.ticket;
    _reportController =
        TextEditingController(text: _currentTicket.technicianReport ?? '');

    // Listen for real-time updates to the ticket
    FirebaseFirestore.instance
        .collection('sav_tickets')
        .doc(widget.ticket.id)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          // Update _currentTicket with the latest data from Firestore
          _currentTicket = SavTicket.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>);
          // Update the report controller only if the text differs
          if (_reportController.text != (_currentTicket.technicianReport ?? '')) {
            _reportController.text = _currentTicket.technicianReport ?? '';
          }
          // Re-check stock if broken parts exist
          if (_currentTicket.brokenParts.isNotEmpty) {
            _checkStockForParts(_currentTicket.brokenParts);
          }
        });
      }
    });

    // Initial stock check
    if (_currentTicket.brokenParts.isNotEmpty) {
      _checkStockForParts(_currentTicket.brokenParts);
    }
  }

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  // --- Helper Functions (Unchanged from your original) ---
  bool _isVideoUrl(String url) {
    final lowercaseUrl = url.toLowerCase();
    return lowercaseUrl.endsWith('.mp4') ||
        lowercaseUrl.endsWith('.mov') ||
        lowercaseUrl.endsWith('.avi') ||
        lowercaseUrl.endsWith('.mkv');
  }

  bool _isVideoPath(String filePath) {
    final p = filePath.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv');
  }

  Future<void> _checkStockForParts(List<BrokenPart> parts) async {
    final tempStatus = <String, int>{};
    for (var part in parts) {
      try {
        final productDoc = await FirebaseFirestore.instance
            .collection('produits')
            .doc(part.productId)
            .get();

        if (productDoc.exists) {
          final data = productDoc.data();
          if (data != null && data.containsKey('stock')) {
            final stockValue = data['stock'] as num?;
            tempStatus[part.productId] = stockValue?.toInt() ?? 0;
          } else {
            tempStatus[part.productId] = 0;
          }
        } else {
          tempStatus[part.productId] = 0;
        }
      } catch (e) {
        print('Error checking stock for ${part.productId}: $e');
        tempStatus[part.productId] = 0; // Assume 0 on error
      }
    }
    if (mounted) {
      setState(() {
        _stockStatus = tempStatus;
      });
    }
  }

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
      File file, Map<String, dynamic> b2Creds) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      // Construct filename for B2 using ticket code and timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(file.path);
      final b2FileName =
          'sav_tickets_media/${_currentTicket.savCode}/tech_upload_$timestamp$fileExtension';

      String? mimeType;
      final lcFileName = b2FileName.toLowerCase();
      if (lcFileName.endsWith('.jpg') || lcFileName.endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (lcFileName.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (lcFileName.endsWith('.mp4')) {
        mimeType = 'video/mp4';
      } else if (lcFileName.endsWith('.mov')) {
        mimeType = 'video/quicktime';
      } // Add more if needed

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(b2FileName), // Use constructed name
          'Content-Type': mimeType ?? 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final returnedFileName = body['fileName'] as String;
        // Correctly encode the path segments
        final encodedPath = returnedFileName.split('/').map(Uri.encodeComponent).join('/');
        return (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
      } else {
        debugPrint('Failed to upload SAV media to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading SAV media file to B2: $e');
      return null;
    }
  }

  Future<void> _pickTechnicianMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
    );
    if (result != null) {
      const maxFileSize = 50 * 1024 * 1024; // 50 MB
      final validFiles = result.files.where((file) {
        if (file.path != null && File(file.path!).existsSync()) {
          final fileLength = File(file.path!).lengthSync();
          if (fileLength <= maxFileSize) {
            return true;
          } else {
            print('File rejected (size > 50MB): ${file.name}');
            return false;
          }
        }
        return false;
      }).toList();

      final rejectedCount = result.files.length - validFiles.length;

      setState(() {
        _technicianMediaToUpload.addAll(validFiles.map((f) => File(f.path!)));
      });

      if (rejectedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$rejectedCount fichier(s) dépassent la limite de 50 Mo.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _updateTicket(String newStatus) async {
    setState(() => _isUpdating = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      List<String> newMediaUrls = [];
      if (_technicianMediaToUpload.isNotEmpty) {
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) {
          throw Exception('Impossible de récupérer les accès B2.');
        }

        // Upload files concurrently
        final uploadFutures = _technicianMediaToUpload.map((file) =>
            _uploadFileToB2(file, b2Credentials)
        ).toList();

        final results = await Future.wait(uploadFutures);
        newMediaUrls = results.whereType<String>().toList(); // Filter out nulls (failed uploads)

        if (newMediaUrls.length != _technicianMediaToUpload.length && mounted) {
          // Inform user if some uploads failed
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Certains médias n\'ont pas pu être uploadés.'), backgroundColor: Colors.orange),
          );
        }
      }

      // Combine existing URLs with newly uploaded URLs
      final combinedMediaUrls = List<String>.from(_currentTicket.itemPhotoUrls)..addAll(newMediaUrls);

      final updateData = {
        'status': newStatus,
        'technicianReport': _reportController.text.trim(),
        'brokenParts': _currentTicket.brokenParts.map((p) => p.toJson()).toList(),
        'itemPhotoUrls': combinedMediaUrls, // Update with combined list
      };

      await FirebaseFirestore.instance
          .collection('sav_tickets')
          .doc(_currentTicket.id)
          .update(updateData);

      await ActivityLogger.logActivity(
        message: "Statut SAV ${_currentTicket.savCode} -> '$newStatus'. ${newMediaUrls.isNotEmpty ? '${newMediaUrls.length} média(s) ajouté(s).' : ''}",
        interventionId: _currentTicket.id, // Using ticket ID as reference
        category: 'SAV',
      );

      if (mounted) {
        setState(() {
          _technicianMediaToUpload.clear(); // Clear the list after successful processing
        });
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Ticket mis à jour.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _showAddPartsDialog() async {
    final selectedProducts = await showDialog<List<DocumentSnapshot>>(
      context: context,
      builder: (context) => _AddPartsDialog(
          initialSelected: _currentTicket.brokenParts.map((p) => p.productId).toList()),
    );

    if (selectedProducts != null) {
      // Map selected products to BrokenPart objects
      final newParts = selectedProducts.map((doc) {
        final data = doc.data() as Map<String, dynamic>?; // Cast data
        return BrokenPart(
          productId: doc.id,
          productName: data?['nom'] as String? ?? 'Nom Inconnu', // Safe access
          status: 'À Remplacer', // Default status for newly added parts
        );
      }).toList();

      // Update the state with the new list of parts
      // This part only updates the local state, Firestore update happens in _updateTicket
      setState(() {
        _currentTicket = SavTicket(
          id: _currentTicket.id,
          serviceType: _currentTicket.serviceType,
          savCode: _currentTicket.savCode,
          clientId: _currentTicket.clientId,
          clientName: _currentTicket.clientName,
          storeId: _currentTicket.storeId,
          storeName: _currentTicket.storeName,
          pickupDate: _currentTicket.pickupDate,
          pickupTechnicianIds: _currentTicket.pickupTechnicianIds,
          pickupTechnicianNames: _currentTicket.pickupTechnicianNames,
          productName: _currentTicket.productName,
          serialNumber: _currentTicket.serialNumber,
          problemDescription: _currentTicket.problemDescription,
          itemPhotoUrls: _currentTicket.itemPhotoUrls,
          storeManagerName: _currentTicket.storeManagerName,
          storeManagerSignatureUrl: _currentTicket.storeManagerSignatureUrl,
          status: _currentTicket.status, // Keep current status
          technicianReport: _reportController.text, // Use current report text
          createdBy: _currentTicket.createdBy,
          createdAt: _currentTicket.createdAt,
          brokenParts: newParts, // <- Use the new list here
          // Keep existing return fields (important!)
          billingStatus: _currentTicket.billingStatus,
          invoiceUrl: _currentTicket.invoiceUrl,
          returnClientName: _currentTicket.returnClientName,
          returnSignatureUrl: _currentTicket.returnSignatureUrl,
          returnPhotoUrl: _currentTicket.returnPhotoUrl,
          // NOTE: returnClientPhone and returnClientEmail are NOT included
          // because they are not in the SavTicket model provided
        );
      });


      // Refresh stock status for the new parts list
      _checkStockForParts(newParts);

      // Save the ticket changes (including the updated parts list) to Firestore
      // Pass the current status so it doesn't revert
      _updateTicket(_currentTicket.status);
    }
  }

  // Modified _openMedia to handle the single return media URL correctly
  void _openMedia(String url) {
    // Check if the URL matches the specific returnPhotoUrl
    if (url == _currentTicket.returnPhotoUrl) {
      if (_isVideoUrl(url)) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => VideoPlayerPage(videoUrl: url),
        ));
      } else {
        // It's the return photo, show it in the gallery by itself
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => ImageGalleryPage(imageUrls: [url], initialIndex: 0),
        ));
      }
    }
    // Check if the URL is part of the initial item photos/videos
    else if (_currentTicket.itemPhotoUrls.contains(url)) {
      if (_isVideoUrl(url)) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => VideoPlayerPage(videoUrl: url),
        ));
      } else {
        // It's an initial image, show it within the gallery of initial images
        final imageLinks = _currentTicket.itemPhotoUrls.where((link) => !_isVideoUrl(link)).toList();
        final initialIndex = imageLinks.indexOf(url);
        if (imageLinks.isNotEmpty) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ImageGalleryPage(
                imageUrls: imageLinks,
                initialIndex: (initialIndex != -1) ? initialIndex : 0),
          ));
        }
      }
    }
    // If the URL doesn't match return or initial photos, do nothing (or log error)
    else {
      print("Error: URL $url not found in ticket media.");
    }
  }
  // --- END Helper Functions ---


  // ✅ --- START: ADDED WIDGET TO SHOW RETURN DETAILS ---
  Widget _buildReturnDetailsCard() {
    // Only build this card if the status is 'Retourné' and relevant data exists
    if (_currentTicket.status != 'Retourné' || _currentTicket.returnClientName == null) {
      return const SizedBox.shrink(); // Return empty space if not applicable
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: const EdgeInsets.only(top: 16.0), // Space above the card
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preuve de Retour Client',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.green), // Distinct color
            ),
            const Divider(height: 20),

            // Display return information using the existing helper row widget
            _buildInfoRow('Client (Réception):', _currentTicket.returnClientName ?? 'N/A'),

            // NOTE: Phone and Email are NOT displayed as they are not in the model

            const SizedBox(height: 16),

            // --- Display Signature ---
            const Text('Signature Client:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_currentTicket.returnSignatureUrl != null)
              Container(
                height: 100, // Fixed height for signature display
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade100, // Light background
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _currentTicket.returnSignatureUrl!,
                    fit: BoxFit.contain, // Ensure signature fits
                    loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.error_outline, color: Colors.red)),
                  ),
                ),
              )
            else
              const Text('Signature non disponible.', style: TextStyle(color: Colors.grey)),

            const SizedBox(height: 16),

            // --- Display Media Proof ---
            const Text('Photo/Vidéo de Preuve:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_currentTicket.returnPhotoUrl != null)
            // Reuse the existing thumbnail widget for consistency
              _buildMediaThumbnail(url: _currentTicket.returnPhotoUrl!)
            else
              const Text('Média non disponible.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
  // ✅ --- END: ADDED WIDGET ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTicket.savCode),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView( // Makes the whole page scrollable
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(), // Basic ticket info
            const SizedBox(height: 16),

            // Section for INITIAL photos/videos added during ticket creation
            if (_currentTicket.itemPhotoUrls.isNotEmpty) ...[
              _buildMediaSection(), // Shows existing media from itemPhotoUrls
              const SizedBox(height: 16),
            ],

            _buildTechnicianSection(), // Section for technician report, status, parts, and adding NEW media

            // ✅ --- THIS IS THE ADDED CALL ---
            _buildReturnDetailsCard(), // Display the return proof card if applicable
            // ✅ --- END OF ADDED CALL ---

            const SizedBox(height: 24), // Spacing before the finalize button

            // Button to navigate to the finalize return page (only if status allows)
            if (_currentTicket.status == 'Approuvé - Prêt pour retour')
              Center( // Center the button
                child: SizedBox(
                  width: double.infinity, // Make button take full width
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.inventory_outlined),
                    label: const Text('Finaliser le Retour'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FinalizeSavReturnPage(ticket: _currentTicket),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Widget Building Methods (Unchanged from your original) ---
  Widget _buildInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations sur le Ticket', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.orange)),
            const Divider(height: 20),
            _buildInfoRow('Client:', _currentTicket.clientName),
            _buildInfoRow('Magasin:', _currentTicket.storeName ?? 'N/A'),
            _buildInfoRow('Produit:', _currentTicket.productName),
            _buildInfoRow('N° de Série:', _currentTicket.serialNumber),
            const SizedBox(height: 8),
            const Text('Description du Problème:', style: TextStyle(fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(_currentTicket.problemDescription, style: const TextStyle(height: 1.4)),
            ),
            const Divider(height: 20),
            _buildInfoRow('Statut Actuel:', _currentTicket.status, isStatus: true),
            if (_currentTicket.billingStatus != null) _buildInfoRow('Facturation:', _currentTicket.billingStatus!),
            _buildInfoRow('Date de création:', DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(_currentTicket.createdAt)),
            _buildInfoRow('Créé par:', _currentTicket.createdBy), // Added Created By for context
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    // Filter out the returnPhotoUrl if it exists in itemPhotoUrls (shouldn't happen, but defensive)
    final initialMedia = _currentTicket.itemPhotoUrls
        .where((url) => url != _currentTicket.returnPhotoUrl)
        .toList();

    if (initialMedia.isEmpty) {
      // Return an empty SizedBox if there's no initial media to show
      return const SizedBox.shrink();
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photos/Vidéos (Initiales)', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.orange)),
            const Divider(height: 20),
            Wrap( // Use Wrap for layout
              spacing: 8.0, // Horizontal space
              runSpacing: 8.0, // Vertical space
              children: initialMedia.map((url) => _buildMediaThumbnail(url: url)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaThumbnail({String? url, File? file}) {
    bool isVideo = (url != null && _isVideoUrl(url)) || (file != null && _isVideoPath(file.path));
    Widget mediaContent;

    // Build content based on whether it's a local file or a network URL
    if (file != null) { // --- Local File Preview ---
      mediaContent = isVideo
          ? FutureBuilder<Uint8List?>( // Thumbnail for local video
        future: VideoThumbnail.thumbnailData(video: file.path, imageFormat: ImageFormat.JPEG, maxWidth: 80, quality: 25),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          return snapshot.hasData && snapshot.data != null
              ? Stack(fit: StackFit.expand, children: [ Image.memory(snapshot.data!, fit: BoxFit.cover), const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30))])
              : const Center(child: Icon(Icons.videocam_off_outlined, color: Colors.grey)); // Placeholder if thumbnail fails
        },
      )
          : Image.file(file, fit: BoxFit.cover); // Direct display for local image
    } else if (url != null) { // --- Network Media Preview ---
      mediaContent = isVideo
          ? FutureBuilder<Uint8List?>( // Thumbnail for network video
        future: VideoThumbnail.thumbnailData(video: url, imageFormat: ImageFormat.JPEG, maxWidth: 80, quality: 25, headers: {}), // Added empty headers map
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          return snapshot.hasData && snapshot.data != null
              ? Stack(fit: StackFit.expand, children: [ Image.memory(snapshot.data!, fit: BoxFit.cover), const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30))])
              : const Center(child: Icon(Icons.videocam_off_outlined, color: Colors.grey)); // Placeholder
        },
      )
          : Image.network( // Direct display for network image
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
      );
    } else { // Should not happen if called correctly
      mediaContent = const Center(child: Icon(Icons.error_outline, color: Colors.red));
    }

    // Wrap content in GestureDetector for opening media, container for styling
    return GestureDetector(
      // Ensure onTap uses the non-null url if available
      onTap: url != null ? () => _openMedia(url) : null,
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade100, // Background color
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: mediaContent,
        ),
      ),
    );
  }

  Widget _buildTechnicianSection() {
    bool isReadOnly = _currentTicket.status == 'Retourné'; // Simplified read-only check

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Make children stretch
          children: [
            Text('Section Technicien', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.orange)),
            const Divider(height: 20),

            // Status Dropdown
            DropdownButtonFormField<String>(
              value: _statusOptions.contains(_currentTicket.status) ? _currentTicket.status : null,
              items: _statusOptions.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
              onChanged: isReadOnly ? null : (value) { // Disable if read-only
                if (value != null && value != _currentTicket.status) {
                  _updateTicket(value); // Update status (and potentially other fields)
                }
              },
              decoration: InputDecoration(
                labelText: 'Changer le statut',
                border: const OutlineInputBorder(),
                filled: isReadOnly, // Visually indicate if disabled
                fillColor: isReadOnly ? Colors.grey[200] : null,
              ),
            ),
            const SizedBox(height: 16),

            // Technician Report Text Field
            TextFormField(
              controller: _reportController,
              readOnly: isReadOnly,
              decoration: InputDecoration(
                labelText: 'Rapport du technicien / Diagnostic',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                filled: isReadOnly,
                fillColor: isReadOnly ? Colors.grey[200] : null,
              ),
              maxLines: 5,
              minLines: 3, // Ensure minimum height
            ),
            const SizedBox(height: 16),

            // --- Technician Media Upload UI ---
            if (!isReadOnly) ...[ // Only show if not read-only
              OutlinedButton.icon(
                onPressed: _pickTechnicianMedia,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Ajouter Photos/Vidéos (Technicien)'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                  foregroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 8),

              // Preview for newly added (but not yet uploaded) media
              if (_technicianMediaToUpload.isNotEmpty)
                Container(
                  height: 100,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _technicianMediaToUpload.length,
                    itemBuilder: (context, index) {
                      final file = _technicianMediaToUpload[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            _buildMediaThumbnail(file: file), // Build preview
                            // Remove Button overlay
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _technicianMediaToUpload.removeAt(index);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
            // --- END Technician Media Upload UI ---

            // Button to Add/Edit Broken Parts
            if (!isReadOnly) ... [
              OutlinedButton.icon(
                onPressed: _showAddPartsDialog,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Ajouter/Modifier Pièces Défectueuses'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                  foregroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Display List of Broken Parts
            if (_currentTicket.brokenParts.isNotEmpty) ...[
              const Text('Pièces Défectueuses:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true, // Important inside SingleChildScrollView
                physics: const NeverScrollableScrollPhysics(), // Disable internal scrolling
                itemCount: _currentTicket.brokenParts.length,
                itemBuilder: (context, index) {
                  final part = _currentTicket.brokenParts[index];
                  final stock = _stockStatus[part.productId];
                  final stockText = stock == null ? 'Chargement...' : stock.toString();
                  final stockColor = stock == null ? Colors.grey : (stock > 0 ? Colors.green : Colors.red);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true, // Make list items more compact
                    leading: Icon(Icons.build_circle_outlined, color: Colors.grey[600]),
                    title: Text(part.productName),
                    trailing: Text('Stock: $stockText', style: TextStyle(color: stockColor, fontWeight: FontWeight.bold)),
                  );
                },
              ),
              const SizedBox(height: 16), // Spacing after parts list
            ],

            // Save Button (only if not read-only)
            if (!isReadOnly)
              ElevatedButton.icon(
                onPressed: _isUpdating ? null : () => _updateTicket(_currentTicket.status), // Pass current status
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                icon: _isUpdating ? Container() : const Icon(Icons.save_outlined), // Hide icon when loading
                label: _isUpdating
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('Enregistrer Modifications'), // Updated text
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    // Determine color for status
    Color valueColor = Colors.black87;
    FontWeight valueWeight = FontWeight.normal;
    if (isStatus) {
      valueWeight = FontWeight.bold;
      switch (value) {
        case 'Nouveau': valueColor = Colors.blue.shade700; break;
        case 'En Diagnostic': valueColor = Colors.orange.shade700; break;
        case 'En Réparation': valueColor = Colors.deepOrange.shade700; break;
        case 'Terminé': valueColor = Colors.green.shade700; break;
        case 'Irréparable - Remplacement Demandé': valueColor = Colors.red.shade700; break;
        case 'Approuvé - Prêt pour retour': valueColor = Colors.purple.shade700; break;
        case 'Retourné': valueColor = Colors.grey.shade700; break;
        default: valueColor = Colors.black87;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Expanded(child: Text(value, style: TextStyle(color: valueColor, fontWeight: valueWeight))),
        ],
      ),
    );
  }
// --- END Widget Building Methods ---
}


// --- Add Parts Dialog (Separate Widget - Unchanged from your original) ---
class _AddPartsDialog extends StatefulWidget {
  final List<String> initialSelected;
  const _AddPartsDialog({required this.initialSelected});

  @override
  _AddPartsDialogState createState() => _AddPartsDialogState();
}

class _AddPartsDialogState extends State<_AddPartsDialog> {
  List<DocumentSnapshot> _allProducts = [];
  List<DocumentSnapshot> _productsForCategory = [];
  String? _selectedCategory;
  bool _isLoadingProducts = true;
  late List<DocumentSnapshot> _selectedParts;
  String _searchQuery = ''; // For filtering products within a category

  @override
  void initState() {
    super.initState();
    _selectedParts = []; // Initialize empty
    _fetchAllProducts();
  }

  Future<void> _fetchAllProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('produits')
          .orderBy('categorie')
          .orderBy('nom')
          .get();
      if (mounted) {
        setState(() {
          _allProducts = snapshot.docs;
          // Pre-select items based on initialSelected
          _selectedParts.addAll(_allProducts.where((p) => widget.initialSelected.contains(p.id)));
          _isLoadingProducts = false;
          // If a category was selected before reloading, re-apply filter
          if (_selectedCategory != null) {
            _filterProductsByCategory(_selectedCategory!);
          }
        });
      }
    } catch (e) {
      print("Error fetching products: $e");
      if (mounted) {
        setState(() => _isLoadingProducts = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur chargement produits: ${e.toString()}'))
        );
      }
    }
  }

  void _filterProductsByCategory(String category) {
    final query = _searchQuery.toLowerCase();
    setState(() {
      _selectedCategory = category;
      _productsForCategory = _allProducts.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        final bool categoryMatch = data?['categorie'] == category;
        if (!categoryMatch) return false;
        // Check search query against name or reference
        final name = (data?['nom'] as String? ?? '').toLowerCase();
        final reference = (data?['reference'] as String? ?? '').toLowerCase();
        return name.contains(query) || reference.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get unique categories and sort them
    final categories = _allProducts
        .map((doc) => (doc.data() as Map<String, dynamic>?)?['categorie'] as String?)
        .where((c) => c != null && c.isNotEmpty) // Filter out null/empty
        .toSet()
        .toList()
      ..sort();

    return AlertDialog(
      title: const Text('Ajouter/Modifier Pièces'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0), // Adjust padding
      content: SizedBox(
        width: double.maxFinite, // Use max width
        height: MediaQuery.of(context).size.height * 0.7, // Increase height
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category Dropdown
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text('Sélectionner une catégorie'),
              isExpanded: true,
              onChanged: (value) {
                if (value != null) {
                  _searchQuery = ''; // Reset search on category change
                  _filterProductsByCategory(value);
                }
              },
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c!))).toList(),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),

            // Search Field (Visible only when category selected)
            if (_selectedCategory != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Filtrer par nom ou référence',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                    _filterProductsByCategory(_selectedCategory!); // Re-filter
                  },
                ),
              ),


            // Product List
            Expanded(
              child: _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedCategory == null
                  ? const Center(child: Text('Sélectionnez une catégorie.'))
                  : _productsForCategory.isEmpty
                  ? Center(child: Text(_searchQuery.isEmpty ? 'Aucun produit trouvé.' : 'Aucun produit correspondant au filtre.'))
                  : ListView.builder( // Use ListView for scrollable list
                itemCount: _productsForCategory.length,
                itemBuilder: (context, index) {
                  final product = _productsForCategory[index];
                  final data = product.data() as Map<String, dynamic>?;
                  final productName = data?['nom'] ?? 'Nom Inconnu';
                  final reference = data?['reference'] ?? '';
                  final isSelected = _selectedParts.any((p) => p.id == product.id);

                  return CheckboxListTile(
                    title: Text(productName),
                    subtitle: reference.isNotEmpty ? Text(reference) : null,
                    value: isSelected,
                    onChanged: (bool? selected) {
                      setState(() {
                        if (selected == true) {
                          // Add only if not already present
                          if (!_selectedParts.any((p) => p.id == product.id)) {
                            _selectedParts.add(product);
                          }
                        } else {
                          _selectedParts.removeWhere((p) => p.id == product.id);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading, // Checkbox on left
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('ANNULER'),
          onPressed: () => Navigator.of(context).pop(), // Pop without returning data
        ),
        ElevatedButton(
          child: const Text('CONFIRMER'),
          onPressed: () => Navigator.of(context).pop(_selectedParts), // Pop returning selected parts
        ),
      ],
    );
  }
}
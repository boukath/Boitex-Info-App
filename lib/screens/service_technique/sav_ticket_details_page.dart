// lib/screens/service_technique/sav_ticket_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:boitex_info_app/screens/service_technique/finalize_sav_return_page.dart';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'dart:io';                       // ✅ ADDED for File
import 'package:http/http.dart' as http; // ✅ ADDED for B2
import 'package:crypto/crypto.dart';      // ✅ ADDED for B2
import 'dart:convert';                   // ✅ ADDED for B2
import 'package:path/path.dart' as path; // ✅ ADDED for basename
import 'package:file_picker/file_picker.dart'; // ✅ ADDED for file picking

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

  // ✅ ADDED: State variable for new technician media uploads
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

  // ✅ ADDED B2 Cloud Function URL constant
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';


  @override
  void initState() {
    super.initState();
    _currentTicket = widget.ticket;
    _reportController =
        TextEditingController(text: _currentTicket.technicianReport ?? '');

    FirebaseFirestore.instance
        .collection('sav_tickets')
        .doc(widget.ticket.id)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          _currentTicket = SavTicket.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>);
          if (_reportController.text != (_currentTicket.technicianReport ?? '')) {
            _reportController.text = _currentTicket.technicianReport ?? '';
          }
          if (_currentTicket.brokenParts.isNotEmpty) {
            _checkStockForParts(_currentTicket.brokenParts);
          }
        });
      }
    });

    if (_currentTicket.brokenParts.isNotEmpty) {
      _checkStockForParts(_currentTicket.brokenParts);
    }
  }

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  bool _isVideoUrl(String url) {
    final lowercaseUrl = url.toLowerCase();
    return lowercaseUrl.endsWith('.mp4') ||
        lowercaseUrl.endsWith('.mov') ||
        lowercaseUrl.endsWith('.avi') ||
        lowercaseUrl.endsWith('.mkv');
  }

  // ✅ ADDED: Helper to check local file path too
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
        tempStatus[part.productId] = 0;
      }
    }
    if (mounted) {
      setState(() {
        _stockStatus = tempStatus;
      });
    }
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
      debugPrint('Error calling Cloud Function: $e');
      return null;
    }
  }

  Future<String?> _uploadFileToB2(
      File file, Map<String, dynamic> b2Creds) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final fileName = path.basename(file.path);

      String? mimeType; // Basic mime type detection
      if (fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (fileName.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (fileName.toLowerCase().endsWith('.mp4')) {
        mimeType = 'video/mp4';
      } else if (fileName.toLowerCase().endsWith('.mov')) {
        mimeType = 'video/quicktime';
      }
      // Add more as needed...

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': mimeType ?? 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final encodedPath = (body['fileName'] as String)
            .split('/')
            .map(Uri.encodeComponent)
            .join('/');
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
  // ✅ --- END: ADDED B2 HELPER FUNCTIONS ---


  // ✅ ADDED: Function to pick technician media
  Future<void> _pickTechnicianMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
    );
    if (result != null) {
      const maxFileSize = 50 * 1024 * 1024; // 50 MB limit
      final validFiles = result.files.where((file) {
        if (file.path != null && File(file.path!).existsSync()) {
          return File(file.path!).lengthSync() <= maxFileSize;
        }
        return false;
      }).toList();

      final rejectedCount = result.files.length - validFiles.length;

      setState(() {
        // Add to existing list, don't replace
        _technicianMediaToUpload.addAll(validFiles.map((f) => File(f.path!)).toList());
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


  // ✅ MODIFIED to handle technician media upload
  Future<void> _updateTicket(String newStatus) async {
    setState(() => _isUpdating = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Capture context

    try {
      // --- Upload NEW Technician Media ---
      List<String> newMediaUrls = [];
      if (_technicianMediaToUpload.isNotEmpty) {
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) {
          throw Exception('Impossible de récupérer les accès B2 pour les médias technicien.');
        }
        for (var file in _technicianMediaToUpload) {
          final downloadUrl = await _uploadFileToB2(file, b2Credentials);
          if (downloadUrl != null) {
            newMediaUrls.add(downloadUrl);
          } else {
            debugPrint('Skipping technician media file due to B2 upload failure: ${path.basename(file.path)}');
            // Optionally inform user about specific file failures
          }
        }
      }

      // --- Prepare Update Data ---
      // Combine existing URLs with newly uploaded URLs
      final combinedMediaUrls = List<String>.from(_currentTicket.itemPhotoUrls)..addAll(newMediaUrls);

      final updateData = {
        'status': newStatus,
        'technicianReport': _reportController.text,
        'brokenParts': _currentTicket.brokenParts.map((p) => p.toJson()).toList(),
        'itemPhotoUrls': combinedMediaUrls, // Save combined list
      };


      // --- Update Firestore ---
      await FirebaseFirestore.instance
          .collection('sav_tickets')
          .doc(_currentTicket.id)
          .update(updateData);

      // --- Log Activity ---
      await ActivityLogger.logActivity(
        message:
        "Le statut du ticket SAV ${_currentTicket.savCode} a été mis à jour à '$newStatus'. ${newMediaUrls.isNotEmpty ? '${newMediaUrls.length} média(s) ajouté(s).' : ''}",
        interventionId: _currentTicket.id,
        category: 'SAV',
      );

      // --- Clear pending uploads and show success ---
      if (mounted) {
        setState(() {
          _technicianMediaToUpload.clear(); // Clear list after successful upload
        });
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text('Ticket mis à jour avec succès.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red),
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
          initialSelected:
          _currentTicket.brokenParts.map((p) => p.productId).toList()),
    );

    if (selectedProducts != null) {
      final newParts = selectedProducts.map((doc) {
        return BrokenPart(
          productId: doc.id,
          productName: doc['nom'] as String,
          status: 'À Remplacer',
        );
      }).toList();

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
          status: _currentTicket.status,
          technicianReport: _reportController.text,
          createdBy: _currentTicket.createdBy,
          createdAt: _currentTicket.createdAt,
          brokenParts: newParts, // Use the NEW list
          billingStatus: _currentTicket.billingStatus,
          invoiceUrl: _currentTicket.invoiceUrl,
          returnClientName: _currentTicket.returnClientName,
          returnSignatureUrl: _currentTicket.returnSignatureUrl,
          returnPhotoUrl: _currentTicket.returnPhotoUrl,
        );
      });
      _checkStockForParts(newParts);
      _updateTicket(_currentTicket.status); // Save updated parts
    }
  }

  void _openMedia(String url) {
    if (_isVideoUrl(url)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(videoUrl: url),
        ),
      );
    } else {
      final List<String> imageLinks = _currentTicket.itemPhotoUrls
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
        title: Text(_currentTicket.savCode),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            // Display INITIAL media (from ticket creation)
            if (_currentTicket.itemPhotoUrls.isNotEmpty) ...[
              _buildMediaSection(), // This shows existing media
              const SizedBox(height: 16),
            ],
            _buildTechnicianSection(), // This contains the add media button
            const SizedBox(height: 24),
            if (_currentTicket.status == 'Approuvé - Prêt pour retour')
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.inventory_outlined),
                    label: const Text('Finaliser le Retour'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              FinalizeSavReturnPage(ticket: _currentTicket),
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

  Widget _buildInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations sur le Ticket',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.orange)),
            const Divider(height: 20),
            _buildInfoRow('Client:', _currentTicket.clientName),
            _buildInfoRow('Magasin:', _currentTicket.storeName ?? 'N/A'),
            _buildInfoRow('Produit:', _currentTicket.productName),
            _buildInfoRow('N° de Série:', _currentTicket.serialNumber),
            const SizedBox(height: 8),
            const Text('Description du Problème:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(_currentTicket.problemDescription,
                  style: const TextStyle(height: 1.4)),
            ),
            const Divider(height: 20),
            _buildInfoRow('Statut Actuel:', _currentTicket.status,
                isStatus: true),
            if (_currentTicket.billingStatus != null)
              _buildInfoRow('Facturation:', _currentTicket.billingStatus!),
            _buildInfoRow(
                'Date de création:',
                DateFormat('dd MMM yyyy, HH:mm', 'fr_FR')
                    .format(_currentTicket.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photos/Vidéos (Initiales)', // Clarify these are the initial ones
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.orange)),
            const Divider(height: 20),
            if (_currentTicket.itemPhotoUrls.isEmpty)
              const Text('Aucun fichier joint initialement.', style: TextStyle(color: Colors.grey))
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _currentTicket.itemPhotoUrls
                    .map((url) => _buildMediaThumbnail(url: url)) // Pass url named parameter
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  // Modified to accept named 'url' or 'file' parameter
  Widget _buildMediaThumbnail({String? url, File? file}) {
    bool isVideo = (url != null && _isVideoUrl(url)) || (file != null && _isVideoPath(file.path));
    Widget mediaContent;

    if (file != null) {
      // Local file preview
      if (isVideo) {
        mediaContent = FutureBuilder<Uint8List?>(
          future: VideoThumbnail.thumbnailData(video: file.path, imageFormat: ImageFormat.JPEG, maxWidth: 80, quality: 25),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            if (snapshot.hasData && snapshot.data != null) {
              return Stack(fit: StackFit.expand, children: [
                Image.memory(snapshot.data!, fit: BoxFit.cover),
                const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30)),
              ]);
            }
            return const Center(child: Icon(Icons.videocam, color: Colors.black54));
          },
        );
      } else {
        mediaContent = Image.file(file, fit: BoxFit.cover);
      }
    } else if (url != null) {
      // Network media preview (existing)
      if (isVideo) {
        mediaContent = FutureBuilder<Uint8List?>(
          future: VideoThumbnail.thumbnailData(video: url, imageFormat: ImageFormat.JPEG, maxWidth: 80, quality: 25),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            if (snapshot.hasData && snapshot.data != null) {
              return Stack(fit: StackFit.expand, children: [
                Image.memory(snapshot.data!, fit: BoxFit.cover),
                const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30)),
              ]);
            }
            return const Center(child: Icon(Icons.videocam, color: Colors.black54));
          },
        );
      } else {
        mediaContent = Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
        );
      }
    } else {
      mediaContent = const Icon(Icons.error, color: Colors.red); // Should not happen
    }


    return GestureDetector(
      onTap: url != null ? () => _openMedia(url) : null, // Only allow opening existing media
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
          child: mediaContent, // Display the determined content
        ),
      ),
    );
  }


  Widget _buildTechnicianSection() {
    bool isReadOnly = _currentTicket.status == 'Terminé' ||
        _currentTicket.status == 'Approuvé - Prêt pour retour' ||
        _currentTicket.status == 'Retourné';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Section Technicien',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.orange)),
            const Divider(height: 20),
            DropdownButtonFormField<String>(
              value: _statusOptions.contains(_currentTicket.status) ? _currentTicket.status : null,
              items: _statusOptions
                  .map((status) =>
                  DropdownMenuItem(value: status, child: Text(status)))
                  .toList(),
              onChanged: isReadOnly
                  ? null
                  : (value) {
                if (value != null && value != _currentTicket.status) {
                  // NOTE: Status update now happens within _updateTicket
                  // Consider if you want separate status updates or only with report/media save
                  _updateTicket(value); // Example: Update status immediately
                }
              },
              decoration: const InputDecoration(
                labelText: 'Changer le statut',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reportController,
              readOnly: isReadOnly,
              decoration: const InputDecoration(
                labelText: 'Rapport du technicien / Diagnostic',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),

            // --- ✅ START: Technician Media Upload UI ---
            if (!isReadOnly) ...[
              OutlinedButton.icon(
                onPressed: _pickTechnicianMedia,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Ajouter Photos/Vidéos (Technicien)'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                  foregroundColor: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              // Preview for newly added technician media
              if (_technicianMediaToUpload.isNotEmpty)
                Container(
                  height: 100, // Adjust height as needed
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _technicianMediaToUpload.length,
                    itemBuilder: (context, index) {
                      final file = _technicianMediaToUpload[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack( // Use Stack to add remove button
                          alignment: Alignment.topRight,
                          children: [
                            _buildMediaThumbnail(file: file), // Pass file named parameter
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                setState(() {
                                  _technicianMediaToUpload.removeAt(index);
                                });
                              },
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
            // --- ✅ END: Technician Media Upload UI ---


            if (!isReadOnly)
              OutlinedButton.icon(
                onPressed: _showAddPartsDialog,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Ajouter/Modifier Pièces Défectueuses'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                  foregroundColor: Colors.orange,
                ),
              ),
            const SizedBox(height: 16),
            if (_currentTicket.brokenParts.isNotEmpty) ...[
              const Text('Pièces Défectueuses:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _currentTicket.brokenParts.length,
                  itemBuilder: (context, index){
                    final part = _currentTicket.brokenParts[index];
                    final stock = _stockStatus[part.productId];
                    final stockText = stock == null ? '...' : stock.toString();
                    final stockColor = stock == null ? Colors.grey : (stock > 0 ? Colors.green : Colors.red);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.build_circle_outlined, color: Colors.grey[600]),
                      title: Text(part.productName),
                      trailing: Text( 'Stock: $stockText',
                        style: TextStyle(color: stockColor, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
              ),
            ],
            const SizedBox(height: 24),
            // "Save" button now saves report, parts (implicitly via dialog), AND new media
            if (!isReadOnly)
              ElevatedButton.icon(
                // Use current status when saving report/media
                onPressed: _isUpdating ? null : () => _updateTicket(_currentTicket.status),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: _isUpdating ? Container() : const Icon(Icons.save_outlined),
                label: _isUpdating
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                // Clarify what is being saved
                    : const Text('Enregistrer Rapport & Médias'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    Color statusColor = Colors.black87;
    if (isStatus) {
      switch (value) {
        case 'Nouveau': statusColor = Colors.blue; break;
        case 'En Diagnostic':
        case 'En Réparation': statusColor = Colors.orange; break;
        case 'Terminé': statusColor = Colors.green; break;
        case 'Irréparable - Remplacement Demandé': statusColor = Colors.red; break;
        case 'Approuvé - Prêt pour retour': statusColor = Colors.purple; break;
        case 'Retourné': statusColor = Colors.grey; break;
        default: statusColor = Colors.black87;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Expanded(
              child: Text(value,
                style: TextStyle(
                    color: statusColor,
                    fontWeight: isStatus ? FontWeight.bold : FontWeight.normal),
              )),
        ],
      ),
    );
  }
}

// --- Add Parts Dialog ---
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

  @override
  void initState() {
    super.initState();
    _selectedParts = [];
    _fetchAllProducts();
  }

  Future<void> _fetchAllProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('produits')
          .orderBy('categorie').orderBy('nom')
          .get();
      if (mounted) {
        setState(() {
          _allProducts = snapshot.docs;
          _selectedParts
              .addAll(_allProducts.where((p) => widget.initialSelected.contains(p.id)));
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur chargement produits: ${e.toString()}'))
        );
      }
    }
  }

  void _filterProductsByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _productsForCategory =
          _allProducts.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data?['categorie'] == category;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories =
    _allProducts.map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return data?['categorie'] as String?;
    }).where((c) => c != null).toSet().toList()..sort();


    return AlertDialog(
      title: const Text('Ajouter/Modifier Pièces'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text('Sélectionner une catégorie'),
              isExpanded: true,
              onChanged: (value) {
                if (value != null) _filterProductsByCategory(value);
              },
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c!)))
                  .toList(),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedCategory == null
                  ? const Center(child: Text('Sélectionnez une catégorie pour voir les produits.'))
                  : _productsForCategory.isEmpty
                  ? const Center(child: Text('Aucun produit trouvé dans cette catégorie.'))
                  : ListView.builder(
                itemCount: _productsForCategory.length,
                itemBuilder: (context, index) {
                  final product = _productsForCategory[index];
                  final productName = (product.data() as Map<String, dynamic>?)?['nom'] ?? 'Nom Inconnu';
                  final isSelected =
                  _selectedParts.any((p) => p.id == product.id);
                  return CheckboxListTile(
                    title: Text(productName),
                    value: isSelected,
                    onChanged: (bool? selected) {
                      setState(() {
                        if (selected == true) {
                          if (!_selectedParts.any((p) => p.id == product.id)) {
                            _selectedParts.add(product);
                          }
                        } else {
                          _selectedParts.removeWhere(
                                  (p) => p.id == product.id);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
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
            onPressed: () => Navigator.of(context).pop()),
        ElevatedButton(
            child: const Text('CONFIRMER'),
            onPressed: () => Navigator.of(context).pop(_selectedParts)),
      ],
    );
  }
}
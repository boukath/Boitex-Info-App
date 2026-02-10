// lib/screens/service_technique/sav_ticket_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:intl/intl.dart';
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
import 'package:path_provider/path_provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';
import 'package:flutter/foundation.dart';
import 'package:file_saver/file_saver.dart';

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

  List<PlatformFile> _technicianMediaToUpload = [];

  // ✅ NEW: Dynamic Status Options based on Ticket Type
  List<String> get _validStatusOptions {
    if (_currentTicket.ticketType == 'removal') {
      // ✅ STEP 4 MODIFICATION: Removed 'Retourné'. Status stays fixed at 'Dépose'.
      return ['Dépose'];
    }
    // Standard statuses
    return [
      'Nouveau',
      'En Diagnostic',
      'En Réparation',
      'Terminé',
      'Irréparable - Remplacement Demandé',
      'Approuvé - Prêt pour retour',
      'Retourné',
    ];
  }

  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  @override
  void initState() {
    super.initState();
    _currentTicket = widget.ticket;
    _reportController =
        TextEditingController(text: _currentTicket.technicianReport ?? '');

    // Listen for real-time updates
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

  // --- Helper Functions ---
  bool _isVideoUrl(String url) {
    final lowercaseUrl = url.toLowerCase();
    return lowercaseUrl.endsWith('.mp4') ||
        lowercaseUrl.endsWith('.mov') ||
        lowercaseUrl.endsWith('.avi') ||
        lowercaseUrl.endsWith('.mkv');
  }

  bool _isVideoFile(PlatformFile file) {
    final extension = file.extension?.toLowerCase() ?? '';
    return ['mp4', 'mov', 'avi', 'mkv'].contains(extension);
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
      PlatformFile file, Map<String, dynamic> b2Creds) async {
    try {
      Uint8List fileBytes;
      String fileName;

      if (kIsWeb) {
        if (file.bytes != null) {
          fileBytes = file.bytes!;
          fileName = file.name;
        } else {
          throw Exception("Web upload failed: File bytes are null");
        }
      } else {
        if (file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
          fileName = path.basename(file.path!);
        } else {
          throw Exception("Mobile upload failed: File path is null");
        }
      }

      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(fileName);
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
      }

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(b2FileName),
          'Content-Type': mimeType ?? 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final returnedFileName = body['fileName'] as String;
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
      withData: true,
    );

    if (result != null) {
      const maxFileSize = 50 * 1024 * 1024;
      final validFiles = result.files.where((file) {
        if (file.size <= maxFileSize) {
          return true;
        } else {
          print('File rejected (size > 50MB): ${file.name}');
          return false;
        }
      }).toList();

      final rejectedCount = result.files.length - validFiles.length;

      setState(() {
        _technicianMediaToUpload.addAll(validFiles);
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

        final uploadFutures = _technicianMediaToUpload.map((file) =>
            _uploadFileToB2(file, b2Credentials)
        ).toList();

        final results = await Future.wait(uploadFutures);
        newMediaUrls = results.whereType<String>().toList();

        if (newMediaUrls.length != _technicianMediaToUpload.length && mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Certains médias n\'ont pas pu être uploadés.'), backgroundColor: Colors.orange),
          );
        }
      }

      final combinedMediaUrls = List<String>.from(_currentTicket.itemPhotoUrls)..addAll(newMediaUrls);

      final updateData = {
        'status': newStatus,
        'technicianReport': _reportController.text.trim(),
        'brokenParts': _currentTicket.brokenParts.map((p) => p.toJson()).toList(),
        'itemPhotoUrls': combinedMediaUrls,
      };

      await FirebaseFirestore.instance
          .collection('sav_tickets')
          .doc(_currentTicket.id)
          .update(updateData);

      await ActivityLogger.logActivity(
        message: "Statut SAV ${_currentTicket.savCode} -> '$newStatus'. ${newMediaUrls.isNotEmpty ? '${newMediaUrls.length} média(s) ajouté(s).' : ''}",
        interventionId: _currentTicket.id,
        category: 'SAV',
      );

      if (mounted) {
        setState(() {
          _technicianMediaToUpload.clear();
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
      final newParts = selectedProducts.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return BrokenPart(
          productId: doc.id,
          productName: data?['nom'] as String? ?? 'Nom Inconnu',
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
          brokenParts: newParts,
          billingStatus: _currentTicket.billingStatus,
          invoiceUrl: _currentTicket.invoiceUrl,
          returnClientName: _currentTicket.returnClientName,
          returnSignatureUrl: _currentTicket.returnSignatureUrl,
          returnPhotoUrl: _currentTicket.returnPhotoUrl,
          multiProducts: _currentTicket.multiProducts, // ✅ Ensure multiProducts are kept
          uploadedFileUrl: _currentTicket.uploadedFileUrl,
        );
      });

      _checkStockForParts(newParts);
      _updateTicket(_currentTicket.status);
    }
  }

  void _openMedia(String url) {
    if (url == _currentTicket.returnPhotoUrl) {
      if (_isVideoUrl(url)) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => VideoPlayerPage(videoUrl: url),
        ));
      } else {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => ImageGalleryPage(imageUrls: [url], initialIndex: 0),
        ));
      }
    }
    else if (_currentTicket.itemPhotoUrls.contains(url)) {
      if (_isVideoUrl(url)) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => VideoPlayerPage(videoUrl: url),
        ));
      } else {
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
    else {
      print("Error: URL $url not found in ticket media.");
    }
  }

  Future<void> _downloadPdf(String type) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('downloadSavPdf')
          .call({
        'ticketId': widget.ticket.id,
        'type': type,
      });

      if (mounted) Navigator.of(context).pop();

      final rawData = result.data;
      if (rawData == null) throw Exception("Réponse vide.");
      final Map<String, dynamic> data = Map<String, dynamic>.from(rawData as Map);

      final String? base64Pdf = data['pdfBase64'];
      if (base64Pdf == null || base64Pdf.isEmpty) throw Exception("PDF invalide.");

      final Uint8List bytes = base64Decode(base64Pdf);
      String filename = data['filename'] ?? 'document.pdf';
      filename = filename.replaceAll(RegExp(r'[/\\]'), '_');

      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: filename.replaceAll('.pdf', ''),
          bytes: bytes,
          ext: 'pdf',
          mimeType: MimeType.pdf,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Téléchargement lancé...'), backgroundColor: Colors.green),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerPage(
              pdfBytes: bytes,
              title: type == 'deposit' ? "Décharge SAV" : "Bon de Restitution",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildReturnDetailsCard() {
    if (_currentTicket.status != 'Retourné' || _currentTicket.returnClientName == null) {
      return const SizedBox.shrink();
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: const EdgeInsets.only(top: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preuve de Retour Client',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.green),
            ),
            const Divider(height: 20),
            _buildInfoRow('Client (Réception):', _currentTicket.returnClientName ?? 'N/A'),
            const SizedBox(height: 16),
            const Text('Signature Client:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_currentTicket.returnSignatureUrl != null)
              Container(
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade100,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _currentTicket.returnSignatureUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                ),
              )
            else
              const Text('Signature non disponible.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            const Text('Photo/Vidéo de Preuve:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_currentTicket.returnPhotoUrl != null)
              _buildMediaThumbnail(url: _currentTicket.returnPhotoUrl!)
            else
              const Text('Média non disponible.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTicket.savCode),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Télécharger la Décharge',
            onPressed: () => _downloadPdf('deposit'),
          ),
          if (_currentTicket.status == "Retourné")
            IconButton(
              icon: const Icon(Icons.assignment_return_outlined),
              tooltip: 'Télécharger le Bon de Restitution',
              onPressed: () => _downloadPdf('return'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),

            // ✅ NEW: Display List of Items if grouped
            if (_currentTicket.multiProducts.isNotEmpty) ...[
              _buildMultiProductsList(),
              const SizedBox(height: 16),
            ],

            if (_currentTicket.itemPhotoUrls.isNotEmpty) ...[
              _buildMediaSection(),
              const SizedBox(height: 16),
            ],

            _buildTechnicianSection(),

            _buildReturnDetailsCard(),

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

            _buildInfoRow('Technicien(s):',
                _currentTicket.pickupTechnicianNames.isNotEmpty
                    ? _currentTicket.pickupTechnicianNames.join(', ')
                    : 'Non assigné'
            ),

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
            _buildInfoRow('Date de création:', DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(_currentTicket.createdAt)),
            _buildInfoRow('Créé par:', _currentTicket.createdBy),

            // ✅ NEW: Show uploaded file link if present
            if (_currentTicket.uploadedFileUrl != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final url = _currentTicket.uploadedFileUrl!;
                  // You might need url_launcher or a webview to open this
                  // For now, just printing or handling via a dialog
                  print("Open URL: $url");
                  // If you have url_launcher: launchUrl(Uri.parse(url));
                },
                child: const Row(
                  children: [
                    Icon(Icons.attach_file, color: Colors.blue),
                    SizedBox(width: 8),
                    Text("Voir fichier joint", style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                  ],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMultiProductsList() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Liste des Appareils (${_currentTicket.multiProducts.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue)),
                const Icon(Icons.list_alt, color: Colors.blue),
              ],
            ),
            const Divider(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentTicket.multiProducts.length,
              separatorBuilder: (ctx, i) => const Divider(),
              itemBuilder: (context, index) {
                final item = _currentTicket.multiProducts[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Text('${index + 1}', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("S/N: ${item.serialNumber}\n${item.problemDescription}"),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    final initialMedia = _currentTicket.itemPhotoUrls
        .where((url) => url != _currentTicket.returnPhotoUrl)
        .toList();

    if (initialMedia.isEmpty) {
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
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: initialMedia.map((url) => _buildMediaThumbnail(url: url)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaThumbnail({String? url, PlatformFile? file}) {
    bool isVideo = false;
    Widget mediaContent;

    if (file != null) {
      isVideo = _isVideoFile(file);
      if (isVideo && kIsWeb) {
        mediaContent = Container(
          color: Colors.black12,
          child: const Center(child: Icon(Icons.movie, size: 40, color: Colors.grey)),
        );
      } else if (isVideo) {
        mediaContent = FutureBuilder<Uint8List?>(
          future: VideoThumbnail.thumbnailData(video: file.path!, imageFormat: ImageFormat.JPEG, maxWidth: 80, quality: 25),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            return snapshot.hasData && snapshot.data != null
                ? Stack(fit: StackFit.expand, children: [ Image.memory(snapshot.data!, fit: BoxFit.cover), const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30))])
                : const Center(child: Icon(Icons.videocam_off_outlined, color: Colors.grey));
          },
        );
      } else {
        if (kIsWeb) {
          mediaContent = file.bytes != null
              ? Image.memory(file.bytes!, fit: BoxFit.cover)
              : const Center(child: Icon(Icons.broken_image));
        } else {
          mediaContent = Image.file(File(file.path!), fit: BoxFit.cover);
        }
      }
    } else if (url != null) {
      isVideo = _isVideoUrl(url);
      if (isVideo && kIsWeb) {
        mediaContent = Container(
          color: Colors.black,
          child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 40)),
        );
      } else {
        mediaContent = isVideo
            ? FutureBuilder<Uint8List?>(
          future: VideoThumbnail.thumbnailData(video: url, imageFormat: ImageFormat.JPEG, maxWidth: 80, quality: 25, headers: {}),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            return snapshot.hasData && snapshot.data != null
                ? Stack(fit: StackFit.expand, children: [ Image.memory(snapshot.data!, fit: BoxFit.cover), const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30))])
                : const Center(child: Icon(Icons.videocam_off_outlined, color: Colors.grey));
          },
        )
            : Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
        );
      }
    } else {
      mediaContent = const Center(child: Icon(Icons.error_outline, color: Colors.red));
    }

    return GestureDetector(
      onTap: url != null ? () => _openMedia(url) : null,
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade100,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: mediaContent,
        ),
      ),
    );
  }

  Widget _buildTechnicianSection() {
    // ✅ STEP 4 MODIFICATION: Treat 'Dépose' as Read-Only (Closed)
    bool isReadOnly = _currentTicket.status == 'Retourné' || _currentTicket.status == 'Dépose';

    final options = _validStatusOptions;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Section Technicien', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.orange)),
            const Divider(height: 20),

            DropdownButtonFormField<String>(
              // ✅ Check if current status is in the allowed list to avoid crashes
              value: options.contains(_currentTicket.status) ? _currentTicket.status : null,
              items: options.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
              onChanged: isReadOnly ? null : (value) {
                if (value != null && value != _currentTicket.status) {
                  _updateTicket(value);
                }
              },
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Changer le statut',
                border: const OutlineInputBorder(),
                filled: isReadOnly,
                fillColor: isReadOnly ? Colors.grey[200] : null,
              ),
            ),
            const SizedBox(height: 16),

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
              minLines: 3,
            ),
            const SizedBox(height: 16),

            if (!isReadOnly) ...[
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
                            _buildMediaThumbnail(file: file),
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

            if (_currentTicket.brokenParts.isNotEmpty) ...[
              const Text('Pièces Défectueuses:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _currentTicket.brokenParts.length,
                itemBuilder: (context, index) {
                  final part = _currentTicket.brokenParts[index];
                  final stock = _stockStatus[part.productId];
                  final stockText = stock == null ? 'Chargement...' : stock.toString();
                  final stockColor = stock == null ? Colors.grey : (stock > 0 ? Colors.green : Colors.red);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.build_circle_outlined, color: Colors.grey[600]),
                    title: Text(part.productName),
                    trailing: Text('Stock: $stockText', style: TextStyle(color: stockColor, fontWeight: FontWeight.bold)),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            if (!isReadOnly)
              ElevatedButton.icon(
                onPressed: _isUpdating ? null : () => _updateTicket(_currentTicket.status),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                icon: _isUpdating ? Container() : const Icon(Icons.save_outlined),
                label: _isUpdating
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('Enregistrer Modifications'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
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
      // ✅ ADDED: Color for Dépose
        case 'Dépose': valueColor = Colors.teal.shade700; break;
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
}

// ... (Keep _AddPartsDialog class) ...

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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedParts = [];
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
          _selectedParts.addAll(_allProducts.where((p) => widget.initialSelected.contains(p.id)));
          _isLoadingProducts = false;
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
        final name = (data?['nom'] as String? ?? '').toLowerCase();
        final reference = (data?['reference'] as String? ?? '').toLowerCase();
        return name.contains(query) || reference.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = _allProducts
        .map((doc) => (doc.data() as Map<String, dynamic>?)?['categorie'] as String?)
        .where((c) => c != null && c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return AlertDialog(
      title: const Text('Ajouter/Modifier Pièces'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text('Sélectionner une catégorie'),
              isExpanded: true,
              onChanged: (value) {
                if (value != null) {
                  _searchQuery = '';
                  _filterProductsByCategory(value);
                }
              },
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c!))).toList(),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),

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
                    _filterProductsByCategory(_selectedCategory!);
                  },
                ),
              ),


            Expanded(
              child: _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedCategory == null
                  ? const Center(child: Text('Sélectionnez une catégorie.'))
                  : _productsForCategory.isEmpty
                  ? Center(child: Text(_searchQuery.isEmpty ? 'Aucun produit trouvé.' : 'Aucun produit correspondant au filtre.'))
                  : ListView.builder(
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
                          if (!_selectedParts.any((p) => p.id == product.id)) {
                            _selectedParts.add(product);
                          }
                        } else {
                          _selectedParts.removeWhere((p) => p.id == product.id);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: const Text('CONFIRMER'),
          onPressed: () => Navigator.of(context).pop(_selectedParts),
        ),
      ],
    );
  }
}
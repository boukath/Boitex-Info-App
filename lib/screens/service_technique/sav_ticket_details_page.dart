// lib/screens/service_technique/sav_ticket_details_page.dart

import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; // ✅ NEW: For gallery access
import 'package:http/http.dart' as http; // ✅ RESTORED: For B2
import 'package:crypto/crypto.dart'; // ✅ RESTORED: For B2

import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';
import 'package:boitex_info_app/models/sav_journal_entry.dart';
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';
import 'package:boitex_info_app/screens/administration/product_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/finalize_sav_return_page.dart';
import 'package:boitex_info_app/widgets/image_gallery_page.dart'; // ✅ RESTORED
import 'package:boitex_info_app/widgets/video_player_page.dart'; // ✅ RESTORED

// ✅ NEW: Import our custom Markup Editor!
import 'package:boitex_info_app/screens/service_technique/widgets/image_markup_page.dart';

class SavTicketDetailsPage extends StatefulWidget {
  final SavTicket ticket;
  const SavTicketDetailsPage({super.key, required this.ticket});

  @override
  State<SavTicketDetailsPage> createState() => _SavTicketDetailsPageState();
}

class _SavTicketDetailsPageState extends State<SavTicketDetailsPage> {
  late SavTicket _currentTicket;
  final TextEditingController _omnibarTextController = TextEditingController();
  late Stream<List<SavJournalEntry>> _journalStream;
  String? _productImageUrl;

  String? _currentUserId;
  String _currentUserName = 'Technicien';

  final String _getB2UploadUrlCloudFunctionUrl = 'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  bool get _isActiveRepair {
    return ['Nouveau', 'En Diagnostic', 'En Réparation'].contains(_currentTicket.status);
  }

  @override
  void initState() {
    super.initState();
    _currentTicket = widget.ticket;

    _journalStream = FirebaseFirestore.instance
        .collection('sav_tickets')
        .doc(widget.ticket.id)
        .collection('journal_entries')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => SavJournalEntry.fromFirestore(doc))
        .toList());

    FirebaseFirestore.instance.collection('sav_tickets').doc(widget.ticket.id).snapshots().listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          _currentTicket = SavTicket.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
        });
      }
    });

    _loadProductImage();
    _fetchCurrentUser();
  }

  @override
  void dispose() {
    _omnibarTextController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // FIREBASE LOGIC
  // ===========================================================================

  Future<void> _fetchCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        if (mounted) setState(() => _currentUserName = user.displayName!);
      }
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['displayName'] != null && data['displayName'].toString().trim().isNotEmpty) {
            if (mounted) setState(() => _currentUserName = data['displayName']);
          } else {
            final prenom = data['prenom'] ?? '';
            final nom = data['nom'] ?? '';
            if (prenom.isNotEmpty || nom.isNotEmpty) {
              if (mounted) setState(() => _currentUserName = '$prenom $nom'.trim());
            } else if (data['name'] != null) {
              if (mounted) setState(() => _currentUserName = data['name']);
            }
          }
        }
      } catch (e) {
        debugPrint('Erreur lors de la récupération de l\'utilisateur: $e');
      }
    }
  }

  Future<void> _loadProductImage() async {
    try {
      if (_currentTicket.multiProducts.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('produits').doc(_currentTicket.multiProducts.first.productId).get();
        if (doc.exists) {
          _extractImageFromDoc(doc);
          return;
        }
      }
      final query = await FirebaseFirestore.instance.collection('produits').where('nom', isEqualTo: _currentTicket.productName).limit(1).get();
      if (query.docs.isNotEmpty) {
        _extractImageFromDoc(query.docs.first);
      }
    } catch (e) {
      debugPrint("Erreur lors du chargement de l'image du produit: $e");
    }
  }

  void _extractImageFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data != null && data.containsKey('imageUrls')) {
      final urls = data['imageUrls'] as List<dynamic>?;
      if (urls != null && urls.isNotEmpty) {
        if (mounted) setState(() => _productImageUrl = urls.first.toString());
      }
    }
  }

  Future<void> _checkAndAutoUpdateStatus() async {
    if (_currentTicket.status == 'Nouveau' || _currentTicket.status == 'En Diagnostic') {
      final oldStatus = _currentTicket.status;
      const newStatus = 'En Réparation';
      try {
        await FirebaseFirestore.instance.collection('sav_tickets').doc(_currentTicket.id).update({'status': newStatus});
        final newEntry = SavJournalEntry(
          id: '',
          timestamp: DateTime.now(),
          authorName: 'Système Automatique',
          authorId: 'system',
          type: JournalEntryType.status_change,
          content: "L'intervention a commencé.",
          metadata: {'oldStatus': oldStatus, 'newStatus': newStatus},
        );
        await FirebaseFirestore.instance.collection('sav_tickets').doc(_currentTicket.id).collection('journal_entries').add(newEntry.toJson());
      } catch (e) {
        debugPrint('Error auto-updating status: $e');
      }
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    if (newStatus == _currentTicket.status) return;
    final oldStatus = _currentTicket.status;

    try {
      await FirebaseFirestore.instance.collection('sav_tickets').doc(_currentTicket.id).update({'status': newStatus});
      final newEntry = SavJournalEntry(
        id: '',
        timestamp: DateTime.now(),
        authorName: _currentUserName,
        authorId: _currentUserId ?? 'unknown_id',
        type: JournalEntryType.status_change,
        content: "L'intervention a été marquée comme : $newStatus",
        metadata: {'oldStatus': oldStatus, 'newStatus': newStatus},
      );
      await FirebaseFirestore.instance.collection('sav_tickets').doc(_currentTicket.id).collection('journal_entries').add(newEntry.toJson());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  // ===========================================================================
  // 📸 NEW MEDIA LOGIC (B2 Upload + Markup Editor)
  // ===========================================================================

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

  Future<void> _pickAndAnnotateMedia() async {
    FocusScope.of(context).unfocus();

    // 1. Pick Media from Gallery
    final ImagePicker picker = ImagePicker();
    final XFile? media = await picker.pickMedia();

    if (media == null) return;

    final String path = media.path.toLowerCase();
    final bool isVideo = path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.avi');

    Uint8List finalBytesToUpload;
    String mimeType;
    String extension;

    if (isVideo) {
      // It's a video: No drawing allowed. Just upload directly.
      finalBytesToUpload = await media.readAsBytes();
      mimeType = 'video/mp4';
      extension = '.mp4';
    } else {
      // It's an image: Open the Markup Editor!
      final File imageFile = File(media.path);

      final Uint8List? annotatedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageMarkupPage(imageFile: imageFile),
        ),
      );

      // If user clicked the back button without validating
      if (annotatedBytes == null) return;

      finalBytesToUpload = annotatedBytes;
      mimeType = 'image/jpeg';
      extension = '.jpg';
    }

    // Show loading overlay during upload
    if (mounted) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.purple)));
    }

    try {
      // 2. Get B2 Credentials
      final b2Credentials = await _getB2UploadCredentials();
      if (b2Credentials == null) throw Exception("Impossible d'obtenir les accès B2.");

      // 3. Upload to B2
      final sha1Hash = sha1.convert(finalBytesToUpload).toString();
      final uploadUri = Uri.parse(b2Credentials['uploadUrl'] as String);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final b2FileName = 'sav_tickets_media/${_currentTicket.savCode}/tech_upload_$timestamp$extension';

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Credentials['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(b2FileName),
          'Content-Type': mimeType,
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': finalBytesToUpload.length.toString(),
        },
        body: finalBytesToUpload,
      );

      if (resp.statusCode != 200) throw Exception("Erreur upload B2.");

      final body = json.decode(resp.body) as Map<String, dynamic>;
      final returnedFileName = body['fileName'] as String;
      final encodedPath = returnedFileName.split('/').map(Uri.encodeComponent).join('/');
      final String fileUrl = (b2Credentials['downloadUrlPrefix'] as String) + encodedPath;

      // 4. Save to Timeline!
      await _checkAndAutoUpdateStatus();

      final newEntry = SavJournalEntry(
        id: '',
        timestamp: DateTime.now(),
        authorName: _currentUserName,
        authorId: _currentUserId ?? 'unknown_id',
        type: JournalEntryType.photo, // Map to photo enum
        content: isVideo ? "Vidéo d'inspection ajoutée." : "Photo d'inspection annotée.",
        metadata: {
          'mediaUrl': fileUrl,
          'isVideo': isVideo,
        },
      );

      await FirebaseFirestore.instance.collection('sav_tickets').doc(_currentTicket.id).collection('journal_entries').add(newEntry.toJson());

      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Média enregistré !'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }


  // ===========================================================================
  // EXISTING METHODS
  // ===========================================================================

  void _showStatusConfirmationDialog(String newStatus, String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(description),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: newStatus == 'Terminé' ? Colors.green : Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(context);
              _changeStatus(newStatus);
            },
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitTextEntry() async {
    final text = _omnibarTextController.text.trim();
    if (text.isEmpty) return;

    _omnibarTextController.clear();
    FocusScope.of(context).unfocus();

    await _checkAndAutoUpdateStatus();

    try {
      final newEntry = SavJournalEntry(
        id: '', timestamp: DateTime.now(), authorName: _currentUserName, authorId: _currentUserId ?? 'unknown_id',
        type: JournalEntryType.text, content: text,
      );
      await FirebaseFirestore.instance.collection('sav_tickets').doc(_currentTicket.id).collection('journal_entries').add(newEntry.toJson());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  void _openPartSelector() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GlobalProductSearchPage(
          isSelectionMode: true,
          onProductSelected: (productData) async {
            Navigator.of(context).pop();
            await _checkAndAutoUpdateStatus();

            final productName = productData['productName'] ?? productData['nom'] ?? 'Pièce inconnue';
            final productRef = productData['partNumber'] ?? productData['reference'] ?? '';
            final productId = productData['productId'] ?? productData['id'] ?? '';

            try {
              String? imageUrl;
              if (productId.isNotEmpty) {
                final doc = await FirebaseFirestore.instance.collection('produits').doc(productId).get();
                if (doc.exists && doc.data() != null) {
                  final urls = doc.data()!['imageUrls'] as List<dynamic>?;
                  if (urls != null && urls.isNotEmpty) {
                    imageUrl = urls.first.toString();
                  }
                }
              }

              final newEntry = SavJournalEntry(
                id: '', timestamp: DateTime.now(), authorName: _currentUserName, authorId: _currentUserId ?? 'unknown_id',
                type: JournalEntryType.part_consumed,
                content: "Pièce remplacée: $productName ${productRef.isNotEmpty ? '($productRef)' : ''}",
                metadata: {'productId': productId, 'productName': productName, 'productRef': productRef, if (imageUrl != null) 'imageUrl': imageUrl},
              );
              await FirebaseFirestore.instance.collection('sav_tickets').doc(_currentTicket.id).collection('journal_entries').add(newEntry.toJson());
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pièce ajoutée au journal !'), backgroundColor: Colors.green));
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
            }
          },
        ),
      ),
    );
  }

  Future<void> _downloadPdf(String type) async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('downloadSavPdf').call({'ticketId': widget.ticket.id, 'type': type});
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
        await FileSaver.instance.saveFile(name: filename.replaceAll('.pdf', ''), bytes: bytes, ext: 'pdf', mimeType: MimeType.pdf);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => PdfViewerPage(pdfBytes: bytes, title: type == 'deposit' ? "Décharge SAV" : "Bon de Restitution")));
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showTicketInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
        padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 40),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Text('Détails Initiaux', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5)),
              const SizedBox(height: 24),
              _buildInfoSheetRow(Icons.business_rounded, 'Client', _currentTicket.clientName),
              if (_currentTicket.storeName != null)
                _buildInfoSheetRow(Icons.storefront_rounded, 'Magasin', _currentTicket.storeName!),
              _buildInfoSheetRow(Icons.tag_rounded, 'N° de Série', _currentTicket.serialNumber),
              _buildInfoSheetRow(Icons.engineering_rounded, 'Techniciens (Retrait)', _currentTicket.pickupTechnicianNames.isNotEmpty ? _currentTicket.pickupTechnicianNames.join(', ') : 'Non assigné'),
              _buildInfoSheetRow(Icons.person_outline_rounded, 'Créé par', _currentTicket.createdBy),
              _buildInfoSheetRow(Icons.calendar_today_rounded, 'Date de création', DateFormat('dd MMM yyyy, HH:mm').format(_currentTicket.createdAt)),
              const Divider(height: 32),
              Text('Description du Problème', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade100)),
                child: Text(_currentTicket.problemDescription, style: TextStyle(color: Colors.orange.shade900, height: 1.5, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSheetRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2026 UI ARCHITECTURE
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  _buildPatientHeader(),

                  StreamBuilder<List<SavJournalEntry>>(
                    stream: _journalStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.blue)));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history_edu, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text("Aucun historique pour le moment.\nUtilisez la barre ci-dessous pour commencer.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                              ],
                            ),
                          ),
                        );
                      }
                      final entries = snapshot.data!;
                      return SliverPadding(
                        padding: const EdgeInsets.all(16.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildRealTimelineBubble(entries[index], index == entries.length - 1),
                            childCount: entries.length,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            _buildContextualActionButtons(),
            if (_isActiveRepair) _buildSmartOmnibar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientHeader() {
    return SliverAppBar(
      expandedHeight: 140.0,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white.withOpacity(0.75),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 44, height: 44,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))]
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _productImageUrl != null
                        ? CachedNetworkImage(
                      imageUrl: _productImageUrl!, fit: BoxFit.cover,
                      placeholder: (context, url) => const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (context, url, error) => Icon(Icons.devices_other_rounded, color: Colors.grey.shade400, size: 24),
                    )
                        : Icon(Icons.devices_other_rounded, color: Colors.grey.shade400, size: 24),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_currentTicket.savCode, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      Text(_currentTicket.productName, style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(16)),
                  child: Text(_currentTicket.status, style: TextStyle(fontSize: 9, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            background: Container(color: Colors.transparent),
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.black87),
      actions: [
        IconButton(icon: const Icon(Icons.info_outline_rounded), tooltip: 'Détails du Ticket', onPressed: _showTicketInfoSheet),
        IconButton(icon: const Icon(Icons.description_outlined), tooltip: 'Télécharger la Décharge', onPressed: () => _downloadPdf('deposit')),
        if (_currentTicket.status == "Retourné")
          IconButton(icon: const Icon(Icons.assignment_return_outlined), tooltip: 'Télécharger le Bon de Restitution', onPressed: () => _downloadPdf('return')),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildRealTimelineBubble(SavJournalEntry entry, bool isLast) {
    IconData iconData;
    Color iconColor;
    Color bubbleColor = Colors.white;

    switch (entry.type) {
      case JournalEntryType.text:
        iconData = Icons.chat_bubble_outline;
        iconColor = Colors.blue;
        break;
      case JournalEntryType.part_consumed:
        iconData = Icons.build_circle_outlined;
        iconColor = Colors.green;
        bubbleColor = Colors.green.shade50;
        break;
      case JournalEntryType.status_change:
        iconData = Icons.swap_horiz_rounded;
        iconColor = Colors.orange;
        bubbleColor = Colors.orange.shade50;
        break;
      case JournalEntryType.photo: // ✅ NEW: PHOTO/VIDEO STYLING
        iconData = Icons.photo_camera_rounded;
        iconColor = Colors.purple;
        bubbleColor = Colors.purple.shade50;
        break;
      default:
        iconData = Icons.info_outline;
        iconColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: Icon(iconData, size: 14, color: iconColor),
              ),
              // Increase the line height if it's a big photo card
              if (!isLast) Container(width: 2, height: entry.type == JournalEntryType.photo ? 180 : 60, color: Colors.grey.shade300),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: entry.type == JournalEntryType.part_consumed && entry.metadata?['productId'] != null
                    ? () async {
                  final pid = entry.metadata!['productId'];
                  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                  final doc = await FirebaseFirestore.instance.collection('produits').doc(pid).get();
                  Navigator.pop(context);
                  if (doc.exists && mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(productDoc: doc)));
                  }
                }
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: entry.type == JournalEntryType.part_consumed ? Colors.green.shade200 : (entry.type == JournalEntryType.photo ? Colors.purple.shade200 : Colors.grey.shade100)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.authorName, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 12)),
                          Text(DateFormat('dd MMM, HH:mm').format(entry.timestamp), style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ✅ NEW: PHOTO / VIDEO RENDERER
                      if (entry.type == JournalEntryType.photo)
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (entry.content.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(entry.content, style: TextStyle(color: Colors.purple.shade900, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              if (entry.metadata?['mediaUrl'] != null)
                                GestureDetector(
                                    onTap: () {
                                      final url = entry.metadata!['mediaUrl'];
                                      if (entry.metadata!['isVideo'] == true) {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerPage(videoUrl: url)));
                                      } else {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => ImageGalleryPage(imageUrls: [url], initialIndex: 0)));
                                      }
                                    },
                                    child: Container(
                                        height: 160,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.purple.shade300)
                                        ),
                                        child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: entry.metadata!['isVideo'] == true
                                                ? Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  Container(color: Colors.black12),
                                                  const Center(child: Icon(Icons.play_circle_fill, size: 50, color: Colors.white70))
                                                ]
                                            )
                                                : CachedNetworkImage(
                                              imageUrl: entry.metadata!['mediaUrl'],
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.purple)),
                                              errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                                            )
                                        )
                                    )
                                )
                            ]
                        )
                      else if (entry.type == JournalEntryType.part_consumed)
                        Row(
                            children: [
                              if (entry.metadata?['imageUrl'] != null)
                                Container(
                                  width: 44, height: 44, margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: entry.metadata!['imageUrl'], fit: BoxFit.cover,
                                      placeholder: (context, url) => const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)),
                                      errorWidget: (context, url, error) => Icon(Icons.build, color: Colors.green.shade700),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 44, height: 44, margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.build_rounded, color: Colors.green.shade700),
                                ),

                              Expanded(
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(entry.metadata?['productName'] ?? 'Pièce inconnue', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green.shade900, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        if (entry.metadata?['productRef'] != null && entry.metadata!['productRef'].isNotEmpty)
                                          Text('Réf: ${entry.metadata!['productRef']}', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                                      ]
                                  )
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.green.shade700),
                            ]
                        )
                      else if (entry.type == JournalEntryType.status_change)
                          Row(
                            children: [
                              Text(entry.metadata?['oldStatus'] ?? '?', style: TextStyle(color: Colors.grey.shade500, decoration: TextDecoration.lineThrough)),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Expanded(child: Text(entry.metadata?['newStatus'] ?? '?', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold))),
                            ],
                          )
                        else
                          Text(entry.content, style: TextStyle(color: Colors.grey.shade800, height: 1.4, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildContextualActionButtons() {
    if (_currentTicket.status == 'Retourné' || _currentTicket.status == 'Dépose') {
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(16), color: Colors.white,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
          child: const Center(child: Text('Ticket Clôturé (Appareil Retourné)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
        ),
      );
    }

    if (_currentTicket.status == 'Irréparable - Remplacement Demandé') {
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(16), color: Colors.white,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
          child: Center(child: Text('Appareil déclaré IRRÉPARABLE', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold))),
        ),
      );
    }

    if (_currentTicket.status == 'Terminé' || _currentTicket.status == 'Approuvé - Prêt pour retour') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.local_shipping_rounded),
          label: const Text('Restituer au Client', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => FinalizeSavReturnPage(ticket: _currentTicket)));
          },
        ),
      );
    }

    if (_isActiveRepair) {
      return Container(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
        color: Colors.grey.shade50,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cancel_rounded, size: 18),
                label: const Text('Irréparable', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red.shade200), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => _showStatusConfirmationDialog('Irréparable - Remplacement Demandé', 'Déclarer comme Irréparable ?', 'Cette action verrouillera le ticket et informera le manager.'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Terminer réparation', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => _showStatusConfirmationDialog('Terminé', 'Marquer comme Terminé ?', 'L\'appareil sera prêt à être restitué au client.'),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSmartOmnibar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, -5))]),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // ✅ UPDATED: The Camera/Gallery button now calls our new function!
            Container(
              decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
              child: IconButton(
                icon: Icon(Icons.camera_alt_rounded, color: Colors.purple.shade700, size: 20),
                onPressed: _pickAndAnnotateMedia,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
              child: IconButton(icon: Icon(Icons.build_circle_rounded, color: Colors.blue.shade700, size: 20), onPressed: _openPartSelector),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade300)),
                child: TextField(
                  controller: _omnibarTextController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitTextEntry(),
                  decoration: InputDecoration(hintText: "Décrire l'intervention...", hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13), border: InputBorder.none),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
              child: IconButton(icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20), onPressed: _submitTextEntry),
            ),
          ],
        ),
      ),
    );
  }
}
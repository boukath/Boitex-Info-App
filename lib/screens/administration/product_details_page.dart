import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/add_product_page.dart';
// Import the image gallery page
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
// Import the PDF viewer page
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';
// Imports for PDF handling and file type checking
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart'; // For fallback file opening

class ProductDetailsPage extends StatefulWidget {
  final DocumentSnapshot productDoc;

  const ProductDetailsPage({super.key, required this.productDoc});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  // ❌ REMOVED: No longer needed for top PageView
  // int _currentImageIndex = 0;
  // final PageController _pageController = PageController();
  bool _isOpeningPdf = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    // ❌ REMOVED: No longer needed for top PageView
    // _pageController.dispose();
    super.dispose();
  }

  // --- PDF Opening Logic (Keep existing) ---
  Future<void> _openPdfViewer(String pdfUrl, String title) async { /* ... Keep existing ... */
    if (_isOpeningPdf) return;
    setState(() => _isOpeningPdf = true);
    ScaffoldMessengerState? scaffoldMessenger;
    if (mounted) scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode == 200) {
        final pdfBytes = response.bodyBytes;
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfViewerPage(
                pdfBytes: pdfBytes,
                title: title,
              ),
            ),
          );
        }
      } else {
        throw Exception('Impossible de télécharger le PDF (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error opening PDF viewer: $e');
      scaffoldMessenger?.showSnackBar(
        SnackBar(
          content: Text('Erreur ouverture PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _openUrl(pdfUrl);
    } finally {
      if (mounted) setState(() => _isOpeningPdf = false);
    }
  }

  Future<void> _openUrl(String? urlString) async { /* ... Keep existing ... */
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir le lien $url')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final data = widget.productDoc.data() as Map<String, dynamic>;
    final imageUrls = (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    final tags = (data['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    final manualFiles = (data['manualFiles'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>()
        .map((map) => {
      'fileName': map['fileName']?.toString() ?? 'Document.pdf',
      'fileUrl': map['fileUrl']?.toString() ?? '',
    }).where((map) => map['fileUrl']!.isNotEmpty)
        .toList() ?? [];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration( // Keep background
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
              Colors.pink.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, data),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // ❌ REMOVED: Large image gallery from top
                      // if (imageUrls.isNotEmpty) _buildImageGallery(imageUrls),
                      // if (imageUrls.isNotEmpty) const SizedBox(height: 20),

                      _buildProductHeader(data),
                      const SizedBox(height: 20),
                      _buildInfoCards(data),
                      const SizedBox(height: 20),
                      if (data['description']?.toString().isNotEmpty ?? false) _buildDescriptionCard(data),
                      if (data['description']?.toString().isNotEmpty ?? false) const SizedBox(height: 20),

                      // ✅ ADDED: Photos Card (placed above Manuals card)
                      if (imageUrls.isNotEmpty) _buildPhotosCard(imageUrls),
                      if (imageUrls.isNotEmpty) const SizedBox(height: 20),

                      if (manualFiles.isNotEmpty) _buildManualsCard(manualFiles),
                      if (manualFiles.isNotEmpty) const SizedBox(height: 20),

                      if (tags.isNotEmpty) _buildTagsCard(tags),
                      if (tags.isNotEmpty) const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Keep build methods: _buildAppBar, _buildProductHeader, _buildInfoCards, _buildInfoCard, _buildDescriptionCard, _buildManualsCard, _buildTagsCard, _getTagColor ---
  Widget _buildAppBar(BuildContext context, Map<String, dynamic> data) { /* ... Keep existing ... */
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Détails',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['nom'] ?? 'Produit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddProductPage(productDoc: widget.productDoc),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.white),
              onPressed: () => _showDeleteDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  // ❌ REMOVED: Large PageView gallery builder
  // Widget _buildImageGallery(List<String> imageUrls) { ... }

  Widget _buildProductHeader(Map<String, dynamic> data) { /* ... Keep existing ... */
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['nom'] ?? 'Nom non disponible',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.category_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                data['categorie'] ?? 'N/A',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (data['mainCategory'] != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              data['mainCategory'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildInfoCards(Map<String, dynamic> data) { /* ... Keep existing ... */
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.business_rounded,
                label: 'Marque',
                value: data['marque'] ?? 'N/A',
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.qr_code_2_rounded,
                label: 'Référence',
                value: data['reference'] ?? 'N/A',
                gradient: const LinearGradient(
                  colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.public_rounded,
          label: 'Origine',
          value: data['origine'] ?? 'N/A',
          gradient: const LinearGradient(
            colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
          ),
        ),
      ],
    );
  }
  Widget _buildInfoCard({ /* ... Keep existing ... */
    required IconData icon,
    required String label,
    required String value,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildDescriptionCard(Map<String, dynamic> data) { /* ... Keep existing ... */
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFA709A), Color(0xFFFEE140)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            data['description'] ?? 'Aucune description disponible.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ --- START: NEW PHOTOS CARD WIDGET ---
  Widget _buildPhotosCard(List<String> imageUrls) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient( // Use a different gradient for photos
                    colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Text(
                'Photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (imageUrls.isEmpty)
            Text( // Should not happen due to outer check, but good practice
              'Aucune photo disponible.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            SizedBox(
              height: 100, // Define height for horizontal list
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: imageUrls.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: _buildImageThumbnail(
                      context: context,
                      imageUrl: imageUrls[index],
                      allImageUrls: imageUrls,
                      index: index,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
  // ✅ --- END: NEW PHOTOS CARD WIDGET ---

  // ✅ --- START: NEW IMAGE THUMBNAIL WIDGET ---
  Widget _buildImageThumbnail({
    required BuildContext context,
    required String imageUrl,
    required List<String> allImageUrls,
    required int index,
  }) {
    // Use the URL as the tag, matching the original gallery implementation
    final String heroTag = imageUrl;

    return GestureDetector(
      onTap: () => _showFullScreenImageGallery(context, allImageUrls, index),
      child: Hero(
        tag: heroTag,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.grey.shade100,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                      strokeWidth: 2,
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade200,
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400, size: 40),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
  // ✅ --- END: NEW IMAGE THUMBNAIL WIDGET ---

  Widget _buildManualsCard(List<Map<String, String>> manualFiles) { /* ... Keep existing ... */
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEA580C)], // Orange gradient
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Text(
                'Manuels / Fichiers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (manualFiles.isEmpty)
            Text(
              'Aucun manuel disponible.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            ListView.separated(
              shrinkWrap: true, // Important inside ListView
              physics: const NeverScrollableScrollPhysics(), // Important inside ListView
              itemCount: manualFiles.length,
              itemBuilder: (context, index) {
                final fileData = manualFiles[index];
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFB91C1C)),
                  title: Text(
                    fileData['fileName']!,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2937)
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _isOpeningPdf ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () => _openPdfViewer(fileData['fileUrl']!, fileData['fileName']!),
                  contentPadding: EdgeInsets.zero,
                );
              },
              separatorBuilder: (context, index) => const Divider(height: 1),
            ),
        ],
      ),
    );
  }
  Widget _buildTagsCard(List<String> tags) { /* ... Keep existing ... */
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF30CFD0), Color(0xFF330867)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Text(
                'Tags',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              final colors = _getTagColor(tags.indexOf(tag));
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.label_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      tag,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  List<Color> _getTagColor(int index) { /* ... Keep existing ... */
    final colors = [
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
      [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
      [const Color(0xFFFA709A), const Color(0xFFFEE140)],
      [const Color(0xFF30CFD0), const Color(0xFF330867)],
    ];
    return colors[index % colors.length];
  }

  // Keep existing _showFullScreenImageGallery and _showDeleteDialog ---
  void _showFullScreenImageGallery(BuildContext context, List<String> imageUrls, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => ImageGalleryPage(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          // ❌ REMOVED: heroTagPrefix parameter
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
  void _showDeleteDialog(BuildContext context) { /* ... Keep existing ... */
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Confirmer'),
            ],
          ),
          content: const Text(
            'Êtes-vous sûr de vouloir supprimer ce produit ? Cette action est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Annuler',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('produits')
                        .doc(widget.productDoc.id)
                        .delete();
                    if (mounted) {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: const [
                              Icon(Icons.check_circle_rounded, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Produit supprimé avec succès'),
                            ],
                          ),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: const [
                              Icon(Icons.error_outline, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Erreur lors de la suppression'),
                            ],
                          ),
                          backgroundColor: const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
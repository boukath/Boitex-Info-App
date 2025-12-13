// lib/widgets/image_gallery_page.dart

import 'dart:io'; // ✅ Required for File operations (Mobile)
import 'package:flutter/foundation.dart'; // ✅ Required for kIsWeb check
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart'; // ✅ Required for temp storage (Mobile)
import 'package:gal/gal.dart'; // ✅ Required for saving to Gallery (Mobile)
import 'package:file_saver/file_saver.dart'; // ✅ Required for Web Downloads

class ImageGalleryPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final Function(String url)? onDelete; // Callback passing the deleted URL

  const ImageGalleryPage({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    this.onDelete,
  });

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<ImageGalleryPage> {
  late PageController _pageController;
  late int _currentIndex;
  late List<String> _images; // Local copy to handle deletions
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _images = List.from(widget.imageUrls); // Copy the list
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // ✅ UPDATED DOWNLOAD FUNCTION (WEB + MOBILE SUPPORT)
  Future<void> _downloadCurrentImage() async {
    if (_isDownloading || _images.isEmpty) return;
    setState(() => _isDownloading = true);

    final url = _images[_currentIndex];

    try {
      // 1. Extract file info
      // Clean the URL to get the extension (remove query params like ?alt=media)
      final cleanUrl = url.split('?').first;
      final ext = cleanUrl.split('.').last;
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}';

      // 2. Download bytes (RAM) - Works on Web & Mobile
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }

      // ⭐️ 3. WEB LOGIC
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: response.bodyBytes,
          ext: ext,
          mimeType: MimeType.jpeg, // Generally safe for photos
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ Téléchargement terminé (Web) !'),
                backgroundColor: Colors.green),
          );
        }
      }
      // 📱 4. MOBILE LOGIC (Your original code)
      else {
        // Check Permissions
        if (!await Gal.requestAccess()) {
          throw Exception('Permission refusée pour la galerie.');
        }

        // Prepare path
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/$fileName.$ext';

        // Write to disk
        final file = File(path);
        await file.writeAsBytes(response.bodyBytes);

        // Save to Gallery
        await Gal.putImage(path);

        // Cleanup
        await file.delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ Photo enregistrée dans la Galerie !'),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ✅ DELETE FUNCTION (Unchanged)
  void _deleteCurrentImage() {
    if (_images.isEmpty) return;
    final urlToDelete = _images[_currentIndex];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la photo ?'),
        content: const Text('Cette action retirera la photo de l\'intervention.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog

              // 1. Notify Parent (InterventionDetailsPage) to update Firestore
              if (widget.onDelete != null) {
                widget.onDelete!(urlToDelete);
              }

              // 2. Update Local UI state for smooth transition
              setState(() {
                _images.removeAt(_currentIndex);
                // Adjust index if we deleted the last item
                if (_currentIndex >= _images.length) {
                  _currentIndex = _images.isEmpty ? 0 : _images.length - 1;
                }
              });

              // 3. Close gallery if empty
              if (_images.isEmpty) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${_images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          // ✅ Download Button
          IconButton(
            icon: _isDownloading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download),
            onPressed: _downloadCurrentImage,
            tooltip: 'Télécharger',
          ),
          // ✅ Delete Button (Only if callback is provided)
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deleteCurrentImage,
              tooltip: 'Supprimer',
            ),
        ],
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          final imageUrl = _images[index];
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(imageUrl),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 2.0,
            heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
          );
        },
        itemCount: _images.length,
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        pageController: _pageController,
        onPageChanged: _onPageChanged,
      ),
    );
  }
}
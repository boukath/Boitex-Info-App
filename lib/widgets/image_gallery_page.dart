// lib/widgets/image_gallery_page.dart

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:file_saver/file_saver.dart';

class ImageGalleryPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final Function(String url)? onDelete;

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
  late List<String> _images;
  bool _isDownloading = false;

  // PRO FEATURES STATE
  bool _showUI = true;
  Timer? _hideUITimer;
  bool _showActionOverlay = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _currentIndex = widget.initialIndex;
    _images = List.from(widget.imageUrls);
    _pageController = PageController(initialPage: _currentIndex);

    _startHideTimer();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    _hideUITimer?.cancel();
    super.dispose();
  }

  // --- PRO FEATURE: Netflix-style Auto-Hide UI ---
  void _startHideTimer() {
    _hideUITimer?.cancel();
    _hideUITimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showUI) {
        setState(() => _showUI = false);
      }
    });
  }

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
    if (_showUI) _startHideTimer();
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    _startHideTimer(); // Reset timer on swipe
  }

  // --- PRO FEATURE: Filmstrip Navigation ---
  void _jumpToImage(int index) {
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    _startHideTimer();
  }

  // --- PRO FEATURE: Instagram-style Long Press ---
  void _handleLongPress() {
    HapticFeedback.heavyImpact();
    setState(() => _showActionOverlay = true);

    // Auto-hide the overlay after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showActionOverlay = false);
    });
  }

  // --- EXISTING LOGIC ---
  Future<void> _downloadCurrentImage() async {
    HapticFeedback.lightImpact();
    setState(() => _isDownloading = true);
    try {
      final currentUrl = _images[_currentIndex];
      final response = await http.get(Uri.parse(currentUrl));

      if (kIsWeb) {
        await FileSaver.instance.saveFile(name: 'boitex_img_${DateTime.now().millisecondsSinceEpoch}', bytes: response.bodyBytes, ext: 'jpg', mimeType: MimeType.jpeg);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/boitex_img_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(response.bodyBytes);
        await Gal.putImage(file.path);
      }
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image téléchargée avec succès !'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _deleteCurrentImage() {
    HapticFeedback.mediumImpact();
    if (widget.onDelete != null) {
      widget.onDelete!(_images[_currentIndex]);
      setState(() {
        _images.removeAt(_currentIndex);
        if (_images.isEmpty) {
          Navigator.of(context).pop();
        } else if (_currentIndex >= _images.length) {
          _currentIndex = _images.length - 1;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleUI, // Tap anywhere to toggle UI
        onLongPress: _handleLongPress, // Long press for Pro Action
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. IMMERSIVE GALLERY
            PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                final imageUrl = _images[index];
                return PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(imageUrl),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 3.0,
                  heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
                );
              },
              itemCount: _images.length,
              loadingBuilder: (context, event) => const Center(child: CupertinoActivityIndicator(radius: 20, color: Colors.white)),
              backgroundDecoration: const BoxDecoration(color: Colors.transparent),
              pageController: _pageController,
              onPageChanged: _onPageChanged,
            ),

            // 2. ANIMATED UI LAYER
            AnimatedOpacity(
              opacity: _showUI ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showUI,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // TOP & BOTTOM GRADIENTS
                    Positioned(
                      top: 0, left: 0, right: 0, height: 140,
                      child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent]))),
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0, height: 180, // Taller for filmstrip
                      child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent]))),
                    ),

                    // TOP NAVIGATION (Back + Pill)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 16, right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildGlassButton(icon: CupertinoIcons.back, onTap: () { HapticFeedback.lightImpact(); Navigator.of(context).pop(); }, size: 45),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.2))),
                                child: Text("${_currentIndex + 1} / ${_images.length}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // FLOATING RIGHT SIDEBAR
                    Positioned(
                      right: 16,
                      bottom: 120,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSidebarButton(icon: _isDownloading ? CupertinoIcons.cloud_download : CupertinoIcons.arrow_down_to_line, label: "Save", onTap: _downloadCurrentImage, isLoading: _isDownloading),
                          if (widget.onDelete != null) ...[
                            const SizedBox(height: 24),
                            _buildSidebarButton(icon: CupertinoIcons.trash, label: "Delete", onTap: _deleteCurrentImage, color: Colors.redAccent),
                          ]
                        ],
                      ),
                    ),

                    // APPLE-STYLE FILMSTRIP SCRUBBER
                    Positioned(
                      bottom: MediaQuery.of(context).padding.bottom + 10,
                      left: 0, right: 0,
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          final isSelected = _currentIndex == index;
                          return GestureDetector(
                            onTap: () => _jumpToImage(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 8),
                              width: isSelected ? 60 : 45,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                                boxShadow: isSelected ? [BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 8)] : [],
                                image: DecorationImage(
                                  image: NetworkImage(_images[index]),
                                  fit: BoxFit.cover,
                                  colorFilter: isSelected ? null : ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. LONG PRESS OVERLAY ANIMATION
            Center(
              child: AnimatedOpacity(
                opacity: _showActionOverlay ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.checkmark_seal_fill, color: Colors.white, size: 60),
                          SizedBox(height: 12),
                          Text("Image Flagged", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Helpers ---
  Widget _buildGlassButton({required IconData icon, required VoidCallback onTap, double size = 50}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.2))),
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarButton({required IconData icon, required String label, required VoidCallback onTap, Color color = Colors.white, bool isLoading = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: isLoading ? null : () { HapticFeedback.lightImpact(); onTap(); },
          child: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.4), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]),
            child: isLoading ? const CupertinoActivityIndicator(color: Colors.white) : Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, shadows: const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))]))
      ],
    );
  }
}
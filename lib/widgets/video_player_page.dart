// lib/widgets/video_player_page.dart

import 'dart:io'; // ✅ Required for File operations
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart'; // ✅ Required for temp storage
import 'package:gal/gal.dart'; // ✅ Required for saving to Gallery

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final VoidCallback? onDelete; // Callback for deletion

  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
    this.onDelete,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isDownloading = false; // Loading state for download

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        // Allow controls to be visible so we can see the AppBar
        fullScreenByDefault: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).primaryColor,
          handleColor: Theme.of(context).primaryColor,
          bufferedColor: Colors.grey.shade300,
          backgroundColor: Colors.grey.shade600,
        ),
        placeholder: const Center(
          child: CircularProgressIndicator(),
        ),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  // ✅ UPDATED DOWNLOAD FUNCTION (Saves to Gallery)
  Future<void> _downloadVideo() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      // 1. Check/Request Permissions
      if (!await Gal.requestAccess()) {
        throw Exception('Permission refusée pour la galerie.');
      }

      // 2. Prepare temporary file path
      final tempDir = await getTemporaryDirectory();
      // Extract extension or default to .mp4
      final ext = widget.videoUrl.split('.').last.split('?').first;
      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '${tempDir.path}/$fileName';

      // 3. Download bytes
      final response = await http.get(Uri.parse(widget.videoUrl));
      if (response.statusCode != 200) {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }

      // 4. Write to temp file
      final file = File(path);
      await file.writeAsBytes(response.bodyBytes);

      // 5. Save to Gallery using Gal
      await Gal.putVideo(path);

      // 6. Cleanup temp file
      await file.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Vidéo enregistrée dans la Galerie !'),
              backgroundColor: Colors.green
          ),
        );
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

  // ✅ DELETE FUNCTION
  void _deleteVideo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la vidéo ?'),
        content: const Text('Cette action retirera la vidéo de l\'intervention.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler')
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              if (widget.onDelete != null) {
                widget.onDelete!(); // Trigger callback
                Navigator.of(context).pop(); // Close player
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    if (!_isLoading && !_hasError) {
      _chewieController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Lecteur Vidéo', style: TextStyle(color: Colors.white)),
        actions: [
          // ✅ Download Button
          IconButton(
            icon: _isDownloading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download),
            onPressed: _downloadVideo,
            tooltip: 'Télécharger',
          ),
          // ✅ Delete Button (Only if callback is provided)
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deleteVideo,
              tooltip: 'Supprimer',
            ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : _hasError
            ? const Text(
          'Impossible de lire la vidéo.\nLe lien est peut-être corrompu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        )
            : Chewie(controller: _chewieController),
      ),
    );
  }
}
// lib/widgets/video_player_page.dart

import 'dart:io'; // ✅ Required for File operations (Mobile)
import 'dart:ui'; // ✅ Required for Glassmorphism (BackdropFilter)
import 'package:flutter/foundation.dart'; // ✅ Required for kIsWeb check
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ For SystemChrome (Immersive Mode)
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart'; // ✅ Required for temp storage (Mobile)
import 'package:gal/gal.dart'; // ✅ Required for saving to Gallery (Mobile)
import 'package:file_saver/file_saver.dart'; // ✅ Required for Web Downloads

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
  ChewieController? _chewieController; // Nullable to handle loading state better
  bool _isLoading = true;
  bool _hasError = false;
  bool _isDownloading = false;
  bool _showControls = true; // To toggle the Glass Header visibility

  @override
  void initState() {
    super.initState();
    // ⚡️ Enter Fullscreen Immersive Mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
        allowMuting: true,
        showControls: true,
        allowPlaybackSpeedChanging: true, // ✅ Premium Feature: Speed Control
        // Customizing the player look
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF2962FF), // Premium Blue
          handleColor: Colors.white,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.black54,
        ),
        placeholder: const Center(
          child: CircularProgressIndicator(color: Color(0xFF2962FF)),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
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

  // ✅ UPDATED DOWNLOAD FUNCTION (WEB + MOBILE SUPPORT)
  Future<void> _downloadVideo() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final cleanUrl = widget.videoUrl.split('?').first;
      final ext = cleanUrl.split('.').last;
      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}';

      final response = await http.get(Uri.parse(widget.videoUrl));
      if (response.statusCode != 200) {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }

      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: response.bodyBytes,
          ext: ext,
          mimeType: MimeType.mpeg,
        );
        if (mounted) _showSnack('✅ Téléchargement terminé (Web)', Colors.green);
      } else {
        if (!await Gal.requestAccess()) {
          throw Exception('Permission refusée pour la galerie.');
        }

        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/$fileName.$ext';
        final file = File(path);
        await file.writeAsBytes(response.bodyBytes);

        await Gal.putVideo(path);
        await file.delete();

        if (mounted) _showSnack('✅ Enregistré dans la Galerie !', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  void _deleteVideo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Supprimer la vidéo ?', style: TextStyle(color: Colors.white)),
        content: const Text(
            'Cette action est irréversible.',
            style: TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler', style: TextStyle(color: Colors.white))
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (widget.onDelete != null) {
                widget.onDelete!();
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
  void dispose() {
    // ⚡️ Restore System UI when leaving
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true, // Key for immersive feel
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Ambient Background (Subtle Gradient)
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF1E1E1E), Colors.black],
                center: Alignment.center,
                radius: 1.5,
              ),
            ),
          ),

          // 2. The Player (Centered)
          Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : _hasError
                ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image, color: Colors.white54, size: 50),
                const SizedBox(height: 10),
                const Text(
                  'Vidéo indisponible',
                  style: TextStyle(color: Colors.white),
                ),
                TextButton(
                  onPressed: _initializePlayer,
                  child: const Text("Réessayer"),
                )
              ],
            )
                : AspectRatio(
              aspectRatio: _videoPlayerController.value.aspectRatio,
              child: Chewie(controller: _chewieController!),
            ),
          ),

          // 3. 🌫️ Glassmorphism Floating Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildGlassHeader(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassHeader(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            bottom: 15,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button (Circle Glass)
              _buildGlassButton(
                icon: Icons.arrow_back_ios_new,
                onTap: () => Navigator.pop(context),
              ),

              const Spacer(),

              // Action Buttons
              Row(
                children: [
                  _buildGlassButton(
                    icon: _isDownloading ? Icons.hourglass_top : Icons.download_rounded,
                    onTap: _downloadVideo,
                    isLoading: _isDownloading,
                  ),
                  if (widget.onDelete != null) ...[
                    const SizedBox(width: 12),
                    _buildGlassButton(
                      icon: Icons.delete_outline,
                      onTap: _deleteVideo,
                      color: Colors.redAccent,
                    ),
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, color: color, size: 20),
      ),
    );
  }
}
// lib/widgets/video_player_page.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // Required for HapticFeedback
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:file_saver/file_saver.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final VoidCallback? onDelete;

  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
    this.onDelete,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoPlayerController;

  bool _isLoading = true;
  bool _isDownloading = false;
  bool _showPlayPauseIcon = false;

  // Premium Player States
  Duration _currentPosition = Duration.zero;
  bool _isDragging = false;
  bool _isMuted = false;
  bool _isSpeedingUp = false;

  // Gesture Trackers
  Offset _lastTapPosition = Offset.zero;
  String _seekOverlayText = "";
  bool _showSeekOverlay = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

    try {
      await _videoPlayerController.initialize();
      _videoPlayerController.setLooping(true);
      _videoPlayerController.play();

      _videoPlayerController.addListener(() {
        if (!_isDragging && mounted) {
          setState(() {
            _currentPosition = _videoPlayerController.value.position;
          });
        }
      });
    } catch (e) {
      debugPrint("Error loading video: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // --- PRO FEATURE: Smart Play/Pause with Haptics ---
  void _togglePlayPause() {
    HapticFeedback.lightImpact(); // Apple-style tactile feel
    setState(() {
      if (_videoPlayerController.value.isPlaying) {
        _videoPlayerController.pause();
        _animationController.reverse();
      } else {
        _videoPlayerController.play();
        _animationController.forward();
      }
      _showPlayPauseIcon = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showPlayPauseIcon = false);
    });
  }

  // --- PRO FEATURE: YouTube Style Double Tap Seek ---
  void _handleDoubleTap() {
    HapticFeedback.mediumImpact();
    final screenWidth = MediaQuery.of(context).size.width;
    final currentPos = _videoPlayerController.value.position;
    final maxDuration = _videoPlayerController.value.duration;

    // Tap on Left side (Rewind)
    if (_lastTapPosition.dx < screenWidth / 3) {
      final newPos = currentPos - const Duration(seconds: 10);
      _videoPlayerController.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
      _triggerSeekOverlay("-10s");
    }
    // Tap on Right side (Fast Forward)
    else if (_lastTapPosition.dx > screenWidth * (2 / 3)) {
      final newPos = currentPos + const Duration(seconds: 10);
      _videoPlayerController.seekTo(newPos > maxDuration ? maxDuration : newPos);
      _triggerSeekOverlay("+10s");
    }
  }

  void _triggerSeekOverlay(String text) {
    setState(() {
      _seekOverlayText = text;
      _showSeekOverlay = true;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showSeekOverlay = false);
    });
  }

  // --- PRO FEATURE: Mute/Unmute ---
  void _toggleMute() {
    HapticFeedback.selectionClick();
    setState(() {
      _isMuted = !_isMuted;
      _videoPlayerController.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  // --- EXISTING DOWNLOAD/DELETE LOGIC ---
  Future<void> _downloadVideo() async {
    setState(() => _isDownloading = true);
    try {
      final response = await http.get(Uri.parse(widget.videoUrl));
      if (kIsWeb) {
        await FileSaver.instance.saveFile(name: 'boitex_video_${DateTime.now().millisecondsSinceEpoch}', bytes: response.bodyBytes, ext: 'mp4', mimeType: MimeType.mpeg);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/boitex_video.mp4');
        await file.writeAsBytes(response.bodyBytes);
        await Gal.putVideo(file.path);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vidéo téléchargée avec succès !'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _deleteVideo() {
    if (widget.onDelete != null) {
      widget.onDelete!();
      Navigator.of(context).pop();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _videoPlayerController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. VIDEO LAYER WITH GESTURES
          if (!_isLoading && _videoPlayerController.value.isInitialized)
            GestureDetector(
              onTapDown: (details) => _lastTapPosition = details.localPosition,
              onTap: _togglePlayPause,
              onDoubleTap: _handleDoubleTap,
              // TikTok 2x Speed Long Press
              onLongPressStart: (_) {
                HapticFeedback.heavyImpact();
                _videoPlayerController.setPlaybackSpeed(2.0);
                setState(() => _isSpeedingUp = true);
              },
              onLongPressEnd: (_) {
                HapticFeedback.lightImpact();
                _videoPlayerController.setPlaybackSpeed(1.0);
                setState(() => _isSpeedingUp = false);
              },
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoPlayerController.value.size.width,
                    height: _videoPlayerController.value.size.height,
                    child: VideoPlayer(_videoPlayerController),
                  ),
                ),
              ),
            )
          else
            const Center(child: CupertinoActivityIndicator(radius: 20, color: Colors.white)),

          // 2. TOP & BOTTOM GRADIENTS
          Positioned(
            top: 0, left: 0, right: 0, height: 140,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.7), Colors.transparent])),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0, height: 150,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])),
              ),
            ),
          ),

          // 3. TOP ACTION BAR (Back + Speed Indicator)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16, right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGlassButton(icon: CupertinoIcons.back, onTap: () => Navigator.of(context).pop(), size: 45),

                // 2x Speed Pill Badge
                AnimatedOpacity(
                  opacity: _isSpeedingUp ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.3))),
                    child: const Row(
                      children: [
                        Text("2x Speed", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(CupertinoIcons.forward_fill, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 45), // Balancing spacer
              ],
            ),
          ),

          // 4. FLOATING RIGHT SIDEBAR (Mute, Download, Delete)
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSidebarButton(
                  icon: _isMuted ? CupertinoIcons.volume_off : CupertinoIcons.volume_up,
                  label: _isMuted ? "Muted" : "Audio",
                  onTap: _toggleMute,
                ),
                const SizedBox(height: 24),
                _buildSidebarButton(
                  icon: _isDownloading ? CupertinoIcons.cloud_download : CupertinoIcons.arrow_down_to_line,
                  label: "Save",
                  onTap: _downloadVideo,
                  isLoading: _isDownloading,
                ),
                if (widget.onDelete != null) ...[
                  const SizedBox(height: 24),
                  _buildSidebarButton(icon: CupertinoIcons.trash, label: "Delete", onTap: _deleteVideo, color: Colors.redAccent),
                ]
              ],
            ),
          ),

          // 5. CENTER PLAY/PAUSE & SEEK OVERLAYS
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Play/Pause Icon
                AnimatedOpacity(
                  opacity: _showPlayPauseIcon ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                    child: Icon(_videoPlayerController.value.isPlaying ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill, color: Colors.white.withOpacity(0.8), size: 50),
                  ),
                ),
                // +/- 10s Text Overlay
                AnimatedOpacity(
                  opacity: _showSeekOverlay ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(30)),
                    child: Text(_seekOverlayText, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          // 6. PREMIUM SCRUBBER & TIMELINE
          if (_videoPlayerController.value.isInitialized)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 10,
              left: 16, right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedOpacity(
                    opacity: _isDragging ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.2))),
                            child: Text("${_formatDuration(_currentPosition)} / ${_formatDuration(_videoPlayerController.value.duration)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 14)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: _isDragging ? 6.0 : 3.0,
                      activeTrackColor: Colors.white, inactiveTrackColor: Colors.white.withOpacity(0.3),
                      thumbColor: Colors.white, thumbShape: RoundSliderThumbShape(enabledThumbRadius: _isDragging ? 8.0 : 5.0),
                      overlayColor: Colors.white.withOpacity(0.2), overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
                    ),
                    child: Slider(
                      value: _currentPosition.inMilliseconds.toDouble().clamp(0.0, _videoPlayerController.value.duration.inMilliseconds.toDouble()),
                      min: 0.0, max: _videoPlayerController.value.duration.inMilliseconds.toDouble(),
                      onChanged: (value) {
                        setState(() => _currentPosition = Duration(milliseconds: value.toInt()));
                        _videoPlayerController.seekTo(_currentPosition);
                      },
                      onChangeStart: (value) {
                        HapticFeedback.lightImpact(); // Haptic on grab
                        setState(() => _isDragging = true);
                        _videoPlayerController.pause();
                      },
                      onChangeEnd: (value) {
                        HapticFeedback.lightImpact(); // Haptic on release
                        setState(() => _isDragging = false);
                        _videoPlayerController.play();
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- UI Helpers ---
  Widget _buildGlassButton({required IconData icon, required VoidCallback onTap, double size = 50}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
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
          onTap: isLoading ? null : () {
            HapticFeedback.lightImpact();
            onTap();
          },
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
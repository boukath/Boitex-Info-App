// lib/widgets/voice_message_bubble.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.audioUrl,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      // Listen to player state changes
      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _isPlaying = false;
              _audioPlayer.seek(Duration.zero);
              _audioPlayer.pause();
            }
          });
        }
      });

      // Listen to position changes for the slider
      _audioPlayer.positionStream.listen((pos) {
        if (mounted) {
          setState(() => _position = pos);
        }
      });

      // Listen to duration changes
      _audioPlayer.durationStream.listen((d) {
        if (mounted && d != null) {
          setState(() => _duration = d);
        }
      });

    } catch (e) {
      debugPrint("Error initializing audio: $e");
    }
  }

  Future<void> _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      // Load source if not loaded yet (lazy loading saves bandwidth)
      if (_duration == Duration.zero) {
        setState(() => _isLoading = true);
        try {
          await _audioPlayer.setUrl(widget.audioUrl);
        } catch (e) {
          debugPrint("Error loading audio URL: $e");
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
      await _audioPlayer.play();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : Colors.black87;
    final subColor = widget.isMe ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      width: 200, // Fixed width for voice messages
      child: Row(
        children: [
          GestureDetector(
            onTap: _playPause,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
                  : Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: color,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Simulating a waveform with a linear progress indicator
                LinearProgressIndicator(
                  value: _duration.inMilliseconds > 0
                      ? _position.inMilliseconds / _duration.inMilliseconds
                      : 0.0,
                  backgroundColor: widget.isMe
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4, // Thicker line
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(_position.inSeconds == 0 && !_isPlaying
                      ? _duration // Show total duration if not started
                      : _position),
                  style: TextStyle(
                    color: subColor,
                    fontSize: 10,
                    fontFamily: "FiraCode",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
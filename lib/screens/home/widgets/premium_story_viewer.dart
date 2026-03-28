// lib/screens/home/widgets/premium_story_viewer.dart

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:boitex_info_app/models/story_item.dart';

// 🚀 NEW IMPORTS FOR FIRESTORE AND AUTH
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PremiumStoryViewer extends StatefulWidget {
  final List<StoryItem> stories;

  const PremiumStoryViewer({super.key, required this.stories});

  @override
  State<PremiumStoryViewer> createState() => _PremiumStoryViewerState();
}

class _PremiumStoryViewerState extends State<PremiumStoryViewer> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentIndex = 0;

  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();

    // 🚀 1. SORT: Oldest first, newest last (Chronological order)
    widget.stories.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 🚀 2. FIND STARTING INDEX: Find the first story the user HAS NOT seen
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      int firstUnseenIndex = widget.stories.indexWhere((s) => !s.viewedBy.contains(currentUser.uid));
      if (firstUnseenIndex != -1) {
        _currentIndex = firstUnseenIndex; // Jump to first unseen
      } else {
        _currentIndex = 0; // If all viewed, start from the beginning
      }
    }

    // 🚀 3. Initialize PageController exactly at the unseen story
    _pageController = PageController(initialPage: _currentIndex);

    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 5));

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 🚀 FIX: If it's a video, DO NOT skip automatically.
        // We let the _videoListener handle the skip when the video actually ends!
        if (_videoController == null) {
          _nextStory();
        }
      }
    });

    _loadStory();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
  }

  // 🚀 4. NEW METHOD: Update Firestore when a story is viewed
  void _markAsSeen(int index) {
    if (index < 0 || index >= widget.stories.length) return;

    final story = widget.stories[index];
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null && !story.viewedBy.contains(currentUser.uid)) {
      // Update local UI state immediately to prevent lag
      setState(() {
        story.viewedBy.add(currentUser.uid);
      });
      // Update Firestore silently in the background
      FirebaseFirestore.instance.collection('daily_stories').doc(story.id).update({
        'viewedBy': FieldValue.arrayUnion([currentUser.uid])
      }).catchError((e) => debugPrint("Failed to update view status: $e"));
    }
  }

  // 🚀 THE SMART VIDEO LISTENER
  // This guarantees the progress bar perfectly matches the video
  // and waits for the video to end before skipping.
  void _videoListener() {
    if (!mounted || _videoController == null || !_videoController!.value.isInitialized) return;

    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    final isBuffering = _videoController!.value.isBuffering;
    final isPlaying = _videoController!.value.isPlaying;

    // 1. Pause progress bar if video is buffering!
    if (isBuffering && _animController.isAnimating) {
      _animController.stop();
    } else if (!isBuffering && isPlaying && !_animController.isAnimating) {
      _animController.forward();
    }

    // 2. Keep the progress bar synced if it drifts
    if (duration.inMilliseconds > 0) {
      final animPosition = duration.inMilliseconds * _animController.value;
      if ((animPosition - position.inMilliseconds).abs() > 500) {
        _animController.value = position.inMilliseconds / duration.inMilliseconds;
      }
    }

    // 3. EXACTLY when the video ends, skip to the next story
    if (position >= duration && duration > Duration.zero) {
      _videoController!.removeListener(_videoListener);
      _nextStory();
    }
  }

  void _nextStory() {
    _animController.stop();
    _videoController?.removeListener(_videoListener);

    if (_currentIndex + 1 < widget.stories.length) {
      setState(() => _currentIndex += 1);
      _loadStory(animateToPage: true);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prevStory() {
    _animController.stop();
    _videoController?.removeListener(_videoListener);

    if (_currentIndex - 1 >= 0) {
      setState(() => _currentIndex -= 1);
      _loadStory(animateToPage: true);
    } else {
      _loadStory(); // restart current
    }
  }

  void _loadStory({bool animateToPage = false}) {
    _animController.stop();
    _animController.value = 0.0;

    // Clean up old video
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _videoController = null;

    // 🚀 Mark the current story as seen instantly
    _markAsSeen(_currentIndex);

    if (animateToPage) {
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 1),
        curve: Curves.easeInOut,
      );
    }

    final story = widget.stories[_currentIndex];

    // --- VIDEO HANDLING ---
    if (story.mediaUrls.isNotEmpty) {
      final url = story.mediaUrls.first;
      final urlLower = url.split('?').first.toLowerCase();

      if (urlLower.endsWith('.mp4') || urlLower.endsWith('.mov') || urlLower.endsWith('.mkv')) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
              _videoController!.setVolume(1.0);
              _videoController!.addListener(_videoListener); // Add the smart listener
              _videoController!.play();

              _animController.duration = _videoController!.value.duration;
              _animController.forward();
            }
          }).catchError((_) {
            // Fallback to 5s if video breaks
            if (mounted) {
              _animController.duration = const Duration(seconds: 5);
              _animController.forward();
            }
          });
        return;
      }
    }

    // --- IMAGE / TEXT HANDLING (5 Seconds) ---
    _animController.duration = const Duration(seconds: 5);
    _animController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double dx = details.globalPosition.dx;

    if (dx < screenWidth / 3) {
      _prevStory();
    } else {
      _nextStory();
    }
  }

  void _pauseStory() {
    _animController.stop();
    _videoController?.pause();
  }

  void _resumeStory() {
    if (_videoController != null) {
      _videoController!.play(); // _videoListener will automatically resume the animController
    } else {
      if (!_animController.isCompleted) {
        _animController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: _onTapUp,
        onLongPressDown: (_) => _pauseStory(),
        onLongPressUp: () => _resumeStory(),
        onLongPressCancel: () => _resumeStory(),

        child: Stack(
          fit: StackFit.expand,
          children: [
            // --- 1. THE DYNAMIC BACKGROUND ---
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.stories.length,
              itemBuilder: (context, i) {
                final currentStory = widget.stories[i];
                return _StoryBackgroundMedia(
                  story: currentStory,
                  videoController: i == _currentIndex ? _videoController : null,
                );
              },
            ),

            // --- 2. FOREGROUND CONTENT & PROGRESS BARS ---
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🚀 INSTAGRAM PROGRESS BARS
                    Row(
                      children: widget.stories.asMap().map((i, e) {
                        return MapEntry(
                          i,
                          AnimatedBar(
                            animController: _animController,
                            position: i,
                            currentIndex: _currentIndex,
                          ),
                        );
                      }).values.toList(),
                    ),
                    const SizedBox(height: 16),

                    // --- HEADER: User & Time ---
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          radius: 18,
                          child: Text(
                            story.userName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              story.userName,
                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Text(
                              timeago.format(story.timestamp, locale: 'fr'),
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // --- BADGE ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.orangeAccent.withOpacity(0.4), blurRadius: 10)],
                      ),
                      child: Text(
                        story.badgeText.toUpperCase(),
                        style: GoogleFonts.poppins(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- STORE INFO WITH BEAUTIFUL 4K LOGO ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (story.storeLogoUrl != null && story.storeLogoUrl!.isNotEmpty)
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: CachedNetworkImage(
                                imageUrl: story.storeLogoUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const CupertinoActivityIndicator(),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blueGrey,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(CupertinoIcons.building_2_fill, color: Colors.white),
                          ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                story.storeName.split(' - ').first,
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.1),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(CupertinoIcons.location_solid, color: Colors.blueAccent, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    story.location,
                                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Colors.white24, height: 1),
                    ),

                    // --- PROBLEM DESCRIPTION / COMPLETION NOTES ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5), // Slightly darker background for better reading
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1))
                      ),
                      child: Text(
                        // 🚀 PRO UI TWEAK: Don't put quotes around the structured Completion reports
                        story.type == 'intervention_completed'
                            ? story.description
                            : "\"${story.description}\"",
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15, // Slightly smaller to fit the rich text
                            height: 1.4,
                            // 🚀 PRO UI TWEAK: Normal text for completion, Italic for problems
                            fontStyle: story.type == 'intervention_completed'
                                ? FontStyle.normal
                                : FontStyle.italic
                        ),
                        maxLines: 8, // 🚀 UPDATED: Increased from 4 to 8 so the 'Solution' text fits!
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🚀 CLEANER STATELESS WIDGET FOR MEDIA (FIXED BLUR)
class _StoryBackgroundMedia extends StatelessWidget {
  final StoryItem story;
  final VideoPlayerController? videoController;

  const _StoryBackgroundMedia({required this.story, this.videoController});

  @override
  Widget build(BuildContext context) {
    String? mediaUrl = story.mediaUrls.isNotEmpty ? story.mediaUrls.first : null;
    bool isVideo = videoController != null && videoController!.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. RENDER MEDIA
        if (isVideo)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: videoController!.value.size.width,
                height: videoController!.value.size.height,
                child: VideoPlayer(videoController!),
              ),
            ),
          )
        else if (mediaUrl != null && !mediaUrl.toLowerCase().endsWith('.mp4') && !mediaUrl.toLowerCase().endsWith('.mov'))
          CachedNetworkImage(
            imageUrl: mediaUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(child: CupertinoActivityIndicator(color: Colors.white)),
          )
        // FALLBACK: Store Logo heavily blurred
        else if (story.storeLogoUrl != null && story.storeLogoUrl!.isNotEmpty)
            Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(imageUrl: story.storeLogoUrl!, fit: BoxFit.cover),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
                  child: Container(color: Colors.black.withOpacity(0.4)),
                ),
              ],
            )
          else
            Container(color: const Color(0xFF1E1E1E)),

        // 2. CINEMATIC GRADIENT OVERLAY (🚀 FIXED TO BE CRYSTAL CLEAR IN THE MIDDLE)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.6), // Top shadow for header & bars
                Colors.transparent,            // COMPLETELY CLEAR MIDDLE
                Colors.transparent,            // COMPLETELY CLEAR MIDDLE
                Colors.black.withOpacity(0.9), // Bottom shadow for text
              ],
              // 🚀 Leaves the middle 60% of the screen perfectly clear!
              stops: const [0.0, 0.15, 0.70, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

// 🚀 CUSTOM WIDGET FOR THE ANIMATED TOP BARS
class AnimatedBar extends StatelessWidget {
  final AnimationController animController;
  final int position;
  final int currentIndex;

  const AnimatedBar({
    super.key,
    required this.animController,
    required this.position,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                _buildContainer(
                  double.infinity,
                  position < currentIndex ? Colors.white : Colors.white.withOpacity(0.3),
                ),
                if (position == currentIndex)
                  AnimatedBuilder(
                    animation: animController,
                    builder: (context, child) {
                      return _buildContainer(
                        constraints.maxWidth * animController.value,
                        Colors.white,
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Container _buildContainer(double width, Color color) {
    return Container(
      height: 3.0,
      width: width,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black26, width: 0.5),
        borderRadius: BorderRadius.circular(3.0),
      ),
    );
  }
}
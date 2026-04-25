// lib/screens/home/widgets/premium_story_viewer.dart

import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:boitex_info_app/models/story_item.dart';

// 🚀 IMPORTS FOR FIRESTORE, AUTH, AND DEEP LINKING
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';

class PremiumStoryViewer extends StatefulWidget {
  final List<StoryItem> stories;

  const PremiumStoryViewer({super.key, required this.stories});

  @override
  State<PremiumStoryViewer> createState() => _PremiumStoryViewerState();
}

class _PremiumStoryViewerState extends State<PremiumStoryViewer> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentIndex = 0;

  late List<StoryItem> _stories;
  VideoPlayerController? _videoController;
  bool _isTextExpanded = false;

  bool _isMediaReady = false; // 🚀 NEW: Tracks if image/video is loaded and ready

  final List<Widget> _floatingReactions = [];

  // 🚀 FIXED: Made static so it remembers what you read even after closing the story!
  static final Map<String, int> _globalReadCommentsCount = {};

  @override
  void initState() {
    super.initState();

    // FLATTEN MULTI-MEDIA STORIES
    _stories = [];
    for (var originalStory in widget.stories) {
      if (originalStory.mediaUrls.length > 1) {
        for (var i = 0; i < originalStory.mediaUrls.length; i++) {
          _stories.add(
            StoryItem(
              id: '${originalStory.id}_part_$i',
              interventionId: originalStory.interventionId,
              installationId: originalStory.installationId,
              userId: originalStory.userId,
              userName: originalStory.userName,
              storeName: originalStory.storeName,
              storeLogoUrl: originalStory.storeLogoUrl,
              location: originalStory.location,
              description: originalStory.description,
              badgeText: originalStory.badgeText,
              mediaUrls: [originalStory.mediaUrls[i]],
              timestamp: originalStory.timestamp.add(Duration(milliseconds: i)),
              type: originalStory.type,
              viewedBy: originalStory.viewedBy,
              reactions: originalStory.reactions,
              comments: originalStory.comments,
            ),
          );
        }
      } else {
        _stories.add(originalStory);
      }
    }

    _stories.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      int firstUnseenIndex = _stories.indexWhere((s) => !s.viewedBy.contains(currentUser.uid));
      if (firstUnseenIndex != -1) {
        _currentIndex = firstUnseenIndex;
      } else {
        _currentIndex = 0;
      }
    }

    _pageController = PageController(initialPage: _currentIndex);
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 5));

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
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

  Future<void> _markAsSeen(int index) async {
    if (index < 0 || index >= _stories.length) return;

    final story = _stories[index];
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || story.viewedBy.contains(currentUser.uid)) return;

    if (mounted) setState(() => story.viewedBy.add(currentUser.uid));

    try {
      final originalDocId = story.id.split('_part_').first;
      await FirebaseFirestore.instance.collection('daily_stories').doc(originalDocId).set({
        'viewedBy': FieldValue.arrayUnion([currentUser.uid])
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating views: $e");
    }
  }

  void _showCommentsSheet(StoryItem story) {
    _pauseStory();

    String originalId = story.id.split('_part_').first;
    setState(() => _globalReadCommentsCount[originalId] = story.comments.length);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CommentsSheet(
          story: story,
          onCommentAdded: (text) async {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser == null) return;

            String userName = currentUser.displayName ?? 'Utilisateur';
            try {
              final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
              if (userDoc.exists) userName = userDoc.data()?['fullName'] ?? userName;
            } catch (_) {}

            final newComment = {
              'uid': currentUser.uid,
              'name': userName,
              'text': text,
              'timestamp': DateTime.now().toIso8601String(),
            };

            setState(() {
              story.comments.add(newComment);
              _globalReadCommentsCount[originalId] = story.comments.length;
            });

            try {
              await FirebaseFirestore.instance.collection('daily_stories').doc(originalId).update({
                'comments': FieldValue.arrayUnion([newComment])
              });
            } catch (e) {
              debugPrint("Error saving comment: $e");
            }
          },
        );
      },
    ).then((_) => _resumeStory());
  }

  void _showEmojiPickerSheet(StoryItem story) {
    _pauseStory();
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Padding(
          padding: const EdgeInsets.only(bottom: 30.0, left: 16, right: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['❤️', '🔥', '👏', '😮', '💯'].map((emoji) => GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _sendReaction(emoji);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 34)),
                  )).toList(),
                ),
              ),
            ),
          ),
        )
    ).then((_) => _resumeStory());
  }

  Future<void> _sendReaction(String emoji) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final story = _stories[_currentIndex];
    final key = UniqueKey();

    String userName = currentUser.displayName ?? '';
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) userName = userDoc.data()?['fullName'] ?? userDoc.data()?['displayName'] ?? userName;
    } catch (e) { debugPrint("Error: $e"); }

    if (userName.trim().isEmpty) userName = 'Utilisateur';

    setState(() {
      _floatingReactions.add(
        FloatingReaction(
          key: key,
          emoji: emoji,
          onComplete: () {
            if (mounted) setState(() => _floatingReactions.removeWhere((w) => w.key == key));
          },
        ),
      );

      story.reactions.add({
        'uid': currentUser.uid,
        'name': userName,
        'emoji': emoji,
      });
    });

    try {
      final originalDocId = story.id.split('_part_').first;
      await FirebaseFirestore.instance.collection('daily_stories').doc(originalDocId).set({
        'reactions': FieldValue.arrayUnion([{
          'uid': currentUser.uid,
          'name': userName,
          'emoji': emoji,
        }])
      }, SetOptions(merge: true));
    } catch (e) {}
  }

  void _showReactionsList(StoryItem story) {
    if (story.reactions.isEmpty) return;

    _pauseStory();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(10)),
              ),
              Text("Réactions", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: story.reactions.length,
                  itemBuilder: (context, index) {
                    final r = story.reactions[index];
                    return ListTile(
                      leading: Text(r['emoji'], style: const TextStyle(fontSize: 28)),
                      title: Text(r['name'] ?? 'Utilisateur', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) => _resumeStory());
  }

  // 🚀 FIXED: Video Buffering strict pausing
  void _videoListener() {
    if (!mounted || _videoController == null || !_videoController!.value.isInitialized) return;

    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    final isBuffering = _videoController!.value.isBuffering;
    final isPlaying = _videoController!.value.isPlaying;

    // Strictly pause animation if video is buffering or stopped
    if (isBuffering || !isPlaying) {
      if (_animController.isAnimating) _animController.stop();
    } else if (!isBuffering && isPlaying) {
      // Resume animation ONLY if playing and not buffering
      if (!_animController.isAnimating) _animController.forward();
    }

    if (duration.inMilliseconds > 0) {
      final animPosition = duration.inMilliseconds * _animController.value;
      if ((animPosition - position.inMilliseconds).abs() > 500) {
        _animController.value = position.inMilliseconds / duration.inMilliseconds;
      }
    }

    if (position >= duration && duration > Duration.zero) {
      _videoController!.removeListener(_videoListener);
      _nextStory();
    }
  }

  // 🚀 NEW: Callback when Image has fully loaded from network
  void _onImageReady() {
    if (!mounted) return;
    if (!_isMediaReady) {
      setState(() {
        _isMediaReady = true;
      });
      // Only start the progress bar if it's not a video (video is handled by listener)
      if (_videoController == null && !_animController.isAnimating) {
        _animController.forward();
      }
    }
  }

  Future<void> _openDetails() async {
    _pauseStory();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    final story = _stories[_currentIndex];
    DocumentSnapshot<Map<String, dynamic>>? targetDoc;

    try {
      if (story.type == 'installation') {
        if (story.installationId != null && story.installationId!.isNotEmpty) {
          String cleanId = story.installationId!.replaceAll('_completed', '');
          targetDoc = await FirebaseFirestore.instance.collection('installations').doc(cleanId).get();
        }

        if (targetDoc == null || !targetDoc.exists) {
          String cleanId = story.id.split('_part_').first.replaceAll('_completed', '');
          targetDoc = await FirebaseFirestore.instance.collection('installations').doc(cleanId).get();
        }

        String currentUserRole = 'Technicien';
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            currentUserRole = userDoc.data()?['role'] ?? 'Technicien';
          }
        }

        if (!mounted) return;
        Navigator.pop(context);

        if (targetDoc != null && targetDoc.exists) {
          await Navigator.push(context, MaterialPageRoute(
            builder: (context) => InstallationDetailsPage(
                installationDoc: targetDoc!,
                userRole: currentUserRole
            ),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("L'installation originale est introuvable."), backgroundColor: Colors.orange));
        }
        _resumeStory();
        return;
      }

      if (story.interventionId != null && story.interventionId!.isNotEmpty) {
        String cleanId = story.interventionId!.replaceAll('_completed', '');
        targetDoc = await FirebaseFirestore.instance.collection('interventions').doc(cleanId).get();
      }

      if (targetDoc == null || !targetDoc.exists) {
        String cleanId = story.id.split('_part_').first.replaceAll('_completed', '');
        targetDoc = await FirebaseFirestore.instance.collection('interventions').doc(cleanId).get();
      }

      if ((targetDoc == null || !targetDoc.exists) && story.badgeText.contains('INT-')) {
        String extractedCode = story.badgeText.split(' - ').first.trim();
        final query = await FirebaseFirestore.instance
            .collection('interventions')
            .where('interventionCode', isEqualTo: extractedCode)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) targetDoc = query.docs.first;
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (targetDoc != null && targetDoc.exists) {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => InterventionDetailsPage(interventionDoc: targetDoc!)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Le ticket original est introuvable."), backgroundColor: Colors.orange));
      }
      _resumeStory();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _resumeStory();
    }
  }

  void _nextStory() {
    _animController.stop();
    _videoController?.removeListener(_videoListener);

    final currentUser = FirebaseAuth.instance.currentUser;
    int nextUnseenIndex = -1;

    if (currentUser != null) {
      for (int i = _currentIndex + 1; i < _stories.length; i++) {
        if (!_stories[i].viewedBy.contains(currentUser.uid)) {
          nextUnseenIndex = i;
          break;
        }
      }
    }

    if (nextUnseenIndex != -1) {
      setState(() => _currentIndex = nextUnseenIndex);
      _loadStory(animateToPage: true);
    } else if (_currentIndex + 1 < _stories.length) {
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
      _loadStory();
    }
  }

  void _loadStory({bool animateToPage = false}) {
    _animController.stop();
    _animController.value = 0.0;

    if (mounted) {
      setState(() {
        _isTextExpanded = false;
        _isMediaReady = false; // 🚀 Reset readiness when changing slides
        _floatingReactions.clear();
      });
    }

    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _videoController = null;

    _markAsSeen(_currentIndex);

    if (animateToPage) {
      _pageController.animateToPage(_currentIndex, duration: const Duration(milliseconds: 1), curve: Curves.easeInOut);
    }

    final story = _stories[_currentIndex];

    if (story.mediaUrls.isNotEmpty) {
      final urlLower = story.mediaUrls.first.split('?').first.toLowerCase();
      if (urlLower.endsWith('.mp4') || urlLower.endsWith('.mov') || urlLower.endsWith('.mkv')) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(story.mediaUrls.first))
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                _isMediaReady = true;
              });
              _videoController!.setVolume(1.0);
              _videoController!.addListener(_videoListener);
              _videoController!.play();
              _animController.duration = _videoController!.value.duration;
              // No forward() here, listener handles it.
            }
          }).catchError((_) {
            if (mounted) {
              setState(() => _isMediaReady = true);
              _animController.duration = const Duration(seconds: 5);
              _animController.forward();
            }
          });
        return;
      }
    }

    _animController.duration = const Duration(seconds: 5);
    // 🚀 Removed forward() here, the _onImageReady callback will trigger it.
  }

  void _onTapUp(TapUpDetails details) {
    if (_isTextExpanded) {
      setState(() { _isTextExpanded = false; _resumeStory(); });
      return;
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dy > MediaQuery.of(context).size.height * 0.75) return;

    if (details.globalPosition.dx < screenWidth / 3) _prevStory();
    else _nextStory();
  }

  void _pauseStory() {
    _animController.stop();
    _videoController?.pause();
  }

  void _resumeStory() {
    if (_videoController != null) {
      _videoController!.play();
    } else if (!_animController.isCompleted && _isMediaReady) {
      // 🚀 Only resume timer if the image is actually loaded
      _animController.forward();
    }
  }

  Widget _buildGlassAction({required IconData icon, required String label, required VoidCallback onTap, VoidCallback? onLongPress, Widget? badge}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                  ),
                ),
                if (badge != null)
                  Positioned(right: -2, top: -2, child: badge),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 4)]
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final story = _stories[_currentIndex];
    String originalId = story.id.split('_part_').first;

    int totalComments = story.comments.length;
    int seenComments = _globalReadCommentsCount[originalId] ?? 0;
    int unreadCount = totalComments - seenComments;
    if (unreadCount < 0) unreadCount = 0;

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
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _stories.length,
              itemBuilder: (context, i) {
                return _StoryBackgroundMedia(
                  story: _stories[i],
                  videoController: i == _currentIndex ? _videoController : null,
                  onMediaReady: i == _currentIndex ? _onImageReady : null, // 🚀 NEW: Pass callback
                );
              },
            ),

            ..._floatingReactions,

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: _stories.asMap().map((i, e) {
                        return MapEntry(i, AnimatedBar(animController: _animController, position: i, currentIndex: _currentIndex));
                      }).values.toList(),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          radius: 18,
                          child: Text(story.userName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(story.userName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14, shadows: const [Shadow(color: Colors.black54, blurRadius: 4)])),
                            Text(timeago.format(story.timestamp, locale: 'fr'), style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, shadows: const [Shadow(color: Colors.black54, blurRadius: 4)])),
                          ],
                        ),
                        const Spacer(),
                        IconButton(icon: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context)),
                      ],
                    ),

                    const Spacer(),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      story.badgeText.toUpperCase(),
                                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (story.storeLogoUrl != null && story.storeLogoUrl!.isNotEmpty)
                                    Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle, color: Colors.white,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: CachedNetworkImage(imageUrl: story.storeLogoUrl!, fit: BoxFit.cover, placeholder: (context, url) => const CupertinoActivityIndicator()),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white30, border: Border.all(color: Colors.white, width: 2)),
                                      child: const Icon(CupertinoIcons.building_2_fill, color: Colors.white, size: 20),
                                    ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          story.storeName.split(' - ').first,
                                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black87, blurRadius: 8)]),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(CupertinoIcons.location_solid, color: Colors.white, size: 12),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(story.location, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, shadows: const [Shadow(color: Colors.black87, blurRadius: 8)]), overflow: TextOverflow.ellipsis),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isTextExpanded = !_isTextExpanded;
                                    if (_isTextExpanded) _pauseStory(); else _resumeStory();
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  constraints: BoxConstraints(maxHeight: _isTextExpanded ? MediaQuery.of(context).size.height * 0.4 : 60),
                                  child: SingleChildScrollView(
                                    physics: _isTextExpanded ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          story.description,
                                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, height: 1.4, shadows: const [Shadow(color: Colors.black87, blurRadius: 6)]),
                                          maxLines: _isTextExpanded ? null : 2,
                                          overflow: _isTextExpanded ? null : TextOverflow.ellipsis,
                                        ),
                                        if (!_isTextExpanded && story.description.length > 70)
                                          Text("Voir plus", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black87, blurRadius: 6)])),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildGlassAction(
                              icon: CupertinoIcons.doc_text_viewfinder,
                              label: 'Détails',
                              onTap: _openDetails,
                            ),
                            _buildGlassAction(
                              icon: CupertinoIcons.chat_bubble_fill,
                              label: totalComments > 0 ? '$totalComments' : 'Chat',
                              onTap: () => _showCommentsSheet(story),
                              badge: unreadCount > 0 ? Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ) : null,
                            ),
                            _buildGlassAction(
                              icon: CupertinoIcons.heart_fill,
                              label: story.reactions.isNotEmpty ? '${story.reactions.length}' : 'Réagir',
                              onTap: () => _showEmojiPickerSheet(story),
                              onLongPress: () => _showReactionsList(story),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
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

class FloatingReaction extends StatefulWidget {
  final String emoji;
  final VoidCallback onComplete;

  const FloatingReaction({super.key, required this.emoji, required this.onComplete});

  @override
  State<FloatingReaction> createState() => _FloatingReactionState();
}

class _FloatingReactionState extends State<FloatingReaction> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _positionAnimation = Tween<double>(
        begin: 0,
        end: MediaQueryData.fromWindow(WidgetsBinding.instance.window).size.height * 0.4
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0))
    );

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double xOffset = math.sin(_controller.value * math.pi * 3) * 30;

        return Positioned(
          bottom: 150 + _positionAnimation.value,
          right: 30 + xOffset,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Text(
                widget.emoji,
                style: const TextStyle(fontSize: 45, shadows: [Shadow(color: Colors.black45, blurRadius: 10)])
            ),
          ),
        );
      },
    );
  }
}

// 🚀 CLEANER STATELESS WIDGET FOR MEDIA
class _StoryBackgroundMedia extends StatelessWidget {
  final StoryItem story;
  final VideoPlayerController? videoController;
  final VoidCallback? onMediaReady; // 🚀 NEW: Callback

  const _StoryBackgroundMedia({required this.story, this.videoController, this.onMediaReady});

  @override
  Widget build(BuildContext context) {
    String? mediaUrl = story.mediaUrls.isNotEmpty ? story.mediaUrls.first : null;
    bool isVideoState = videoController != null && videoController!.value.isInitialized;

    String? cleanUrl = mediaUrl?.split('?').first.toLowerCase();
    bool isVideoFile = cleanUrl != null &&
        (cleanUrl.endsWith('.mp4') || cleanUrl.endsWith('.mov') || cleanUrl.endsWith('.mkv'));

    // Trigger ready state immediately if video is already initialized.
    if (isVideoState && onMediaReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onMediaReady!());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (isVideoState)
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
        else if (isVideoFile)
          const Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 16))
        else if (mediaUrl != null && !isVideoFile)
            CachedNetworkImage(
                imageUrl: mediaUrl,
                fit: BoxFit.cover,
                // 🚀 FIXED: Correct parameter name is `image`, not `imageProvider`
                imageBuilder: (context, imageProvider) {
                  if (onMediaReady != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => onMediaReady!());
                  }
                  return Image(image: imageProvider, fit: BoxFit.cover);
                },
                placeholder: (context, url) => const Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 16)),
                errorWidget: (context, url, error) {
                  if (onMediaReady != null) WidgetsBinding.instance.addPostFrameCallback((_) => onMediaReady!()); // Fail safe
                  return Container(
                    color: const Color(0xFF1E1E1E),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.white54, size: 40),
                        SizedBox(height: 8),
                        Text("Média indisponible", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  );
                }
            )
          else if (story.storeLogoUrl != null && story.storeLogoUrl!.isNotEmpty)
              Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: story.storeLogoUrl!,
                    fit: BoxFit.cover,
                    // 🚀 FIXED: Correct parameter name is `image`, not `imageProvider`
                    imageBuilder: (context, imageProvider) {
                      if (onMediaReady != null) WidgetsBinding.instance.addPostFrameCallback((_) => onMediaReady!());
                      return Image(image: imageProvider, fit: BoxFit.cover);
                    },
                    errorWidget: (context, url, error) {
                      if (onMediaReady != null) WidgetsBinding.instance.addPostFrameCallback((_) => onMediaReady!());
                      return const SizedBox();
                    },
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
                    child: Container(color: Colors.black.withOpacity(0.4)),
                  ),
                ],
              )
            else
              Builder(
                  builder: (context) {
                    if (onMediaReady != null) WidgetsBinding.instance.addPostFrameCallback((_) => onMediaReady!());
                    return Container(color: const Color(0xFF1E1E1E));
                  }
              ),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.9),
              ],
              stops: const [0.0, 0.20, 0.60, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

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

class _CommentsSheet extends StatefulWidget {
  final StoryItem story;
  final Function(String) onCommentAdded;

  const _CommentsSheet({required this.story, required this.onCommentAdded});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();

  void _submit() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onCommentAdded(_controller.text.trim());
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            color: Colors.black.withOpacity(0.6),
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(10)),
                ),
                Text("Commentaires", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24),

                Expanded(
                  child: widget.story.comments.isEmpty
                      ? const Center(child: Text("Soyez le premier à commenter !", style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: widget.story.comments.length,
                    itemBuilder: (context, index) {
                      final comment = widget.story.comments[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.blueAccent.withOpacity(0.5),
                              child: Text(comment['name'].toString().substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comment['name'], style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text(comment['text'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                      color: Colors.black54,
                      border: Border(top: BorderSide(color: Colors.white12))
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: "Ajouter un commentaire...",
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _submit,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                          child: const Icon(CupertinoIcons.paperplane_fill, color: Colors.white, size: 18),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
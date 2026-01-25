// lib/screens/service_technique/installation_timeline_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'; // ☁️ Added for AI
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

// 📦 Import the models & widgets
import 'package:boitex_info_app/models/daily_log.dart';
import 'package:boitex_info_app/screens/service_technique/widgets/add_log_sheet.dart';
// 📦 Import the Report Page for navigation
import 'package:boitex_info_app/screens/service_technique/installation_report_page.dart';

// 📸 Import Media Viewers
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';

class InstallationTimelinePage extends StatefulWidget {
  final String installationId;
  final Map<String, dynamic> installationData;

  const InstallationTimelinePage({
    super.key,
    required this.installationId,
    required this.installationData,
  });

  @override
  State<InstallationTimelinePage> createState() => _InstallationTimelinePageState();
}

class _InstallationTimelinePageState extends State<InstallationTimelinePage> {
  // 🎨 Brand Colors
  final Color _primaryBlue = const Color(0xFF2962FF);
  final Color _bgLight = const Color(0xFFF4F6F9);

  // ⏳ State to track AI Processing
  bool _isGeneratingReport = false;

  @override
  Widget build(BuildContext context) {
    // 🛑 LOADING STATE: If AI is working, show a blocking screen
    if (_isGeneratingReport) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(strokeWidth: 4),
              ),
              const SizedBox(height: 32),
              Text(
                "L'IA analyse les logs...",
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "Génération du rapport technique en cours.\nVeuillez patienter.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // 🟢 NORMAL STATE
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Suivi d'Installation",
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              widget.installationData['clientName'] ?? 'Client Inconnu',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: _primaryBlue,
        elevation: 0,
        actions: [
          // 🏁 CLÔTURER BUTTON (Updated Logic)
          TextButton.icon(
            onPressed: () => _confirmFinalization(context),
            icon: const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
            label: Text(
              "CLÔTURER",
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // 📍 Sticky Header: Status & Info
          _buildStatusHeader(),

          // 📜 The Feed
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('installations')
                  .doc(widget.installationId)
                  .collection('daily_logs')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Erreur de chargement", style: TextStyle(color: Colors.red)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final log = DailyLog.fromFirestore(docs[index]);
                    final showHeader = _shouldShowDateHeader(docs, index);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader) _buildDateHeader(log.timestamp),
                        _DailyLogCard(log: log),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // 🚀 Quick Action Bar
      floatingActionButton: _buildQuickActions(),
    );
  }

  // ------------------------------------------------------------------------
  // 🧠 STEP 4 LOGIC: Finalize & AI Handover
  // ------------------------------------------------------------------------

  Future<void> _confirmFinalization(BuildContext context) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Clôturer l'intervention ?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          "L'IA va analyser tous les logs quotidiens, compiler les photos et générer un rapport de synthèse professionnel.\n\nCette action changera le statut en 'Terminée'.",
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Annuler", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check, color: Colors.white, size: 16),
            label: const Text("Générer le Rapport", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _triggerAIGeneration();
    }
  }

  Future<void> _triggerAIGeneration() async {
    setState(() => _isGeneratingReport = true);

    try {
      // 1. Trigger the Cloud Function
      await FirebaseFunctions.instance
          .httpsCallable('generateInstallationReport')
          .call({'installationId': widget.installationId});

      if (!mounted) return;

      setState(() => _isGeneratingReport = false);

      // 2. Navigate to the Final Report Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InstallationReportPage(
            installationId: widget.installationId,
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _isGeneratingReport = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur IA: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ------------------------------------------------------------------------
  // 🧩 UI COMPONENTS
  // ------------------------------------------------------------------------

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  "EN COURS",
                  style: GoogleFonts.poppins(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Icon(Icons.location_on, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            widget.installationData['storeLocation'] ?? "Unknown",
            style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Aucune activité",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
            ),
          ),
          Text(
            "Commencez par ajouter un log.",
            style: GoogleFonts.poppins(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    String label;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) {
      label = "Aujourd'hui";
    } else if (checkDate == yesterday) {
      label = "Hier";
    } else {
      label = DateFormat('EEEE d MMMM', 'fr_FR').format(date);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => AddLogSheet(installationId: widget.installationId),
            );
          },
          backgroundColor: _primaryBlue,
          icon: const Icon(Icons.add_comment, color: Colors.white),
          label: Text("AJOUTER UN LOG", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          mini: true,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => AddLogSheet(installationId: widget.installationId),
            );
          },
          backgroundColor: Colors.white,
          child: Icon(Icons.camera_alt, color: _primaryBlue),
        ),
      ],
    );
  }

  bool _shouldShowDateHeader(List<QueryDocumentSnapshot> docs, int index) {
    if (index == 0) return true;
    final current = (docs[index].data() as Map<String, dynamic>)['timestamp'] as Timestamp;
    final previous = (docs[index - 1].data() as Map<String, dynamic>)['timestamp'] as Timestamp;
    final currDate = current.toDate();
    final prevDate = previous.toDate();
    return currDate.day != prevDate.day || currDate.month != prevDate.month;
  }
}

// ------------------------------------------------------------------------
// 🃏 THE CARD WIDGET
// ------------------------------------------------------------------------

class _DailyLogCard extends StatelessWidget {
  final DailyLog log;
  const _DailyLogCard({required this.log});

  // Helper to detect video extensions
  bool _isVideo(String url) {
    final uri = Uri.parse(url);
    // Remove query params to see the real extension (e.g. .mp4?alt=media)
    final path = uri.path.toLowerCase();
    return path.contains('.mp4') ||
        path.contains('.mov') ||
        path.contains('.avi') ||
        path.contains('.mkv');
  }

  @override
  Widget build(BuildContext context) {
    IconData typeIcon;
    Color typeColor;

    switch (log.type) {
      case 'blockage': typeIcon = Icons.warning_amber_rounded; typeColor = Colors.red; break;
      case 'material': typeIcon = Icons.inventory_2_outlined; typeColor = Colors.orange; break;
      case 'work': default: typeIcon = Icons.build_circle_outlined; typeColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: typeColor.withOpacity(0.1), radius: 16, child: Icon(typeIcon, size: 18, color: typeColor)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log.technicianName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(timeago.format(log.timestamp, locale: 'fr'), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                    ],
                  ),
                ),
                if (log.type == 'blockage') Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade100)),
                  child: Text("BLOQUÉ", style: TextStyle(fontSize: 10, color: Colors.red.shade800, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(log.description, style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF2D3436), height: 1.5)),

            // ✅ DISPLAY MEDIA THUMBNAILS WITH CLICK ACTIONS
            if (log.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: log.mediaUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final url = log.mediaUrls[index];
                    final isVideo = _isVideo(url);

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GestureDetector(
                        onTap: () {
                          // 1. If VIDEO: Open Video Player
                          if (isVideo) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VideoPlayerPage(videoUrl: url),
                              ),
                            );
                          }
                          // 2. If IMAGE: Open Gallery
                          else {
                            // Filter list to only contain images (so gallery doesn't break on videos)
                            final onlyImages = log.mediaUrls.where((u) => !_isVideo(u)).toList();
                            // Find the new index in this filtered list
                            final newIndex = onlyImages.indexOf(url);

                            if (newIndex != -1) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ImageGalleryPage(
                                    imageUrls: onlyImages,
                                    initialIndex: newIndex,
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Thumbnail
                            CachedNetworkImage(
                              imageUrl: url,
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                              // If it's a video, we might not get a thumbnail easily without a cloud function generator.
                              // Fallback: Show a generic placeholder or the image itself if backend provides thumbs.
                              placeholder: (context, url) => Container(width: 80, color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                              errorWidget: (context, url, error) => Container(
                                width: 80,
                                height: 80,
                                color: Colors.black12,
                                child: Icon(isVideo ? Icons.videocam_off : Icons.broken_image, color: Colors.grey),
                              ),
                            ),

                            // Video Overlay Icon
                            if (isVideo)
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (log.mediaStatus == 'uploading') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text("Envoi des médias...", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}
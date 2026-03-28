// lib/screens/dashboard/morning_briefing_summary_page.dart

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ✅ Models
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/models/mission.dart';

// ✅ Detail Pages
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';
import 'package:boitex_info_app/screens/administration/mission_details_page.dart';
import 'package:boitex_info_app/screens/administration/project_details_page.dart';
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';

class MorningBriefingSummaryPage extends StatefulWidget {
  const MorningBriefingSummaryPage({super.key});

  @override
  State<MorningBriefingSummaryPage> createState() =>
      _MorningBriefingSummaryPageState();
}

class _MorningBriefingSummaryPageState extends State<MorningBriefingSummaryPage>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;

  bool _isLoading = true;
  int _currentIndex = 0;
  String? _userRole;

  // Data maps to hold fetched documents for each department
  Map<String, List<DocumentSnapshot>> _dataTech = {};
  Map<String, List<DocumentSnapshot>> _dataIT = {};
  Map<String, List<DocumentSnapshot>> _dataAdmin = {};

  late List<Map<String, dynamic>> _stories = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Base duration. It will auto-pause when you open a list!
    _animationController = AnimationController(
        vsync: this, duration: const Duration(seconds: 15));

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _initializeBriefing();
  }

  Future<void> _initializeBriefing() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      _userRole = userDoc.data()?['role'];
    }

    // Determine permissions based on role
    bool canSeeTech = false;
    bool canSeeIT = false;
    bool canSeeAdmin = false;

    if (_userRole != null) {
      switch (_userRole) {
        case 'Admin':
        case 'PDG':
        case 'Responsable Administratif':
        case 'Responsable Commercial':
        case 'Chef de Projet':
          canSeeTech = true;
          canSeeIT = true;
          canSeeAdmin = true;
          break;
        case 'Responsable Technique':
          canSeeTech = true;
          canSeeIT = false;
          canSeeAdmin = true;
          break;
        case 'Responsable IT':
          canSeeTech = false;
          canSeeIT = true;
          canSeeAdmin = true;
          break;
        case 'Technicien ST':
          canSeeTech = true;
          canSeeIT = false;
          canSeeAdmin = false;
          break;
        case 'Technicien IT':
          canSeeTech = false;
          canSeeIT = true;
          canSeeAdmin = false;
          break;
      }
    }

    // Only fetch data if the user has permission to see it!
    await Future.wait([
      if (canSeeTech) _fetchServiceTechniqueData(),
      if (canSeeIT) _fetchServiceITData(),
      if (canSeeAdmin) _fetchAdministrationData(),
    ]);

    // Build the stories array based on the same permissions
    _buildStoriesArray(canSeeTech, canSeeIT, canSeeAdmin);

    if (mounted) {
      setState(() => _isLoading = false);
      _loadStory(animateToPage: false);
    }
  }

  // --- DATA FETCHING LOGIC ---

  Future<void> _fetchServiceTechniqueData() async {
    final db = FirebaseFirestore.instance;
    final futures = await Future.wait([
      db.collection('installations').where('serviceType', isEqualTo: 'Service Technique').where('status', whereIn: ['En Cours', 'À Planifier']).get(),
      db.collection('interventions').where('serviceType', isEqualTo: 'Service Technique').where('status', whereIn: ['En Cours', 'Nouvelle Demande']).get(),
      db.collection('sav_tickets').where('serviceType', isEqualTo: 'Service Technique').where('status', whereIn: ['En Diagnostic', 'En Réparation', 'Nouveau']).get(),
      db.collection('livraisons').where('serviceType', isEqualTo: 'Service Technique').where('status', whereIn: ['À Préparer', 'En Cours de Livraison']).get(),
      db.collection('missions').where('serviceType', isEqualTo: 'Service Technique').where('status', isEqualTo: 'Planifiée').get(),
      db.collection('projects').where('serviceType', isEqualTo: 'Service Technique').where('status', isEqualTo: 'Nouvelle Demande').get(),
    ]);

    _dataTech = {
      'Installations': futures[0].docs,
      'Interventions': futures[1].docs,
      'Tickets SAV': futures[2].docs,
      'Livraisons': futures[3].docs,
      'Missions': futures[4].docs,
      'Projets': futures[5].docs,
    };
  }

  Future<void> _fetchServiceITData() async {
    final db = FirebaseFirestore.instance;
    final futures = await Future.wait([
      db.collection('installations').where('serviceType', isEqualTo: 'Service IT').where('status', whereIn: ['En Cours', 'À Planifier']).get(),
      db.collection('interventions').where('serviceType', isEqualTo: 'Service IT').where('status', whereIn: ['En Cours', 'Nouvelle Demande']).get(),
      db.collection('sav_tickets').where('serviceType', isEqualTo: 'Service IT').where('status', whereIn: ['En Diagnostic', 'En Réparation', 'Nouveau']).get(),
      db.collection('livraisons').where('serviceType', isEqualTo: 'Service IT').where('status', whereIn: ['À Préparer', 'En Cours de Livraison']).get(),
      db.collection('missions').where('serviceType', isEqualTo: 'Service IT').where('status', isEqualTo: 'Planifiée').get(),
      db.collection('projects').where('serviceType', isEqualTo: 'Service IT').where('status', isEqualTo: 'Nouvelle Demande').get(),
    ]);

    _dataIT = {
      'Installations': futures[0].docs,
      'Interventions': futures[1].docs,
      'Tickets SAV': futures[2].docs,
      'Livraisons': futures[3].docs,
      'Missions': futures[4].docs,
      'Projets': futures[5].docs,
    };
  }

  Future<void> _fetchAdministrationData() async {
    final db = FirebaseFirestore.instance;
    final futures = await Future.wait([
      db.collection('interventions').where('status', isEqualTo: 'Terminé').get(),
      db.collection('requisitions').where('status', whereIn: ['Commandée', "En attente d'approbation", 'Partiellement Reçue']).get(),
    ]);

    _dataAdmin = {
      'Facturation': futures[0].docs,
      'Réquisitions': futures[1].docs,
    };
  }

  void _buildStoriesArray(bool canSeeTech, bool canSeeIT, bool canSeeAdmin) {
    _stories = [
      {
        "title": "Aperçu Matinal",
        "icon": CupertinoIcons.sun_max_fill,
        "color": const Color(0xFFFFB347),
        "content": _buildWelcomeStory(),
      },
    ];

    if (canSeeTech) {
      _stories.add({
        "title": "Service Technique",
        "icon": CupertinoIcons.wrench_fill,
        "color": const Color(0xFFF59E0B),
        "content": _buildDepartmentList(_dataTech),
      });
    }

    if (canSeeIT) {
      _stories.add({
        "title": "Service IT",
        "icon": CupertinoIcons.device_laptop,
        "color": const Color(0xFF32ADE6),
        "content": _buildDepartmentList(_dataIT),
      });
    }

    if (canSeeAdmin) {
      _stories.add({
        "title": "Administration",
        "icon": CupertinoIcons.shield_fill,
        "color": const Color(0xFF8B5CF6),
        "content": _buildDepartmentList(_dataAdmin),
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // --- STORY NAVIGATION LOGIC ---

  void _loadStory({bool animateToPage = true}) {
    _animationController.stop();
    _animationController.reset();
    _animationController.forward();

    if (animateToPage) {
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextStory() {
    HapticFeedback.lightImpact();
    if (_currentIndex < _stories.length - 1) {
      setState(() => _currentIndex++);
      _loadStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    HapticFeedback.lightImpact();
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _loadStory();
    } else {
      _loadStory(animateToPage: false);
    }
  }

  void _pauseTimer() => _animationController.stop();
  void _resumeTimer() => _animationController.forward();

  void _onBackgroundTap(TapUpDetails details) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double dx = details.globalPosition.dx;

    if (dx < screenWidth * 0.3) {
      _previousStory();
    } else {
      _nextStory();
    }
  }

  // --- MAIN BUILD ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CupertinoActivityIndicator(color: Colors.white, radius: 20),
              const SizedBox(height: 24),
              Text("Préparation de votre briefing...",
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: _onBackgroundTap,
        child: Stack(
          children: [
            // 1. The main PageView
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _stories.length,
              itemBuilder: (context, index) {
                return _buildStoryPage(_stories[index]);
              },
            ),

            // 2. Top Progress Bars
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    child: Row(
                      children: _stories.asMap().entries.map((entry) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: _buildProgressBar(entry.key),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(CupertinoIcons.clear, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        double value = 0.0;
        if (index < _currentIndex) value = 1.0;
        else if (index == _currentIndex) value = _animationController.value;

        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 3,
          ),
        );
      },
    );
  }

  Widget _buildStoryPage(Map<String, dynamic> story) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [story['color'].withOpacity(0.9), const Color(0xFF0F172A)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(story['icon'], color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                story['title'],
                style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -1.0),
              ),
              const SizedBox(height: 24),
              Expanded(child: story['content']),
            ],
          ),
        ),
      ),
    );
  }

  // --- STORY CONTENT BUILDERS ---

  Widget _buildWelcomeStory() {
    final dateStr = DateFormat('EEEE d MMMM', 'fr').format(DateTime.now());
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(dateStr.toUpperCase(), style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 2)),
          const SizedBox(height: 20),
          Text("Votre briefing est prêt.", textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3)),
          const SizedBox(height: 40),
          const Icon(CupertinoIcons.chevron_right_2, color: Colors.white54, size: 40),
          const SizedBox(height: 10),
          Text("Appuyez à droite pour avancer", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDepartmentList(Map<String, List<DocumentSnapshot>> dataMap) {
    final activeSections = dataMap.entries.where((e) => e.value.isNotEmpty).toList();

    if (activeSections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.checkmark_seal_fill, size: 64, color: Colors.white54),
            const SizedBox(height: 24),
            Text("Aucune tâche en attente !", style: GoogleFonts.poppins(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollStartNotification) _pauseTimer();
        else if (scrollNotification is ScrollEndNotification) _resumeTimer();
        return false;
      },
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 60),
        itemCount: activeSections.length,
        itemBuilder: (context, index) {
          final sectionName = activeSections[index].key;
          final docs = activeSections[index].value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildGlassExpansionTile(sectionName, docs),
          );
        },
      ),
    );
  }

  Widget _buildGlassExpansionTile(String sectionName, List<DocumentSnapshot> docs) {
    IconData sectionIcon;
    switch (sectionName) {
      case 'Installations': sectionIcon = CupertinoIcons.hammer; break;
      case 'Interventions': case 'Facturation': sectionIcon = CupertinoIcons.wrench; break;
      case 'Tickets SAV': sectionIcon = CupertinoIcons.ticket; break;
      case 'Livraisons': sectionIcon = CupertinoIcons.cube_box; break;
      case 'Missions': sectionIcon = CupertinoIcons.map_pin_ellipse; break;
      case 'Projets': sectionIcon = CupertinoIcons.building_2_fill; break;
      case 'Réquisitions': sectionIcon = CupertinoIcons.cart; break;
      default: sectionIcon = CupertinoIcons.doc;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              onExpansionChanged: (expanded) {
                if (expanded) {
                  _pauseTimer();
                  HapticFeedback.lightImpact();
                } else {
                  _resumeTimer();
                }
              },
              iconColor: Colors.white,
              collapsedIconColor: Colors.white70,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Row(
                children: [
                  Icon(sectionIcon, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                      sectionName.toUpperCase(),
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.0)
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: Text("${docs.length}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              children: docs.map((doc) => Column(
                children: [
                  Divider(color: Colors.white.withOpacity(0.1), height: 1),
                  _buildItemTile(sectionName, doc),
                ],
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }

// --- ITEM ROUTING & UI ---

  Widget _buildItemTile(String section, DocumentSnapshot doc) {
    final typedDoc = doc as DocumentSnapshot<Map<String, dynamic>>;
    final data = typedDoc.data() ?? {};

    // Smart fallbacks for Title
    String title = data['storeName'] ?? data['clientName'] ?? 'Inconnu';

    // Smart fallbacks for Location (handles different collections)
    String loc = data['storeLocation'] ?? data['clientCity'] ?? data['location'] ?? data['ville'] ?? '';
    String locText = loc.isNotEmpty ? "$loc • " : ""; // Formats nicely with a bullet if it exists

    String status = data['status'] ?? '';
    String subtitle = status;
    VoidCallback onTap;

    switch (section) {
      case 'Installations':
        subtitle = "Inst. ${data['serviceType'] ?? ''} • $locText$status";
        onTap = () => _navigateTo(InstallationDetailsPage(installationDoc: typedDoc, userRole: _userRole ?? ''));
        break;

      case 'Interventions':
      case 'Facturation':
        subtitle = "$locText$status";
        onTap = () => _navigateTo(InterventionDetailsPage(interventionDoc: typedDoc));
        break;

      case 'Tickets SAV':
        subtitle = "${data['productName'] ?? 'Produit'} • $locText$status";
        onTap = () => _navigateTo(SavTicketDetailsPage(ticket: SavTicket.fromFirestore(typedDoc)));
        break;

      case 'Livraisons':
        title = data['clientName'] ?? 'Inconnu'; // Override for livraisons
        subtitle = "BL: ${data['bonLivraisonCode'] ?? 'N/A'} • $locText$status";
        onTap = () => _navigateTo(LivraisonDetailsPage(livraisonId: typedDoc.id));
        break;

      case 'Missions':
        title = data['title'] ?? 'Mission';
        onTap = () => _navigateTo(MissionDetailsPage(mission: Mission.fromFirestore(typedDoc)));
        break;

      case 'Projets':
        title = data['projectName'] ?? 'Projet';
        subtitle = "$locText$status";
        onTap = () => _navigateTo(ProjectDetailsPage(projectId: typedDoc.id, userRole: _userRole ?? ''));
        break;

      case 'Réquisitions':
        title = data['title'] ?? data['requisitionCode'] ?? 'Achat';
        subtitle = "Par: ${data['requestedBy'] ?? ''} • $status";
        onTap = () => _navigateTo(RequisitionDetailsPage(requisitionId: typedDoc.id, userRole: _userRole ?? ''));
        break;

      default:
        onTap = () {};
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
      ),
      trailing: const Icon(CupertinoIcons.chevron_right, color: Colors.white54, size: 16),
      onTap: onTap,
    );
  }

  void _navigateTo(Widget page) {
    _pauseTimer();
    Navigator.push(context, CupertinoPageRoute(builder: (_) => page)).then((_) => _resumeTimer());
  }
}
// lib/screens/commercial/prospect_details_page.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/models/prospect.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:http/http.dart' as http; // For downloading PDFs
import 'package:path/path.dart' as path;
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Delete

// ✅ Viewers
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';

// ✅ Import AddProspectPage for editing
import 'package:boitex_info_app/screens/commercial/add_prospect_page.dart';

class ProspectDetailsPage extends StatelessWidget {
  final Prospect prospect;

  const ProspectDetailsPage({super.key, required this.prospect});

  // --- Actions ---

  Future<void> _deleteProspect(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce prospect ?'),
        content: const Text('Cette action est irréversible. Toutes les données seront perdues.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 🗑 Delete from Firestore
      await FirebaseFirestore.instance.collection('prospects').doc(prospect.id).delete();

      if (context.mounted) {
        Navigator.pop(context); // Return to Dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Prospect supprimé avec succès.")),
        );
      }
    }
  }

  // --- Helper: Launchers ---
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openMap(double? lat, double? lng) async {
    if (lat == null || lng == null) return;
    final googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    }
  }

  // ✅ PDF Opener Logic (Downloads bytes -> Opens Viewer)
  Future<void> _openPdf(BuildContext context, String url, String title) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF9966))),
    );

    try {
      final response = await http.get(Uri.parse(url));
      if (context.mounted) Navigator.pop(context); // Close loading

      if (response.statusCode == 200) {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfViewerPage(
                pdfBytes: response.bodyBytes,
                title: title,
              ),
            ),
          );
        }
      } else {
        throw Exception("Erreur téléchargement: ${response.statusCode}");
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading if error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible d'ouvrir le PDF: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ File Type Helper
  bool _isPdf(String url) => url.toLowerCase().contains('.pdf');

  @override
  Widget build(BuildContext context) {
    final Color headerColor = const Color(0xFFFF9966);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 1. APP BAR
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: headerColor,
            // ✅ ADDED ACTIONS HERE
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    // Navigate to Edit Mode
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddProspectPage(prospectToEdit: prospect),
                      ),
                    );
                  } else if (value == 'delete') {
                    _deleteProspect(context);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Modifier'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Supprimer'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                prospect.companyName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [headerColor, Colors.deepOrange.shade400],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.store_mall_directory,
                    size: 80,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
            ),
          ),

          // 2. CONTENT
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- QUICK ACTIONS ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.phone,
                        label: 'Appeler',
                        color: Colors.green,
                        onTap: () => _makePhoneCall(prospect.phoneNumber),
                      ),
                      if (prospect.email.isNotEmpty)
                        _buildActionButton(
                          icon: Icons.email,
                          label: 'Email',
                          color: Colors.blue,
                          onTap: () => _sendEmail(prospect.email),
                        ),
                      if (prospect.latitude != null && prospect.longitude != null)
                        _buildActionButton(
                          icon: Icons.map,
                          label: 'Itinéraire',
                          color: Colors.orange,
                          onTap: () => _openMap(prospect.latitude, prospect.longitude),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- INFO CARD ---
                  _buildSectionTitle('Informations Générales'),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildInfoRow(Icons.category, 'Activité', prospect.serviceType),
                          const Divider(),
                          _buildInfoRow(Icons.person, 'Contact', '${prospect.contactName} (${prospect.role})'),
                          const Divider(),
                          _buildInfoRow(Icons.location_on, 'Adresse', prospect.address),
                          const Divider(),
                          _buildInfoRow(Icons.calendar_today, 'Créé',
                              '${DateFormat('dd/MM/yyyy').format(prospect.createdAt)} (${timeago.format(prospect.createdAt, locale: 'fr')})'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- NOTES ---
                  if (prospect.notes.isNotEmpty) ...[
                    _buildSectionTitle('Notes & Observations'),
                    Card(
                      color: Colors.yellow[50],
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          prospect.notes,
                          style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 📷 --- MEDIA SECTION: PHOTOS ---
                  if (prospect.photoUrls.isNotEmpty) ...[
                    _buildSectionTitle('Photos (${prospect.photoUrls.length})'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: prospect.photoUrls.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () {
                                // ✅ Open Image Gallery
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ImageGalleryPage(
                                      imageUrls: prospect.photoUrls,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Hero(
                                  tag: prospect.photoUrls[index],
                                  child: Image.network(
                                    prospect.photoUrls[index],
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Container(
                                      width: 120,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 🎥 --- MEDIA SECTION: VIDEOS & DOCS ---
                  if (prospect.videoUrls.isNotEmpty) ...[
                    _buildSectionTitle('Vidéos & Documents (${prospect.videoUrls.length})'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: prospect.videoUrls.length,
                        itemBuilder: (context, index) {
                          final url = prospect.videoUrls[index];
                          final isPdf = _isPdf(url);
                          final fileName = path.basename(Uri.parse(url).path);

                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: InkWell(
                              onTap: () {
                                if (isPdf) {
                                  // ✅ Open PDF
                                  _openPdf(context, url, fileName);
                                } else {
                                  // ✅ Open Video
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => VideoPlayerPage(videoUrl: url),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                width: 200,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isPdf ? Colors.red.shade50 : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isPdf ? Icons.picture_as_pdf : Icons.play_circle_fill,
                                        color: isPdf ? Colors.red : Colors.blue,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isPdf ? "Document PDF" : "Vidéo / Média",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // --- FOOTER BUTTON ---
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fonctionnalité "Convertir en Client" à venir...')),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('CONVERTIR EN CLIENT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFFFF9966)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Non renseigné' : value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
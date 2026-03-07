// lib/widgets/technician_podium.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/models/analytics_stats.dart';
import 'dart:math';

class TechnicianPodium extends StatelessWidget {
  final List<TechnicianData> topTechnicians;

  const TechnicianPodium({super.key, required this.topTechnicians});

  @override
  Widget build(BuildContext context) {
    if (topTechnicians.isEmpty) {
      return _buildEmptyState();
    }

    final sortedList = List<TechnicianData>.from(topTechnicians)
      ..sort((a, b) => b.score.compareTo(a.score));

    final top3 = sortedList.take(3).toList();
    final rest = sortedList.skip(3).toList();

    return Column(
      children: [
        const SizedBox(height: 20),
        // 🏆 THE PODIUM SECTION
        if (top3.isNotEmpty)
          SizedBox(
            height: 290,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (top3.length >= 2)
                  _buildPodiumSpot(
                    context,
                    data: top3[1],
                    rank: 2,
                    height: 140,
                    size: 80,
                    color: const Color(0xFFC0C0C0), // Silver
                  ),
                _buildPodiumSpot(
                  context,
                  data: top3[0],
                  rank: 1,
                  height: 180,
                  size: 110,
                  color: const Color(0xFFFFD700), // Gold
                  isWinner: true,
                ),
                if (top3.length >= 3)
                  _buildPodiumSpot(
                    context,
                    data: top3[2],
                    rank: 3,
                    height: 120,
                    size: 80,
                    color: const Color(0xFFCD7F32), // Bronze
                  ),
              ],
            ),
          ),

        const SizedBox(height: 30),

        // 📜 THE "BEST OF THE REST" LIST
        if (rest.isNotEmpty)
          ...rest.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            return _buildRankListItem(context, data, index + 4);
          }),

        if (rest.isEmpty && top3.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              "Seuls les 5 meilleurs sont affichés.",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildPodiumSpot(
      BuildContext context, {
        required TechnicianData data,
        required int rank,
        required double height,
        required double size,
        required Color color,
        bool isWinner = false,
      }) {
    final bool isUp = Random().nextBool();

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(bottom: 5),
            child: Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 32),
          ),

        GestureDetector(
          onTap: () => _showDetails(context, data),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 4),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _getInitials(data.name),
                style: GoogleFonts.poppins(
                  fontSize: isWinner ? 24 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          data.name.split(' ').first,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${_formatScore(data.score)} XP",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              isUp ? Icons.arrow_drop_up_rounded : Icons.remove_rounded,
              color: isUp ? Colors.green : Colors.grey,
              size: 18,
            ),
          ],
        ),

        Container(
          margin: const EdgeInsets.only(top: 2, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getBadgeColor(data.badge).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              Text(
                "${data.efficiency.toStringAsFixed(1)} xp/job",
                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                data.badge.toUpperCase(),
                style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: _getBadgeColor(data.badge)
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),
        Container(
          width: size,
          height: rank == 1 ? 40 : 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withOpacity(0.6), color.withOpacity(0.0)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          alignment: Alignment.center,
          child: Text(
            "#$rank",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankListItem(BuildContext context, TechnicianData data, int rank) {
    final bool isUp = Random().nextBool();

    return InkWell(
      onTap: () => _showDetails(context, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Text(
                "$rank",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Row(
                    children: [
                      // 👇 Wrap the text in Expanded with maxLines
                      Expanded(
                        child: Text(
                          "${data.count} tâches • ${data.efficiency.toStringAsFixed(1)} xp/j",
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _getBadgeColor(data.badge).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          data.badge,
                          style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: _getBadgeColor(data.badge)
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${_formatScore(data.score)} pts",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                Icon(
                  isUp ? Icons.arrow_drop_up_rounded : Icons.remove_rounded,
                  color: isUp ? Colors.green : Colors.grey,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🔄 REPLACED: Now opens the advanced Stateful Dialog
  void _showDetails(BuildContext context, TechnicianData data) {
    showDialog(
      context: context,
      builder: (context) => TechnicianDetailsDialog(data: data),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "";
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }
    if (name.length >= 2) {
      return name.substring(0, 2).toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getBadgeColor(String badge) {
    switch (badge) {
      case 'Installateur': return Colors.purple;
      case 'Expert SAV': return Colors.red;
      case 'Logistique': return Colors.orange;
      case 'Mission': return Colors.teal;
      default: return Colors.blue;
    }
  }

  String _formatScore(double score) {
    if (score == score.truncateToDouble()) {
      return score.toInt().toString();
    }
    return score.toStringAsFixed(1);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.leaderboard_outlined, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            "Aucun classement disponible",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ✅ NEW: ADVANCED DIALOG WITH REAL-TIME FIRESTORE HISTORY
// ============================================================================
class TechnicianDetailsDialog extends StatelessWidget {
  final TechnicianData data;

  const TechnicianDetailsDialog({super.key, required this.data});

  Color _getBadgeColor(String badge) {
    switch (badge) {
      case 'Installateur': return Colors.purple;
      case 'Expert SAV': return Colors.red;
      case 'Logistique': return Colors.orange;
      case 'Mission': return Colors.teal;
      default: return Colors.blue;
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "";
    final parts = name.trim().split(' ');
    if (parts.length > 1) return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    if (name.length >= 2) return name.substring(0, 2).toUpperCase();
    return name[0].toUpperCase();
  }

  // 🔍 THE BRAIN: Fetches real history from all 4 collections (Strictly Completed Tasks)
  Future<List<Map<String, dynamic>>> _fetchRecentActivity() async {
    final db = FirebaseFirestore.instance;
    List<Map<String, dynamic>> activities = [];

    // 🗓️ Helper safely extracts the date to prevent crashes
    DateTime extractDate(Map<String, dynamic> data) {
      final ts = data['updatedAt'] ?? data['closedAt'] ?? data['endDate'] ?? data['createdAt'] ?? data['timestamp'];
      if (ts is Timestamp) return ts.toDate();
      return DateTime(2000); // Fallback date if missing
    }

    // 1. Interventions
    try {
      final intSnap = await db.collection('interventions')
          .where('assignedTechnicians', arrayContains: data.name)
          .where('status', whereIn: ['Terminé', 'Clôturé'])
          .get(); // 👈 LIMIT REMOVED!

      var docs = intSnap.docs.toList();
      // Sort locally (Newest first)
      docs.sort((a, b) => extractDate(b.data()).compareTo(extractDate(a.data())));

      for (var doc in docs.take(15)) { // Only take the newest 15
        final d = doc.data();
        activities.add({
          'type': 'Intervention',
          'title': d['storeName'] ?? d['clientName'] ?? d['interventionCode'] ?? 'Intervention',
          'status': d['status'] ?? 'Inconnu',
          'date': extractDate(d),
        });
      }
    } catch (e) { debugPrint("Error Interventions: $e"); }

    // 2. Installations
    try {
      final instSnap = await db.collection('installations')
          .where('assignedTechnicianNames', arrayContains: data.name)
          .where('status', isEqualTo: 'Terminée')
          .get();

      var docs = instSnap.docs.toList();
      docs.sort((a, b) => extractDate(b.data()).compareTo(extractDate(a.data())));

      for (var doc in docs.take(15)) {
        final d = doc.data();
        activities.add({
          'type': 'Installation',
          'title': d['storeName'] ?? d['clientName'] ?? d['installationCode'] ?? 'Installation',
          'status': d['status'] ?? 'Inconnu',
          'date': extractDate(d),
        });
      }
    } catch (e) { debugPrint("Error Installations: $e"); }

    // 3. Missions
    try {
      final missSnap = await db.collection('missions')
          .where('assignedTechniciansNames', arrayContains: data.name)
          .where('status', isEqualTo: 'Terminée')
          .get();

      var docs = missSnap.docs.toList();
      docs.sort((a, b) => extractDate(b.data()).compareTo(extractDate(a.data())));

      for (var doc in docs.take(15)) {
        final d = doc.data();
        activities.add({
          'type': 'Mission',
          'title': d['title'] ?? d['missionCode'] ?? 'Mission',
          'status': d['status'] ?? 'Inconnu',
          'date': extractDate(d),
        });
      }
    } catch (e) { debugPrint("Error Missions: $e"); }

    // 4. SAV
    try {
      final journalSnap = await db.collectionGroup('journal_entries')
          .where('authorName', isEqualTo: data.name)
          .get();

      var docs = journalSnap.docs.toList();
      docs.sort((a, b) => extractDate(b.data()).compareTo(extractDate(a.data())));

      for (var doc in docs) {
        final d = doc.data();

        // 🌟 Use trim() to destroy hidden spaces, and check the 'content' as a backup!
        final newStatus = d['newStatus']?.toString().trim() ?? '';
        final content = d['content']?.toString() ?? '';

        if (newStatus == 'Terminé' || content.contains('Terminé')) {

          final parentRef = doc.reference.parent.parent;
          if (parentRef != null) {
            final parentDoc = await parentRef.get();

            if (parentDoc.exists) {
              final parentData = parentDoc.data() as Map<String, dynamic>;
              final parentStatus = parentData['status']?.toString().trim() ?? '';

              // ✅ Correct Parent Status Check
              if (parentStatus == 'Retourné' || parentStatus == 'Terminé') {
                final product = parentData['productName'] ?? 'Matériel';
                final client = parentData['clientName'] ?? parentData['storeName'] ?? '';
                final title = client.isNotEmpty ? '$product - $client' : product;

                // 🛡️ Prevent duplicates if the user generated multiple journal entries
                bool alreadyAdded = activities.any((a) => a['title'] == title && a['type'] == 'SAV');

                if (!alreadyAdded) {
                  activities.add({
                    'type': 'SAV',
                    'title': title,
                    'status': 'Réparé',
                    'date': extractDate(doc.data()),
                  });
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("❌ CRITICAL ERROR IN SAV: $e");
    }

    // 🏆 Final sort of all combined activities
    activities.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return activities.take(15).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFF8F9FA),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650), // Prevent taking whole screen
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: _getBadgeColor(data.badge).withOpacity(0.2),
                    child: Text(
                      _getInitials(data.name),
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _getBadgeColor(data.badge),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.name,
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    data.badge,
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                  ),

                  const SizedBox(height: 16),

                  // Summary Blocks
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSummaryCard("Score", "${data.score.toStringAsFixed(1)} xp", Colors.blue),
                      _buildSummaryCard("Tâches", "${data.count}", Colors.green),
                    ],
                  ),
                ],
              ),
            ),

            // --- HISTORY LIST ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text("Historique Récent", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),

                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _fetchRecentActivity(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(
                                child: Text(
                                    "Aucune activité récente trouvée.",
                                    style: GoogleFonts.poppins(color: Colors.grey)
                                )
                            );
                          }

                          final items = snapshot.data!;
                          return ListView.separated(
                            shrinkWrap: true,
                            itemCount: items.length,
                            separatorBuilder: (c, i) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final date = item['date'] as DateTime;

                              IconData icon;
                              Color iconColor;
                              switch (item['type']) {
                                case 'Installation': icon = Icons.handyman; iconColor = Colors.purple; break;
                                case 'Intervention': icon = Icons.build_circle; iconColor = Colors.blue; break;
                                case 'SAV': icon = Icons.medical_services; iconColor = Colors.red; break;
                                case 'Mission': icon = Icons.directions_car; iconColor = Colors.teal; break;
                                default: icon = Icons.work; iconColor = Colors.grey;
                              }

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: iconColor.withOpacity(0.1),
                                      radius: 20,
                                      child: Icon(icon, color: iconColor, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title'],
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                  item['type'],
                                                  style: GoogleFonts.poppins(fontSize: 11, color: iconColor, fontWeight: FontWeight.w500)
                                              ),
                                              const Text(" • ", style: TextStyle(color: Colors.grey)),
                                              Expanded(
                                                child: Text(
                                                  item['status'],
                                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    Text(
                                      DateFormat('dd MMM').format(date),
                                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                    )
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- FOOTER BUTTON ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: Text("Fermer", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3))
      ),
      child: Column(
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
          Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
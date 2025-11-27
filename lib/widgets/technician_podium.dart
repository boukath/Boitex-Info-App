// lib/widgets/technician_podium.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boitex_info_app/models/analytics_stats.dart'; // ✅ Needed for TechnicianData
import 'dart:math'; // ✅ Needed for random Trend simulation

class TechnicianPodium extends StatelessWidget {
  // 🔄 UPDATED: Now accepts the List object to access efficiency data
  final List<TechnicianData> topTechnicians;

  const TechnicianPodium({super.key, required this.topTechnicians});

  @override
  Widget build(BuildContext context) {
    if (topTechnicians.isEmpty) {
      return _buildEmptyState();
    }

    // 1. Sort by Score (Highest first) - ensures correct podium order
    final sortedList = List<TechnicianData>.from(topTechnicians)
      ..sort((a, b) => b.score.compareTo(a.score));

    // 2. Split Top 3 (Podium) and The Rest (List)
    final top3 = sortedList.take(3).toList();
    final rest = sortedList.skip(3).toList();

    return Column(
      children: [
        const SizedBox(height: 20),
        // 🏆 THE PODIUM SECTION
        if (top3.isNotEmpty)
          SizedBox(
            // 📏 FIXED: Height 290 to prevent overflow
            height: 290,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end, // Align to bottom
              children: [
                // 🥈 2nd Place (Left)
                if (top3.length >= 2)
                  _buildPodiumSpot(
                    context, // 👈 Added Context
                    data: top3[1],
                    rank: 2,
                    height: 140,
                    size: 80,
                    color: const Color(0xFFC0C0C0), // Silver
                  ),

                // 🥇 1st Place (Center - Biggest)
                _buildPodiumSpot(
                  context, // 👈 Added Context
                  data: top3[0],
                  rank: 1,
                  height: 180, // Taller
                  size: 110, // Bigger
                  color: const Color(0xFFFFD700), // Gold
                  isWinner: true,
                ),

                // 🥉 3rd Place (Right)
                if (top3.length >= 3)
                  _buildPodiumSpot(
                    context, // 👈 Added Context
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
            // Rank starts at 4
            return _buildRankListItem(context, data, index + 4); // 👈 Added Context
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

  // 🔹 BUILD A PODIUM SPOT
  Widget _buildPodiumSpot(
      BuildContext context, {
        required TechnicianData data,
        required int rank,
        required double height,
        required double size,
        required Color color,
        bool isWinner = false,
      }) {
    // 🎲 SIMULATED TREND (Random for now)
    final bool isUp = Random().nextBool();

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 1. The Crown (Only for #1)
        if (isWinner)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 32),
          ),

        // 2. The Avatar with Border (Clickable)
        GestureDetector(
          onTap: () => _showDetails(context, data), // 👈 Handle Click
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

        // 3. The Name
        Text(
          data.name.split(' ').first, // Just first name
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),

        // 4. Score & Trend Arrow 📈
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${data.score} XP",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 2),
            // ✅ Trend Arrow
            Icon(
              isUp ? Icons.arrow_drop_up_rounded : Icons.remove_rounded,
              color: isUp ? Colors.green : Colors.grey,
              size: 18,
            ),
          ],
        ),

        // 5. Efficiency Badge & Specialist Title ⚡️
        Container(
          margin: const EdgeInsets.only(top: 2, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            // Change color based on badge type
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
              // 🏅 THE SPECIALIST BADGE
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

        // 6. The Podium Step (Visual Anchor)
        const SizedBox(height: 4),
        Container(
          width: size,
          height: rank == 1 ? 40 : 20, // 1st place has taller block
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

  // 🔹 BUILD A LIST ITEM (For Rank 4+)
  Widget _buildRankListItem(BuildContext context, TechnicianData data, int rank) {
    // 🎲 SIMULATED TREND
    final bool isUp = Random().nextBool();

    return InkWell(
      onTap: () => _showDetails(context, data), // 👈 Handle Click
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
            // Rank Badge
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

            // Name & Efficiency & Badge
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
                  // ✅ Efficiency Subtitle with Badge
                  Row(
                    children: [
                      Text(
                        "${data.count} msns • ${data.efficiency.toStringAsFixed(1)} xp/j",
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
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

            // Score & Trend
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${data.score} pts",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                // ✅ Trend Icon
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

  // 📊 SHOW DETAILS DIALOG (New Function)
  void _showDetails(BuildContext context, TechnicianData data) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 24),

                // Detailed List from Breakdown
                if (data.breakdown.isEmpty)
                  Text("Aucun détail disponible.", style: GoogleFonts.poppins(color: Colors.grey)),

                ...data.breakdown.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${e.value}",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                )),

                const SizedBox(height: 20),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total Missions", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      Text(
                        "${data.count}",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ IMPROVED INITIALS EXTRACTOR
  String _getInitials(String name) {
    if (name.isEmpty) return "";
    final parts = name.trim().split(' ');

    // Case 1: First Name + Last Name (e.g. "Amine S.") -> "AS"
    if (parts.length > 1) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }

    // Case 2: Only First Name (e.g. "Athmane") -> "AT" (First 2 letters)
    if (name.length >= 2) {
      return name.substring(0, 2).toUpperCase();
    }

    // Fallback: Just 1 letter
    return name[0].toUpperCase();
  }

  // Helper function to pick colors for badges
  Color _getBadgeColor(String badge) {
    switch (badge) {
      case 'Installateur': return Colors.purple;
      case 'Expert SAV': return Colors.red;
      case 'Logistique': return Colors.orange;
      case 'Mission': return Colors.teal;
      default: return Colors.blue; // Polyvalent
    }
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
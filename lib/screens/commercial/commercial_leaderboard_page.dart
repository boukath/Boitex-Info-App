// lib/screens/commercial/commercial_leaderboard_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/models/prospect.dart';
import 'package:boitex_info_app/screens/commercial/prospect_details_page.dart';

// ---------------------------------------------------------------------------
// 1. HELPER CLASS TO STORE AGGREGATED STATS
// ---------------------------------------------------------------------------
class CommercialStats {
  final String userId;
  final String userName;
  final List<Prospect> prospects;

  CommercialStats({
    required this.userId,
    required this.userName,
    required this.prospects,
  });

  int get totalCount => prospects.length;
}

// ---------------------------------------------------------------------------
// 2. MAIN LEADERBOARD PAGE
// ---------------------------------------------------------------------------
class CommercialLeaderboardPage extends StatefulWidget {
  const CommercialLeaderboardPage({super.key});

  @override
  State<CommercialLeaderboardPage> createState() => _CommercialLeaderboardPageState();
}

class _CommercialLeaderboardPageState extends State<CommercialLeaderboardPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🏆 Classement Commercial"),
        backgroundColor: const Color(0xFFFF9966),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFF9966).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('prospects').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text("Erreur: ${snapshot.error}"));
            }

            final docs = snapshot.data?.docs ?? [];

            // --- 📊 AGGREGATION LOGIC ---
            // 1. Group prospects by 'createdBy' (User ID)
            final Map<String, List<Prospect>> groupedByUserId = {};
            final Map<String, String> userNames = {}; // Map ID -> Name

            for (var doc in docs) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final p = Prospect.fromMap({...data, 'id': doc.id});

                if (!groupedByUserId.containsKey(p.createdBy)) {
                  groupedByUserId[p.createdBy] = [];
                }
                groupedByUserId[p.createdBy]!.add(p);

                // ⚡ FIX: Smart Name Resolution
                // If this document has a real name (not "Commercial"), use it.
                // We do NOT overwrite a real name with "Commercial" if we find an old doc later.
                if (p.authorName != 'Commercial') {
                  userNames[p.createdBy] = p.authorName;
                } else {
                  // Only set default "Commercial" if we don't have a name yet for this ID
                  if (!userNames.containsKey(p.createdBy)) {
                    userNames[p.createdBy] = 'Commercial';
                  }
                }
              } catch (e) {
                // Skip corrupted docs
              }
            }

            // 2. Convert to List of Stats
            final List<CommercialStats> statsList = groupedByUserId.entries.map((entry) {
              final uid = entry.key;
              final list = entry.value;
              final name = userNames[uid] ?? 'Inconnu';
              return CommercialStats(userId: uid, userName: name, prospects: list);
            }).toList();

            // 3. Sort by Count (Descending)
            statsList.sort((a, b) => b.totalCount.compareTo(a.totalCount));

            if (statsList.isEmpty) {
              return const Center(child: Text("Aucune donnée disponible."));
            }

            // --- 🎨 BUILD LIST ---
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: statsList.length,
              itemBuilder: (context, index) {
                final stat = statsList[index];
                final rank = index + 1;

                return _buildLeaderboardCard(stat, rank, context);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeaderboardCard(CommercialStats stat, int rank, BuildContext context) {
    Color rankColor = Colors.grey.shade100;
    IconData? rankIcon;
    Color iconColor = Colors.grey;
    double scale = 1.0;

    if (rank == 1) {
      rankColor = const Color(0xFFFFD700).withOpacity(0.2); // Gold
      rankIcon = Icons.emoji_events;
      iconColor = const Color(0xFFFFD700); // Gold
      scale = 1.05;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0).withOpacity(0.2); // Silver
      rankIcon = Icons.emoji_events;
      iconColor = const Color(0xFFC0C0C0);
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32).withOpacity(0.2); // Bronze
      rankIcon = Icons.emoji_events;
      iconColor = const Color(0xFFCD7F32);
    } else {
      rankIcon = Icons.star_outline;
    }

    return Transform.scale(
      scale: scale,
      child: Card(
        elevation: rank <= 3 ? 4 : 1,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Navigate to Detailed Profile Page
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CommercialProfilePage(stats: stat),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: rank <= 3 ? Border.all(color: iconColor, width: 2) : null,
            ),
            child: Row(
              children: [
                // Rank Circle
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: rankColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: rankIcon != null
                        ? Icon(rankIcon, color: iconColor, size: 28)
                        : Text("#$rank", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 16),

                // Name & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.userName, // ✅ Shows 'Amine Tounsi' if available
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${stat.totalCount} Prospects trouvés",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. DRILL-DOWN: USER DETAIL PAGE (List of all their work)
// ---------------------------------------------------------------------------
class CommercialProfilePage extends StatelessWidget {
  final CommercialStats stats;

  const CommercialProfilePage({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    // Sort prospects by newest first for the detail view
    final sortedProspects = List<Prospect>.from(stats.prospects)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(stats.userName),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header Stats
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.blue.shade800,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderStat("TOTAL", "${stats.totalCount}"),
                _buildHeaderStat("DERNIER AJOUT",
                    sortedProspects.isNotEmpty
                        ? DateFormat('dd/MM').format(sortedProspects.first.createdAt)
                        : "-"
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedProspects.length,
              itemBuilder: (context, index) {
                final p = sortedProspects[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orangeAccent,
                      child: Icon(Icons.store, color: Colors.white, size: 20),
                    ),
                    title: Text(p.companyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${p.serviceType} • ${p.commune}"),
                    trailing: Text(
                      DateFormat('dd/MM/yyyy').format(p.createdAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      // Open full detail of the prospect
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProspectDetailsPage(prospect: p),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
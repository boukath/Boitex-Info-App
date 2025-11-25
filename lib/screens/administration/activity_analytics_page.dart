// lib/screens/administration/activity_analytics_page.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/models/analytics_stats.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class ActivityAnalyticsPage extends StatelessWidget {
  final String categoryTitle;
  final CategoryStats stats;

  const ActivityAnalyticsPage({
    super.key,
    required this.categoryTitle,
    required this.stats,
  });

  // Helper: Maps the Category Title to the actual Firestore Collection Name
  String _getCollectionName() {
    switch (categoryTitle) {
      case "Interventions": return "interventions";
      case "Installations": return "installations";
      case "Livraisons": return "livraisons";
      case "Missions": return "missions";
      case "SAV": return "sav_tickets";
      default: return "interventions";
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectionName = _getCollectionName();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text("$categoryTitle - Détails", style: GoogleFonts.poppins(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Performance Card
            _buildDetailCard(),
            const SizedBox(height: 24),

            // 2. Recent Activity Header
            Text(
              "Activités Récentes (10 dernières)",
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
            ),
            const SizedBox(height: 16),

            // 3. Live List
            _buildRecentActivityList(collectionName),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatColumn("Total", "${stats.total}"),
              Container(width: 1, height: 40, color: Colors.white30),
              _buildStatColumn("Succès", "${stats.success}"),
              Container(width: 1, height: 40, color: Colors.white30),
              _buildStatColumn("Taux", "${stats.successRate.toStringAsFixed(1)}%"),
            ],
          ),
          const SizedBox(height: 20),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: stats.total > 0 ? stats.success / stats.total : 0,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _buildRecentActivityList(String collectionName) {
    // Note: Ensure your collections have a timestamp field.
    // If 'createdAt' varies, we might need a more complex query, but this is standard.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionName)
      // Try to order by 'createdAt' or 'timestamp' or 'date'.
      // For this example, we don't use orderBy to avoid "Index Required" errors on new collections.
      // We just fetch the last 10 added (limit).
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Aucune activité récente."));
        }

        final docs = snapshot.data!.docs;

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (c, i) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? 'Inconnu';
            final title = data['title'] ?? data['clientName'] ?? data['productName'] ?? "Sans titre";

            // Color based on status (Simple logic)
            Color statusColor = Colors.grey;
            if (['Terminé', 'Clôturé', 'Livré', 'Retourné', 'Terminée'].contains(status)) statusColor = Colors.green;
            if (['En cours', 'En route'].contains(status)) statusColor = Colors.blue;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(Icons.history, color: statusColor, size: 20),
                ),
                title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text("Status: $status"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }
}
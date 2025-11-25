// lib/screens/administration/analytics_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/models/analytics_stats.dart';
import 'package:boitex_info_app/services/analytics_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boitex_info_app/screens/administration/activity_analytics_page.dart';
// ignore: unused_import
import 'package:intl/intl.dart';

class AnalyticsDashboardPage extends StatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  State<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends State<AnalyticsDashboardPage> with SingleTickerProviderStateMixin {
  final AnalyticsService _service = AnalyticsService();
  late TabController _tabController;

  // 🎨 CONFIGURATION VISUELLE (Couleurs et Icônes fixes pour chaque type)
  final Map<String, _ActivityStyle> _activityStyles = {
    "Interventions": _ActivityStyle(Colors.blue, Icons.handyman_rounded),
    "Installations": _ActivityStyle(Colors.purple, Icons.settings_input_component_rounded),
    "Livraisons": _ActivityStyle(Colors.orange, Icons.local_shipping_rounded),
    "Missions": _ActivityStyle(Colors.teal, Icons.map_rounded),
    "SAV": _ActivityStyle(Colors.redAccent, Icons.confirmation_number_rounded),
  };

  @override
  void initState() {
    super.initState();
    // ✅ UPDATED: 3 Tabs only (Global, Opérations, Logistique)
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Boitex Analytics Hub',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[700],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue[700],
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: "Global"),
            Tab(text: "Opérations"), // ✅ Renamed from "Technique"
            Tab(text: "Logistique"),
          ],
        ),
      ),
      body: StreamBuilder<AnalyticsStats>(
        stream: _service.getStatsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Erreur : ${snapshot.error}"));
          }

          final stats = snapshot.data ?? AnalyticsStats.empty();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildGlobalTab(stats),
              _buildOperationsTab(stats), // ✅ Uses the unified Operations view
              _buildLogisticsTab(stats),
            ],
          );
        },
      ),
    );
  }

  // --- 1. GLOBAL OVERVIEW TAB ---
  Widget _buildGlobalTab(AnalyticsStats stats) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          "Performances du Mois",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
        ),
        const SizedBox(height: 16),

        // KPI Row 1
        Row(
          children: [
            Expanded(child: _buildKpiCard("Total Actions", "${stats.totalInterventionsMonth}", Icons.analytics, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _buildKpiCard("Taux de Succès", "${stats.successRate}%", Icons.check_circle, Colors.green)),
          ],
        ),
        const SizedBox(height: 12),

        // KPI Row 2 (Livraisons Only)
        Row(
          children: [
            Expanded(child: _buildKpiCard("Livraisons en attente", "${stats.pendingLivraisons}", Icons.local_shipping, Colors.orange)),
          ],
        ),

        const SizedBox(height: 24),
        Text(
          "Répartition par Activité",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
        ),
        const SizedBox(height: 16),

        // PIE CHART + DETAILS SECTION
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              // Le Graphique
              SizedBox(
                height: 250,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: _getPieSections(stats.interventionsByType),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // La Liste Détaillée (Légende)
              _buildActivityLegend(stats.interventionsByType, stats), // ✅ Updated call
            ],
          ),
        ),
      ],
    );
  }

  // --- Widget: Liste détaillée des activités (Légende) ---
  // ✅ Updated Signature to accept 'fullStats'
  Widget _buildActivityLegend(Map<String, int> data, AnalyticsStats fullStats) {
    if (data.isEmpty) {
      return const Center(child: Text("Aucune donnée disponible"));
    }

    // Trier pour afficher les plus gros volumes en premier
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedEntries.map((entry) {
        final style = _activityStyles[entry.key] ?? _ActivityStyle(Colors.grey, Icons.circle);

        // ✅ Get detailed stats safely
        final catStats = fullStats.categoryPerformance[entry.key] ?? CategoryStats(total: entry.value, success: 0);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0), // Tighter spacing
          child: InkWell( // ✅ Make it clickable
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  ActivityAnalyticsPage(categoryTitle: entry.key, stats: catStats)
              ));
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: style.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(style.icon, size: 18, color: style.color),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    entry.key,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                  const Spacer(),
                  Text(
                    "${entry.value}",
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: style.color),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20), // Hint arrow
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- 2. OPERATIONS TAB (Unified View) ---
  Widget _buildOperationsTab(AnalyticsStats stats) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          "Top Techniciens",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
        ),
        const SizedBox(height: 16),

        Container(
          height: 350,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 60,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final names = stats.topTechnicians.keys.toList();
                      if (value.toInt() >= 0 && value.toInt() < names.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            names[value.toInt()].split(' ').first,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: _getBarGroups(stats.topTechnicians),
            ),
          ),
        ),
      ],
    );
  }

  // --- 3. LOGISTICS TAB ---
  Widget _buildLogisticsTab(AnalyticsStats stats) {
    final int lowStock = stats.stockHealth['low_stock'] ?? 0;
    final int inMoves = stats.stockHealth['movements_in'] ?? 0;
    final int outMoves = stats.stockHealth['movements_out'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. ALERTS SECTION
        Text(
          "Santé du Stock",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
        ),
        const SizedBox(height: 16),
        _buildKpiCard(
            "Produits en Alerte (<5)",
            "$lowStock",
            Icons.warning_amber_rounded,
            lowStock > 0 ? Colors.red : Colors.green
        ),
        const SizedBox(height: 24),

        // 2. FLOW SECTION
        Text(
          "Flux du Mois (Mouvements)",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (inMoves > outMoves ? inMoves : outMoves).toDouble() + 5, // Auto-scale
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const Padding(padding: EdgeInsets.only(top: 8), child: Text("Entrées (+)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)));
                      if (value == 1) return const Padding(padding: EdgeInsets.only(top: 8), child: Text("Sorties (-)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)));
                      return const Text("");
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: [
                BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: inMoves.toDouble(), color: Colors.green, width: 30, borderRadius: BorderRadius.circular(6))]),
                BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: outMoves.toDouble(), color: Colors.red, width: 30, borderRadius: BorderRadius.circular(6))]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- HELPERS ---

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text("Mois", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // Generate Pie Chart Sections with Fixed Colors
  List<PieChartSectionData> _getPieSections(Map<String, int> data) {
    return data.entries.map((entry) {
      final style = _activityStyles[entry.key] ?? _ActivityStyle(Colors.grey, Icons.circle);
      final isLarge = entry.value > 50;

      return PieChartSectionData(
        color: style.color,
        value: entry.value.toDouble(),
        title: '${entry.value}', // Just show number on chart to keep it clean
        radius: isLarge ? 60 : 50,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  List<BarChartGroupData> _getBarGroups(Map<String, int> data) {
    int index = 0;
    return data.entries.map((entry) {
      final x = index++;
      return BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: index == 1 ? Colors.amber : Colors.blue,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();
  }
}

// Petite classe helper pour le style
class _ActivityStyle {
  final Color color;
  final IconData icon;
  _ActivityStyle(this.color, this.icon);
}
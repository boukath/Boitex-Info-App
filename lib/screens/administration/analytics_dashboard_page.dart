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

  // ✅ FIX: Store the stream to prevent reloading on every build
  late Stream<AnalyticsStats> _statsStream;

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

    // ✅ FIX: Initialize the stream here
    _statsStream = _service.getStatsStream();
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
        stream: _statsStream, // ✅ FIX: Use the initialized stream variable
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
              _buildLogisticsTab(stats),  // ✅ NEW PRO VERSION
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

  // --- 3. LOGISTICS TAB (✅ CRASH PROOF VERSION) ---
  Widget _buildLogisticsTab(AnalyticsStats stats) {
    final int lowStock = stats.stockHealth['low_stock'] ?? 0;
    final int inMoves = stats.stockHealth['movements_in'] ?? 0;
    final int outMoves = stats.stockHealth['movements_out'] ?? 0;

    // Calculate Net Flow
    final int netFlow = inMoves - outMoves;
    final bool positiveFlow = netFlow >= 0;

    // ✅ SAFETY CHECK 1: Ensure enough data points
    final bool hasEnoughHistory = stats.stockHistory.length >= 2;

    // ✅ SAFETY CHECK 2: Calculate Max Y to prevent "Divide by Zero" crash
    double maxY = 0;
    if (hasEnoughHistory) {
      double maxIn = 0;
      double maxOut = 0;
      for (var item in stats.stockHistory) {
        if (item.incoming > maxIn) maxIn = item.incoming.toDouble();
        if (item.outgoing > maxOut) maxOut = item.outgoing.toDouble();
      }
      // Pick the highest value and add 20% padding
      maxY = (maxIn > maxOut ? maxIn : maxOut) * 1.2;
    }
    // If maxY is still 0 (e.g., all history is 0), force it to 10 so the chart has height
    if (maxY == 0) maxY = 10;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. HEADER: Stock Velocity Overview
        Text(
          "Vue d'ensemble des Flux",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            // Main Card: Net Flow
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(20),
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: positiveFlow
                        ? [const Color(0xFF11998e), const Color(0xFF38ef7d)]
                        : [const Color(0xFFcb2d3e), const Color(0xFFef473a)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(positiveFlow ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 28),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                          child: Text("Flux Net", style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        )
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${positiveFlow ? '+' : ''}$netFlow",
                          style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          "Unités ce mois",
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Side Card: Low Stock Alert
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(16),
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: lowStock > 0 ? Colors.redAccent.withOpacity(0.2) : Colors.grey.withOpacity(0.1)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 60, height: 60,
                          child: CircularProgressIndicator(
                            value: lowStock > 10 ? 1.0 : (lowStock / 10), // Example threshold
                            backgroundColor: Colors.grey[100],
                            color: Colors.redAccent,
                            strokeWidth: 6,
                          ),
                        ),
                        Text(
                          "$lowStock",
                          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Alertes Stock",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 2. GRID: Quick Stats
        Row(
          children: [
            _buildLogisticsStatItem("Entrées", "+$inMoves", Icons.arrow_downward_rounded, Colors.green),
            const SizedBox(width: 12),
            _buildLogisticsStatItem("Sorties", "-$outMoves", Icons.arrow_upward_rounded, Colors.orange),
            const SizedBox(width: 12),
            _buildLogisticsStatItem("Rotation", "${((outMoves + inMoves) / 2).toStringAsFixed(0)}", Icons.sync, Colors.blue),
          ],
        ),

        const SizedBox(height: 24),

        // 3. CHART: Timeline Trends
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Mouvements (30 Jours)",
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
            ),
            // Legend
            Row(
              children: [
                _buildChartLegend(Colors.green, "Entrées"),
                const SizedBox(width: 12),
                _buildChartLegend(Colors.orange, "Sorties"),
              ],
            )
          ],
        ),
        const SizedBox(height: 16),

        Container(
          height: 300,
          padding: const EdgeInsets.only(right: 16, top: 24, bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: !hasEnoughHistory
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.show_chart, size: 48, color: Colors.grey[300]), const SizedBox(height: 16), Text("En attente de plus de données...", style: GoogleFonts.poppins(color: Colors.grey)), Text("Effectuez une autre action de stock.", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400]))]))
              : LineChart(
            LineChartData(
              // ✅ FIXED: Explicitly set Min/Max Y to prevent loop
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 5, // Nice grid spacing
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[100], strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide dates for cleaner look or implement date mapping
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: maxY / 5,
                    getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                // Line 1: Incoming (Green)
                LineChartBarData(
                  spots: stats.stockHistory.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value.incoming.toDouble());
                  }).toList(),
                  // ✅ FIXED: Set curved to false if data is sparse to prevent calc errors
                  isCurved: true,
                  color: const Color(0xFF38ef7d),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: const Color(0xFF38ef7d).withOpacity(0.1)),
                ),
                // Line 2: Outgoing (Orange)
                LineChartBarData(
                  spots: stats.stockHistory.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value.outgoing.toDouble());
                  }).toList(),
                  isCurved: true,
                  color: const Color(0xFFef473a),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 50),
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

  // --- New Helpers for Logistics Tab ---
  Widget _buildLogisticsStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
      ],
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
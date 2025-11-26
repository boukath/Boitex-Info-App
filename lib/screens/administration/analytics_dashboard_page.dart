// lib/screens/administration/analytics_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/analytics_stats.dart';
import 'package:boitex_info_app/services/analytics_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boitex_info_app/screens/administration/activity_analytics_page.dart';
import 'package:intl/intl.dart'; // ✅ Required for date formatting
import 'package:boitex_info_app/screens/administration/stock_movements_page.dart'; // ✅ Added for navigation

class AnalyticsDashboardPage extends StatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  State<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends State<AnalyticsDashboardPage> with SingleTickerProviderStateMixin {
  final AnalyticsService _service = AnalyticsService();
  late TabController _tabController;
  late Stream<AnalyticsStats> _statsStream;

  // 🎨 CONFIGURATION VISUELLE
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
    _tabController = TabController(length: 3, vsync: this);
    _statsStream = _service.getStatsStream();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 🧠 SMART FORMATTER: 410950 -> 410k
  String _formatNumber(num number) {
    if (number >= 1000000) {
      double val = number / 1000000;
      return "${val.toStringAsFixed(val >= 10 ? 0 : 1)}M";
    }
    if (number >= 1000) {
      double val = number / 1000;
      return "${val.toStringAsFixed(val >= 10 ? 0 : 1)}k";
    }
    return number.toString();
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
            Tab(text: "Opérations"),
            Tab(text: "Logistique"),
          ],
        ),
      ),
      body: StreamBuilder<AnalyticsStats>(
        stream: _statsStream,
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
              _buildOperationsTab(stats),
              _buildLogisticsTabGoogleStyle(stats), // ✅ NEW GOOGLE STYLE TAB
            ],
          );
        },
      ),
    );
  }

  // --- 1. GLOBAL TAB ---
  Widget _buildGlobalTab(AnalyticsStats stats) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Performances du Mois", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildSimpleKpiCard("Total Actions", "${stats.totalInterventionsMonth}", Icons.analytics, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _buildSimpleKpiCard("Taux de Succès", "${stats.successRate}%", Icons.check_circle, Colors.green)),
          ],
        ),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _buildSimpleKpiCard("Livraisons en attente", "${stats.pendingLivraisons}", Icons.local_shipping, Colors.orange))]),
        const SizedBox(height: 24),
        Text("Répartition par Activité", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
          child: Column(
            children: [
              SizedBox(height: 250, child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 40, sections: _getPieSections(stats.interventionsByType)))),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _buildActivityLegend(stats.interventionsByType, stats),
            ],
          ),
        ),
      ],
    );
  }

  // --- 2. OPERATIONS TAB ---
  Widget _buildOperationsTab(AnalyticsStats stats) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Top Techniciens", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
        const SizedBox(height: 16),
        Container(
          height: 350,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 60,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (double value, TitleMeta meta) {
                  final names = stats.topTechnicians.keys.toList();
                  if (value.toInt() >= 0 && value.toInt() < names.length) {
                    return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(names[value.toInt()].split(' ').first, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)));
                  }
                  return const Text('');
                })),
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

  // ==============================================================================
  // 🚀 3. LOGISTICS TAB (GOOGLE ANALYTICS STYLE) - ✅ NEW VERSION
  // ==============================================================================
  Widget _buildLogisticsTabGoogleStyle(AnalyticsStats stats) {
    // 1. Calculate Totals based on History (or fallback to snapshot values)
    int totalIn = stats.stockHistory.fold(0, (sum, item) => sum + item.incoming);
    int totalOut = stats.stockHistory.fold(0, (sum, item) => sum + item.outgoing);
    // If history is empty, use the monthly totals from stats object as fallback
    if (stats.stockHistory.isEmpty) {
      totalIn = stats.stockHealth['movements_in'] ?? 0;
      totalOut = stats.stockHealth['movements_out'] ?? 0;
    }

    int netChange = totalIn - totalOut;

    // 2. Stock Health Logic
    int lowStock = stats.stockHealth['low_stock'] ?? 0;
    int outOfStock = 5; // Example/Mock if not in stats
    int healthy = 100 - lowStock - outOfStock; // Example

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 📊 SECTION 1: KEY PERFORMANCE INDICATORS (KPIs)
          Text("Vue d'ensemble", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildDetailedKpiCard(
                  "Entrées",
                  "+$totalIn",
                  Icons.arrow_circle_down_rounded,
                  Colors.green,
                  "Produits reçus",
                  // ✅ ADDED TAP ACTION
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const StockMovementsPage(type: StockMovementType.entry)
                    ));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailedKpiCard(
                  "Sorties",
                  "-$totalOut",
                  Icons.arrow_circle_up_rounded,
                  Colors.redAccent,
                  "Utilisés/Vendus",
                  // ✅ ADDED TAP ACTION
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const StockMovementsPage(type: StockMovementType.exit)
                    ));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailedKpiCard(
                  "Flux Net",
                  "${netChange > 0 ? '+' : ''}$netChange",
                  Icons.compare_arrows_rounded,
                  netChange >= 0 ? Colors.blue : Colors.orange,
                  "Variation",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailedKpiCard(
                  "Alertes",
                  "$lowStock",
                  Icons.warning_amber_rounded,
                  Colors.orangeAccent,
                  "Stock critique",
                  isAlert: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // 📈 SECTION 2: DUAL-LINE TREND CHART
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Tendances des Stocks", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
              _buildLegendRow(),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            height: 320,
            padding: const EdgeInsets.only(right: 20, left: 10, top: 20, bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: stats.stockHistory.isEmpty
                ? const Center(child: Text("Pas assez de données pour le graphique"))
                : LineChart(_buildLogisticsLineChart(stats.stockHistory)),
          ),

          const SizedBox(height: 30),

          // 🍩 SECTION 3: STOCK HEALTH DONUT
          Text("Santé du Stock", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
          const SizedBox(height: 15),
          Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          value: lowStock.toDouble(),
                          color: Colors.orangeAccent,
                          title: "$lowStock",
                          radius: 50,
                          titleStyle: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        PieChartSectionData(
                          value: outOfStock.toDouble(),
                          color: Colors.redAccent,
                          title: "$outOfStock",
                          radius: 45,
                          titleStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        PieChartSectionData(
                          value: healthy.toDouble(),
                          color: const Color(0xFF4CAF50),
                          title: "", // Clean look
                          radius: 60,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSimpleLegend(const Color(0xFF4CAF50), "Sain"),
                      const SizedBox(height: 10),
                      _buildSimpleLegend(Colors.orangeAccent, "Faible"),
                      const SizedBox(height: 10),
                      _buildSimpleLegend(Colors.redAccent, "Rupture"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --- 🧩 HELPER WIDGETS FOR LOGISTICS ---

  // ✅ UPDATED: Now accepts an onTap callback and uses GestureDetector
  Widget _buildDetailedKpiCard(String title, String value, IconData icon, Color color, String subtitle, {bool isAlert = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isAlert ? Border.all(color: color.withOpacity(0.3), width: 1.5) : Border.all(color: Colors.transparent),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
                // ✅ Show small indicator if clickable
                if (onTap != null)
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey[300]),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
            const SizedBox(height: 2),
            Text(title, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow() {
    return Row(
      children: [
        _buildLegendDot(Colors.green, "Entrées"),
        const SizedBox(width: 12),
        _buildLegendDot(Colors.redAccent, "Sorties"),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String text) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSimpleLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  // --- 📈 CHART LOGIC ---

  LineChartData _buildLogisticsLineChart(List<DailyStockStat> history) {
    List<FlSpot> incomingSpots = [];
    List<FlSpot> outgoingSpots = [];
    double maxY = 0;

    for (int i = 0; i < history.length; i++) {
      final stat = history[i];
      incomingSpots.add(FlSpot(i.toDouble(), stat.incoming.toDouble()));
      outgoingSpots.add(FlSpot(i.toDouble(), stat.outgoing.toDouble()));

      if (stat.incoming > maxY) maxY = stat.incoming.toDouble();
      if (stat.outgoing > maxY) maxY = stat.outgoing.toDouble();
    }

    // Add buffer to Y axis
    maxY = maxY * 1.2;
    if (maxY == 0) maxY = 10;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 5,
        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              int index = value.toInt();
              if (index >= 0 && index < history.length) {
                // Show date every 2 or 3 items to avoid clutter
                if (history.length > 7 && index % 2 != 0) return const SizedBox.shrink();

                final date = history[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('dd/MM').format(date),
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            interval: 1,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: maxY / 5,
            getTitlesWidget: (value, meta) {
              if (value == 0) return const Text('');
              return Text(value.toInt().toString(), style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey));
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (history.length - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        // 🟢 Incoming Line (Green)
        LineChartBarData(
          spots: incomingSpots,
          isCurved: true,
          color: Colors.green,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.green.withOpacity(0.1),
          ),
        ),
        // 🔴 Outgoing Line (Red)
        LineChartBarData(
          spots: outgoingSpots,
          isCurved: true,
          color: Colors.redAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.redAccent.withOpacity(0.05),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipRoundedRadius: 8,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final isIncoming = spot.barIndex == 0;
              return LineTooltipItem(
                "${isIncoming ? 'Entrées' : 'Sorties'}: ${spot.y.toInt()}",
                GoogleFonts.poppins(
                  color: isIncoming ? Colors.green : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  // --- 🏷️ HELPER FOR GLOBAL TAB (OLD STYLE) ---
  Widget _buildSimpleKpiCard(String title, String value, IconData icon, Color color) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: color, size: 20), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text("Mois", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)))]), const SizedBox(height: 12), FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87))), const SizedBox(height: 4), Text(title, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))]));
  }

  Widget _buildActivityLegend(Map<String, int> data, AnalyticsStats fullStats) {
    if (data.isEmpty) return const Center(child: Text("Aucune donnée disponible"));
    final sortedEntries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: sortedEntries.map((entry) {
        final style = _activityStyles[entry.key] ?? _ActivityStyle(Colors.grey, Icons.circle);
        final catStats = fullStats.categoryPerformance[entry.key] ?? CategoryStats(total: entry.value, success: 0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityAnalyticsPage(categoryTitle: entry.key, stats: catStats))),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: style.color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(style.icon, size: 18, color: style.color)),
                  const SizedBox(width: 12),
                  Text(entry.key, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
                  const Spacer(),
                  Text("${entry.value}", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: style.color)),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<PieChartSectionData> _getPieSections(Map<String, int> data) {
    return data.entries.map((entry) {
      final style = _activityStyles[entry.key] ?? _ActivityStyle(Colors.grey, Icons.circle);
      final isLarge = entry.value > 50;
      return PieChartSectionData(color: style.color, value: entry.value.toDouble(), title: '${entry.value}', radius: isLarge ? 60 : 50, titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white));
    }).toList();
  }

  List<BarChartGroupData> _getBarGroups(Map<String, int> data) {
    int index = 0;
    return data.entries.map((entry) {
      final x = index++;
      return BarChartGroupData(x: x, barRods: [BarChartRodData(toY: entry.value.toDouble(), color: index == 1 ? Colors.amber : Colors.blue, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]);
    }).toList();
  }
}

class _ActivityStyle {
  final Color color;
  final IconData icon;
  _ActivityStyle(this.color, this.icon);
}
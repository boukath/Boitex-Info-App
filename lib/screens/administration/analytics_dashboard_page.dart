// lib/screens/administration/analytics_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/analytics_stats.dart';
import 'package:boitex_info_app/services/analytics_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boitex_info_app/screens/administration/activity_analytics_page.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Required for locale
import 'package:boitex_info_app/screens/administration/stock_movements_page.dart';
// ✅ ADDED: Import for the Report Dialog
import 'package:boitex_info_app/widgets/logistics_report_dialog.dart';
// 🏆 ✅ ADDED: Import for the new Podium Widget
import 'package:boitex_info_app/widgets/technician_podium.dart';

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
    initializeDateFormatting('fr_FR', null);
    _tabController = TabController(length: 3, vsync: this);
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
        // ✅ ADDED: Action Button to Open PDF Dialog
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.black87),
            tooltip: "Générer Rapport PDF",
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const LogisticsReportDialog(),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
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
            Tab(text: "Logistique"), // This is the PRO tab
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
              // ✅ WE USE A SEPARATE WIDGET FOR THE PRO TAB TO MANAGE ITS OWN DATE STATE
              LogisticsProTab(currentStats: stats),
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

  // --- 2. OPERATIONS TAB (UPDATED ONLY HERE) ---
  Widget _buildOperationsTab(AnalyticsStats stats) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Classement Techniciens (XP)", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
        const SizedBox(height: 8), // Adjusted spacing slightly

        // 🏆 REPLACED: Old BarChart with New Podium Widget
        // The rest of the page remains exactly the same.
        TechnicianPodium(topTechnicians: stats.topTechnicians),
      ],
    );
  }

  // --- 🏷️ HELPERS FOR GLOBAL TAB ---
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

// ==================================================================================
// 🌟 PRO LOGISTICS TAB (SEPARATE WIDGET FOR DATE STATE MANAGEMENT)
// ==================================================================================

class LogisticsProTab extends StatefulWidget {
  final AnalyticsStats currentStats;
  const LogisticsProTab({super.key, required this.currentStats});

  @override
  State<LogisticsProTab> createState() => _LogisticsProTabState();
}

class _LogisticsProTabState extends State<LogisticsProTab> {
  DateTime _selectedDate = DateTime.now();
  List<DailyStockStat> _historyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistoryForMonth(_selectedDate);
  }

  // 📅 QUERY FIRESTORE FOR SPECIFIC MONTH
  Future<void> _fetchHistoryForMonth(DateTime date) async {
    setState(() => _isLoading = true);

    final startOfMonth = DateTime(date.year, date.month, 1);
    final endOfMonth = DateTime(date.year, date.month + 1, 1);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('stock_history')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfMonth))
          .get();

      final dailyMap = <int, DailyStockStat>{}; // Day -> Stat

      // Process documents
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final change = (data['change'] ?? 0) as int;
        final day = timestamp.day;

        if (!dailyMap.containsKey(day)) {
          dailyMap[day] = DailyStockStat(date: timestamp, incoming: 0, outgoing: 0);
        }

        // Accumulate
        if (change > 0) {
          dailyMap[day] = DailyStockStat(
            date: timestamp,
            incoming: dailyMap[day]!.incoming + change,
            outgoing: dailyMap[day]!.outgoing,
          );
        } else {
          dailyMap[day] = DailyStockStat(
            date: timestamp,
            incoming: dailyMap[day]!.incoming,
            outgoing: dailyMap[day]!.outgoing + change.abs(),
          );
        }
      }

      // Convert Map to List and Sort
      final sortedList = dailyMap.values.toList()
        ..sort((a, b) => a.date.day.compareTo(b.date.day));

      setState(() {
        _historyData = sortedList;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint("Error fetching history: $e");
      setState(() => _isLoading = false);
    }
  }

  // 🗓️ SELECT DATE DIALOG
  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2022),
      lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF667EEA)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchHistoryForMonth(picked);
    }
  }

  void _changeMonth(int offset) {
    final newDate = DateTime(_selectedDate.year, _selectedDate.month + offset, 1);
    setState(() => _selectedDate = newDate);
    _fetchHistoryForMonth(newDate);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate Totals for the SELECTED month
    int totalIn = _historyData.fold(0, (sum, item) => sum + item.incoming);
    int totalOut = _historyData.fold(0, (sum, item) => sum + item.outgoing);
    int netChange = totalIn - totalOut;

    // Use Global Stats for Snapshot Data (Alerts, Health)
    int lowStock = widget.currentStats.stockHealth['low_stock'] ?? 0;
    int outOfStock = 5; // Example threshold
    int healthy = 100 - lowStock - outOfStock;

    final dateLabel = DateFormat.yMMMM('fr_FR').format(_selectedDate);
    final formattedDateLabel = dateLabel[0].toUpperCase() + dateLabel.substring(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🗓️ HEADER: DATE SELECTOR
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _changeMonth(-1)),
                GestureDetector(
                  onTap: _pickMonth,
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Color(0xFF667EEA)),
                      const SizedBox(width: 8),
                      Text(
                        formattedDateLabel,
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _changeMonth(1)),
              ],
            ),
          ),

          // 📊 DYNAMIC KPIS (Based on Selected Month)
          Row(
            children: [
              Expanded(
                child: _buildDetailedKpiCard(
                  "Entrées",
                  "+$totalIn",
                  Icons.arrow_circle_down_rounded,
                  Colors.green,
                  "Ce mois-ci",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockMovementsPage(type: StockMovementType.entry))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailedKpiCard(
                  "Sorties",
                  "-$totalOut",
                  Icons.arrow_circle_up_rounded,
                  Colors.redAccent,
                  "Ce mois-ci",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockMovementsPage(type: StockMovementType.exit))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDetailedKpiCard("Flux Net", "${netChange > 0 ? '+' : ''}$netChange", Icons.compare_arrows_rounded, netChange >= 0 ? Colors.blue : Colors.orange, "Variation")),
              const SizedBox(width: 12),
              Expanded(child: _buildDetailedKpiCard("Alertes", "$lowStock", Icons.warning_amber_rounded, Colors.orangeAccent, "Stock actuel", isAlert: true)),
            ],
          ),

          const SizedBox(height: 30),

          // 📈 PRO BAR CHART
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Flux Journaliers", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
              _buildLegendRow(),
            ],
          ),
          const SizedBox(height: 15),

          Container(
            height: 340,
            padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _historyData.isEmpty
                ? Center(child: Text("Aucun mouvement en $formattedDateLabel", style: GoogleFonts.poppins(color: Colors.grey)))
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _historyData.length < 7
                    ? MediaQuery.of(context).size.width - 64
                    : _historyData.length * 60.0,
                child: _buildLogisticsBarChart(_historyData),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // 🍩 DONUT CHART (Current Status)
          Text("Santé du Stock (Actuel)", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
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
                        PieChartSectionData(value: lowStock.toDouble(), color: Colors.orangeAccent, title: "$lowStock", radius: 50, titleStyle: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                        PieChartSectionData(value: outOfStock.toDouble(), color: Colors.redAccent, title: "$outOfStock", radius: 45, titleStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        PieChartSectionData(value: healthy.toDouble(), color: const Color(0xFF4CAF50), title: "", radius: 60),
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

  // --- CHART BUILDER ---
  Widget _buildLogisticsBarChart(List<DailyStockStat> history) {
    double maxY = 0;
    for (var stat in history) {
      if (stat.incoming > maxY) maxY = stat.incoming.toDouble();
      if (stat.outgoing > maxY) maxY = stat.outgoing.toDouble();
    }
    if (maxY == 0) maxY = 10;
    maxY = maxY * 1.1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.center,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (FlTouchEvent event, barTouchResponse) {
            if (!event.isInterestedForInteractions || barTouchResponse == null || barTouchResponse.spot == null) return;
            if (event is FlTapUpEvent) {
              // Navigate to Details on Tap
              final rodIndex = barTouchResponse.spot!.touchedRodDataIndex;
              final isEntry = rodIndex == 0;
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => StockMovementsPage(type: isEntry ? StockMovementType.entry : StockMovementType.exit)
              ));
            }
          },
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(12),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final isEntry = rodIndex == 0;
              final dateStr = DateFormat('d MMM', 'fr_FR').format(history[groupIndex].date);
              return BarTooltipItem(
                '$dateStr\n',
                GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                children: <TextSpan>[
                  TextSpan(
                    text: '${isEntry ? 'Entrées' : 'Sorties'}: ${rod.toY.toInt()}',
                    style: GoogleFonts.poppins(color: isEntry ? Colors.greenAccent : Colors.redAccent.shade100, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (double value, TitleMeta meta) {
                int index = value.toInt();
                if (index >= 0 && index < history.length) {
                  final date = history[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      children: [
                        Text(DateFormat('dd').format(date), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text(DateFormat('MMM', 'fr_FR').format(date), style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 5, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        groupsSpace: 25,
        barGroups: history.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(toY: stat.incoming.toDouble(), color: const Color(0xFF10B981), width: 14, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
              BarChartRodData(toY: stat.outgoing.toDouble(), color: const Color(0xFFEF4444), width: 14, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
            ],
          );
        }).toList(),
      ),
    );
  }

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
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
                if (onTap != null) Icon(Icons.chevron_right, size: 18, color: Colors.grey[300]),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87))),
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
        _buildLegendDot(const Color(0xFF10B981), "Entrées"),
        const SizedBox(width: 12),
        _buildLegendDot(const Color(0xFFEF4444), "Sorties"),
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
}
// lib/models/analytics_stats.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ NEW: Helper class for Daily History Chart
class DailyStockStat {
  final DateTime date;
  final int incoming;
  final int outgoing;

  DailyStockStat({required this.date, required this.incoming, required this.outgoing});
}

class CategoryStats {
  final int total;
  final int success;
  double get successRate => total > 0 ? (success / total) * 100 : 0.0;
  CategoryStats({required this.total, required this.success});

  factory CategoryStats.fromMap(Map<String, dynamic> data) {
    return CategoryStats(total: data['total'] ?? 0, success: data['success'] ?? 0);
  }
}

class AnalyticsStats {
  final int totalInterventionsMonth;
  final double successRate;
  final int pendingLivraisons;
  final Map<String, int> interventionsByType;
  final Map<String, int> interventionsByStatus;
  final Map<String, int> topTechnicians;
  final Map<String, int> stockHealth;
  final Map<String, CategoryStats> categoryPerformance;

  // ✅ NEW: List of history for the Line Chart
  final List<DailyStockStat> stockHistory;
  final DateTime lastUpdated;

  AnalyticsStats({
    required this.totalInterventionsMonth,
    required this.successRate,
    required this.pendingLivraisons,
    required this.interventionsByType,
    required this.interventionsByStatus,
    required this.topTechnicians,
    required this.stockHealth,
    required this.categoryPerformance,
    required this.stockHistory, // ✅ Required
    required this.lastUpdated,
  });

  factory AnalyticsStats.empty() {
    return AnalyticsStats(
      totalInterventionsMonth: 0,
      successRate: 0.0,
      pendingLivraisons: 0,
      interventionsByType: {},
      interventionsByStatus: {},
      topTechnicians: {},
      stockHealth: {},
      categoryPerformance: {},
      stockHistory: [],
      lastUpdated: DateTime.now(),
    );
  }

  static Map<String, int> _safeParseMap(Map<String, dynamic>? input) {
    if (input == null) return {};
    final result = <String, int>{};
    input.forEach((key, value) {
      if (value is int) result[key] = value;
      else if (value is double) result[key] = value.toInt();
    });
    return result;
  }

  factory AnalyticsStats.fromMap(Map<String, dynamic> data) {
    final rawCatPerf = data['category_performance'] as Map<String, dynamic>? ?? {};
    final parsedCatPerf = <String, CategoryStats>{};
    rawCatPerf.forEach((key, value) {
      if (value is Map<String, dynamic>) parsedCatPerf[key] = CategoryStats.fromMap(value);
    });

    // ✅ NEW: Advanced Parsing for Daily History
    // It reads the map {"2025-11-25": {"in": 5, "out": 2}} and converts to List
    final List<DailyStockStat> historyList = [];
    final rawStock = data['stock_health'] as Map<String, dynamic>? ?? {};

    if (rawStock.containsKey('daily_history') && rawStock['daily_history'] is Map) {
      final historyMap = rawStock['daily_history'] as Map<String, dynamic>;
      historyMap.forEach((dateKey, val) {
        if (val is Map) {
          try {
            // Parse Date from String (assuming format YYYY-MM-DD or similar)
            // If your keys are simple strings, we might need to adjust.
            // Ideally, store dates as ISO strings.
            final date = DateTime.tryParse(dateKey) ?? DateTime.now();
            historyList.add(DailyStockStat(
                date: date,
                incoming: val['in'] ?? 0,
                outgoing: val['out'] ?? 0
            ));
          } catch (e) {
            // Ignore bad dates
          }
        }
      });
    }

    // Sort by date so the chart flows correctly
    historyList.sort((a, b) => a.date.compareTo(b.date));

    return AnalyticsStats(
      totalInterventionsMonth: data['total_interventions_month'] ?? 0,
      successRate: (data['success_rate'] ?? 0).toDouble(),
      pendingLivraisons: data['livraisons_pending'] ?? 0,
      interventionsByType: _safeParseMap(data['interventions_by_type']),
      interventionsByStatus: _safeParseMap(data['interventions_by_status']),
      topTechnicians: _safeParseMap(data['top_technicians']),
      stockHealth: _safeParseMap(data['stock_health']),
      categoryPerformance: parsedCatPerf,
      stockHistory: historyList, // ✅ Added
      lastUpdated: (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
// lib/models/analytics_stats.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ NEW: Helper class for Technician Leaderboard (Supports Score + Count + Badge + Breakdown)
class TechnicianData {
  final String name;
  final int score;
  final int count;
  final String badge;
  final Map<String, int> breakdown; // 👈 NEW FIELD

  // Calculated: Average XP per Job (Efficiency)
  double get efficiency => count > 0 ? score / count : 0.0;

  TechnicianData({
    required this.name,
    required this.score,
    required this.count,
    this.badge = 'Polyvalent', // Default badge
    this.breakdown = const {}, // Default empty map
  });

  factory TechnicianData.fromMap(String name, Map<String, dynamic> data) {
    // Safely parse the breakdown map from Firestore
    Map<String, int> parsedBreakdown = {};
    if (data['breakdown'] != null && data['breakdown'] is Map) {
      (data['breakdown'] as Map).forEach((k, v) {
        parsedBreakdown[k.toString()] = (v is int) ? v : 0;
      });
    }

    return TechnicianData(
      name: name,
      score: (data['score'] ?? 0) as int,
      count: (data['count'] ?? 1) as int,
      badge: (data['badge'] ?? 'Polyvalent') as String,
      breakdown: parsedBreakdown, // 👈 Store the parsed map
    );
  }
}

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

  // 🔄 CHANGED: Now a List of Objects instead of a simple Map
  final List<TechnicianData> topTechnicians;

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
    required this.topTechnicians, // 👈 Updated Type
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
      topTechnicians: [], // 👈 Empty List
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
    // 🔄 NEW PARSING LOGIC FOR TECHNICIANS
    final List<TechnicianData> techList = [];
    final rawTechs = data['top_technicians'];

    if (rawTechs is Map<String, dynamic>) {
      rawTechs.forEach((key, value) {
        // Handle both old format (int) and new format (Map)
        if (value is Map<String, dynamic>) {
          techList.add(TechnicianData.fromMap(key, value));
        } else if (value is int) {
          // Fallback for old data to prevent crashes during migration
          techList.add(TechnicianData(name: key, score: value, count: 1));
        }
      });
    }
    // Sort by Score Descending
    techList.sort((a, b) => b.score.compareTo(a.score));

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
      topTechnicians: techList, // 👈 Assigned the list
      stockHealth: _safeParseMap(data['stock_health']),
      categoryPerformance: parsedCatPerf,
      stockHistory: historyList, // ✅ Added
      lastUpdated: (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
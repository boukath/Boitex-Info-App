// lib/models/analytics_stats.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper class to hold specific stats for a category (e.g., "Interventions")
class CategoryStats {
  final int total;
  final int success;

  // Computed property for easy UI access
  double get successRate => total > 0 ? (success / total) * 100 : 0.0;

  CategoryStats({required this.total, required this.success});

  factory CategoryStats.fromMap(Map<String, dynamic> data) {
    return CategoryStats(
      total: data['total'] ?? 0,
      success: data['success'] ?? 0,
    );
  }
}

class AnalyticsStats {
  // --- 1. Global KPIs ---
  final int totalInterventionsMonth;
  final double successRate;
  final int pendingLivraisons;

  // --- 2. Chart Data (Maps) ---
  final Map<String, int> interventionsByType;
  final Map<String, int> interventionsByStatus;

  // --- 3. Leaderboard ---
  final Map<String, int> topTechnicians;

  // --- 4. Logistics & Stock ---
  final Map<String, int> stockHealth;

  // --- 5. Detailed Category Performance (✅ NEW ADDITION) ---
  final Map<String, CategoryStats> categoryPerformance;

  // --- 6. Metadata ---
  final DateTime lastUpdated;

  AnalyticsStats({
    required this.totalInterventionsMonth,
    required this.successRate,
    required this.pendingLivraisons,
    required this.interventionsByType,
    required this.interventionsByStatus,
    required this.topTechnicians,
    required this.stockHealth,
    required this.categoryPerformance, // ✅ Required
    required this.lastUpdated,
  });

  /// Factory to create a clean empty object (Skeleton Loader state)
  factory AnalyticsStats.empty() {
    return AnalyticsStats(
      totalInterventionsMonth: 0,
      successRate: 0.0,
      pendingLivraisons: 0,
      interventionsByType: {},
      interventionsByStatus: {},
      topTechnicians: {},
      stockHealth: {},
      categoryPerformance: {}, // ✅ Initialize empty
      lastUpdated: DateTime.now(),
    );
  }

  // ✅ THE FIX: A helper that ignores Maps (like 'daily_history') and safe parses Integers
  static Map<String, int> _safeParseMap(Map<String, dynamic>? input) {
    if (input == null) return {};
    final result = <String, int>{};
    input.forEach((key, value) {
      if (value is int) {
        result[key] = value;
      } else if (value is double) {
        result[key] = value.toInt();
      }
      // If it's a Map (like daily_history), we simply skip it! No crash.
    });
    return result;
  }

  /// Parser: Converts Firestore Data -> Dart Object
  factory AnalyticsStats.fromMap(Map<String, dynamic> data) {
    // ✅ Logic to parse the nested 'category_performance' map safely
    final rawCatPerf = data['category_performance'] as Map<String, dynamic>? ?? {};
    final parsedCatPerf = <String, CategoryStats>{};

    rawCatPerf.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        parsedCatPerf[key] = CategoryStats.fromMap(value);
      }
    });

    return AnalyticsStats(
      totalInterventionsMonth: data['total_interventions_month'] ?? 0,

      // Handle double conversion safely
      successRate: (data['success_rate'] ?? 0).toDouble(),

      pendingLivraisons: data['livraisons_pending'] ?? 0,

      // ✅ Robust casting for Maps using _safeParseMap
      interventionsByType: _safeParseMap(data['interventions_by_type']),
      interventionsByStatus: _safeParseMap(data['interventions_by_status']),
      topTechnicians: _safeParseMap(data['top_technicians']),

      // ✅ Parse stock health safely (Ignores 'daily_history' map to fix crash)
      stockHealth: _safeParseMap(data['stock_health']),

      // ✅ Assign the parsed category stats
      categoryPerformance: parsedCatPerf,

      // Handle Timestamp conversion
      lastUpdated: (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
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

  /// Parser: Converts Firestore Data -> Dart Object
  factory AnalyticsStats.fromMap(Map<String, dynamic> data) {
    // ✅ Logic to parse the nested 'category_performance' map
    final rawCatPerf = data['category_performance'] as Map<String, dynamic>? ?? {};
    final parsedCatPerf = rawCatPerf.map(
            (key, value) => MapEntry(key, CategoryStats.fromMap(value as Map<String, dynamic>))
    );

    return AnalyticsStats(
      totalInterventionsMonth: data['total_interventions_month'] ?? 0,

      // Handle double conversion safely
      successRate: (data['success_rate'] ?? 0).toDouble(),

      pendingLivraisons: data['livraisons_pending'] ?? 0,

      // Robust casting for Maps
      interventionsByType: Map<String, int>.from(data['interventions_by_type'] ?? {}),
      interventionsByStatus: Map<String, int>.from(data['interventions_by_status'] ?? {}),
      topTechnicians: Map<String, int>.from(data['top_technicians'] ?? {}),

      // Parse stock health
      stockHealth: Map<String, int>.from(data['stock_health'] ?? {}),

      // ✅ Assign the parsed category stats
      categoryPerformance: parsedCatPerf,

      // Handle Timestamp conversion
      lastUpdated: (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
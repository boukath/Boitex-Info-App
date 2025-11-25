// lib/models/analytics_stats.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsStats {
  // --- 1. Global KPIs ---
  final int totalInterventionsMonth;
  final double successRate;
  final int pendingLivraisons;

  // --- 2. Chart Data (Maps) ---
  // Maps a category (e.g., "SAV") to a count (e.g., 40)
  final Map<String, int> interventionsByType;
  final Map<String, int> interventionsByStatus;

  // --- 3. Leaderboard ---
  final Map<String, int> topTechnicians;

  // --- 4. Logistics & Stock (✅ NEW ADDITION) ---
  final Map<String, int> stockHealth;

  // --- 5. Metadata ---
  final DateTime lastUpdated;

  AnalyticsStats({
    required this.totalInterventionsMonth,
    required this.successRate,
    required this.pendingLivraisons,
    required this.interventionsByType,
    required this.interventionsByStatus,
    required this.topTechnicians,
    required this.stockHealth, // ✅ Required in constructor
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
      stockHealth: {}, // ✅ Initialize empty map
      lastUpdated: DateTime.now(),
    );
  }

  /// Parser: Converts Firestore Data -> Dart Object
  factory AnalyticsStats.fromMap(Map<String, dynamic> data) {
    return AnalyticsStats(
      totalInterventionsMonth: data['total_interventions_month'] ?? 0,

      // Handle double conversion safely (Firestore sometimes returns ints for round numbers)
      successRate: (data['success_rate'] ?? 0).toDouble(),

      pendingLivraisons: data['livraisons_pending'] ?? 0,

      // Robust casting for Maps
      interventionsByType: Map<String, int>.from(data['interventions_by_type'] ?? {}),
      interventionsByStatus: Map<String, int>.from(data['interventions_by_status'] ?? {}),
      topTechnicians: Map<String, int>.from(data['top_technicians'] ?? {}),

      // ✅ Parse the stock health map safely
      stockHealth: Map<String, int>.from(data['stock_health'] ?? {}),

      // Handle Timestamp conversion
      lastUpdated: (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
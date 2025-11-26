// lib/services/analytics_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/analytics_stats.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ⚡️ PRO TIP: Set this to TRUE to design the UI without cost/data.
  // Set to FALSE when you are ready to ship to production.
  // ✅ UPDATE: Switched to FALSE. We are now LIVE!
  static const bool _useMockData = false;

  /// Returns a stream of stats.
  /// Using a Stream ensures the dashboard updates in real-time
  /// if a new intervention is added.
  Stream<AnalyticsStats> getStatsStream() {
    if (_useMockData) {
      return _getMockStats();
    } else {
      return _getRealStats();
    }
  }

  /// ---------------------------------------------------------
  /// 🟢 REAL FIRESTORE IMPLEMENTATION
  /// ---------------------------------------------------------
  Stream<AnalyticsStats> _getRealStats() {
    return _firestore
        .collection('analytics_dashboard')
        .doc('stats_overview')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        // Return skeleton/empty data if the document doesn't exist yet
        return AnalyticsStats.empty();
      }
      return AnalyticsStats.fromMap(snapshot.data()!);
    });
  }

  /// ---------------------------------------------------------
  /// 🟡 MOCK IMPLEMENTATION (For Development)
  /// ---------------------------------------------------------
  Stream<AnalyticsStats> _getMockStats() async* {
    // Simulate a network delay (1.5 seconds) so you can test
    // your "Loading Shimmer" animations.
    await Future.delayed(const Duration(milliseconds: 1500));

    yield AnalyticsStats(
      totalInterventionsMonth: 142,
      successRate: 94.5, // 94.5% success
      pendingLivraisons: 12,

      // Chart 1 Data: Breakdown by Service
      interventionsByType: {
        'Interventions': 45,
        'Installations': 78,
        'Service IT': 19,
        'Livraisons': 30,
        'Missions': 10,
        'SAV': 5,
      },

      // Chart 2 Data: Status
      interventionsByStatus: {
        'Terminé': 125,
        'En cours': 12,
        'Annulé': 5,
      },

      // Leaderboard Data
      topTechnicians: {
        'Amine S.': 42,
        'Sarah K.': 38,
        'Mohamed B.': 31,
        'Yacine D.': 25,
      },

      // ✅ ADDED: Dummy Stock Health Data
      stockHealth: {
        'low_stock': 3,
        'movements_in': 25,
        'movements_out': 18,
      },

      // ✅ ADDED: Dummy Category Performance Data (Fixes the Error)
      categoryPerformance: {
        'Interventions': CategoryStats(total: 50, success: 45),
        'Installations': CategoryStats(total: 80, success: 78),
        'Livraisons': CategoryStats(total: 35, success: 30),
        'Missions': CategoryStats(total: 12, success: 10),
        'SAV': CategoryStats(total: 8, success: 5),
      },

      // ✅ FIXED: Added missing stockHistory parameter for the compiler
      stockHistory: [
        DailyStockStat(date: DateTime.now().subtract(const Duration(days: 5)), incoming: 5, outgoing: 2),
        DailyStockStat(date: DateTime.now().subtract(const Duration(days: 4)), incoming: 8, outgoing: 4),
        DailyStockStat(date: DateTime.now().subtract(const Duration(days: 3)), incoming: 2, outgoing: 6),
        DailyStockStat(date: DateTime.now().subtract(const Duration(days: 2)), incoming: 10, outgoing: 3),
        DailyStockStat(date: DateTime.now().subtract(const Duration(days: 1)), incoming: 4, outgoing: 8),
      ],

      lastUpdated: DateTime.now(),
    );
  }
}